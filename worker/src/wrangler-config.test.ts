import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import { describe, expect, it } from 'vitest';

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
  const toml = readFileSync(join(__dirname, '..', 'wrangler.toml'), 'utf8');
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
