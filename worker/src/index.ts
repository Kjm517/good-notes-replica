/**
 * Notably file service.
 *
 * The app stores notes and annotations in Firestore, but the source files
 * (PDFs, images) live in Cloudflare R2 — 10 GB free with no egress charges,
 * which matters when a single textbook is 150 MB.
 *
 * R2 credentials must never ship inside the app, so this Worker sits in
 * front: it verifies the caller's Firebase ID token, then reads or writes
 * objects strictly under that user's own `users/{uid}/` prefix.
 */

export interface Env {
  /** R2 bucket binding (see wrangler.toml). */
  BUCKET: R2Bucket;
  /** Firebase project id — tokens must be issued for this project. */
  FIREBASE_PROJECT_ID: string;
}

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET,PUT,POST,OPTIONS',
  'Access-Control-Allow-Headers': 'Authorization,Content-Type',
  'Access-Control-Max-Age': '86400',
};

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    const url = new URL(request.url);
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
      // A Worker request body is capped (100 MB on the free plan) and a
      // phone cannot hold a textbook in memory anyway, so large files arrive
      // a part at a time and R2 stitches them together.
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
        // R2 needs a known length per part, and the app sends fixed-size
        // chunks, so buffering one part here is bounded and safe.
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

function stripLeadingSlashes(key: string): string {
  return key.replace(/^\/+/, '');
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}

/** Extracts and verifies the Firebase ID token, returning the user's uid. */
async function requireUid(request: Request, env: Env): Promise<string> {
  const header = request.headers.get('Authorization') ?? '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';
  if (!token) throw new Error('Missing Authorization header.');
  return verifyFirebaseToken(token, env.FIREBASE_PROJECT_ID);
}

/**
 * Verifies a Firebase ID token: RS256 signature against Google's published
 * certificates, plus issuer, audience and expiry.
 */
async function verifyFirebaseToken(
  token: string,
  projectId: string,
): Promise<string> {
  const [rawHeader, rawPayload, rawSignature] = token.split('.');
  if (!rawHeader || !rawPayload || !rawSignature) {
    throw new Error('Malformed token.');
  }

  const header = JSON.parse(decodeBase64Url(rawHeader)) as {
    alg: string;
    kid: string;
  };
  const payload = JSON.parse(decodeBase64Url(rawPayload)) as {
    aud: string;
    iss: string;
    sub: string;
    exp: number;
  };

  if (header.alg !== 'RS256') throw new Error('Unexpected token algorithm.');
  if (payload.aud !== projectId) throw new Error('Token is for another app.');
  if (payload.iss !== `https://securetoken.google.com/${projectId}`) {
    throw new Error('Unexpected token issuer.');
  }
  if (payload.exp * 1000 < Date.now()) throw new Error('Token expired.');
  if (!payload.sub) throw new Error('Token has no subject.');

  const certificate = await googleCertificate(header.kid);
  const key = await crypto.subtle.importKey(
    'spki',
    pemToArrayBuffer(certificate),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify'],
  );

  const valid = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    key,
    base64UrlToBytes(rawSignature),
    new TextEncoder().encode(`${rawHeader}.${rawPayload}`),
  );
  if (!valid) throw new Error('Invalid token signature.');

  return payload.sub;
}

/** Google's signing certificates, cached by the Workers HTTP cache. */
async function googleCertificate(kid: string): Promise<string> {
  const response = await fetch(
    'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com',
    { cf: { cacheTtl: 3600, cacheEverything: true } },
  );
  const certificates = (await response.json()) as Record<string, string>;
  const certificate = certificates[kid];
  if (!certificate) throw new Error('Unknown token key id.');
  return certificate;
}

function decodeBase64Url(value: string): string {
  return new TextDecoder().decode(base64UrlToBytes(value));
}

function base64UrlToBytes(value: string): Uint8Array {
  const base64 = value.replace(/-/g, '+').replace(/_/g, '/');
  const padded = base64.padEnd(
    base64.length + ((4 - (base64.length % 4)) % 4),
    '=',
  );
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const body = pem
    .replace(/-----BEGIN CERTIFICATE-----/, '')
    .replace(/-----END CERTIFICATE-----/, '')
    .replace(/\s+/g, '');
  return spkiFromCertificate(base64UrlToBytes(body.replace(/\+/g, '-').replace(/\//g, '_')));
}

/**
 * Google publishes X.509 certificates but WebCrypto wants a bare SPKI public
 * key, so pull the SubjectPublicKeyInfo out of the DER structure.
 */
function spkiFromCertificate(der: Uint8Array): ArrayBuffer {
  // Walk the DER looking for the RSA algorithm identifier that starts the
  // SubjectPublicKeyInfo block.
  const marker = [0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d,
    0x01, 0x01, 0x01];
  for (let i = 0; i < der.length - marker.length; i++) {
    let hit = true;
    for (let j = 0; j < marker.length; j++) {
      if (der[i + j] !== marker[j]) {
        hit = false;
        break;
      }
    }
    if (!hit) continue;

    // The SPKI SEQUENCE starts just before this identifier; find its header.
    for (let start = i - 4; start >= 0; start--) {
      if (der[start] === 0x30 && der[start + 1] === 0x82) {
        const length = (der[start + 2] << 8) | der[start + 3];
        return der.slice(start, start + 4 + length).buffer as ArrayBuffer;
      }
    }
  }
  throw new Error('Could not read public key from certificate.');
}
