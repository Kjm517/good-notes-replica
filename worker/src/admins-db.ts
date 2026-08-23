/** Postgres `public.admins` via PostgREST (caller JWT + anon, or service role). */

import { supabaseProjectUrl } from './supabase-admin';

export interface AdminsDbEnv {
  SUPABASE_URL: string;
  /** Public anon key — used with the caller's access token (preferred). */
  SUPABASE_ANON_KEY?: string;
  /** Service role — fallback / Auth Admin API only. */
  SUPABASE_SERVICE_ROLE_KEY?: string;
}

export interface AdminRow {
  user_id: string;
  email?: string | null;
  role: string;
  created_at: string;
  created_by?: string | null;
}

function restBase(env: AdminsDbEnv): string {
  return `${supabaseProjectUrl(env.SUPABASE_URL)}/rest/v1`;
}

/** Prefer user JWT + anon key; fall back to service role. */
function restHeaders(
  env: AdminsDbEnv,
  userAccessToken?: string,
): HeadersInit {
  const anon = env.SUPABASE_ANON_KEY?.trim();
  const service = env.SUPABASE_SERVICE_ROLE_KEY?.trim();
  const userToken = userAccessToken?.trim();

  if (userToken && anon) {
    return {
      Authorization: `Bearer ${userToken}`,
      apikey: anon,
      Accept: 'application/json',
      'Content-Type': 'application/json',
    };
  }
  if (service) {
    return {
      Authorization: `Bearer ${service}`,
      apikey: service,
      Accept: 'application/json',
      'Content-Type': 'application/json',
    };
  }
  throw new Error(
    'Set SUPABASE_ANON_KEY (wrangler.toml vars) or SUPABASE_SERVICE_ROLE_KEY for admins lookups.',
  );
}

export async function isUserAdmin(
  env: AdminsDbEnv,
  uid: string,
  userAccessToken?: string,
): Promise<boolean> {
  const url = `${restBase(env)}/admins?user_id=eq.${encodeURIComponent(uid)}&role=eq.admin&select=user_id`;
  const res = await fetch(url, {
    headers: restHeaders(env, userAccessToken),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`admins lookup failed (${res.status}): ${text}`);
  }
  const rows = (await res.json()) as Array<{ user_id: string }>;
  return rows.length > 0;
}

export async function listAdmins(
  env: AdminsDbEnv,
  userAccessToken?: string,
): Promise<AdminRow[]> {
  const url = `${restBase(env)}/admins?select=*&order=created_at.asc`;
  const res = await fetch(url, {
    headers: restHeaders(env, userAccessToken),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`admins list failed (${res.status}): ${text}`);
  }
  return (await res.json()) as AdminRow[];
}

export async function upsertAdmin(
  env: AdminsDbEnv,
  row: {
    user_id: string;
    email?: string;
    role?: string;
    created_by?: string;
  },
  userAccessToken?: string,
): Promise<AdminRow> {
  const url = `${restBase(env)}/admins?on_conflict=user_id`;
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      ...restHeaders(env, userAccessToken),
      Prefer: 'resolution=merge-duplicates,return=representation',
    },
    body: JSON.stringify({
      user_id: row.user_id,
      email: row.email ?? null,
      role: row.role ?? 'admin',
      created_by: row.created_by ?? null,
    }),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`admins upsert failed (${res.status}): ${text}`);
  }
  const rows = (await res.json()) as AdminRow[];
  if (!rows[0]) throw new Error('admins upsert returned no row.');
  return rows[0];
}

export async function deleteAdmin(
  env: AdminsDbEnv,
  uid: string,
  userAccessToken?: string,
): Promise<boolean> {
  const url = `${restBase(env)}/admins?user_id=eq.${encodeURIComponent(uid)}`;
  const res = await fetch(url, {
    method: 'DELETE',
    headers: {
      ...restHeaders(env, userAccessToken),
      Prefer: 'return=representation',
    },
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`admins delete failed (${res.status}): ${text}`);
  }
  const rows = (await res.json()) as AdminRow[];
  return rows.length > 0;
}
