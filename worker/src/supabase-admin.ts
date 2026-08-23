/** Supabase Auth Admin API helpers (service role — Worker only). */

export interface SupabaseAdminEnv {
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
}

/** Project root URL without trailing slash or /rest/v1. */
export function supabaseProjectUrl(raw: string): string {
  return raw
    .trim()
    .replace(/\/$/, '')
    .replace(/\/rest\/v1$/i, '');
}

export async function createSupabaseUser(
  env: SupabaseAdminEnv,
  params: { email: string; password: string; name?: string },
): Promise<{ id: string; email: string }> {
  const key = env.SUPABASE_SERVICE_ROLE_KEY?.trim();
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
  const res = await fetch(`${base}/auth/v1/admin/users`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${key}`,
      apikey: key,
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
  const key = env.SUPABASE_SERVICE_ROLE_KEY?.trim();
  if (!key) return;

  const base = supabaseProjectUrl(env.SUPABASE_URL);
  const name = params.displayName?.trim();
  const res = await fetch(`${base}/auth/v1/admin/users/${encodeURIComponent(uid)}`, {
    method: 'PUT',
    headers: {
      Authorization: `Bearer ${key}`,
      apikey: key,
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
): Promise<boolean> {
  const key = env.SUPABASE_SERVICE_ROLE_KEY?.trim();
  if (!key) return false;

  const base = supabaseProjectUrl(env.SUPABASE_URL);
  const res = await fetch(`${base}/auth/v1/admin/users/${encodeURIComponent(uid)}`, {
    method: 'DELETE',
    headers: {
      Authorization: `Bearer ${key}`,
      apikey: key,
    },
  });
  if (res.status === 404) return false;
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Supabase delete user failed (${res.status}): ${text}`);
  }
  return true;
}
