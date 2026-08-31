/**
 * Notably file service.
 *
 * Notes sync via Supabase Postgres; source files (PDFs, images) live in
 * Cloudflare R2 — 10 GB free with no egress charges, which matters when a
 * single textbook is 150 MB.
 *
 * R2 credentials must never ship inside the app, so this Worker sits in
 * front: it verifies the caller's Supabase access token, then reads or writes
 * objects strictly under that user's own `users/{uid}/` prefix.
 *
 * Billing (PayMongo card / GCash / Maya) uses the same auth and stores entitlement
 * JSON beside each user's files in R2.
 */

import { requireUid } from './auth';
import { handleAdmin } from './admin';
import { handleUserTelemetry } from './user-telemetry';
import { deleteDeviceToken, saveDeviceToken } from './notifications';
import {
  handleBillingCheckout,
  handleBillingEntitlement,
  handleBillingPayments,
  handleBillingReturn,
  handleBillingStatus,
  handleBillingWebhook,
  handleBillingVoucherValidate,
  payMongoConfigured,
} from './billing';

export interface Env {
  /** R2 bucket binding (see wrangler.toml). */
  BUCKET: R2Bucket;
  /** Firebase service-account JSON, for FCM push. Optional. */
  FIREBASE_SERVICE_ACCOUNT?: string;
  /** Supabase project URL, e.g. https://xxxx.supabase.co */
  SUPABASE_URL: string;
  /** Public anon key — admins lookups with the caller's JWT. */
  SUPABASE_ANON_KEY?: string;
  /** Supabase JWT secret — optional if project uses ES256 signing keys (JWKS). */
  SUPABASE_JWT_SECRET?: string;
  /** Service role — create admin Auth users. Never expose to the Flutter app. */
  SUPABASE_SERVICE_ROLE_KEY?: string;
  /** PayMongo secret API key — set via `wrangler secret put PAYMONGO_SECRET_KEY`. */
  PAYMONGO_SECRET_KEY?: string;
  /** PayMongo webhook signing secret — `wrangler secret put PAYMONGO_WEBHOOK_SECRET`. */
  PAYMONGO_WEBHOOK_SECRET?: string;
  /** Bootstrap super-admin Supabase UUIDs (comma-separated). */
  ADMIN_UIDS?: string;
}

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET,HEAD,PUT,POST,PATCH,DELETE,OPTIONS',
  'Access-Control-Allow-Headers': 'Authorization,Content-Type',
  'Access-Control-Max-Age': '86400',
};

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    const url = new URL(request.url);

    // ---- Admin (voucher management) ---------------------------------
    if (url.pathname.startsWith('/admin/')) {
      return handleAdminRoutes(request, env, url);
    }

    // ---- User telemetry (heartbeat, bugs, AI usage) -----------------
    if (url.pathname.startsWith('/user/')) {
      return handleUserRoutes(request, env, url);
    }

    // ---- Billing (PayMongo) -----------------------------------------
    if (url.pathname.startsWith('/billing/')) {
      return handleBilling(request, env, url);
    }

    const key = url.searchParams.get('key');

    let uid: string;
    try {
      uid = await requireUid(request, env);
    } catch (e) {
      return json({ error: (e as Error).message }, 401);
    }

    if (!key) return json({ error: 'Missing "key" parameter.' }, 400);

    // Hard scoping: a token for one user can only ever touch that user's
    // prefix, whatever key string they send.
    const objectKey = `users/${uid}/${stripLeadingSlashes(key)}`;

    switch (`${request.method} ${url.pathname}`) {
      case 'PUT /file': {
        await env.BUCKET.put(objectKey, request.body, {
          httpMetadata: {
            contentType:
              request.headers.get('content-type') ?? 'application/octet-stream',
          },
        });
        return json({ ok: true, key: objectKey });
      }

      case 'GET /file': {
        const object = await env.BUCKET.get(objectKey);
        if (!object) return json({ error: 'Not found' }, 404);
        const headers = new Headers(CORS_HEADERS);
        object.writeHttpMetadata(headers);
        headers.set('etag', object.httpEtag);
        return new Response(object.body, { headers });
      }

      case 'GET /head': {
        const object = await env.BUCKET.head(objectKey);
        return object
          ? json({ exists: true, size: object.size })
          : json({ exists: false });
      }

      // ---- Multipart upload -------------------------------------------
      case 'POST /multipart/create': {
        const upload = await env.BUCKET.createMultipartUpload(objectKey, {
          httpMetadata: {
            contentType:
              url.searchParams.get('mime') ?? 'application/octet-stream',
          },
        });
        return json({ uploadId: upload.uploadId, key: objectKey });
      }

      case 'PUT /multipart/part': {
        const uploadId = url.searchParams.get('uploadId');
        const partNumber = Number(url.searchParams.get('part'));
        if (!uploadId || !Number.isInteger(partNumber) || partNumber < 1) {
          return json({ error: 'Missing uploadId or part number.' }, 400);
        }
        if (!request.body) return json({ error: 'Empty part.' }, 400);
        const upload = env.BUCKET.resumeMultipartUpload(objectKey, uploadId);
        const part = await upload.uploadPart(
          partNumber,
          await request.arrayBuffer(),
        );
        return json({ partNumber: part.partNumber, etag: part.etag });
      }

      case 'POST /multipart/complete': {
        const uploadId = url.searchParams.get('uploadId');
        if (!uploadId) return json({ error: 'Missing uploadId.' }, 400);
        const body = (await request.json()) as {
          parts?: { partNumber: number; etag: string }[];
        };
        const parts = body.parts ?? [];
        if (parts.length === 0) return json({ error: 'No parts.' }, 400);
        const upload = env.BUCKET.resumeMultipartUpload(objectKey, uploadId);
        await upload.complete(parts);
        return json({ ok: true, key: objectKey });
      }

      case 'POST /multipart/abort': {
        const uploadId = url.searchParams.get('uploadId');
        if (!uploadId) return json({ error: 'Missing uploadId.' }, 400);
        await env.BUCKET.resumeMultipartUpload(objectKey, uploadId).abort();
        return json({ ok: true });
      }

      case 'POST /delete': {
        await env.BUCKET.delete(objectKey);
        return json({ ok: true });
      }

      default:
        return json({ error: 'Not found' }, 404);
    }
  },
};

async function handleUserRoutes(
  request: Request,
  env: Env,
  url: URL,
): Promise<Response> {
  try {
    const route = `${request.method} ${url.pathname}`;

    // Device push tokens. Registered by the app after the user allows
    // notifications, and deleted on sign-out so a shared phone does not keep
    // receiving the previous account's pushes.
    if (route === 'POST /user/devices' || route === 'DELETE /user/devices') {
      const uid = await requireUid(request, env);
      const body = (await request.json()) as {
        token?: string;
        platform?: string;
      };
      const token = body.token?.trim();
      if (!token) return withCors(json({ error: 'Missing token.' }, 400));

      if (request.method === 'DELETE') {
        await deleteDeviceToken(env.BUCKET, uid, token);
        return withCors(json({ ok: true }));
      }

      const platform =
        body.platform === 'ios' || body.platform === 'web'
          ? body.platform
          : 'android';
      await saveDeviceToken(env.BUCKET, uid, token, platform);
      return withCors(json({ ok: true }));
    }

    return withCors(await handleUserTelemetry(request, env, url));
  } catch (e) {
    const message = (e as Error).message;
    const status = message.includes('Authorization') ? 401 : 500;
    return withCors(json({ error: message }, status));
  }
}

async function handleAdminRoutes(
  request: Request,
  env: Env,
  url: URL,
): Promise<Response> {
  try {
    return withCors(await handleAdmin(request, env, url));
  } catch (e) {
    const message = (e as Error).message;
    let status = 500;
    if (message.includes('Authorization')) status = 401;
    // 503, not 403: the admins table could not be read, so this is the
    // service being unable to answer rather than the caller being refused.
    // Reporting it as 403 is what makes a broken RLS policy look like a
    // missing account.
    else if ((e as Error).name === 'AdminCheckUnavailable') status = 503;
    else if (message.includes('Admin access')) status = 403;
    return withCors(json({ error: message }, status));
  }
}

async function handleBilling(
  request: Request,
  env: Env,
  url: URL,
): Promise<Response> {
  const route = `${request.method} ${url.pathname}`;
  const origin = url.origin;

  try {
    switch (route) {
      case 'GET /billing/config':
        return withCors(
          json({
            paymongo: payMongoConfigured(env),
            wallets: ['card', 'gcash', 'paymaya'],
            methods: ['card', 'gcash', 'paymaya', 'qrph'],
          }),
        );

      case 'GET /billing/return':
        return withCors(await handleBillingReturn(request, env));

      case 'POST /billing/webhook':
        return withCors(await handleBillingWebhook(request, env));

      case 'POST /billing/checkout': {
        const uid = await requireUid(request, env);
        return withCors(
          await handleBillingCheckout(request, env, uid, origin),
        );
      }

      case 'GET /billing/status': {
        const uid = await requireUid(request, env);
        return withCors(
          await handleBillingStatus(
            env,
            uid,
            url.searchParams.get('paymentIntentId'),
          ),
        );
      }

      case 'GET /billing/payments': {
        const uid = await requireUid(request, env);
        return withCors(await handleBillingPayments(env, uid));
      }

      case 'GET /billing/entitlement': {
        const uid = await requireUid(request, env);
        return withCors(await handleBillingEntitlement(env, uid));
      }

      case 'GET /billing/vouchers/validate': {
        const code = url.searchParams.get('code') ?? '';
        return withCors(await handleBillingVoucherValidate(env, code));
      }

      default:
        return withCors(json({ error: 'Not found' }, 404));
    }
  } catch (e) {
    const message = (e as Error).message;
    const status = message.includes('Authorization') ? 401 : 500;
    return withCors(json({ error: message }, status));
  }
}

function stripLeadingSlashes(key: string): string {
  return key.replace(/^\/+/, '');
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}

function withCors(response: Response): Response {
  const headers = new Headers(response.headers);
  for (const [key, value] of Object.entries(CORS_HEADERS)) {
    headers.set(key, value);
  }
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}
