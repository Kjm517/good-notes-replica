const VOUCHERS_KEY = 'config/vouchers.json';

export interface StoredVoucher {
  code: string;
  discountRate: number;
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

export async function resolveVoucherDiscount(
  bucket: R2Bucket,
  rawCode?: string | null,
): Promise<{ discountRate: number; label?: string } | null> {
  if (!rawCode?.trim()) return null;
  const code = normalizeCode(rawCode);
  const store = await readVoucherStore(bucket);
  const match = store.vouchers.find((v) => normalizeCode(v.code) === code);
  if (!match || !voucherIsUsable(match)) return null;
  return { discountRate: match.discountRate, label: match.label };
}

export async function validateVoucherPublic(
  bucket: R2Bucket,
  rawCode: string,
): Promise<{
  valid: boolean;
  code: string;
  discountRate?: number;
  label?: string;
}> {
  const code = normalizeCode(rawCode);
  const resolved = await resolveVoucherDiscount(bucket, code);
  if (!resolved) return { valid: false, code };
  return {
    valid: true,
    code,
    discountRate: resolved.discountRate,
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
    discountRate: number;
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
  if (input.discountRate <= 0 || input.discountRate >= 1) {
    throw new Error('Discount must be between 1% and 99%.');
  }

  const store = await readVoucherStore(bucket);
  const existing = store.vouchers.find((v) => normalizeCode(v.code) === code);
  const now = new Date().toISOString();

  const row: StoredVoucher = {
    code,
    discountRate: input.discountRate,
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
