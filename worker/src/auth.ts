/** Extracts and verifies a Supabase access token, returning the user's uid. */

export interface AuthEnv {
  /** e.g. https://xxxx.supabase.co — used for issuer + JWKS. */
  SUPABASE_URL: string;
  /**
   * Legacy HS256 JWT secret (Project Settings → API → JWT Secret).
   * Optional when the project uses asymmetric signing keys (ES256/RS256).
   */
  SUPABASE_JWT_SECRET?: string;
}

export interface AuthUser {
  uid: string;
  email?: string;
  name?: string;
}

export async function requireUid(
  request: Request,
  env: AuthEnv,
): Promise<string> {
  const user = await requireUser(request, env);
  return user.uid;
}

/** Verified Supabase user with optional profile fields from the token. */
export async function requireUser(
  request: Request,
  env: AuthEnv,
): Promise<AuthUser> {
  const header = request.headers.get('Authorization') ?? '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';
  if (!token) throw new Error('Missing Authorization header.');
  return verifySupabaseToken(token, env);
}

type JwtHeader = { alg: string; typ?: string; kid?: string };
type JwtPayload = {
  aud?: string | string[];
  iss?: string;
  sub?: string;
  exp?: number;
  email?: string;
  role?: string;
  user_metadata?: { full_name?: string; name?: string };
};

/**
 * Verifies a Supabase access token.
 * Supports legacy HS256 (JWT secret) and modern ES256/RS256 (JWKS).
 */
export async function verifySupabaseToken(
  token: string,
  env: AuthEnv,
): Promise<AuthUser> {
  const baseUrl = normalizeSupabaseUrl(env.SUPABASE_URL);
  if (!baseUrl) throw new Error('SUPABASE_URL is not configured.');

  const [rawHeader, rawPayload, rawSignature] = token.split('.');
  if (!rawHeader || !rawPayload || !rawSignature) {
    throw new Error('Malformed token.');
  }

  const header = JSON.parse(decodeBase64Url(rawHeader)) as JwtHeader;
  const payload = JSON.parse(decodeBase64Url(rawPayload)) as JwtPayload;

  assertClaims(payload, baseUrl);

  const data = new TextEncoder().encode(`${rawHeader}.${rawPayload}`);
  const signature = base64UrlToBytes(rawSignature);

  let valid = false;
  if (header.alg === 'HS256') {
    valid = await verifyHs256(env.SUPABASE_JWT_SECRET, data, signature);
  } else if (header.alg === 'ES256' || header.alg === 'RS256') {
    valid = await verifyAsymmetric(baseUrl, header, data, signature);
  } else {
    throw new Error(`Unexpected token algorithm: ${header.alg}`);
  }
  if (!valid) throw new Error('Invalid token signature.');

  const name =
    payload.user_metadata?.full_name ?? payload.user_metadata?.name;

  return {
    uid: payload.sub!,
    email: payload.email,
    name,
  };
}

function normalizeSupabaseUrl(raw: string | undefined): string {
  return (raw ?? '')
    .trim()
    .replace(/\/$/, '')
    .replace(/\/rest\/v1$/i, '');
}

function assertClaims(payload: JwtPayload, baseUrl: string): void {
  const expectedIss = `${baseUrl}/auth/v1`;
  if (payload.iss !== expectedIss) {
    throw new Error('Unexpected token issuer.');
  }

  const aud = payload.aud;
  const audOk = Array.isArray(aud)
    ? aud.includes('authenticated')
    : aud === 'authenticated';
  if (!audOk) throw new Error('Token is for another audience.');

  if (!payload.exp || payload.exp * 1000 < Date.now()) {
    throw new Error('Token expired.');
  }
  if (!payload.sub) throw new Error('Token has no subject.');
}

async function verifyHs256(
  secret: string | undefined,
  data: Uint8Array,
  signature: Uint8Array,
): Promise<boolean> {
  const keyMaterial = secret?.trim();
  if (!keyMaterial) {
    throw new Error(
      'Token is HS256 but SUPABASE_JWT_SECRET is not configured.',
    );
  }
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(keyMaterial),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['verify'],
  );
  return crypto.subtle.verify('HMAC', key, signature, data);
}

async function verifyAsymmetric(
  baseUrl: string,
  header: JwtHeader,
  data: Uint8Array,
  signature: Uint8Array,
): Promise<boolean> {
  const jwksUrl = `${baseUrl}/auth/v1/.well-known/jwks.json`;
  const res = await fetch(jwksUrl, {
    headers: { Accept: 'application/json' },
  });
  if (!res.ok) {
    throw new Error(`Failed to fetch JWKS (${res.status}).`);
  }
  const jwks = (await res.json()) as {
    keys?: Array<JsonWebKey & { kid?: string; alg?: string }>;
  };
  const keys = jwks.keys ?? [];
  if (keys.length === 0) {
    throw new Error(
      'JWKS has no keys. Use legacy JWT Secret (HS256) or enable signing keys in Supabase.',
    );
  }

  const jwk =
    (header.kid ? keys.find((k) => k.kid === header.kid) : undefined) ??
    keys.find((k) => !k.alg || k.alg === header.alg) ??
    keys[0];

  if (header.alg === 'ES256') {
    const key = await crypto.subtle.importKey(
      'jwk',
      jwk,
      { name: 'ECDSA', namedCurve: 'P-256' },
      false,
      ['verify'],
    );
    return crypto.subtle.verify(
      { name: 'ECDSA', hash: 'SHA-256' },
      key,
      signature,
      data,
    );
  }

  // RS256
  const key = await crypto.subtle.importKey(
    'jwk',
    jwk,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify'],
  );
  return crypto.subtle.verify('RSASSA-PKCS1-v1_5', key, signature, data);
}

function decodeBase64Url(value: string): string {
  return new TextDecoder().decode(base64UrlToBytes(value));
}

function base64UrlToBytes(value: string): Uint8Array {
  const base64 = value.replace(/-/g, '+').replace(/_/g, '/');
  const padded = base64.padEnd(
    base64.length + ((4 - base64.length % 4) % 4),
    '=',
  );
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}
