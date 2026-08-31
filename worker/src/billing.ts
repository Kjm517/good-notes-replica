import {
  createMethodCheckout,
  extractPaymentIntentId,
  extractWebhookEventType,
  extractWebhookMetadata,
  isPayMongoMethod,
  retrievePaymentIntent,
  verifyPayMongoWebhookSignature,
  type PayMongoMethod,
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
  /** Payment method used: card | gcash | paymaya */
  wallet?: PayMongoMethod;
  updatedAt: string;
}

/** PayMongo rejects any charge below ₱20. */
const PAYMONGO_MINIMUM_CENTAVOS = 2000;

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
  if (base <= 0) return 0;
  const resolved = await resolveVoucherDiscount(bucket, voucher);
  if (resolved) {
    const discounted =
      resolved.discountKind === 'amount' &&
      (resolved.discountAmountCentavos ?? 0) > 0
        ? base - (resolved.discountAmountCentavos ?? 0)
        : Math.round(base * (1 - resolved.discountRate));

    // Free is free — the caller grants premium without touching PayMongo.
    if (discounted <= 0) return 0;
    // Anything still payable must clear PayMongo's ₱20 minimum, or checkout
    // fails with an error the user cannot act on. This floor once applied to
    // percentage vouchers only, so a large peso-off code produced an
    // unchargeable amount.
    return Math.max(PAYMONGO_MINIMUM_CENTAVOS, discounted);
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

/** One settled payment. Appended per successful charge, never overwritten. */
export interface PaymentLedgerEntry {
  paymentIntentId?: string;
  plan: PaidBillingPlan;
  /** card | gcash | paymaya | qrph, or absent for admin/voucher grants. */
  method?: PayMongoMethod;
  amountCentavos: number;
  paidAt: string;
  /** Expiry this payment bought, after any stacking onto an existing term. */
  expiresAt: string;
}

function paymentsKey(uid: string): string {
  return `users/${uid}/payments.json`;
}

export async function readPaymentLedger(
  bucket: R2Bucket,
  uid: string,
): Promise<PaymentLedgerEntry[]> {
  const object = await bucket.get(paymentsKey(uid));
  if (!object) return [];
  try {
    const parsed = JSON.parse(await object.text());
    return Array.isArray(parsed) ? (parsed as PaymentLedgerEntry[]) : [];
  } catch {
    return [];
  }
}

async function appendPaymentLedger(
  bucket: R2Bucket,
  uid: string,
  entry: PaymentLedgerEntry,
): Promise<void> {
  const entries = await readPaymentLedger(bucket, uid);
  // The caller already deduped by intent id, but a webhook and a status poll
  // racing on the same intent could still both land here.
  if (
    entry.paymentIntentId &&
    entries.some((e) => e.paymentIntentId === entry.paymentIntentId)
  ) {
    return;
  }
  entries.push(entry);
  await bucket.put(paymentsKey(uid), JSON.stringify(entries), {
    httpMetadata: { contentType: 'application/json' },
  });
}

export async function grantPremiumFromPayment(
  bucket: R2Bucket,
  uid: string,
  plan: PaidBillingPlan,
  opts?: {
    paymentIntentId?: string;
    wallet?: PayMongoMethod;
    /** Actually charged, in centavos. Falls back to list price when unknown. */
    amountCentavos?: number | null;
  },
): Promise<BillingRecord> {
  const existing = await readBillingRecord(bucket, uid);

  // Idempotency: the status endpoint polls every few seconds while the payer
  // is looking at the QR, and the webhook / return page can fire for the same
  // intent too. Without this guard each poll would extend the expiry again.
  // Only PayMongo ids are deduped — voucher grants reuse their code as the id
  // and must stay redeemable for a later renewal.
  const dedupable =
    opts?.paymentIntentId != null &&
    (opts.paymentIntentId.startsWith('pi_') ||
      opts.paymentIntentId.startsWith('cs_'));
  if (
    dedupable &&
    existing?.isPremium &&
    existing.paymentIntentId === opts!.paymentIntentId
  ) {
    return existing;
  }

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

  // The billing record only ever holds the *latest* payment; the ledger is
  // what makes renewals and payment history visible in the admin console.
  await appendPaymentLedger(bucket, uid, {
    paymentIntentId: opts?.paymentIntentId,
    plan,
    method: opts?.wallet,
    // The real charge, not the list price — a voucher may have discounted it,
    // and recording the sticker price makes revenue reports disagree with
    // PayMongo's own numbers.
    amountCentavos: opts?.amountCentavos ?? PLAN_AMOUNTS_CENTAVOS[plan],
    paidAt: now.toISOString(),
    expiresAt: record.expiresAt!,
  });

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
  const body = (await request.json()) as {
    plan?: PaidBillingPlan;
    /** Preferred: card | gcash | paymaya | qrph */
    method?: string;
    /** Legacy alias for method */
    wallet?: string;
    voucher?: string | null;
  };

  const plan = body.plan;
  const methodRaw = body.method ?? body.wallet;
  if (plan !== 'monthly' && plan !== 'yearly') {
    return json({ error: 'Invalid plan.' }, 400);
  }
  if (!isPayMongoMethod(methodRaw)) {
    return json(
      { error: 'Invalid payment method. Use card, gcash, paymaya, or qrph.' },
      400,
    );
  }
  const method = methodRaw;

  const amountCentavos = await amountCentavosForPlan(
    env.BUCKET,
    plan,
    body.voucher,
  );

  if (amountCentavos <= 0) {
    const record = await grantPremiumFromPayment(env.BUCKET, uid, plan, {
      paymentIntentId: `voucher:${(body.voucher ?? 'free').trim()}`,
      wallet: method,
      amountCentavos: 0,
    });
    return json({
      granted: true,
      amountCentavos: 0,
      plan,
      wallet: method,
      method,
      expiresAt: record.expiresAt,
    });
  }

  if (!payMongoConfigured(env)) {
    return json({ error: 'PayMongo is not configured on this worker.' }, 503);
  }

  const returnUrl = `${workerOrigin}/billing/return`;
  const secretKey = env.PAYMONGO_SECRET_KEY!;

  const checkout = await createMethodCheckout(secretKey, {
    amountCentavos,
    method,
    returnUrl,
    cancelUrl: returnUrl,
    description: `Notably Premium ${plan}`,
    metadata: {
      uid,
      plan,
      wallet: method,
      method,
    },
  });

  return json({
    redirectUrl: checkout.redirectUrl,
    qrImageUrl: checkout.qrImageUrl,
    paymentIntentId: checkout.paymentIntentId,
    amountCentavos,
    plan,
    wallet: method,
    method,
  });
}

/// The caller's own payment history, newest first.
///
/// Same ledger the admin console reads, scoped to one uid — the app used to
/// keep this only in device prefs, so a reinstall or a second device showed an
/// empty history for someone who had paid.
export async function handleBillingPayments(
  env: { BUCKET: R2Bucket },
  uid: string,
): Promise<Response> {
  const entries = await readPaymentLedger(env.BUCKET, uid);
  const payments = [...entries].sort((a, b) =>
    (b.paidAt ?? '').localeCompare(a.paidAt ?? ''),
  );
  return json({ payments });
}

export async function handleBillingEntitlement(
  env: { BUCKET: R2Bucket },
  uid: string,
): Promise<Response> {
  const record = await readBillingRecord(env.BUCKET, uid);
  return json(entitlementResponse(record));
}

export type BillingPaymentStatus =
  | 'paid'
  | 'pending'
  | 'failed'
  | 'unknown';

/**
 * Polled by the QR checkout screen while the payer is scanning.
 *
 * Confirmation is server-side only: we ask PayMongo what the intent's status
 * is (or trust an already-written billing record). The client never asserts
 * that it paid, so there is nothing for it to lie about — the same reason the
 * webhook stays the primary grant path.
 */
export async function handleBillingStatus(
  env: {
    BUCKET: R2Bucket;
    PAYMONGO_SECRET_KEY?: string;
  },
  uid: string,
  paymentIntentId: string | null,
): Promise<Response> {
  if (!paymentIntentId?.trim()) {
    return json({ error: 'Missing paymentIntentId.' }, 400);
  }
  const intentId = paymentIntentId.trim();

  // Fast path: the webhook already landed for this intent.
  const record = await readBillingRecord(env.BUCKET, uid);
  if (record?.isPremium && record.paymentIntentId === intentId) {
    return json({ status: 'paid', ...entitlementResponse(record) });
  }

  // Card checkout sessions (cs_...) have no retrievable intent until PayMongo
  // creates one, so for those the webhook is the only signal.
  if (!intentId.startsWith('pi_') || !payMongoConfigured(env)) {
    return json({
      status: record?.isPremium ? 'paid' : 'pending',
      ...entitlementResponse(record ?? null),
    });
  }

  let intent: Awaited<ReturnType<typeof retrievePaymentIntent>>;
  try {
    intent = await retrievePaymentIntent(env.PAYMONGO_SECRET_KEY!, intentId);
  } catch {
    // Transient PayMongo error — the poller should keep waiting, not fail.
    return json({ status: 'unknown', ...entitlementResponse(record ?? null) });
  }

  // The intent id came from the client, so bind it to the caller before it can
  // grant anything: without this, any signed-in user could poll someone else's
  // successful intent and be handed their premium.
  if (intent.metadata.uid !== uid) {
    return json({ error: 'Payment does not belong to this account.' }, 403);
  }

  const status = mapIntentStatus(intent.status);
  if (status === 'paid') {
    const plan = intent.metadata.plan;
    if (plan !== 'monthly' && plan !== 'yearly') {
      return json({ status: 'unknown', ...entitlementResponse(record ?? null) });
    }
    const granted = await grantPremiumFromPayment(env.BUCKET, uid, plan, {
      paymentIntentId: intentId,
      wallet: (intent.metadata.method ?? intent.metadata.wallet) as
        | PayMongoMethod
        | undefined,
      amountCentavos: intent.amountCentavos,
    });
    return json({ status: 'paid', ...entitlementResponse(granted) });
  }

  return json({ status, ...entitlementResponse(record ?? null) });
}

function mapIntentStatus(raw: string): BillingPaymentStatus {
  switch (raw) {
    case 'succeeded':
    case 'paid':
      return 'paid';
    case 'awaiting_payment_method':
    case 'awaiting_next_action':
    case 'processing':
      return 'pending';
    case 'cancelled':
    case 'canceled':
    case 'failed':
      return 'failed';
    default:
      return 'unknown';
  }
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

  let paid = false;

  if (paymentIntentId && payMongoConfigured(env)) {
    try {
      const intent = await retrievePaymentIntent(
        env.PAYMONGO_SECRET_KEY!,
        paymentIntentId,
      );
      if (intent.status === 'succeeded') {
        paid = true;
        const uid = intent.metadata.uid;
        const plan = intent.metadata.plan as BillingPlan | undefined;
        const wallet = intent.metadata.wallet as PayMongoMethod | undefined;
        if (uid && (plan === 'monthly' || plan === 'yearly')) {
          await grantPremiumFromPayment(env.BUCKET, uid, plan, {
            paymentIntentId,
            wallet,
            amountCentavos: intent.amountCentavos,
          });
        }
      }
    } catch {
      // The return page still renders; webhooks remain the primary path.
    }
  }

  const status = url.searchParams.get('status');
  return htmlReturnPage(paid || status !== 'failed');
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

  const eventType = extractWebhookEventType(body);

  if (
    eventType !== 'payment.paid' &&
    eventType !== 'payment.failed' &&
    eventType !== 'checkout_session.payment.paid'
  ) {
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
    paymentIntentId.startsWith('pi_') &&
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
  const wallet = (metadata.method ?? metadata.wallet) as
    | PayMongoMethod
    | undefined;

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

/** Custom scheme already registered natively for Supabase's own OAuth return. */
const APP_DEEP_LINK = 'io.supabase.notably://billing-callback/';

function htmlReturnPage(paid: boolean): Response {
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
    p { color:#aaa; line-height:1.5; margin:0 0 20px; }
    a.button { display:inline-block; background:#fff; color:#111; text-decoration:none;
      font-weight:600; padding:12px 22px; border-radius:12px; }
  </style>
</head>
<body>
  <div class="card">
    <h1>${paid ? 'Payment received' : 'Payment incomplete'}</h1>
    <p>${paid
      ? 'Taking you back to Notably — Premium unlocks automatically.'
      : 'You can close this page and try again from Notably.'}</p>
    <a class="button" href="${APP_DEEP_LINK}">Open Notably</a>
  </div>
  <script>
    // Most mobile browsers allow one programmatic custom-scheme navigation
    // right after page load; if the app isn't installed this just no-ops and
    // the button above stays as a manual fallback.
    location.href = ${JSON.stringify(APP_DEEP_LINK)};
  </script>
</body>
</html>`;
  return new Response(html, {
    status: 200,
    headers: { 'Content-Type': 'text/html; charset=utf-8' },
  });
}
