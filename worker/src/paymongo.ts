const PAYMONGO_BASE = 'https://api.paymongo.com/v1';
const PAYMONGO_V2_BASE = 'https://api.paymongo.com/v2';

/** E-wallets, QR Ph, plus debit/credit card (card uses hosted Checkout). */
export type PayMongoMethod = 'gcash' | 'paymaya' | 'card' | 'qrph';

/** @deprecated Prefer [PayMongoMethod]. */
export type PayMongoWallet = PayMongoMethod;

export interface PayMongoEnv {
  PAYMONGO_SECRET_KEY?: string;
  PAYMONGO_WEBHOOK_SECRET?: string;
}

export const PAYMONGO_METHODS: PayMongoMethod[] = [
  'card',
  'gcash',
  'paymaya',
  'qrph',
];

export function isPayMongoMethod(value: unknown): value is PayMongoMethod {
  return (
    value === 'gcash' ||
    value === 'paymaya' ||
    value === 'card' ||
    value === 'qrph'
  );
}

interface PayMongoResource<T> {
  data: {
    id: string;
    attributes: T;
  };
}

async function payMongoRequest<T>(
  secretKey: string,
  path: string,
  init?: { method?: string; body?: unknown; base?: string },
): Promise<PayMongoResource<T>> {
  const base = init?.base ?? PAYMONGO_BASE;
  const response = await fetch(`${base}${path}`, {
    method: init?.method ?? (init?.body ? 'POST' : 'GET'),
    headers: {
      Authorization: `Basic ${btoa(`${secretKey}:`)}`,
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: init?.body ? JSON.stringify(init.body) : undefined,
  });

  const text = await response.text();
  let json: unknown = {};
  try {
    json = text ? JSON.parse(text) : {};
  } catch {
    json = { raw: text };
  }

  if (!response.ok) {
    const message =
      typeof json === 'object' &&
      json !== null &&
      'errors' in json &&
      Array.isArray((json as { errors: { detail?: string }[] }).errors)
        ? (json as { errors: { detail?: string }[] }).errors
            .map((e) => e.detail)
            .filter(Boolean)
            .join('; ')
        : text || response.statusText;
    throw new Error(message || `PayMongo HTTP ${response.status}`);
  }

  return json as PayMongoResource<T>;
}

/**
 * One checkout, two shapes: redirect-based methods hand back a URL to open,
 * QR Ph hands back a QR image to display. Exactly one is set.
 */
export interface PayMongoCheckoutResult {
  paymentIntentId: string;
  redirectUrl?: string;
  /** Base64 data URI of the QR Ph code, for QR Ph only. */
  qrImageUrl?: string;
}

/**
 * Creates a PayMongo checkout for GCash, Maya, card, or QR Ph.
 * Card uses hosted Checkout Sessions (card details never touch our app).
 * Wallets keep the Payment Intent + attach redirect flow.
 * QR Ph uses the same intent/attach flow but returns a scannable code
 * instead of a redirect — nothing to open, the payer scans it from any bank
 * or e-wallet app that supports the national QR Ph standard.
 */
export async function createMethodCheckout(
  secretKey: string,
  opts: {
    amountCentavos: number;
    method: PayMongoMethod;
    returnUrl: string;
    cancelUrl?: string;
    description: string;
    metadata: Record<string, string>;
  },
): Promise<PayMongoCheckoutResult> {
  if (opts.method === 'card') {
    return createCardCheckoutSession(secretKey, opts);
  }
  if (opts.method === 'qrph') {
    return createQrPhCheckout(secretKey, opts);
  }
  return createWalletCheckout(secretKey, {
    ...opts,
    wallet: opts.method,
  });
}

/** How long a generated QR Ph code stays payable. Matches the app's window. */
const QRPH_EXPIRY_SECONDS = 900;

/**
 * QR Ph: create intent, create a `qrph` payment method, attach, then read the
 * generated code out of `next_action.code.image_url`.
 */
async function createQrPhCheckout(
  secretKey: string,
  opts: {
    amountCentavos: number;
    description: string;
    metadata: Record<string, string>;
  },
): Promise<PayMongoCheckoutResult> {
  const intent = await payMongoRequest<{
    client_key?: string;
    status: string;
  }>(secretKey, '/payment_intents', {
    body: {
      data: {
        attributes: {
          amount: opts.amountCentavos,
          currency: 'PHP',
          payment_method_allowed: ['qrph'],
          capture_type: 'automatic',
          description: opts.description,
          metadata: opts.metadata,
        },
      },
    },
  });

  const paymentMethod = await payMongoRequest<{ type: string }>(
    secretKey,
    '/payment_methods',
    {
      body: { data: { attributes: { type: 'qrph' } } },
    },
  );

  const attached = await payMongoRequest<{
    status: string;
    next_action?: {
      type?: string;
      code?: { image_url?: string };
    };
  }>(secretKey, `/payment_intents/${intent.data.id}/attach`, {
    body: {
      data: {
        attributes: {
          payment_method: paymentMethod.data.id,
          client_key: intent.data.attributes.client_key,
          expiry_seconds: QRPH_EXPIRY_SECONDS,
        },
      },
    },
  });

  const qrImageUrl = attached.data.attributes.next_action?.code?.image_url;
  if (!qrImageUrl) {
    throw new Error('PayMongo did not return a QR Ph code.');
  }

  return { qrImageUrl, paymentIntentId: intent.data.id };
}

/** @deprecated Use [createMethodCheckout]. */
export async function createWalletCheckout(
  secretKey: string,
  opts: {
    amountCentavos: number;
    wallet: Exclude<PayMongoMethod, 'card'>;
    returnUrl: string;
    description: string;
    metadata: Record<string, string>;
  },
): Promise<PayMongoCheckoutResult> {
  const intent = await payMongoRequest<{
    client_key?: string;
    status: string;
  }>(secretKey, '/payment_intents', {
    body: {
      data: {
        attributes: {
          amount: opts.amountCentavos,
          currency: 'PHP',
          payment_method_allowed: [opts.wallet],
          capture_type: 'automatic',
          description: opts.description,
          metadata: opts.metadata,
        },
      },
    },
  });

  const paymentMethod = await payMongoRequest<{ type: string }>(
    secretKey,
    '/payment_methods',
    {
      body: {
        data: {
          attributes: {
            type: opts.wallet,
          },
        },
      },
    },
  );

  const attached = await payMongoRequest<{
    status: string;
    next_action?: {
      type?: string;
      redirect?: { url?: string; return_url?: string };
    };
  }>(secretKey, `/payment_intents/${intent.data.id}/attach`, {
    body: {
      data: {
        attributes: {
          payment_method: paymentMethod.data.id,
          return_url: opts.returnUrl,
        },
      },
    },
  });

  const redirectUrl = attached.data.attributes.next_action?.redirect?.url;
  if (!redirectUrl) {
    throw new Error('PayMongo did not return a wallet redirect URL.');
  }

  return { redirectUrl, paymentIntentId: intent.data.id };
}

/** Debit/credit via PayMongo Hosted Checkout — card form is on their page. */
async function createCardCheckoutSession(
  secretKey: string,
  opts: {
    amountCentavos: number;
    returnUrl: string;
    cancelUrl?: string;
    description: string;
    metadata: Record<string, string>;
  },
): Promise<PayMongoCheckoutResult> {
  const session = await payMongoRequest<{
    checkout_url?: string;
    payment_intent?: { id?: string } | null;
  }>(secretKey, '/checkout_sessions', {
    base: PAYMONGO_V2_BASE,
    body: {
      data: {
        attributes: {
          send_email_receipt: true,
          show_description: true,
          show_line_items: true,
          description: opts.description,
          line_items: [
            {
              currency: 'PHP',
              amount: opts.amountCentavos,
              name: opts.description,
              quantity: 1,
            },
          ],
          payment_method_types: ['card'],
          success_url: opts.returnUrl,
          cancel_url: opts.cancelUrl ?? opts.returnUrl,
          metadata: opts.metadata,
        },
      },
    },
  });

  const redirectUrl = session.data.attributes.checkout_url;
  if (!redirectUrl) {
    throw new Error('PayMongo did not return a card checkout URL.');
  }

  // v2 may defer the payment intent; track the session id until webhook fires.
  const paymentIntentId =
    session.data.attributes.payment_intent?.id ?? session.data.id;

  return { redirectUrl, paymentIntentId };
}

export async function retrievePaymentIntent(
  secretKey: string,
  paymentIntentId: string,
): Promise<{
  status: string;
  metadata: Record<string, string>;
  /** What was actually charged, which a voucher may have discounted. */
  amountCentavos: number | null;
}> {
  const intent = await payMongoRequest<{
    status: string;
    amount?: number;
    metadata?: Record<string, string>;
  }>(secretKey, `/payment_intents/${paymentIntentId}`);

  return {
    status: intent.data.attributes.status,
    metadata: intent.data.attributes.metadata ?? {},
    amountCentavos: intent.data.attributes.amount ?? null,
  };
}

/** Validates PayMongo-Signature header (t=..., te=..., li=...). */
export async function verifyPayMongoWebhookSignature(
  payload: string,
  signatureHeader: string | null,
  webhookSecret: string,
): Promise<boolean> {
  if (!signatureHeader) return false;

  const parts = Object.fromEntries(
    signatureHeader.split(',').map((piece) => {
      const [key, value] = piece.trim().split('=');
      return [key, value ?? ''];
    }),
  ) as Record<string, string>;

  const timestamp = parts.t;
  const testSignature = parts.te;
  const liveSignature = parts.li;
  if (!timestamp) return false;

  const signedPayload = `${timestamp}.${payload}`;
  const expected = await hmacSha256Hex(webhookSecret, signedPayload);

  if (testSignature && timingSafeEqual(testSignature, expected)) return true;
  if (liveSignature && timingSafeEqual(liveSignature, expected)) return true;
  return false;
}

async function hmacSha256Hex(key: string, message: string): Promise<string> {
  const enc = new TextEncoder();
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    enc.encode(key),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign('HMAC', cryptoKey, enc.encode(message));
  return [...new Uint8Array(sig)]
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

export function extractWebhookMetadata(body: unknown): Record<string, string> {
  if (typeof body !== 'object' || body === null) return {};
  // Support classic payment.paid nesting and checkout_session.payment.paid.
  const root = body as Record<string, unknown>;
  const data = root.data as Record<string, unknown> | undefined;
  if (!data) return {};

  const attrs = data.attributes as Record<string, unknown> | undefined;
  const nestedResource = attrs?.data as Record<string, unknown> | undefined;
  const nestedAttrs = nestedResource?.attributes as
    | Record<string, unknown>
    | undefined;
  if (nestedAttrs?.metadata && typeof nestedAttrs.metadata === 'object') {
    return nestedAttrs.metadata as Record<string, string>;
  }

  const session = data.data as Record<string, unknown> | undefined;
  const sessionAttrs = session?.attributes as Record<string, unknown> | undefined;
  if (sessionAttrs?.metadata && typeof sessionAttrs.metadata === 'object') {
    return sessionAttrs.metadata as Record<string, string>;
  }

  const intent = sessionAttrs?.payment_intent as Record<string, unknown> | undefined;
  const intentAttrs = intent?.attributes as Record<string, unknown> | undefined;
  if (intentAttrs?.metadata && typeof intentAttrs.metadata === 'object') {
    return intentAttrs.metadata as Record<string, string>;
  }

  if (attrs?.metadata && typeof attrs.metadata === 'object') {
    return attrs.metadata as Record<string, string>;
  }

  return {};
}

export function extractPaymentIntentId(body: unknown): string | null {
  if (typeof body !== 'object' || body === null) return null;
  const root = body as Record<string, unknown>;
  const data = root.data as Record<string, unknown> | undefined;
  if (!data) return null;

  const attrs = data.attributes as Record<string, unknown> | undefined;
  const nestedResource = attrs?.data as Record<string, unknown> | undefined;
  const nestedAttrs = nestedResource?.attributes as
    | Record<string, unknown>
    | undefined;
  const classic = nestedAttrs?.payment_intent_id;
  if (typeof classic === 'string' && classic) return classic;

  const session = data.data as Record<string, unknown> | undefined;
  const sessionAttrs = session?.attributes as Record<string, unknown> | undefined;
  const intent = sessionAttrs?.payment_intent as Record<string, unknown> | undefined;
  if (typeof intent?.id === 'string' && intent.id) return intent.id;

  if (typeof session?.id === 'string' && session.id.startsWith('cs_')) {
    return session.id;
  }

  return null;
}

export function extractWebhookEventType(body: unknown): string | null {
  if (typeof body !== 'object' || body === null) return null;
  const root = body as Record<string, unknown>;
  const data = root.data as Record<string, unknown> | undefined;
  if (!data) return null;
  const attrs = data.attributes as Record<string, unknown> | undefined;
  if (typeof attrs?.type === 'string') return attrs.type;
  if (typeof data.type === 'string') return data.type;
  return null;
}
