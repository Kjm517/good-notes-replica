import { requireUser } from './auth';
import {
  appendSentNotification,
  firebaseConfigured,
  readDeviceTokens,
  readSentNotifications,
  sendPush,
  type SentNotification,
} from './notifications';
import {
  addTeamMember,
  clearAudit,
  deleteUserData,
  deleteUserFiles,
  getAiUsage,
  getOverview,
  listAudit,
  listBugReports,
  readBugAttachment,
  listDocuments,
  listPayments,
  listSubscriptions,
  listTeam,
  listUsers,
  removeTeamMember,
  setSubscription,
  updateBugStatus,
  updateUserProfile,
} from './admin-data';
import {
  appendAudit,
  type BugStatus,
  parseAdminUids,
  staffRoleForUid,
} from './admin-store';
import {
  deleteAdmin,
  deleteAuthUserViaRpc,
  listAdmins,
  upsertAdmin,
} from './admins-db';
import {
  createSupabaseUser,
  deleteSupabaseUser,
  searchAuthUsers,
  updateSupabaseUserMetadata,
} from './supabase-admin';
import {
  deleteVoucherAdmin,
  listVouchersAdmin,
  upsertVoucherAdmin,
  type StoredVoucher,
} from './vouchers';

export interface AdminEnv {
  BUCKET: R2Bucket;
  SUPABASE_URL: string;
  SUPABASE_ANON_KEY?: string;
  SUPABASE_JWT_SECRET?: string;
  /** Service role — create Auth users from Team. Never ship to the app. */
  SUPABASE_SERVICE_ROLE_KEY?: string;
  ADMIN_UIDS?: string;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function accessTokenFrom(request: Request): string {
  const header = request.headers.get('Authorization') ?? '';
  return header.startsWith('Bearer ') ? header.slice(7).trim() : '';
}

async function requireStaff(
  request: Request,
  env: AdminEnv,
): Promise<{ uid: string; email?: string; accessToken: string; role: string }> {
  const user = await requireUser(request, env);
  const accessToken = accessTokenFrom(request);
  const role = await staffRoleForUid(user.uid, env, accessToken);
  if (!role) {
    throw new Error('Admin access required.');
  }
  return { uid: user.uid, email: user.email, accessToken, role };
}

async function requireAdmin(
  request: Request,
  env: AdminEnv,
): Promise<{ uid: string; email?: string; accessToken: string; role: string }> {
  const staff = await requireStaff(request, env);
  if (staff.role !== 'admin') {
    throw new Error('Viewer accounts cannot change this.');
  }
  return staff;
}

export async function handleAdmin(
  request: Request,
  env: AdminEnv,
  url: URL,
): Promise<Response> {
  const path = url.pathname;
  const method = request.method;

  // ---- Overview ---------------------------------------------------
  if (path === '/admin/overview' && method === 'GET') {
    await requireStaff(request, env);
    const days = Math.min(90, Math.max(1, Number(url.searchParams.get('days') ?? 30)));
    const overview = await getOverview(env.BUCKET, days);
    return json({ overview });
  }

  // ---- Users ------------------------------------------------------
  if (path === '/admin/users' && method === 'GET') {
    await requireStaff(request, env);
    const q = url.searchParams.get('q') ?? '';
    let authHits: Array<{ id: string; email?: string; displayName?: string }> = [];
    if (q.trim()) {
      try {
        authHits = await searchAuthUsers(env, q);
      } catch (e) {
        console.error('Auth user search failed:', e);
      }
    }
    const users = await listUsers(env.BUCKET, q, authHits);
    return json({ users });
  }

  if (path.startsWith('/admin/users/') && method === 'PATCH') {
    const actor = await requireAdmin(request, env);
    const uid = decodeURIComponent(path.slice('/admin/users/'.length)).trim();
    if (!uid) return json({ error: 'uid is required.' }, 400);
    try {
      const body = (await request.json()) as {
        email?: string | null;
        displayName?: string | null;
        isPremium?: boolean;
        plan?: 'monthly' | 'yearly' | 'lifetime';
        expiresAt?: string | null;
      };

      let profile;
      if (body.email !== undefined || body.displayName !== undefined) {
        profile = await updateUserProfile(
          env.BUCKET,
          uid,
          { email: body.email, displayName: body.displayName },
          actor,
        );
        if (body.displayName !== undefined) {
          try {
            await updateSupabaseUserMetadata(
              {
                SUPABASE_URL: env.SUPABASE_URL,
                SUPABASE_SERVICE_ROLE_KEY: env.SUPABASE_SERVICE_ROLE_KEY,
                SUPABASE_JWT_SECRET: env.SUPABASE_JWT_SECRET,
                SUPABASE_ANON_KEY: env.SUPABASE_ANON_KEY,
              },
              uid,
              { displayName: body.displayName },
            );
          } catch {
            // Profile in R2 still saved; Auth metadata is best-effort.
          }
        }
      }

      let subscription;
      if (body.isPremium !== undefined) {
        subscription = await setSubscription(
          env.BUCKET,
          uid,
          {
            isPremium: body.isPremium,
            plan: body.plan,
            expiresAt: body.expiresAt,
          },
          actor,
        );
      }

      return json({
        ok: true,
        profile: profile ?? null,
        subscription: subscription ?? null,
      });
    } catch (e) {
      return json({ error: e instanceof Error ? e.message : String(e) }, 400);
    }
  }

  if (path.startsWith('/admin/users/') && method === 'DELETE') {
    const actor = await requireAdmin(request, env);
    const uid = decodeURIComponent(path.slice('/admin/users/'.length)).trim();
    if (!uid) return json({ error: 'uid is required.' }, 400);
    if (uid === actor.uid) {
      return json({ error: 'You cannot delete your own account from here.' }, 400);
    }

    const result = await deleteUserData(env.BUCKET, uid, actor);
    let authDeleted = false;
    let authError: string | undefined;

    const rpc = await deleteAuthUserViaRpc(env, uid, actor.accessToken);
    if (rpc.deleted) {
      authDeleted = true;
    } else if (!rpc.missing && rpc.error) {
      authError = rpc.error;
    }

    if (!authDeleted) {
      const gotrue = await deleteSupabaseUser(
        {
          SUPABASE_URL: env.SUPABASE_URL,
          SUPABASE_SERVICE_ROLE_KEY: env.SUPABASE_SERVICE_ROLE_KEY,
          SUPABASE_JWT_SECRET: env.SUPABASE_JWT_SECRET,
          SUPABASE_ANON_KEY: env.SUPABASE_ANON_KEY,
        },
        uid,
      );
      authDeleted = gotrue.deleted;
      if (!authDeleted && gotrue.error) authError = gotrue.error;
      else if (!authDeleted && rpc.missing && !authError) {
        authError =
          'Run supabase/admin_delete_user.sql in the SQL Editor so Auth logins can be deleted.';
      }
    }

    return json({
      ok: true,
      deletedObjects: result.deletedObjects,
      authDeleted,
      authError: authDeleted ? null : authError ?? null,
    });
  }

  // ---- Notifications ----------------------------------------------
  if (path === '/admin/notifications' && method === 'GET') {
    await requireStaff(request, env);
    const [sent, subscriptions] = await Promise.all([
      readSentNotifications(env.BUCKET),
      listSubscriptions(env.BUCKET),
    ]);
    return json({
      sent,
      configured: firebaseConfigured(env),
      audienceCounts: {
        all: subscriptions.length,
        premium: subscriptions.filter((s) => s.isPremium).length,
        free: subscriptions.filter((s) => !s.isPremium).length,
      },
    });
  }

  if (path === '/admin/notifications' && method === 'POST') {
    const actor = await requireAdmin(request, env);
    const body = (await request.json()) as {
      title?: string;
      body?: string;
      audience?: 'all' | 'premium' | 'free';
    };
    const title = body.title?.trim();
    const message = body.body?.trim();
    if (!title || !message) {
      return json({ error: 'Title and message are required.' }, 400);
    }
    if (!firebaseConfigured(env)) {
      return json(
        { error: 'Push is not configured. Set FIREBASE_SERVICE_ACCOUNT.' },
        503,
      );
    }

    const audience = body.audience ?? 'all';
    const subscriptions = await listSubscriptions(env.BUCKET);
    const recipients = subscriptions.filter((s) =>
      audience === 'premium'
        ? s.isPremium
        : audience === 'free'
          ? !s.isPremium
          : true,
    );

    const tokens: string[] = [];
    for (const row of recipients) {
      const devices = await readDeviceTokens(env.BUCKET, row.uid);
      for (const d of devices) tokens.push(d.token);
    }

    const result = await sendPush(env, tokens, { title, body: message });

    const entry: SentNotification = {
      id: crypto.randomUUID(),
      title,
      body: message,
      audience,
      sentAt: new Date().toISOString(),
      sentBy: actor.email ?? actor.uid,
      delivered: result.delivered,
      failed: result.failed,
    };
    await appendSentNotification(env.BUCKET, entry);
    await appendAudit(env.BUCKET, {
      action: 'notification.send',
      actorUid: actor.uid,
      actorEmail: actor.email,
      target: audience,
      detail: `${title} (${result.delivered} delivered, ${result.failed} failed)`,
    });

    return json({ sent: entry });
  }

  // ---- Subscriptions ----------------------------------------------
  // Read-only, so viewers get it too — same rule as the subscriptions list.
  if (path === '/admin/payments' && method === 'GET') {
    await requireStaff(request, env);
    const payments = await listPayments(env.BUCKET);
    return json({ payments });
  }

  if (path === '/admin/subscriptions' && method === 'GET') {
    await requireStaff(request, env);
    const subscriptions = await listSubscriptions(env.BUCKET);
    return json({ subscriptions });
  }

  if (path.startsWith('/admin/subscriptions/') && method === 'PATCH') {
    const actor = await requireAdmin(request, env);
    const uid = decodeURIComponent(path.slice('/admin/subscriptions/'.length));
    const body = (await request.json()) as {
      isPremium?: boolean;
      plan?: 'monthly' | 'yearly' | 'lifetime';
      expiresAt?: string | null;
    };
    try {
      const record = await setSubscription(
        env.BUCKET,
        uid,
        {
          isPremium: body.isPremium ?? false,
          plan: body.plan,
          expiresAt: body.expiresAt,
        },
        actor,
      );
      return json({ subscription: record });
    } catch (e) {
      return json({ error: e instanceof Error ? e.message : String(e) }, 400);
    }
  }

  // ---- Documents --------------------------------------------------
  if (path === '/admin/documents' && method === 'GET') {
    await requireStaff(request, env);
    const documents = await listDocuments(env.BUCKET);
    return json({ documents });
  }

  if (path.startsWith('/admin/documents/') && method === 'DELETE') {
    const actor = await requireAdmin(request, env);
    const uid = decodeURIComponent(path.slice('/admin/documents/'.length)).trim();
    if (!uid) return json({ error: 'uid is required.' }, 400);
    const result = await deleteUserFiles(env.BUCKET, uid, actor);
    return json({ ok: true, deletedObjects: result.deletedObjects });
  }

  // ---- Bug reports ------------------------------------------------
  if (path === '/admin/bugs' && method === 'GET') {
    await requireStaff(request, env);
    const reports = await listBugReports(env.BUCKET);
    return json({ reports });
  }

  const bugFile = path.match(/^\/admin\/bugs\/([^/]+)\/files\/(\d+)$/);
  if (bugFile && method === 'GET') {
    await requireStaff(request, env);
    const id = decodeURIComponent(bugFile[1]);
    const index = Number(bugFile[2]);
    const file = await readBugAttachment(env.BUCKET, id, index);
    if (!file) return json({ error: 'Attachment not found.' }, 404);
    return new Response(file.body, {
      headers: {
        'Content-Type': file.mime,
        'Content-Disposition': `inline; filename="${file.name.replace(/"/g, '')}"`,
      },
    });
  }

  if (path.startsWith('/admin/bugs/') && method === 'PATCH') {
    const actor = await requireAdmin(request, env);
    const id = decodeURIComponent(path.slice('/admin/bugs/'.length));
    const body = (await request.json()) as { status?: BugStatus; reply?: string };
    if (!body.status && body.reply === undefined) {
      return json({ error: 'status or reply is required.' }, 400);
    }
    const report = await updateBugStatus(
      env.BUCKET,
      id,
      body.status,
      actor,
      body.reply,
    );
    if (!report) return json({ error: 'Report not found.' }, 404);
    return json({ report });
  }

  // ---- AI usage ---------------------------------------------------
  if (path === '/admin/ai' && method === 'GET') {
    await requireStaff(request, env);
    const days = Math.min(90, Math.max(1, Number(url.searchParams.get('days') ?? 30)));
    const usage = await getAiUsage(env.BUCKET, days);
    return json({ usage });
  }

  // ---- Me (Flutter admin gate via public.admins) ------------------
  if (path === '/admin/me' && method === 'GET') {
    const user = await requireUser(request, env);
    const token = accessTokenFrom(request);
    // An unreachable admins table throws AdminCheckUnavailable, which the
    // router turns into 503. Deliberately not caught here: the gate should
    // say "could not check", never quietly answer {admin: false}.
    const role = await staffRoleForUid(user.uid, env, token);
    return json({
      admin: role != null,
      canWrite: role === 'admin',
      role,
      uid: user.uid,
      email: user.email ?? null,
    });
  }

  // ---- Team (public.admins) ---------------------------------------
  if (path === '/admin/team' && method === 'GET') {
    const actor = await requireStaff(request, env);
    try {
      const rows = await listAdmins(env, actor.accessToken);
      // Only rows in public.admins — do not inject ADMIN_UIDS phantoms (those
      // cannot be removed via DELETE and surfaced as "Member not found").
      const members = rows.map((r) => ({
        uid: r.user_id,
        email: r.email ?? undefined,
        role: r.role,
        addedAt: r.created_at,
        addedBy: r.created_by ?? undefined,
      }));
      return json({ members });
    } catch {
      const members = await listTeam(env.BUCKET, parseAdminUids(env.ADMIN_UIDS));
      return json({ members });
    }
  }

  if (path === '/admin/team/create' && method === 'POST') {
    const actor = await requireAdmin(request, env);
    if (!env.SUPABASE_JWT_SECRET?.trim() && !env.SUPABASE_SERVICE_ROLE_KEY?.trim()) {
      return json(
        {
          error:
            'Set SUPABASE_SERVICE_ROLE_KEY on the worker to create admin accounts.',
        },
        503,
      );
    }
    const body = (await request.json()) as {
      email?: string;
      password?: string;
      name?: string;
      role?: 'admin' | 'viewer';
    };
    if (!body.email?.trim() || !body.password) {
      return json({ error: 'email and password are required.' }, 400);
    }
    try {
      const created = await createSupabaseUser(
        {
          SUPABASE_URL: env.SUPABASE_URL,
          SUPABASE_SERVICE_ROLE_KEY: env.SUPABASE_SERVICE_ROLE_KEY,
          SUPABASE_JWT_SECRET: env.SUPABASE_JWT_SECRET,
          SUPABASE_ANON_KEY: env.SUPABASE_ANON_KEY,
        },
        {
          email: body.email,
          password: body.password,
          name: body.name,
        },
      );
      const row = await upsertAdmin(
        env,
        {
          user_id: created.id,
          email: created.email,
          role: body.role === 'viewer' ? 'viewer' : 'admin',
          created_by: actor.uid,
        },
        actor.accessToken,
      );
      await appendAudit(env.BUCKET, {
        actorUid: actor.uid,
        actorEmail: actor.email,
        action: 'team.create_account',
        target: created.id,
        detail: created.email,
      });
      return json({
        member: {
          uid: row.user_id,
          email: row.email ?? created.email,
          role: row.role,
          addedAt: row.created_at,
          addedBy: row.created_by ?? actor.uid,
        },
        user: created,
      });
    } catch (e) {
      return json({ error: e instanceof Error ? e.message : String(e) }, 400);
    }
  }

  if (path === '/admin/team' && method === 'POST') {
    const actor = await requireAdmin(request, env);
    const body = (await request.json()) as {
      uid?: string;
      email?: string;
      role?: 'admin' | 'viewer';
    };
    if (!body.uid?.trim()) return json({ error: 'uid is required.' }, 400);
    try {
      const row = await upsertAdmin(
        env,
        {
          user_id: body.uid.trim(),
          email: body.email,
          role: body.role ?? 'admin',
          created_by: actor.uid,
        },
        actor.accessToken,
      );
      await appendAudit(env.BUCKET, {
        actorUid: actor.uid,
        actorEmail: actor.email,
        action: 'team.add',
        target: row.user_id,
        detail: row.role,
      });
      return json({
        member: {
          uid: row.user_id,
          email: row.email ?? undefined,
          role: row.role,
          addedAt: row.created_at,
          addedBy: row.created_by ?? actor.uid,
        },
      });
    } catch {
      const member = await addTeamMember(
        env.BUCKET,
        { uid: body.uid, email: body.email, role: body.role },
        actor,
      );
      return json({ member });
    }
  }

  if (path.startsWith('/admin/team/') && method === 'DELETE') {
    const actor = await requireAdmin(request, env);
    const uid = decodeURIComponent(path.slice('/admin/team/'.length)).trim();
    if (!uid || uid === 'create') return json({ error: 'Not found.' }, 404);
    if (uid === actor.uid) {
      return json({ error: 'You cannot remove your own admin access.' }, 400);
    }

    // Prefer public.admins; if that misses (legacy R2 team, or RLS returned
    // zero rows), fall through to R2. Returning 404 on the first miss left
    // listed members undeletable when the list came from R2 / ADMIN_UIDS.
    let removedFromDb = false;
    try {
      removedFromDb = await deleteAdmin(env, uid, actor.accessToken);
      if (!removedFromDb && env.SUPABASE_SERVICE_ROLE_KEY?.trim()) {
        removedFromDb = await deleteAdmin(env, uid);
      }
    } catch {
      // Postgres unreachable or misconfigured — try R2 below.
    }
    let removedFromR2 = false;
    if (!removedFromDb) {
      removedFromR2 = await removeTeamMember(env.BUCKET, uid, actor);
    }
    if (!removedFromDb && !removedFromR2) {
      if (parseAdminUids(env.ADMIN_UIDS).has(uid)) {
        return json(
          {
            error:
              'This uid is only in ADMIN_UIDS (worker env). Remove it from wrangler secrets, not here.',
          },
          400,
        );
      }
      return json({ error: 'Member not found.' }, 404);
    }
    if (removedFromDb) {
      await appendAudit(env.BUCKET, {
        actorUid: actor.uid,
        actorEmail: actor.email,
        action: 'team.remove',
        target: uid,
      });
    }
    return json({ ok: true });
  }

  // ---- Audit log --------------------------------------------------
  if (path === '/admin/audit' && method === 'GET') {
    await requireStaff(request, env);
    const entries = await listAudit(env.BUCKET);
    return json({ entries });
  }

  if (path === '/admin/audit' && method === 'DELETE') {
    const actor = await requireAdmin(request, env);
    const cleared = await clearAudit(env.BUCKET);
    await appendAudit(env.BUCKET, {
      actorUid: actor.uid,
      actorEmail: actor.email,
      action: 'audit.clear',
      detail: `cleared=${cleared}`,
    });
    return json({ ok: true, cleared });
  }

  // ---- Vouchers (existing) ----------------------------------------
  if (path === '/admin/vouchers' && method === 'GET') {
    await requireStaff(request, env);
    const vouchers = await listVouchersAdmin(env.BUCKET);
    return json({ vouchers });
  }

  if (path === '/admin/vouchers' && method === 'POST') {
    const actor = await requireAdmin(request, env);
    const body = (await request.json()) as {
      code?: string;
      discountRate?: number;
      discountPercent?: number;
      discountAmountCentavos?: number;
      discountKind?: 'percent' | 'amount';
      label?: string;
      active?: boolean;
      expiresAt?: string | null;
      maxUses?: number | null;
    };
    if (!body.code?.trim()) return json({ error: 'Code is required.' }, 400);
    const kind =
      body.discountKind === 'amount' || (body.discountAmountCentavos ?? 0) > 0
        ? 'amount'
        : 'percent';
    const rate =
      body.discountRate ??
      (body.discountPercent != null ? body.discountPercent / 100 : undefined);
    if (kind === 'percent' && rate == null) {
      return json({ error: 'discountRate or discountPercent is required.' }, 400);
    }
    try {
      const voucher = await upsertVoucherAdmin(env.BUCKET, {
        code: body.code,
        discountRate: rate,
        discountAmountCentavos: body.discountAmountCentavos,
        discountKind: kind,
        label: body.label,
        active: body.active,
        expiresAt: body.expiresAt,
        maxUses: body.maxUses,
      });
      await appendAudit(env.BUCKET, {
        actorUid: actor.uid,
        actorEmail: actor.email,
        action: 'voucher.upsert',
        target: voucher.code,
      });
      return json({ voucher });
    } catch (e) {
      return json({ error: (e as Error).message }, 400);
    }
  }

  if (path.startsWith('/admin/vouchers/') && method === 'DELETE') {
    const actor = await requireAdmin(request, env);
    const code = decodeURIComponent(path.slice('/admin/vouchers/'.length));
    const deleted = await deleteVoucherAdmin(env.BUCKET, code);
    if (!deleted) return json({ error: 'Voucher not found.' }, 404);
    await appendAudit(env.BUCKET, {
      actorUid: actor.uid,
      actorEmail: actor.email,
      action: 'voucher.delete',
      target: code,
    });
    return json({ ok: true });
  }

  return json({ error: 'Not found' }, 404);
}

export type { StoredVoucher };
