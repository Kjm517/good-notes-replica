import { afterEach, describe, expect, it, vi } from 'vitest';

import { handleAccountDelete, type AccountEnv } from './account';

/**
 * R2 stand-in that records deletes and can pretend to hold more than one page
 * of objects, which is the case the prefix walk exists for.
 */
function fakeBucket(keys: string[] = []) {
  const remaining = [...keys];
  const deleted: string[] = [];
  return {
    deleted,
    async list({ prefix, limit = 1000 }: { prefix?: string; limit?: number }) {
      const matching = remaining.filter((k) => k.startsWith(prefix ?? ''));
      const page = matching.slice(0, limit);
      return {
        objects: page.map((key) => ({ key })),
        truncated: matching.length > page.length,
        cursor: 'next',
      };
    },
    async delete(keys: string | string[]) {
      const list = Array.isArray(keys) ? keys : [keys];
      deleted.push(...list);
      for (const k of list) {
        const i = remaining.indexOf(k);
        if (i >= 0) remaining.splice(i, 1);
      }
    },
  } as unknown as R2Bucket & { deleted: string[] };
}

/** A token whose signature verification is stubbed out below. */
function req(token = 'tok') {
  return new Request('https://w.dev/user/account/delete', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
  });
}

function env(overrides: Partial<AccountEnv> = {}): AccountEnv & {
  BUCKET: R2Bucket & { deleted: string[] };
} {
  return {
    BUCKET: fakeBucket(['users/me/a.pdf', 'users/me/b.png']),
    SUPABASE_URL: 'https://proj.supabase.co',
    SUPABASE_SERVICE_ROLE_KEY: 'service-key',
    ...overrides,
  } as AccountEnv & { BUCKET: R2Bucket & { deleted: string[] } };
}

/** Stubs auth so these tests exercise deletion, not JWT verification. */
async function withUser(uid: string, run: () => Promise<Response>) {
  const auth = await import('./auth');
  const spy = vi
    .spyOn(auth, 'requireUser')
    .mockResolvedValue({ uid } as Awaited<ReturnType<typeof auth.requireUser>>);
  try {
    return await run();
  } finally {
    spy.mockRestore();
  }
}

afterEach(() => vi.restoreAllMocks());

describe('account deletion', () => {
  it('refuses anything but POST', async () => {
    const res = await handleAccountDelete(
      new Request('https://w.dev/user/account/delete'),
      env(),
    );
    expect(res.status).toBe(405);
  });

  it('propagates the 401 when there is no valid token', async () => {
    // requireUser throws; the route wrapper turns that into a 401.
    await expect(
      handleAccountDelete(
        new Request('https://w.dev/user/account/delete', { method: 'POST' }),
        env(),
      ),
    ).rejects.toThrow();
  });

  it('fails closed when the service role key is missing', async () => {
    const e = env({ SUPABASE_SERVICE_ROLE_KEY: undefined });
    const fetchSpy = vi.spyOn(globalThis, 'fetch');
    const res = await withUser('me', () => handleAccountDelete(req(), e));
    expect(res.status).toBe(503);
    // Nothing was destroyed, so the user can be told honestly that it failed
    // rather than losing files while keeping a login.
    expect(e.BUCKET.deleted).toHaveLength(0);
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it('deletes files, then rows, then the auth user', async () => {
    const calls: string[] = [];
    vi.spyOn(globalThis, 'fetch').mockImplementation((async (
      input: RequestInfo | URL,
      init?: RequestInit,
    ) => {
      calls.push(`${init?.method ?? 'GET'} ${String(input)}`);
      return new Response('[]', { status: 200 });
    }) as typeof fetch);

    const e = env();
    const res = await withUser('me', () => handleAccountDelete(req(), e));
    expect(res.status).toBe(200);

    // Only this account's prefix.
    expect(e.BUCKET.deleted).toEqual(['users/me/a.pdf', 'users/me/b.png']);

    // Every owned table, and the auth user last.
    for (const table of ['documents', 'pages', 'ink', 'assets', 'user_prefs']) {
      expect(calls.some((c) => c.includes(`/rest/v1/${table}?user_id=eq.me`)))
        .toBe(true);
    }
    expect(calls.at(-1)).toContain('/auth/v1/admin/users/me');
  });

  it('only ever deletes the caller, whatever the body says', async () => {
    const calls: string[] = [];
    vi.spyOn(globalThis, 'fetch').mockImplementation((async (
      input: RequestInfo | URL,
    ) => {
      calls.push(String(input));
      return new Response('[]', { status: 200 });
    }) as typeof fetch);

    const e = env({ BUCKET: fakeBucket(['users/victim/secret.pdf']) });
    const hostile = new Request('https://w.dev/user/account/delete', {
      method: 'POST',
      headers: { Authorization: 'Bearer tok', 'Content-Type': 'application/json' },
      body: JSON.stringify({ uid: 'victim' }),
    });
    await withUser('attacker', () => handleAccountDelete(hostile, e));

    // The uid comes from the verified token, never the request.
    expect(calls.every((c) => c.includes('attacker'))).toBe(true);
    expect(calls.some((c) => c.includes('victim'))).toBe(false);
    expect(e.BUCKET.deleted).toHaveLength(0);
  });

  it('walks past the first page of objects', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(new Response('[]'));
    const many = Array.from({ length: 1500 }, (_, i) => `users/me/f${i}.png`);
    const e = env({ BUCKET: fakeBucket(many) });
    await withUser('me', () => handleAccountDelete(req(), e));
    expect(e.BUCKET.deleted).toHaveLength(1500);
  });

  it('stops before deleting the login if the rows cannot be removed', async () => {
    vi.spyOn(globalThis, 'fetch').mockImplementation((async (
      input: RequestInfo | URL,
    ) => {
      if (String(input).includes('/rest/v1/')) {
        return new Response('nope', { status: 500 });
      }
      return new Response('[]');
    }) as typeof fetch);

    const e = env();
    await expect(
      withUser('me', () => handleAccountDelete(req(), e)),
    ).rejects.toThrow(/Could not delete/);
  });
});
