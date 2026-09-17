import { describe, expect, it } from 'vitest';

import toml from '../wrangler.toml?raw';

/**
 * Which TOML table each top-level key ends up in.
 *
 * TOML hands every key after a `[table]` header to that table, so adding a
 * binding above the vars silently moves them out of [vars]. That is not a
 * syntax error and wrangler reports no problem — the Worker just deploys with
 * no AI providers configured and every request 503s. It happened once; this
 * keeps it from happening quietly again.
 */
function tablesOf(toml: string): Map<string, string> {
  const owner = new Map<string, string>();
  let table = '';
  for (const raw of toml.split('\n')) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const header = line.match(/^\[{1,2}([^\]]+)\]{1,2}$/);
    if (header) {
      table = header[1];
      continue;
    }
    const key = line.match(/^([A-Za-z0-9_]+)\s*=/);
    if (key) owner.set(key[1], table);
  }
  return owner;
}

describe('wrangler.toml', () => {
  const owner = tablesOf(toml);

  // Without a provider and model pair the gateway builds an empty chain and
  // answers "No AI provider is configured" to every request.
  const required = [
    'AI_TEXT_PROVIDER',
    'AI_TEXT_MODEL',
    'AI_VISION_PROVIDER',
    'AI_VISION_MODEL',
    'AI_FALLBACK_PROVIDER',
    'AI_FALLBACK_MODEL',
    'AI_QUALITY',
    'MONTHLY_AI_BUDGET',
    'MAX_AI_REQUESTS_PER_USER',
    'SUPABASE_URL',
  ];

  for (const key of required) {
    it(`keeps ${key} inside [vars]`, () => {
      expect(owner.get(key)).toBe('vars');
    });
  }

  it('declares the Workers AI binding', () => {
    expect(toml).toMatch(/^\[ai\]\s*$/m);
    expect(owner.get('binding')).toBe('ai');
  });
});

describe('AI models are priced', () => {
  /**
   * A model with no entry in MODEL_PRICES is charged at UNKNOWN_MODEL_PRICE
   * ($5/$15 per M), which is deliberately dear so nothing unpriced slips past
   * a budget check. That is right for a surprise model and wrong for the free
   * tier: a Workers AI id that drifts out of the table starts eating the
   * monthly ceiling despite costing nothing.
   */
  it('prices every configured Workers AI model as free', async () => {
    const { MODEL_PRICES } = await import('./ai/pricing');
    const configured = [...toml.matchAll(/^AI_\w*MODEL\s*=\s*"([^"]+)"/gm)].map(
      (m) => m[1],
    );
    const workersAi = configured.filter((m) => m.startsWith('free/'));
    expect(workersAi.length).toBeGreaterThan(0);
    for (const model of workersAi) {
      expect(MODEL_PRICES).toHaveProperty(model);
      expect((MODEL_PRICES as Record<string, { inPerM: number }>)[model].inPerM)
        .toBe(0);
    }
  });
});
