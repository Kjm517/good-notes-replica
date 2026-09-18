import { requireUser } from './auth';

/**
 * Account deletion.
 *
 * Google Play and the App Store both require that an app which creates
 * accounts can delete them from inside the app, and the deletion has to reach
 * the data, not just the login. Everything this account owns therefore goes:
 * the objects in R2 under its prefix, its rows in Postgres, and finally the
 * auth user itself.
 *
 * The client cannot do any of this. Deleting an auth user needs the service
 * role key, which only ever exists here, and the row deletes have to happen
 * with the user still resolvable so ownership can be checked.
 */
export interface AccountEnv {
  BUCKET: R2Bucket;
  /** Required; [requireUser] refuses the request when it is missing. */
  SUPABASE_URL: string;
  SUPABASE_ANON_KEY?: string;
  SUPABASE_SERVICE_ROLE_KEY?: string;
  SUPABASE_JWT_SECRET?: string;
}

/** Tables holding per-account rows, all keyed on `user_id`. */
const OWNED_TABLES = [
  'ink',
  'elements',
  'pages',
  'quizzes',
  'assets',
  'user_prefs',
  'documents',
] as const;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function restBase(env: AccountEnv): string {
  return `${env.SUPABASE_URL.replace(/\/$/, '')}/rest/v1`;
}

function serviceHeaders(env: AccountEnv): HeadersInit {
  const service = env.SUPABASE_SERVICE_ROLE_KEY?.trim();
  if (!service) {
    throw new Error('SUPABASE_SERVICE_ROLE_KEY is not configured.');
  }
  return {
    Authorization: `Bearer ${service}`,
    apikey: service,
    Accept: 'application/json',
    'Content-Type': 'application/json',
  };
}

/**
 * Removes every object under this account's prefix.
 *
 * R2 lists 1000 keys at a time, and a library of scanned pages goes past that,
 * so this pages through until the prefix is empty rather than deleting the
 * first page and reporting success.
 */
async function deleteBucketPrefix(
  bucket: R2Bucket,
  prefix: string,
): Promise<number> {
  let deleted = 0;
  let cursor: string | undefined;
  do {
    const listed = await bucket.list({ prefix, cursor, limit: 1000 });
    const keys = listed.objects.map((o) => o.key);
    if (keys.length > 0) {
      await bucket.delete(keys);
      deleted += keys.length;
    }
    cursor = listed.truncated ? listed.cursor : undefined;
  } while (cursor);
  return deleted;
}

/** Deletes this account's rows from one table. */
async function deleteOwnedRows(
  env: AccountEnv,
  table: string,
  uid: string,
): Promise<void> {
  const url = `${restBase(env)}/${table}?user_id=eq.${encodeURIComponent(uid)}`;
  const res = await fetch(url, {
    method: 'DELETE',
    headers: serviceHeaders(env),
  });
  // 404 means the table is not in this schema, which is not a failure worth
  // aborting a deletion over — the point is that no rows are left behind.
  if (!res.ok && res.status !== 404) {
    throw new Error(`Could not delete ${table} rows (${res.status}).`);
  }
}

/** Deletes the Supabase auth user. Irreversible. */
async function deleteAuthUser(env: AccountEnv, uid: string): Promise<void> {
  const base = env.SUPABASE_URL.replace(/\/$/, '');
  const res = await fetch(
    `${base}/auth/v1/admin/users/${encodeURIComponent(uid)}`,
    { method: 'DELETE', headers: serviceHeaders(env) },
  );
  if (!res.ok && res.status !== 404) {
    throw new Error(`Could not delete the account (${res.status}).`);
  }
}

/**
 * `POST /user/account/delete`
 *
 * Deletes the caller's own account. There is no uid parameter on purpose: the
 * only account this can remove is the one the bearer token proves ownership
 * of, so a stolen endpoint cannot be pointed at somebody else.
 *
 * Data goes before the auth user. If this fails halfway the account still
 * exists and the user can try again; doing it the other way round would leave
 * orphaned rows nobody can reach or clean up.
 */
export async function handleAccountDelete(
  request: Request,
  env: AccountEnv,
): Promise<Response> {
  if (request.method !== 'POST') {
    return json({ error: 'Method not allowed.' }, 405);
  }
  const user = await requireUser(request, env);
  const uid = user.uid;

  if (!env.SUPABASE_SERVICE_ROLE_KEY?.trim()) {
    // Fail loudly rather than deleting the files and leaving the login alive,
    // which would look to the user like their account survived a deletion.
    return json({ error: 'Account deletion is not configured.' }, 503);
  }

  const files = await deleteBucketPrefix(env.BUCKET, `users/${uid}/`);

  // Children before parents: pages and ink reference documents, and a
  // half-deleted account is easier to recover from than a broken one.
  for (const table of OWNED_TABLES) {
    await deleteOwnedRows(env, table, uid);
  }

  await deleteAuthUser(env, uid);

  return json({ ok: true, filesDeleted: files });
}
