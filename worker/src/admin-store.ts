/** Shared R2-backed config stores for the admin console. */

export const USERS_INDEX_KEY = 'config/users-index.json';
export const BUGS_KEY = 'config/bug-reports.json';
export const AI_USAGE_KEY = 'config/ai-usage.json';
export const TEAM_KEY = 'config/admin-team.json';
export const AUDIT_KEY = 'config/audit-log.json';

export interface UserIndexEntry {
  uid: string;
  email?: string;
  displayName?: string;
  lastSeenAt: string;
  storageBytes?: number;
  fileCount?: number;
}

export interface UsersIndex {
  users: Record<string, UserIndexEntry>;
}

export type BugStatus = 'open' | 'triaged' | 'resolved' | 'closed';

export interface BugReport {
  id: string;
  uid: string;
  email?: string;
  category: string;
  subject: string;
  description: string;
  device: string;
  status: BugStatus;
  createdAt: string;
  updatedAt: string;
}

export interface BugStore {
  reports: BugReport[];
}

export interface AiUsageEvent {
  id: string;
  uid: string;
  feature: string;
  promptTokens: number;
  outputTokens: number;
  createdAt: string;
}

export interface AiUsageStore {
  events: AiUsageEvent[];
}

export interface TeamMember {
  uid: string;
  email?: string;
  role: 'admin' | 'viewer';
  addedAt: string;
  addedBy?: string;
}

export interface TeamStore {
  members: TeamMember[];
}

export interface AuditEntry {
  id: string;
  actorUid: string;
  actorEmail?: string;
  action: string;
  target?: string;
  detail?: string;
  createdAt: string;
}

export interface AuditStore {
  entries: AuditEntry[];
}

export async function readJson<T>(
  bucket: R2Bucket,
  key: string,
  fallback: T,
): Promise<T> {
  const object = await bucket.get(key);
  if (!object) return structuredClone(fallback);
  try {
    return JSON.parse(await object.text()) as T;
  } catch {
    return structuredClone(fallback);
  }
}

export async function writeJson(
  bucket: R2Bucket,
  key: string,
  value: unknown,
): Promise<void> {
  await bucket.put(key, JSON.stringify(value), {
    httpMetadata: { contentType: 'application/json' },
  });
}

export function newId(prefix: string): string {
  return `${prefix}_${crypto.randomUUID()}`;
}

export async function appendAudit(
  bucket: R2Bucket,
  entry: Omit<AuditEntry, 'id' | 'createdAt'>,
): Promise<AuditEntry> {
  const store = await readJson<AuditStore>(bucket, AUDIT_KEY, { entries: [] });
  const row: AuditEntry = {
    ...entry,
    id: newId('aud'),
    createdAt: new Date().toISOString(),
  };
  store.entries.unshift(row);
  store.entries = store.entries.slice(0, 500);
  await writeJson(bucket, AUDIT_KEY, store);
  return row;
}

export function parseAdminUids(raw: string | undefined): Set<string> {
  if (!raw?.trim()) return new Set();
  return new Set(
    raw
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean),
  );
}

/**
 * The admins table could not be consulted, so "not an admin" is unknown
 * rather than false.
 *
 * Worth its own type: a misconfigured database and a genuine non-admin used
 * to be indistinguishable, and both came out as "Admin access required." —
 * which sends you looking at accounts and roles when the real answer is that
 * the lookup never completed.
 */
export class AdminCheckUnavailable extends Error {
  constructor(reason: string) {
    super(`Could not verify admin access: ${reason}`);
    this.name = 'AdminCheckUnavailable';
  }
}

export async function isAdminUid(
  uid: string,
  env: {
    ADMIN_UIDS?: string;
    BUCKET: R2Bucket;
    SUPABASE_URL?: string;
    SUPABASE_ANON_KEY?: string;
    SUPABASE_SERVICE_ROLE_KEY?: string;
  },
  userAccessToken?: string,
): Promise<boolean> {
  // Optional bootstrap fallback while migrating off wrangler ADMIN_UIDS.
  if (parseAdminUids(env.ADMIN_UIDS).has(uid)) return true;

  let lookupFailure: string | undefined;
  if (env.SUPABASE_URL) {
    const { isUserAdmin } = await import('./admins-db');
    try {
      if (
        await isUserAdmin(
          {
            SUPABASE_URL: env.SUPABASE_URL,
            SUPABASE_ANON_KEY: env.SUPABASE_ANON_KEY,
            SUPABASE_SERVICE_ROLE_KEY: env.SUPABASE_SERVICE_ROLE_KEY,
          },
          uid,
          userAccessToken,
        )
      ) {
        return true;
      }
    } catch (e) {
      lookupFailure = e instanceof Error ? e.message : String(e);
      console.error('admins table check failed:', e);
    }
  }

  // Legacy R2 team list (pre-admins-table). Still authoritative if it grants
  // access, so a broken Supabase lookup cannot lock out an existing admin.
  const team = await readJson<TeamStore>(env.BUCKET, TEAM_KEY, { members: [] });
  if (team.members.some((m) => m.uid === uid && m.role === 'admin')) return true;

  // Nothing granted access, but the one source that should have known was
  // unreachable. Saying "no" here would be a guess dressed as an answer.
  if (lookupFailure) throw new AdminCheckUnavailable(lookupFailure);
  return false;
}
