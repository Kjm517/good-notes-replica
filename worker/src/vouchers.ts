const VOUCHERS_KEY = 'config/vouchers.json';

export type VoucherDiscountKind = 'percent' | 'amount';

export interface StoredVoucher {
  code: string;
  /** 0–1 for percent vouchers. Ignored when [discountKind] is amount. */
  discountRate: number;
  /** Fixed peso off, in centavos (₱99 = 9900). */
  discountAmountCentavos?: number | null;
  discountKind?: VoucherDiscountKind;
  label?: string;
  active: boolean;
  createdAt: string;
  expiresAt?: string | null;
  maxUses?: number | null;
  usedCount: number;
}

export interface VoucherStore {
  vouchers: StoredVoucher[];
}

const DEFAULT_STORE: VoucherStore = {
  vouchers: [
    {
      code: 'STUDENT20',
      discountRate: 0.2,
      label: 'Student discount · ₱159/mo',
      active: true,
      createdAt: new Date().toISOString(),
      usedCount: 0,
    },
    {
      code: 'LAUNCH99',
      discountRate: 1 - 99 / 199,
      label: 'Launch promo · ₱99 first month',
      active: true,
      createdAt: new Date().toISOString(),
      usedCount: 0,
      maxUses: 500,
    },
  ],
};

export function parseAdminUids(raw: string | undefined): Set<string> {
  if (!raw?.trim()) return new Set();
  return new Set(
    raw
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean),
  );
}

// Re-exported from admin-store for backwards compatibility in tests.
export { isAdminUid } from './admin-store';

export async function readVoucherStore(bucket: R2Bucket): Promise<VoucherStore> {
  const object = await bucket.get(VOUCHERS_KEY);
  if (!object) {
    await writeVoucherStore(bucket, DEFAULT_STORE);
    return structuredClone(DEFAULT_STORE);
  }
  try {
    const parsed = JSON.parse(await object.text()) as VoucherStore;
    if (!Array.isArray(parsed.vouchers)) return structuredClone(DEFAULT_STORE);
    return parsed;
  } catch {
    return structuredClone(DEFAULT_STORE);
  }
}

export async function writeVoucherStore(
  bucket: R2Bucket,
  store: VoucherStore,
): Promise<void> {
  await bucket.put(VOUCHERS_KEY, JSON.stringify(store), {
    httpMetadata: { contentType: 'application/json' },
  });
}

function normalizeCode(code: string): string {
  return code.trim().toUpperCase();
}

function voucherIsUsable(v: StoredVoucher, now = Date.now()): boolean {
  if (!v.active) return false;
  if (v.expiresAt) {
    const exp = Date.parse(v.expiresAt);
    if (!Number.isNaN(exp) && exp < now) return false;
  }
  if (v.maxUses != null && v.usedCount >= v.maxUses) return false;
  return true;
}

export interface ResolvedVoucher {
  discountRate: number;
  discountKind: VoucherDiscountKind;
  discountAmountCentavos?: number | null;
  label?: string;
}

export function voucherKind(v: StoredVoucher): VoucherDiscountKind {
  if (v.discountKind === 'amount' || (v.discountAmountCentavos ?? 0) > 0) {
    return 'amount';
  }
  return 'percent';
}

export async function resolveVoucherDiscount(
  bucket: R2Bucket,
  rawCode?: string | null,
): Promise<ResolvedVoucher | null> {
  if (!rawCode?.trim()) return null;
  const code = normalizeCode(rawCode);
  const store = await readVoucherStore(bucket);
  const match = store.vouchers.find((v) => normalizeCode(v.code) === code);
  if (!match || !voucherIsUsable(match)) return null;
  return {
    discountRate: match.discountRate,
    discountKind: voucherKind(match),
    discountAmountCentavos: match.discountAmountCentavos ?? null,
    label: match.label,
  };
}

export async function validateVoucherPublic(
  bucket: R2Bucket,
  rawCode: string,
): Promise<{
  valid: boolean;
  code: string;
  discountRate?: number;
  discountKind?: VoucherDiscountKind;
  discountAmountCentavos?: number;
  label?: string;
}> {
  const code = normalizeCode(rawCode);
  const resolved = await resolveVoucherDiscount(bucket, code);
  if (!resolved) return { valid: false, code };
  return {
    valid: true,
    code,
    discountRate: resolved.discountRate,
    discountKind: resolved.discountKind,
    discountAmountCentavos: resolved.discountAmountCentavos ?? undefined,
    label: resolved.label,
  };
}

export async function listVouchersAdmin(bucket: R2Bucket): Promise<StoredVoucher[]> {
  const store = await readVoucherStore(bucket);
  return store.vouchers
    .slice()
    .sort((a, b) => a.code.localeCompare(b.code));
}

export async function upsertVoucherAdmin(
  bucket: R2Bucket,
  input: {
    code: string;
    discountRate?: number;
    discountAmountCentavos?: number | null;
    discountKind?: VoucherDiscountKind;
    label?: string;
    active?: boolean;
    expiresAt?: string | null;
    maxUses?: number | null;
  },
): Promise<StoredVoucher> {
  const code = normalizeCode(input.code);
  if (!/^[A-Z0-9_-]{3,32}$/.test(code)) {
    throw new Error('Code must be 3–32 characters (letters, numbers, _ or -).');
  }
  const kind: VoucherDiscountKind =
    input.discountKind === 'amount' ||
    (input.discountAmountCentavos != null && input.discountAmountCentavos > 0)
      ? 'amount'
      : 'percent';

  let discountRate = 0;
  let discountAmountCentavos: number | null = null;
  if (kind === 'amount') {
    const amount = Math.round(input.discountAmountCentavos ?? 0);
    if (amount < 100 || amount > 148900) {
      throw new Error('Peso discount must be between ₱1 and ₱1,489.');
    }
    discountAmountCentavos = amount;
  } else {
    const rate = input.discountRate ?? 0;
    if (rate <= 0 || rate > 1) {
      throw new Error('Discount must be between 1% and 100%.');
    }
    discountRate = rate;
  }

  const store = await readVoucherStore(bucket);
  const existing = store.vouchers.find((v) => normalizeCode(v.code) === code);
  const now = new Date().toISOString();

  const row: StoredVoucher = {
    code,
    discountRate,
    discountAmountCentavos,
    discountKind: kind,
    label: input.label?.trim() || undefined,
    active: input.active ?? true,
    createdAt: existing?.createdAt ?? now,
    expiresAt: input.expiresAt ?? null,
    maxUses: input.maxUses ?? null,
    usedCount: existing?.usedCount ?? 0,
  };

  if (existing) {
    Object.assign(existing, row);
  } else {
    store.vouchers.push(row);
  }

  await writeVoucherStore(bucket, store);
  return row;
}

export async function deleteVoucherAdmin(
  bucket: R2Bucket,
  rawCode: string,
): Promise<boolean> {
  const code = normalizeCode(rawCode);
  const store = await readVoucherStore(bucket);
  const before = store.vouchers.length;
  store.vouchers = store.vouchers.filter(
    (v) => normalizeCode(v.code) !== code,
  );
  if (store.vouchers.length === before) return false;
  await writeVoucherStore(bucket, store);
  return true;
}
