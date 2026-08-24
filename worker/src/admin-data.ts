import { readBillingRecord, type BillingRecord, type BillingPlan, LIFETIME_EXPIRES_AT } from './billing';
import {
  appendAudit,
  type AiUsageEvent,
  type AiUsageStore,
  AI_USAGE_KEY,
  AUDIT_KEY,
  type AuditStore,
  BUGS_KEY,
  type BugReport,
  type BugAttachment,
  type BugStatus,
  type BugStore,
  newId,
  readJson,
  TEAM_KEY,
  type TeamMember,
  type TeamStore,
  USERS_INDEX_KEY,
  type UserIndexEntry,
  type UsersIndex,
  writeJson,
} from './admin-store';

const PLAN_MRR_CENTAVOS: Record<BillingPlan, number> = {
  monthly: 19900,
  yearly: Math.round(149900 / 12),
  lifetime: 0,
};

export interface AdminOverview {
  totalUsers: number;
  premiumAccounts: number;
  mrrPhp: number;
  aiSpendEstimateUsd: number;
  openBugs: number;
  storageBytes: number;
  fileCount: number;
  aiEventsInPeriod: number;
  periodDays: number;
}

export interface AdminUserRow {
  uid: string;
  email?: string;
  displayName?: string;
  lastSeenAt?: string;
  storageBytes: number;
  fileCount: number;
  isPremium: boolean;
  plan: BillingPlan | null;
  premiumExpiresAt: string | null;
}

export interface AdminSubscriptionRow {
  uid: string;
  email?: string;
  isPremium: boolean;
  plan: BillingPlan | null;
  expiresAt: string | null;
  source: string;
  updatedAt: string;
  mrrPhp: number;
}

export interface AdminDocumentRow {
  uid: string;
  email?: string;
  storageBytes: number;
  fileCount: number;
}

export async function upsertUserHeartbeat(
  bucket: R2Bucket,
  uid: string,
  profile: { email?: string; displayName?: string },
): Promise<UserIndexEntry> {
  const index = await readJson<UsersIndex>(bucket, USERS_INDEX_KEY, { users: {} });
  const existing = index.users[uid];
  const entry: UserIndexEntry = {
    uid,
    email: profile.email ?? existing?.email,
    displayName: profile.displayName ?? existing?.displayName,
    lastSeenAt: new Date().toISOString(),
    storageBytes: existing?.storageBytes,
    fileCount: existing?.fileCount,
  };
  index.users[uid] = entry;
  await writeJson(bucket, USERS_INDEX_KEY, index);
  return entry;
}

export async function discoverUserUids(bucket: R2Bucket): Promise<Set<string>> {
  const uids = new Set<string>();
  let cursor: string | undefined;
  do {
    const page = await bucket.list({ prefix: 'users/', cursor, limit: 1000 });
    for (const obj of page.objects) {
      const parts = obj.key.split('/');
      if (parts.length >= 2 && parts[1]) uids.add(parts[1]);
    }
    cursor = page.truncated ? page.cursor : undefined;
  } while (cursor);
  return uids;
}

export async function measureUserStorage(
  bucket: R2Bucket,
  uid: string,
): Promise<{ storageBytes: number; fileCount: number }> {
  let storageBytes = 0;
  let fileCount = 0;
  let cursor: string | undefined;
  const prefix = `users/${uid}/`;
  do {
    const page = await bucket.list({ prefix, cursor, limit: 1000 });
    for (const obj of page.objects) {
      if (obj.key.endsWith('/billing.json')) continue;
      storageBytes += obj.size;
      fileCount += 1;
    }
    cursor = page.truncated ? page.cursor : undefined;
  } while (cursor);
  return { storageBytes, fileCount };
}

async function loadUserRows(bucket: R2Bucket): Promise<AdminUserRow[]> {
  const index = await readJson<UsersIndex>(bucket, USERS_INDEX_KEY, { users: {} });
  const discovered = await discoverUserUids(bucket);
  for (const uid of discovered) index.users[uid] ??= { uid, lastSeenAt: '' };

  const rows: AdminUserRow[] = [];
  for (const uid of Object.keys(index.users)) {
    const profile = index.users[uid];
    const storage = await measureUserStorage(bucket, uid);
    profile.storageBytes = storage.storageBytes;
    profile.fileCount = storage.fileCount;
    const billing = await readBillingRecord(bucket, uid);
    const premium = billing?.isPremium === true &&
      (!billing.expiresAt || new Date(billing.expiresAt) > new Date());
    rows.push({
      uid,
      email: profile.email,
      displayName: profile.displayName,
      lastSeenAt: profile.lastSeenAt || undefined,
      storageBytes: storage.storageBytes,
      fileCount: storage.fileCount,
      isPremium: premium,
      plan: premium ? billing?.plan ?? null : null,
      premiumExpiresAt: billing?.expiresAt ?? null,
    });
  }

  await writeJson(bucket, USERS_INDEX_KEY, index);
  rows.sort((a, b) => (b.lastSeenAt ?? '').localeCompare(a.lastSeenAt ?? ''));
  return rows;
}

export async function getOverview(
  bucket: R2Bucket,
  periodDays: number,
): Promise<AdminOverview> {
  const rows = await loadUserRows(bucket);
  const premium = rows.filter((r) => r.isPremium);
  const mrrPhp = premium.reduce((sum, r) => {
    if (r.plan === 'yearly') return sum + PLAN_MRR_CENTAVOS.yearly / 100;
    if (r.plan === 'monthly') return sum + PLAN_MRR_CENTAVOS.monthly / 100;
    return sum;
  }, 0);

  const bugs = await readJson<BugStore>(bucket, BUGS_KEY, { reports: [] });
  const openBugs = bugs.reports.filter((b) => b.status === 'open' || b.status === 'triaged').length;

  const ai = await readJson<AiUsageStore>(bucket, AI_USAGE_KEY, { events: [] });
  const cutoff = Date.now() - periodDays * 86400000;
  const recentAi = ai.events.filter((e) => new Date(e.createdAt).getTime() >= cutoff);
  const totalTokens = recentAi.reduce(
    (s, e) => s + e.promptTokens + e.outputTokens,
    0,
  );
  // Rough Gemini Flash pricing ~ $0.10 / 1M input + $0.40 / 1M output — blended estimate.
  const aiSpendEstimateUsd = Math.round((totalTokens / 1_000_000) * 0.25 * 100) / 100;

  const storageBytes = rows.reduce((s, r) => s + r.storageBytes, 0);
  const fileCount = rows.reduce((s, r) => s + r.fileCount, 0);

  return {
    totalUsers: rows.length,
    premiumAccounts: premium.length,
    mrrPhp: Math.round(mrrPhp),
    aiSpendEstimateUsd,
    openBugs,
    storageBytes,
    fileCount,
    aiEventsInPeriod: recentAi.length,
    periodDays,
  };
}

export async function listUsers(
  bucket: R2Bucket,
  query: string,
  authHits: Array<{ id: string; email?: string; displayName?: string }> = [],
): Promise<AdminUserRow[]> {
  const q = query.trim().toLowerCase();
  const rows = await loadUserRows(bucket);
  if (authHits.length > 0) {
    const byUid = new Map(rows.map((r) => [r.uid, r]));
    for (const hit of authHits) {
      const existing = byUid.get(hit.id);
      if (existing) {
        existing.email = existing.email || hit.email;
        existing.displayName = existing.displayName || hit.displayName;
      } else {
        rows.push({
          uid: hit.id,
          email: hit.email,
          displayName: hit.displayName,
          lastSeenAt: undefined,
          storageBytes: 0,
          fileCount: 0,
          isPremium: false,
          plan: null,
          premiumExpiresAt: null,
        });
      }
    }
  }
  if (!q) return rows;
  return rows.filter(
    (r) =>
      r.uid.toLowerCase().includes(q) ||
      (r.email?.toLowerCase().includes(q) ?? false) ||
      (r.displayName?.toLowerCase().includes(q) ?? false),
  );
}

export async function listSubscriptions(
  bucket: R2Bucket,
): Promise<AdminSubscriptionRow[]> {
  const rows = await loadUserRows(bucket);
  return rows
    .filter((r) => r.isPremium || r.premiumExpiresAt != null)
    .map((r) => ({
      uid: r.uid,
      email: r.email,
      isPremium: r.isPremium,
      plan: r.plan,
      expiresAt: r.premiumExpiresAt,
      source: 'paymongo',
      updatedAt: r.lastSeenAt ?? '',
      mrrPhp: r.isPremium
        ? (r.plan === 'yearly'
            ? PLAN_MRR_CENTAVOS.yearly
            : r.plan === 'monthly'
              ? PLAN_MRR_CENTAVOS.monthly
              : 0) / 100
        : 0,
    }));
}

export async function setSubscription(
  bucket: R2Bucket,
  uid: string,
  body: {
    isPremium: boolean;
    plan?: BillingPlan;
    /** ISO timestamp; when omitted and granting premium, defaults to plan length. */
    expiresAt?: string | null;
  },
  actor: { uid: string; email?: string },
): Promise<BillingRecord> {
  const now = new Date();
  let record: BillingRecord;
  if (body.isPremium) {
    const plan = body.plan ?? 'monthly';
    if (plan !== 'monthly' && plan !== 'yearly' && plan !== 'lifetime') {
      throw new Error('plan must be monthly, yearly, or lifetime.');
    }
    let expiresAt: string;
    if (body.expiresAt === null || plan === 'lifetime') {
      // Explicit clear, or lifetime — still premium until revoked.
      expiresAt = LIFETIME_EXPIRES_AT;
    } else if (body.expiresAt) {
      const parsed = new Date(body.expiresAt);
      if (Number.isNaN(parsed.getTime())) {
        throw new Error('Invalid expiresAt.');
      }
      expiresAt = parsed.toISOString();
    } else {
      const expires = new Date(now);
      expires.setUTCDate(expires.getUTCDate() + (plan === 'yearly' ? 365 : 30));
      expiresAt = expires.toISOString();
    }
    record = {
      isPremium: true,
      plan,
      expiresAt,
      source: 'paymongo',
      updatedAt: now.toISOString(),
    };
  } else {
    record = {
      isPremium: false,
      plan: null,
      expiresAt: null,
      source: 'paymongo',
      updatedAt: now.toISOString(),
    };
  }
  await bucket.put(`users/${uid}/billing.json`, JSON.stringify(record), {
    httpMetadata: { contentType: 'application/json' },
  });
  await appendAudit(bucket, {
    actorUid: actor.uid,
    actorEmail: actor.email,
    action: body.isPremium ? 'subscription.grant' : 'subscription.revoke',
    target: uid,
    detail: body.isPremium
      ? `plan=${body.plan ?? 'monthly'};expires=${record.expiresAt}`
      : undefined,
  });
  return record;
}

/** Update admin-facing profile fields in the users index. */
export async function updateUserProfile(
  bucket: R2Bucket,
  uid: string,
  patch: { email?: string | null; displayName?: string | null },
  actor: { uid: string; email?: string },
): Promise<UserIndexEntry> {
  const index = await readJson<UsersIndex>(bucket, USERS_INDEX_KEY, { users: {} });
  const existing = index.users[uid] ?? { uid, lastSeenAt: '' };
  if (patch.email !== undefined) {
    const email = patch.email?.trim();
    existing.email = email && email.length > 0 ? email : undefined;
  }
  if (patch.displayName !== undefined) {
    const name = patch.displayName?.trim();
    existing.displayName = name && name.length > 0 ? name : undefined;
  }
  index.users[uid] = existing;
  await writeJson(bucket, USERS_INDEX_KEY, index);
  await appendAudit(bucket, {
    actorUid: actor.uid,
    actorEmail: actor.email,
    action: 'user.update',
    target: uid,
    detail: [
      patch.displayName !== undefined ? `name=${existing.displayName ?? ''}` : null,
      patch.email !== undefined ? `email=${existing.email ?? ''}` : null,
    ]
      .filter(Boolean)
      .join(';'),
  });
  return existing;
}

/** Delete all R2 objects under users/{uid}/ and drop the index entry. */
export async function deleteUserData(
  bucket: R2Bucket,
  uid: string,
  actor: { uid: string; email?: string },
): Promise<{ deletedObjects: number }> {
  const prefix = `users/${uid}/`;
  let deletedObjects = 0;
  let cursor: string | undefined;
  do {
    const page = await bucket.list({ prefix, cursor, limit: 1000 });
    for (const obj of page.objects) {
      await bucket.delete(obj.key);
      deletedObjects += 1;
    }
    cursor = page.truncated ? page.cursor : undefined;
  } while (cursor);

  const index = await readJson<UsersIndex>(bucket, USERS_INDEX_KEY, { users: {} });
  if (index.users[uid]) {
    delete index.users[uid];
    await writeJson(bucket, USERS_INDEX_KEY, index);
  }

  await appendAudit(bucket, {
    actorUid: actor.uid,
    actorEmail: actor.email,
    action: 'user.delete',
    target: uid,
    detail: `objects=${deletedObjects}`,
  });
  return { deletedObjects };
}

/** Delete a user's R2 files (PDFs/images) but keep billing.json. */
export async function deleteUserFiles(
  bucket: R2Bucket,
  uid: string,
  actor: { uid: string; email?: string },
): Promise<{ deletedObjects: number }> {
  const prefix = `users/${uid}/`;
  let deletedObjects = 0;
  let cursor: string | undefined;
  do {
    const page = await bucket.list({ prefix, cursor, limit: 1000 });
    for (const obj of page.objects) {
      if (obj.key.endsWith('/billing.json')) continue;
      await bucket.delete(obj.key);
      deletedObjects += 1;
    }
    cursor = page.truncated ? page.cursor : undefined;
  } while (cursor);

  const index = await readJson<UsersIndex>(bucket, USERS_INDEX_KEY, { users: {} });
  if (index.users[uid]) {
    index.users[uid].storageBytes = 0;
    index.users[uid].fileCount = 0;
    await writeJson(bucket, USERS_INDEX_KEY, index);
  }

  await appendAudit(bucket, {
    actorUid: actor.uid,
    actorEmail: actor.email,
    action: 'documents.delete',
    target: uid,
    detail: `objects=${deletedObjects}`,
  });
  return { deletedObjects };
}

export async function listDocuments(
  bucket: R2Bucket,
): Promise<AdminDocumentRow[]> {
  const rows = await loadUserRows(bucket);
  return rows
    .map((r) => ({
      uid: r.uid,
      email: r.email,
      storageBytes: r.storageBytes,
      fileCount: r.fileCount,
    }))
    .sort((a, b) => b.storageBytes - a.storageBytes);
}

export async function submitBugReport(
  bucket: R2Bucket,
  input: {
    uid: string;
    email?: string;
    category: string;
    subject: string;
    description: string;
    device: string;
    attachments?: Array<{ name: string; mime: string; data: string }>;
  },
): Promise<BugReport> {
  const store = await readJson<BugStore>(bucket, BUGS_KEY, { reports: [] });
  const now = new Date().toISOString();
  const id = newId('bug');
  const attachments: BugAttachment[] = [];
  const incoming = (input.attachments ?? []).slice(0, 3);
  for (let i = 0; i < incoming.length; i += 1) {
    const item = incoming[i];
    const mime = (item.mime || 'application/octet-stream').slice(0, 80);
    if (!mime.startsWith('image/')) continue;
    const binary = Uint8Array.from(atob(item.data.replace(/^data:[^;]+;base64,/, '')), (c) =>
      c.charCodeAt(0),
    );
    if (binary.byteLength === 0 || binary.byteLength > 1_500_000) continue;
    const ext = mime.includes('png') ? 'png' : mime.includes('webp') ? 'webp' : 'jpg';
    const key = `bugs/${id}/${i}.${ext}`;
    await bucket.put(key, binary, { httpMetadata: { contentType: mime } });
    attachments.push({
      key,
      name: (item.name || `screenshot-${i + 1}.${ext}`).slice(0, 80),
      mime,
    });
  }
  const report: BugReport = {
    id,
    uid: input.uid,
    email: input.email,
    category: input.category,
    subject: input.subject.trim(),
    description: input.description.trim(),
    device: input.device,
    status: 'open',
    createdAt: now,
    updatedAt: now,
    attachments: attachments.length > 0 ? attachments : undefined,
  };
  store.reports.unshift(report);
  store.reports = store.reports.slice(0, 200);
  await writeJson(bucket, BUGS_KEY, store);
  return report;
}

export async function listBugReports(bucket: R2Bucket): Promise<BugReport[]> {
  const store = await readJson<BugStore>(bucket, BUGS_KEY, { reports: [] });
  return store.reports;
}

export async function updateBugStatus(
  bucket: R2Bucket,
  id: string,
  status: BugStatus | undefined,
  actor: { uid: string; email?: string },
  reply?: string,
): Promise<BugReport | null> {
  const store = await readJson<BugStore>(bucket, BUGS_KEY, { reports: [] });
  const report = store.reports.find((r) => r.id === id);
  if (!report) return null;
  const now = new Date().toISOString();
  if (status) report.status = status;
  if (reply !== undefined) {
    report.adminReply = reply.trim();
    report.adminReplyAt = now;
  }
  report.updatedAt = now;
  await writeJson(bucket, BUGS_KEY, store);
  await appendAudit(bucket, {
    actorUid: actor.uid,
    actorEmail: actor.email,
    action: reply ? 'bug.reply' : 'bug.update',
    target: id,
    detail: [status, reply ? 'reply' : undefined].filter(Boolean).join(','),
  });
  return report;
}

export async function readBugAttachment(
  bucket: R2Bucket,
  id: string,
  index: number,
): Promise<{ body: ArrayBuffer; mime: string; name: string } | null> {
  const store = await readJson<BugStore>(bucket, BUGS_KEY, { reports: [] });
  const report = store.reports.find((r) => r.id === id);
  const file = report?.attachments?.[index];
  if (!file) return null;
  const object = await bucket.get(file.key);
  if (!object) return null;
  return {
    body: await object.arrayBuffer(),
    mime: file.mime,
    name: file.name,
  };
}

export async function recordAiUsage(
  bucket: R2Bucket,
  input: {
    uid: string;
    feature: string;
    promptTokens: number;
    outputTokens: number;
  },
): Promise<AiUsageEvent> {
  const store = await readJson<AiUsageStore>(bucket, AI_USAGE_KEY, { events: [] });
  const event: AiUsageEvent = {
    id: newId('ai'),
    uid: input.uid,
    feature: input.feature,
    promptTokens: input.promptTokens,
    outputTokens: input.outputTokens,
    createdAt: new Date().toISOString(),
  };
  store.events.unshift(event);
  store.events = store.events.slice(0, 2000);
  await writeJson(bucket, AI_USAGE_KEY, store);
  return event;
}

export interface AiUsageSummary {
  totalEvents: number;
  totalPromptTokens: number;
  totalOutputTokens: number;
  estimatedSpendUsd: number;
  byUser: { uid: string; events: number; tokens: number }[];
  recent: AiUsageEvent[];
}

export async function getAiUsage(
  bucket: R2Bucket,
  periodDays: number,
): Promise<AiUsageSummary> {
  const store = await readJson<AiUsageStore>(bucket, AI_USAGE_KEY, { events: [] });
  const cutoff = Date.now() - periodDays * 86400000;
  const recent = store.events.filter(
    (e) => new Date(e.createdAt).getTime() >= cutoff,
  );
  const totalPromptTokens = recent.reduce((s, e) => s + e.promptTokens, 0);
  const totalOutputTokens = recent.reduce((s, e) => s + e.outputTokens, 0);
  const totalTokens = totalPromptTokens + totalOutputTokens;

  const byUserMap = new Map<string, { events: number; tokens: number }>();
  for (const e of recent) {
    const row = byUserMap.get(e.uid) ?? { events: 0, tokens: 0 };
    row.events += 1;
    row.tokens += e.promptTokens + e.outputTokens;
    byUserMap.set(e.uid, row);
  }
  const byUser = [...byUserMap.entries()]
    .map(([uid, v]) => ({ uid, ...v }))
    .sort((a, b) => b.tokens - a.tokens);

  return {
    totalEvents: recent.length,
    totalPromptTokens,
    totalOutputTokens,
    estimatedSpendUsd: Math.round((totalTokens / 1_000_000) * 0.25 * 100) / 100,
    byUser,
    recent: recent.slice(0, 50),
  };
}

export async function listTeam(
  bucket: R2Bucket,
  envUids: Set<string>,
): Promise<TeamMember[]> {
  const store = await readJson<TeamStore>(bucket, TEAM_KEY, { members: [] });
  const seen = new Set(store.members.map((m) => m.uid));
  for (const uid of envUids) {
    if (!seen.has(uid)) {
      store.members.push({
        uid,
        role: 'admin',
        addedAt: new Date().toISOString(),
      });
    }
  }
  return store.members;
}

export async function addTeamMember(
  bucket: R2Bucket,
  member: { uid: string; email?: string; role?: 'admin' | 'viewer' },
  actor: { uid: string; email?: string },
): Promise<TeamMember> {
  const store = await readJson<TeamStore>(bucket, TEAM_KEY, { members: [] });
  const existing = store.members.find((m) => m.uid === member.uid);
  if (existing) {
    existing.email = member.email ?? existing.email;
    existing.role = member.role ?? existing.role;
    await writeJson(bucket, TEAM_KEY, store);
    return existing;
  }
  const row: TeamMember = {
    uid: member.uid.trim(),
    email: member.email?.trim(),
    role: member.role ?? 'admin',
    addedAt: new Date().toISOString(),
    addedBy: actor.uid,
  };
  store.members.push(row);
  await writeJson(bucket, TEAM_KEY, store);
  await appendAudit(bucket, {
    actorUid: actor.uid,
    actorEmail: actor.email,
    action: 'team.add',
    target: row.uid,
    detail: row.role,
  });
  return row;
}

export async function removeTeamMember(
  bucket: R2Bucket,
  uid: string,
  actor: { uid: string; email?: string },
): Promise<boolean> {
  const store = await readJson<TeamStore>(bucket, TEAM_KEY, { members: [] });
  const before = store.members.length;
  store.members = store.members.filter((m) => m.uid !== uid);
  if (store.members.length === before) return false;
  await writeJson(bucket, TEAM_KEY, store);
  await appendAudit(bucket, {
    actorUid: actor.uid,
    actorEmail: actor.email,
    action: 'team.remove',
    target: uid,
  });
  return true;
}

export async function listAudit(bucket: R2Bucket): Promise<AuditStore['entries']> {
  const store = await readJson<AuditStore>(bucket, AUDIT_KEY, { entries: [] });
  return store.entries;
}

/** Wipe the audit log. Returns how many entries were removed. */
export async function clearAudit(bucket: R2Bucket): Promise<number> {
  const store = await readJson<AuditStore>(bucket, AUDIT_KEY, { entries: [] });
  const count = store.entries.length;
  await writeJson(bucket, AUDIT_KEY, { entries: [] } satisfies AuditStore);
  return count;
}
