/** Supabase Auth Admin API helpers (service role — Worker only). */

export interface SupabaseAdminEnv {
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY?: string;
  SUPABASE_JWT_SECRET?: string;
  SUPABASE_ANON_KEY?: string;
}

/** Project root URL without trailing slash or /rest/v1. */
export function supabaseProjectUrl(raw: string): string {
  return raw
    .trim()
    .replace(/\/$/, '')
    .replace(/\/rest\/v1$/i, '');
}

/** Strip quotes / Bearer prefix that make wrangler secrets look like invalid keys. */
export function sanitizeSecret(raw: string | undefined): string {
  return (raw ?? '')
    .trim()
    .replace(/^Bearer\s+/i, '')
    .replace(/^["']|["']$/g, '')
    .trim();
}

function decodeJwtPayload(token: string): { role?: string } | null {
  const parts = token.split('.');
  if (parts.length < 2) return null;
  try {
    const b64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    const padded = b64 + '='.repeat((4 - (b64.length % 4)) % 4);
    return JSON.parse(atob(padded)) as { role?: string };
  } catch {
    return null;
  }
}

/** True when the secret can call GoTrue's admin API. */
export function isServiceRoleKey(raw: string | undefined): boolean {
  const key = sanitizeSecret(raw);
  if (!key) return false;
  if (key.startsWith('sb_secret_')) return true;
  return decodeJwtPayload(key)?.role === 'service_role';
}

function base64UrlEncode(bytes: Uint8Array): string {
  let bin = '';
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

function projectRefFromUrl(url: string): string {
  return new URL(supabaseProjectUrl(url)).hostname.split('.')[0] ?? '';
}

/** HS256 service_role JWT from the project's JWT secret (legacy API keys). */
export async function mintServiceRoleJwt(
  jwtSecret: string,
  supabaseUrl: string,
): Promise<string> {
  const header = base64UrlEncode(
    new TextEncoder().encode(JSON.stringify({ alg: 'HS256', typ: 'JWT' })),
  );
  const now = Math.floor(Date.now() / 1000);
  const payload = base64UrlEncode(
    new TextEncoder().encode(
      JSON.stringify({
        iss: 'supabase',
        role: 'service_role',
        ref: projectRefFromUrl(supabaseUrl),
        iat: now,
        exp: now + 60 * 60,
      }),
    ),
  );
  const data = `${header}.${payload}`;
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(sanitizeSecret(jwtSecret)),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign('HMAC', cryptoKey, new TextEncoder().encode(data));
  return `${data}.${base64UrlEncode(new Uint8Array(sig))}`;
}

export async function resolveGoTrueAdminKey(
  env: SupabaseAdminEnv,
): Promise<string | null> {
  const stored = sanitizeSecret(env.SUPABASE_SERVICE_ROLE_KEY);
  if (isServiceRoleKey(stored)) return stored;
  const jwtSecret = sanitizeSecret(env.SUPABASE_JWT_SECRET);
  if (!jwtSecret) return null;
  return mintServiceRoleJwt(jwtSecret, env.SUPABASE_URL);
}

export async function createSupabaseUser(
  env: SupabaseAdminEnv,
  params: { email: string; password: string; name?: string },
): Promise<{ id: string; email: string }> {
  const key = await resolveGoTrueAdminKey(env);
  if (!key) {
    throw new Error(
      'SUPABASE_SERVICE_ROLE_KEY is not configured. Run: wrangler secret put SUPABASE_SERVICE_ROLE_KEY',
    );
  }

  const base = supabaseProjectUrl(env.SUPABASE_URL);
  const email = params.email.trim().toLowerCase();
  const password = params.password;
  if (!email || !password) throw new Error('email and password are required.');
  if (password.length < 6) {
    throw new Error('Password must be at least 6 characters.');
  }

  const name = params.name?.trim();
  const apikey = sanitizeSecret(env.SUPABASE_ANON_KEY) || key;
  const res = await fetch(`${base}/auth/v1/admin/users`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${key}`,
      apikey,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      email,
      password,
      email_confirm: true,
      user_metadata:
        name && name.length > 0
          ? { full_name: name, display_name: name }
          : undefined,
    }),
  });

  const body = (await res.json().catch(() => ({}))) as {
    id?: string;
    email?: string;
    msg?: string;
    message?: string;
    error_description?: string;
  };

  if (!res.ok) {
    const msg =
      body.msg ??
      body.message ??
      body.error_description ??
      `Supabase create user failed (${res.status}).`;
    throw new Error(msg);
  }
  if (!body.id) throw new Error('Supabase did not return a user id.');

  return { id: body.id, email: body.email ?? email };
}

export async function updateSupabaseUserMetadata(
  env: SupabaseAdminEnv,
  uid: string,
  params: { displayName?: string | null },
): Promise<void> {
  const key = await resolveGoTrueAdminKey(env);
  if (!key) return;

  const base = supabaseProjectUrl(env.SUPABASE_URL);
  const name = params.displayName?.trim();
  const apikey = sanitizeSecret(env.SUPABASE_ANON_KEY) || key;
  const res = await fetch(`${base}/auth/v1/admin/users/${encodeURIComponent(uid)}`, {
    method: 'PUT',
    headers: {
      Authorization: `Bearer ${key}`,
      apikey,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      user_metadata:
        name && name.length > 0
          ? { full_name: name, display_name: name }
          : { full_name: null, display_name: null },
    }),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Supabase update user failed (${res.status}): ${text}`);
  }
}

export async function deleteSupabaseUser(
  env: SupabaseAdminEnv,
  uid: string,
): Promise<{ deleted: boolean; error?: string }> {
  const key = await resolveGoTrueAdminKey(env);
  if (!key) {
    return { deleted: false };
  }

  const base = supabaseProjectUrl(env.SUPABASE_URL);
  const apikey = sanitizeSecret(env.SUPABASE_ANON_KEY) || key;
  const res = await fetch(`${base}/auth/v1/admin/users/${encodeURIComponent(uid)}`, {
    method: 'DELETE',
    headers: {
      Authorization: `Bearer ${key}`,
      apikey,
    },
  });
  if (res.status === 404) return { deleted: false };
  if (!res.ok) {
    const text = await res.text();
    return {
      deleted: false,
      error: `Supabase delete user failed (${res.status}): ${text}`,
    };
  }
  return { deleted: true };
}

export interface AuthUserHit {
  id: string;
  email?: string;
  displayName?: string;
}

/** Lists Auth users matching [query] (email, name, or uid substring). */
export async function searchAuthUsers(
  env: SupabaseAdminEnv,
  query: string,
): Promise<AuthUserHit[]> {
  const key = await resolveGoTrueAdminKey(env);
  if (!key) return [];
  const q = query.trim().toLowerCase();
  if (!q) return [];

  const base = supabaseProjectUrl(env.SUPABASE_URL);
  const apikey = sanitizeSecret(env.SUPABASE_ANON_KEY) || key;
  const hits: AuthUserHit[] = [];

  for (let page = 1; page <= 5; page += 1) {
    const res = await fetch(
      `${base}/auth/v1/admin/users?page=${page}&per_page=200`,
      {
        headers: {
          Authorization: `Bearer ${key}`,
          apikey,
          Accept: 'application/json',
        },
      },
    );
    if (!res.ok) break;
    const body = (await res.json()) as {
      users?: Array<{
        id: string;
        email?: string;
        user_metadata?: { full_name?: string; display_name?: string; name?: string };
      }>;
    };
    const users = body.users ?? [];
    for (const u of users) {
      const email = u.email ?? '';
      const displayName =
        u.user_metadata?.display_name ||
        u.user_metadata?.full_name ||
        u.user_metadata?.name ||
        '';
      if (
        u.id.toLowerCase().includes(q) ||
        email.toLowerCase().includes(q) ||
        displayName.toLowerCase().includes(q)
      ) {
        hits.push({
          id: u.id,
          email: email || undefined,
          displayName: displayName || undefined,
        });
      }
    }
    if (users.length < 200) break;
  }
  return hits;
}
