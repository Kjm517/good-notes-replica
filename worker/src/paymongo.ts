const PAYMONGO_BASE = 'https://api.paymongo.com/v1';

export type PayMongoWallet = 'gcash' | 'paymaya';

export interface PayMongoEnv {
  PAYMONGO_SECRET_KEY?: string;
  PAYMONGO_WEBHOOK_SECRET?: string;
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
  init?: { method?: string; body?: unknown },
): Promise<PayMongoResource<T>> {
  const response = await fetch(`${PAYMONGO_BASE}${path}`, {
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

export async function createWalletCheckout(
  secretKey: string,
  opts: {
    amountCentavos: number;
    wallet: PayMongoWallet;
    returnUrl: string;
    description: string;
    metadata: Record<string, string>;
  },
): Promise<{ redirectUrl: string; paymentIntentId: string }> {
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

export async function retrievePaymentIntent(
  secretKey: string,
  paymentIntentId: string,
): Promise<{
  status: string;
  metadata: Record<string, string>;
}> {
  const intent = await payMongoRequest<{
    status: string;
    metadata?: Record<string, string>;
  }>(secretKey, `/payment_intents/${paymentIntentId}`);

  return {
    status: intent.data.attributes.status,
    metadata: intent.data.attributes.metadata ?? {},
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
  const root = body as {
    data?: {
      attributes?: {
        type?: string;
        data?: {
          attributes?: {
            metadata?: Record<string, string>;
            payment_intent_id?: string;
          };
        };
      };
    };
  };

  const direct = root.data?.attributes?.data?.attributes?.metadata;
  if (direct && typeof direct === 'object') return direct;

  return {};
}

export function extractPaymentIntentId(body: unknown): string | null {
  if (typeof body !== 'object' || body === null) return null;
  const attrs = (body as { data?: { attributes?: { data?: { attributes?: { payment_intent_id?: string } } } } })
    .data?.attributes?.data?.attributes;
  return attrs?.payment_intent_id ?? null;
}
