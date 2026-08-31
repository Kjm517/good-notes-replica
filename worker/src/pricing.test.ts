import { describe, expect, it } from 'vitest';

import { amountCentavosForPlan } from './billing';
import type { StoredVoucher } from './vouchers';

/** PayMongo rejects any charge below ₱20. */
const PAYMONGO_MINIMUM_CENTAVOS = 2000;

function bucketWithVouchers(vouchers: StoredVoucher[]) {
  const store = new Map<string, string>();
  store.set('config/vouchers.json', JSON.stringify({ vouchers }));
  return {
    async get(key: string) {
      const value = store.get(key);
      if (value === undefined) return null;
      return { text: async () => value };
    },
    async put(key: string, value: string) {
      store.set(key, value);
    },
  } as unknown as R2Bucket;
}

function voucher(overrides: Partial<StoredVoucher>): StoredVoucher {
  return {
    code: 'TEST',
    discountRate: 0,
    active: true,
    createdAt: new Date().toISOString(),
    usedCount: 0,
    ...overrides,
  };
}

describe('amountCentavosForPlan', () => {
  it('charges list price with no voucher', async () => {
    const bucket = bucketWithVouchers([]);
    expect(await amountCentavosForPlan(bucket, 'monthly')).toBe(19900);
    expect(await amountCentavosForPlan(bucket, 'yearly')).toBe(149900);
  });

  it('ignores a code that does not exist', async () => {
    const bucket = bucketWithVouchers([]);
    expect(await amountCentavosForPlan(bucket, 'monthly', 'NOPE')).toBe(19900);
  });

  it('ignores an inactive voucher', async () => {
    const bucket = bucketWithVouchers([
      voucher({ code: 'OFF50', discountRate: 0.5, active: false }),
    ]);
    expect(await amountCentavosForPlan(bucket, 'monthly', 'OFF50')).toBe(19900);
  });

  it('applies a percentage discount', async () => {
    const bucket = bucketWithVouchers([
      voucher({ code: 'STUDENT20', discountRate: 0.2 }),
    ]);
    expect(await amountCentavosForPlan(bucket, 'monthly', 'STUDENT20')).toBe(
      15920,
    );
  });

  it('treats 100% off as free rather than as the minimum charge', async () => {
    const bucket = bucketWithVouchers([
      voucher({ code: 'FREE', discountRate: 1 }),
    ]);
    expect(await amountCentavosForPlan(bucket, 'monthly', 'FREE')).toBe(0);
  });

  it('raises a deep percentage discount to PayMongo\'s minimum', async () => {
    // 99% off ₱199 is ₱1.99, which PayMongo would reject.
    const bucket = bucketWithVouchers([
      voucher({ code: 'DEEP', discountRate: 0.99 }),
    ]);
    expect(await amountCentavosForPlan(bucket, 'monthly', 'DEEP')).toBe(
      PAYMONGO_MINIMUM_CENTAVOS,
    );
  });

  it('applies a fixed-amount discount', async () => {
    const bucket = bucketWithVouchers([
      voucher({
        code: 'PHP50OFF',
        discountKind: 'amount',
        discountAmountCentavos: 5000,
      }),
    ]);
    expect(await amountCentavosForPlan(bucket, 'monthly', 'PHP50OFF')).toBe(
      14900,
    );
  });

  it('treats a fixed discount at or above the price as free', async () => {
    const bucket = bucketWithVouchers([
      voucher({
        code: 'ALLOFF',
        discountKind: 'amount',
        discountAmountCentavos: 19900,
      }),
    ]);
    expect(await amountCentavosForPlan(bucket, 'monthly', 'ALLOFF')).toBe(0);
  });

  /**
   * The percentage branch floors at ₱20, the fixed-amount branch floored only
   * at zero — so a large peso-off voucher produced a charge PayMongo rejects,
   * and checkout failed with no explanation the user could act on.
   */
  it('raises a large fixed discount to the minimum instead of an unchargeable amount', async () => {
    const bucket = bucketWithVouchers([
      voucher({
        code: 'PHP190OFF',
        discountKind: 'amount',
        discountAmountCentavos: 19000,
      }),
    ]);
    const amount = await amountCentavosForPlan(bucket, 'monthly', 'PHP190OFF');
    expect(
      amount === 0 || amount >= PAYMONGO_MINIMUM_CENTAVOS,
      `₱${amount / 100} is chargeable`,
    ).toBe(true);
  });

  it('never returns an amount PayMongo would reject, for any discount', async () => {
    for (let off = 0; off <= 19900; off += 500) {
      const bucket = bucketWithVouchers([
        voucher({
          code: 'SWEEP',
          discountKind: 'amount',
          discountAmountCentavos: off,
        }),
      ]);
      const amount = await amountCentavosForPlan(bucket, 'monthly', 'SWEEP');
      expect(
        amount === 0 || amount >= PAYMONGO_MINIMUM_CENTAVOS,
        `discount ${off} produced ₱${amount / 100}`,
      ).toBe(true);
    }
  });

  it('is case- and whitespace-insensitive about codes', async () => {
    const bucket = bucketWithVouchers([
      voucher({ code: 'STUDENT20', discountRate: 0.2 }),
    ]);
    expect(await amountCentavosForPlan(bucket, 'monthly', '  student20  ')).toBe(
      15920,
    );
  });

  it('ignores an expired voucher', async () => {
    const bucket = bucketWithVouchers([
      voucher({
        code: 'OLD',
        discountRate: 0.5,
        expiresAt: new Date(Date.now() - 86_400_000).toISOString(),
      }),
    ]);
    expect(await amountCentavosForPlan(bucket, 'monthly', 'OLD')).toBe(19900);
  });

  it('ignores a voucher that hit its use cap', async () => {
    const bucket = bucketWithVouchers([
      voucher({ code: 'CAPPED', discountRate: 0.5, maxUses: 5, usedCount: 5 }),
    ]);
    expect(await amountCentavosForPlan(bucket, 'monthly', 'CAPPED')).toBe(19900);
  });
});
