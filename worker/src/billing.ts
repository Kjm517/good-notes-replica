import {
  createWalletCheckout,
  extractPaymentIntentId,
  extractWebhookMetadata,
  retrievePaymentIntent,
  verifyPayMongoWebhookSignature,
  type PayMongoWallet,
} from './paymongo';
import { resolveVoucherDiscount, validateVoucherPublic } from './vouchers';

export type PaidBillingPlan = 'monthly' | 'yearly';
export type BillingPlan = PaidBillingPlan | 'lifetime';

export const LIFETIME_EXPIRES_AT = '9999-12-31T23:59:59.000Z';

export interface BillingRecord {
  isPremium: boolean;
  plan: BillingPlan | null;
  expiresAt: string | null;
  source: 'paymongo';
  paymentIntentId?: string;
  wallet?: PayMongoWallet;
  updatedAt: string;
}

const PLAN_AMOUNTS_CENTAVOS: Record<PaidBillingPlan, number> = {
  monthly: 19900,
  yearly: 149900,
};

/** Admin lifetime grants, or any expiry in year 2099+. */
export function isLifetimeExpiry(expiresAt: string | null | undefined): boolean {
  if (!expiresAt) return true;
  const year = new Date(expiresAt).getUTCFullYear();
  return Number.isFinite(year) && year >= 2099;
}

export function isLifetimeRecord(
  record: Pick<BillingRecord, 'plan' | 'expiresAt'>,
): boolean {
  return record.plan === 'lifetime' || isLifetimeExpiry(record.expiresAt);
}

function billingKey(uid: string): string {
  return `users/${uid}/billing.json`;
}

export function payMongoConfigured(env: {
  PAYMONGO_SECRET_KEY?: string;
}): boolean {
  return Boolean(env.PAYMONGO_SECRET_KEY?.trim());
}

export async function amountCentavosForPlan(
  bucket: R2Bucket,
  plan: PaidBillingPlan,
  voucher?: string | null,
): Promise<number> {
  const base = PLAN_AMOUNTS_CENTAVOS[plan];
  const resolved = await resolveVoucherDiscount(bucket, voucher);
  if (resolved) {
    return Math.max(2000, Math.round(base * (1 - resolved.discountRate)));
  }
  return base;
}

export async function handleBillingVoucherValidate(
  env: { BUCKET: R2Bucket },
  code: string,
): Promise<Response> {
  if (!code.trim()) return json({ error: 'Missing code.' }, 400);
  const result = await validateVoucherPublic(env.BUCKET, code);
  return json(result);
}

export async function readBillingRecord(
  bucket: R2Bucket,
  uid: string,
): Promise<BillingRecord | null> {
  const object = await bucket.get(billingKey(uid));
  if (!object) return null;
  try {
    return JSON.parse(await object.text()) as BillingRecord;
  } catch {
    return null;
  }
}

export async function writeBillingRecord(
  bucket: R2Bucket,
  uid: string,
  record: BillingRecord,
): Promise<void> {
  await bucket.put(billingKey(uid), JSON.stringify(record), {
    httpMetadata: { contentType: 'application/json' },
  });
}

function addPlanDuration(from: Date, plan: PaidBillingPlan): Date {
  const next = new Date(from);
  if (plan === 'yearly') {
    next.setUTCDate(next.getUTCDate() + 365);
  } else {
    next.setUTCDate(next.getUTCDate() + 30);
  }
  return next;
}

export async function grantPremiumFromPayment(
  bucket: R2Bucket,
  uid: string,
  plan: PaidBillingPlan,
  opts?: { paymentIntentId?: string; wallet?: PayMongoWallet },
): Promise<BillingRecord> {
  const existing = await readBillingRecord(bucket, uid);
  const now = new Date();
  let base = now;
  if (existing?.expiresAt) {
    const currentExpiry = new Date(existing.expiresAt);
    if (currentExpiry > now) base = currentExpiry;
  }

  const record: BillingRecord = {
    isPremium: true,
    plan,
    expiresAt: addPlanDuration(base, plan).toISOString(),
    source: 'paymongo',
    paymentIntentId: opts?.paymentIntentId,
    wallet: opts?.wallet,
    updatedAt: now.toISOString(),
  };
  await writeBillingRecord(bucket, uid, record);
  return record;
}

export function entitlementResponse(record: BillingRecord | null) {
  if (!record?.isPremium) {
    return { isPremium: false, plan: null, expiresAt: null, source: null };
  }
  // Lifetime: no expiry, far-future expiry, or explicit lifetime plan.
  // Previously `!expiresAt` was treated as not premium, so admin lifetime
  // grants never reached the app.
  if (isLifetimeRecord(record)) {
    return {
      isPremium: true,
      plan: 'lifetime' as const,
      expiresAt: null,
      source: record.source,
      wallet: record.wallet ?? null,
    };
  }
  const expiresAt = new Date(record.expiresAt!);
  if (Number.isNaN(expiresAt.getTime()) || expiresAt.getTime() <= Date.now()) {
    return { isPremium: false, plan: null, expiresAt: null, source: null };
  }
  return {
    isPremium: true,
    plan: record.plan,
    expiresAt: record.expiresAt,
    source: record.source,
    wallet: record.wallet ?? null,
  };
}

export async function handleBillingCheckout(
  request: Request,
  env: {
    BUCKET: R2Bucket;
    PAYMONGO_SECRET_KEY?: string;
  },
  uid: string,
  workerOrigin: string,
): Promise<Response> {
  if (!payMongoConfigured(env)) {
    return json({ error: 'PayMongo is not configured on this worker.' }, 503);
  }

  const body = (await request.json()) as {
    plan?: PaidBillingPlan;
    wallet?: PayMongoWallet;
    voucher?: string | null;
  };

  const plan = body.plan;
  const wallet = body.wallet;
  if (plan !== 'monthly' && plan !== 'yearly') {
    return json({ error: 'Invalid plan.' }, 400);
  }
  if (wallet !== 'gcash' && wallet !== 'paymaya') {
    return json({ error: 'Invalid wallet.' }, 400);
  }

  const amountCentavos = await amountCentavosForPlan(
    env.BUCKET,
    plan,
    body.voucher,
  );
  const returnUrl = `${workerOrigin}/billing/return`;
  const secretKey = env.PAYMONGO_SECRET_KEY!;

  const checkout = await createWalletCheckout(secretKey, {
    amountCentavos,
    wallet,
    returnUrl,
    description: `Notably Premium ${plan}`,
    metadata: {
      uid,
      plan,
      wallet,
    },
  });

  return json({
    redirectUrl: checkout.redirectUrl,
    paymentIntentId: checkout.paymentIntentId,
    amountCentavos,
    plan,
    wallet,
  });
}

export async function handleBillingEntitlement(
  env: { BUCKET: R2Bucket },
  uid: string,
): Promise<Response> {
  const record = await readBillingRecord(env.BUCKET, uid);
  return json(entitlementResponse(record));
}

export async function handleBillingReturn(
  request: Request,
  env: {
    BUCKET: R2Bucket;
    PAYMONGO_SECRET_KEY?: string;
  },
): Promise<Response> {
  const url = new URL(request.url);
  const paymentIntentId =
    url.searchParams.get('payment_intent_id') ??
    url.searchParams.get('payment_intent');

  if (paymentIntentId && payMongoConfigured(env)) {
    try {
      const intent = await retrievePaymentIntent(
        env.PAYMONGO_SECRET_KEY!,
        paymentIntentId,
      );
      if (intent.status === 'succeeded') {
        const uid = intent.metadata.uid;
        const plan = intent.metadata.plan as BillingPlan | undefined;
        const wallet = intent.metadata.wallet as PayMongoWallet | undefined;
        if (uid && (plan === 'monthly' || plan === 'yearly')) {
          await grantPremiumFromPayment(env.BUCKET, uid, plan, {
            paymentIntentId,
            wallet,
          });
        }
      }
    } catch {
      // The return page still renders; webhooks remain the primary path.
    }
  }

  return htmlReturnPage(url.searchParams.get('status'));
}

export async function handleBillingWebhook(
  request: Request,
  env: {
    BUCKET: R2Bucket;
    PAYMONGO_SECRET_KEY?: string;
    PAYMONGO_WEBHOOK_SECRET?: string;
  },
): Promise<Response> {
  const payload = await request.text();
  const signature = request.headers.get('Paymongo-Signature');

  if (env.PAYMONGO_WEBHOOK_SECRET) {
    const valid = await verifyPayMongoWebhookSignature(
      payload,
      signature,
      env.PAYMONGO_WEBHOOK_SECRET,
    );
    if (!valid) return json({ error: 'Invalid webhook signature.' }, 401);
  }

  let body: unknown;
  try {
    body = JSON.parse(payload);
  } catch {
    return json({ error: 'Invalid JSON.' }, 400);
  }

  const eventType =
    typeof body === 'object' && body !== null
      ? (body as { data?: { attributes?: { type?: string } } }).data?.attributes
          ?.type
      : null;

  if (eventType !== 'payment.paid' && eventType !== 'payment.failed') {
    return json({ ok: true, ignored: true });
  }

  if (eventType === 'payment.failed') {
    return json({ ok: true });
  }

  let metadata = extractWebhookMetadata(body);
  let paymentIntentId = extractPaymentIntentId(body);

  if (
    payMongoConfigured(env) &&
    paymentIntentId &&
    (!metadata.uid || !metadata.plan)
  ) {
    try {
      const intent = await retrievePaymentIntent(
        env.PAYMONGO_SECRET_KEY!,
        paymentIntentId,
      );
      metadata = { ...metadata, ...intent.metadata };
    } catch {
      // Fall through — metadata on the webhook may still be enough.
    }
  }

  const uid = metadata.uid;
  const plan = metadata.plan as BillingPlan | undefined;
  const wallet = metadata.wallet as PayMongoWallet | undefined;

  if (uid && (plan === 'monthly' || plan === 'yearly')) {
    await grantPremiumFromPayment(env.BUCKET, uid, plan, {
      paymentIntentId: paymentIntentId ?? undefined,
      wallet,
    });
  }

  return json({ ok: true });
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function htmlReturnPage(status: string | null): Response {
  const paid = status !== 'failed';
  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Notably · Payment</title>
  <style>
    body { font-family: system-ui, sans-serif; background:#111; color:#f5f5f5;
      display:flex; min-height:100vh; align-items:center; justify-content:center;
      margin:0; padding:24px; }
    .card { max-width:420px; background:#1c1c1c; border:1px solid #333;
      border-radius:16px; padding:28px; text-align:center; }
    h1 { font-size:22px; margin:0 0 8px; }
    p { color:#aaa; line-height:1.5; margin:0; }
  </style>
</head>
<body>
  <div class="card">
    <h1>${paid ? 'Payment received' : 'Payment incomplete'}</h1>
    <p>${paid
      ? 'Return to the Notably app — Premium unlocks automatically once payment is confirmed.'
      : 'You can close this page and try again from Notably.'}</p>
  </div>
</body>
</html>`;
  return new Response(html, {
    status: 200,
    headers: { 'Content-Type': 'text/html; charset=utf-8' },
  });
}
