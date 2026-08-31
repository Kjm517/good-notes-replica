import { describe, expect, it } from 'vitest';

import {
  entitlementResponse,
  grantPremiumFromPayment,
  readPaymentLedger,
  type BillingRecord,
} from './billing';

/**
 * Minimal in-memory stand-in for the R2 binding.
 *
 * The billing logic only ever does get/put of small JSON blobs, so faking the
 * two methods is enough and keeps these tests runnable without miniflare.
 */
function fakeBucket() {
  const store = new Map<string, string>();
  return {
    store,
    async get(key: string) {
      const value = store.get(key);
      if (value === undefined) return null;
      return { text: async () => value };
    },
    async put(key: string, value: string) {
      store.set(key, value);
    },
  } as unknown as R2Bucket & { store: Map<string, string> };
}

const UID = 'user-1';

describe('grantPremiumFromPayment', () => {
  it('grants a fresh 30-day term for monthly', async () => {
    const bucket = fakeBucket();
    const before = Date.now();

    const record = await grantPremiumFromPayment(bucket, UID, 'monthly', {
      paymentIntentId: 'pi_1',
    });

    expect(record.isPremium).toBe(true);
    expect(record.plan).toBe('monthly');
    const expiry = new Date(record.expiresAt!).getTime();
    const days = (expiry - before) / 86_400_000;
    expect(days).toBeGreaterThan(29.9);
    expect(days).toBeLessThan(30.1);
  });

  it('stacks a renewal onto the remaining term instead of restarting it', async () => {
    const bucket = fakeBucket();
    await grantPremiumFromPayment(bucket, UID, 'monthly', {
      paymentIntentId: 'pi_1',
    });
    const first = await readBillingJson(bucket);

    const second = await grantPremiumFromPayment(bucket, UID, 'monthly', {
      paymentIntentId: 'pi_2',
    });

    const gained =
      new Date(second.expiresAt!).getTime() -
      new Date(first.expiresAt!).getTime();
    // Paying twice buys ~60 days total, not 30 — the user must not lose the
    // time they already paid for.
    expect(gained / 86_400_000).toBeGreaterThan(29.9);
  });

  /**
   * The status endpoint polls every 3 seconds while a QR code is on screen.
   * Without deduping, each poll would re-grant and extend the expiry again —
   * a user could sit on the screen and accrue months for one payment.
   */
  it('ignores a repeat grant for the same payment intent', async () => {
    const bucket = fakeBucket();
    const first = await grantPremiumFromPayment(bucket, UID, 'monthly', {
      paymentIntentId: 'pi_repeat',
    });
    const second = await grantPremiumFromPayment(bucket, UID, 'monthly', {
      paymentIntentId: 'pi_repeat',
    });

    expect(second.expiresAt).toBe(first.expiresAt);
    const ledger = await readPaymentLedger(bucket, UID);
    expect(ledger).toHaveLength(1);
  });

  it('still dedupes card checkout session ids', async () => {
    const bucket = fakeBucket();
    const first = await grantPremiumFromPayment(bucket, UID, 'yearly', {
      paymentIntentId: 'cs_repeat',
    });
    const second = await grantPremiumFromPayment(bucket, UID, 'yearly', {
      paymentIntentId: 'cs_repeat',
    });
    expect(second.expiresAt).toBe(first.expiresAt);
  });

  /**
   * Voucher grants reuse the code as their id. Deduping those would stop a
   * returning user from redeeming the same promo for a later term.
   */
  it('does not dedupe voucher grants', async () => {
    const bucket = fakeBucket();
    const first = await grantPremiumFromPayment(bucket, UID, 'monthly', {
      paymentIntentId: 'voucher:STUDENT20',
    });
    const second = await grantPremiumFromPayment(bucket, UID, 'monthly', {
      paymentIntentId: 'voucher:STUDENT20',
    });
    expect(second.expiresAt).not.toBe(first.expiresAt);
  });

  it('records what was charged, not the list price', async () => {
    const bucket = fakeBucket();
    await grantPremiumFromPayment(bucket, UID, 'monthly', {
      paymentIntentId: 'pi_discounted',
      amountCentavos: 15920,
    });

    const ledger = await readPaymentLedger(bucket, UID);
    expect(ledger[0].amountCentavos).toBe(15920);
  });

  it('falls back to the list price when the amount is unknown', async () => {
    const bucket = fakeBucket();
    await grantPremiumFromPayment(bucket, UID, 'monthly', {
      paymentIntentId: 'pi_unknown',
    });

    const ledger = await readPaymentLedger(bucket, UID);
    expect(ledger[0].amountCentavos).toBe(19900);
  });
});

describe('entitlementResponse', () => {
  it('reports no premium for a missing record', () => {
    expect(entitlementResponse(null).isPremium).toBe(false);
  });

  it('treats an elapsed expiry as lapsed', () => {
    const record: BillingRecord = {
      isPremium: true,
      plan: 'monthly',
      expiresAt: new Date(Date.now() - 1000).toISOString(),
      source: 'paymongo',
      updatedAt: new Date().toISOString(),
    };
    expect(entitlementResponse(record).isPremium).toBe(false);
  });

  it('keeps access right up to the expiry instant', () => {
    const record: BillingRecord = {
      isPremium: true,
      plan: 'monthly',
      expiresAt: new Date(Date.now() + 60_000).toISOString(),
      source: 'paymongo',
      updatedAt: new Date().toISOString(),
    };
    // Cancelling does not shorten the term, so a minute left is still premium.
    expect(entitlementResponse(record).isPremium).toBe(true);
  });

  it('reports a far-future expiry as lifetime', () => {
    const record: BillingRecord = {
      isPremium: true,
      plan: 'yearly',
      expiresAt: '9999-12-31T23:59:59.000Z',
      source: 'paymongo',
      updatedAt: new Date().toISOString(),
    };
    const result = entitlementResponse(record);
    expect(result.isPremium).toBe(true);
    expect(result.plan).toBe('lifetime');
    expect(result.expiresAt).toBeNull();
  });

  /**
   * Admin lifetime grants leave expiresAt null. This used to read as "not
   * premium", so the grant never reached the app.
   */
  it('treats a null expiry as lifetime, not lapsed', () => {
    const record: BillingRecord = {
      isPremium: true,
      plan: 'lifetime',
      expiresAt: null,
      source: 'paymongo',
      updatedAt: new Date().toISOString(),
    };
    expect(entitlementResponse(record).isPremium).toBe(true);
  });
});

async function readBillingJson(bucket: R2Bucket): Promise<BillingRecord> {
  const object = await bucket.get(`users/${UID}/billing.json`);
  return JSON.parse(await object!.text()) as BillingRecord;
}
