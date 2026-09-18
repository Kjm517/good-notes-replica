import { describe, expect, it } from 'vitest';

import { isOriginAllowed } from './index';
import { handleBillingWebhook } from './billing';

/** Minimal R2 stand-in; the webhook path below never reaches storage. */
function fakeBucket() {
  const store = new Map<string, string>();
  return {
    store,
    async get(key: string) {
      const v = store.get(key);
      return v == null ? null : { text: async () => v };
    },
    async put(key: string, value: string) {
      store.set(key, value);
    },
  } as unknown as R2Bucket;
}

describe('CORS origin allowlist', () => {
  const env = {};

  it('allows the production web app', () => {
    expect(isOriginAllowed('https://notably-sigma.vercel.app', env)).toBe(true);
  });

  it('allows Cloudflare Pages, where the site is served from', () => {
    expect(isOriginAllowed('https://navie.pages.dev', env)).toBe(true);
    expect(isOriginAllowed('https://abc123.navie.pages.dev', env)).toBe(true);
  });

  it('refuses a lookalike of the Pages domain', () => {
    expect(isOriginAllowed('https://evil-pages.dev', env)).toBe(false);
    expect(isOriginAllowed('https://notpages.dev', env)).toBe(false);
  });

  it('allows the site on this account\'s workers.dev subdomain', () => {
    expect(isOriginAllowed('https://navie.notably.workers.dev', env)).toBe(true);
  });

  it('refuses another account\'s workers.dev subdomain', () => {
    expect(isOriginAllowed('https://evil.someone-else.workers.dev', env))
      .toBe(false);
    expect(isOriginAllowed('https://evil-notably.workers.dev', env)).toBe(false);
  });

  it('allows Vercel preview deployments', () => {
    expect(
      isOriginAllowed('https://notably-2ovmvfu6a-karens.vercel.app', env),
    ).toBe(true);
  });

  it('allows localhost on any port, so flutter run -d chrome works', () => {
    expect(isOriginAllowed('http://localhost:5000', env)).toBe(true);
    expect(isOriginAllowed('http://127.0.0.1:8789', env)).toBe(true);
  });

  it('refuses an unrelated origin', () => {
    expect(isOriginAllowed('https://evil.example.com', env)).toBe(false);
  });

  it('refuses a lookalike that merely ends with the allowed name', () => {
    expect(isOriginAllowed('https://notavercel.app', env)).toBe(false);
    expect(isOriginAllowed('https://evil-vercel.app', env)).toBe(false);
  });

  it('refuses plain http for non-localhost', () => {
    expect(isOriginAllowed('http://notably-sigma.vercel.app', env)).toBe(false);
  });

  it('sends nothing when there is no Origin (native apps)', () => {
    expect(isOriginAllowed(null, env)).toBe(false);
  });

  it('honours an explicit ALLOWED_ORIGINS override', () => {
    const custom = { ALLOWED_ORIGINS: 'https://notably.app' };
    expect(isOriginAllowed('https://notably.app', custom)).toBe(true);
    // The defaults no longer apply once the var is set.
    expect(isOriginAllowed('https://notably-sigma.vercel.app', custom)).toBe(
      false,
    );
  });
});

describe('PayMongo webhook fails closed', () => {
  const paidEvent = JSON.stringify({
    data: {
      attributes: {
        type: 'payment.paid',
        data: {
          id: 'pay_forged',
          attributes: { metadata: { uid: 'victim', plan: 'lifetime' } },
        },
      },
    },
  });

  it('refuses to grant anything when the secret is not configured', async () => {
    const env = { BUCKET: fakeBucket() };
    const res = await handleBillingWebhook(
      new Request('https://w.dev/billing/webhook', {
        method: 'POST',
        body: paidEvent,
      }),
      env,
    );
    expect(res.status).toBe(503);
    // Nothing was written, so no entitlement was granted.
    expect((env.BUCKET as unknown as { store: Map<string, string> }).store.size)
      .toBe(0);
  });

  it('rejects a forged signature when the secret is configured', async () => {
    const env = {
      BUCKET: fakeBucket(),
      PAYMONGO_WEBHOOK_SECRET: 'whsk_test',
    };
    const res = await handleBillingWebhook(
      new Request('https://w.dev/billing/webhook', {
        method: 'POST',
        body: paidEvent,
        headers: { 'Paymongo-Signature': 't=1,te=deadbeef' },
      }),
      env,
    );
    expect(res.status).toBe(401);
    expect((env.BUCKET as unknown as { store: Map<string, string> }).store.size)
      .toBe(0);
  });
});
