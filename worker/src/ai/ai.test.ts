import { describe, expect, it, vi } from 'vitest';

import { AiCache, cacheKey, hashImage } from './cache';
import { actualCost, estimateCost, priceFor, UNKNOWN_MODEL_PRICE } from './pricing';
import {
  AiQuotaError,
  AiUnavailableError,
  type AiProvider,
} from './provider';
import { aiSettings, candidates, runWithFallback, type AiEnv } from './router';
import { UsageStore, type BudgetLimits } from './usage';

/** In-memory stand-in for the R2 bucket the cache normally writes to. */
function fakeBucket() {
  const store = new Map<string, string>();
  return {
    store,
    bucket: {
      get: async (key: string) =>
        store.has(key) ? { text: async () => store.get(key)! } : null,
      put: async (key: string, body: string) => {
        store.set(key, body);
      },
    } as unknown as R2Bucket,
  };
}

const limits: BudgetLimits = {
  monthlyBudgetUsd: 10,
  warnBudgetUsd: 5,
  maxRequestsPerUserPerDay: 25,
  maxVisionRequestsPerUserPerDay: 10,
};

describe('pricing', () => {
  it('treats an unknown model as expensive, never free', () => {
    // A missing price must not be the reason a budget check passes.
    expect(priceFor('some-model-released-tomorrow')).toBe(UNKNOWN_MODEL_PRICE);
    expect(priceFor('some-model-released-tomorrow').inPerM).toBeGreaterThan(0);
  });

  it('charges for images on top of the prompt', () => {
    const textOnly = estimateCost({
      model: 'gemini-3.5-flash-lite',
      promptText: 'a'.repeat(3500),
      maxOutputTokens: 1000,
    });
    const withImages = estimateCost({
      model: 'gemini-3.5-flash-lite',
      promptText: 'a'.repeat(3500),
      images: 12,
      maxOutputTokens: 1000,
    });
    expect(withImages.inputTokens).toBeGreaterThan(textOnly.inputTokens);
    expect(withImages.usd).toBeGreaterThan(textOnly.usd);
  });

  it('costs a free-tier model at zero but still names it', () => {
    const free = estimateCost({
      model: 'free/@cf/meta/llama-3.1-8b-instruct',
      promptText: 'a'.repeat(10000),
      maxOutputTokens: 2000,
    });
    expect(free.usd).toBe(0);
    expect(free.inputTokens).toBeGreaterThan(0);
  });

  it('reports the real cost once tokens are known', () => {
    expect(actualCost('gemini-3.5-flash-lite', 1_000_000, 0)).toBeCloseTo(0.10);
    expect(actualCost('gemini-3.5-flash-lite', 0, 1_000_000)).toBeCloseTo(0.40);
  });
});

describe('cache key', () => {
  it('is stable for identical work', async () => {
    const parts = {
      promptVersion: 'v1',
      model: 'm',
      prompt: 'What is the marked structure?',
    };
    expect(await cacheKey(parts)).toBe(await cacheKey(parts));
  });

  it('changes when anything that changes the answer changes', async () => {
    const base = { promptVersion: 'v1', model: 'm', prompt: 'p' };
    const key = await cacheKey(base);
    expect(await cacheKey({ ...base, promptVersion: 'v2' })).not.toBe(key);
    expect(await cacheKey({ ...base, model: 'other' })).not.toBe(key);
    expect(await cacheKey({ ...base, prompt: 'p2' })).not.toBe(key);
    expect(await cacheKey({ ...base, imageHashes: ['abc'] })).not.toBe(key);
  });

  it('separates users when the cache is scoped per account', async () => {
    const base = { promptVersion: 'v1', model: 'm', prompt: 'p' };
    expect(await cacheKey({ ...base, userId: 'a' })).not.toBe(
      await cacheKey({ ...base, userId: 'b' }),
    );
  });

  it('hashes the same image to the same key — the diagram is analysed once',
    async () => {
      expect(await hashImage('aGVsbG8=')).toBe(await hashImage('aGVsbG8='));
      expect(await hashImage('aGVsbG8=')).not.toBe(await hashImage('d29ybGQ='));
    });
});

describe('AiCache', () => {
  it('serves the second identical request without a second AI call', async () => {
    const { bucket } = fakeBucket();
    const cache = new AiCache(bucket);
    const key = await cacheKey({ promptVersion: 'v1', model: 'm', prompt: 'p' });

    expect(await cache.get(key)).toBeNull();
    await cache.put(key, {
      text: '{"questions":[]}',
      model: 'm',
      provider: 'gemini',
      inputTokens: 100,
      outputTokens: 50,
    });
    const hit = await cache.get(key);
    expect(hit?.text).toBe('{"questions":[]}');
    expect(hit?.storedAt).toBeTruthy();
  });

  it('treats a corrupt entry as a miss rather than an error', async () => {
    const { store, bucket } = fakeBucket();
    store.set('ai-cache/broken.json', 'not json');
    expect(await new AiCache(bucket).get('broken')).toBeNull();
  });

  it('stores nothing when caching is disabled', async () => {
    const { store, bucket } = fakeBucket();
    const cache = new AiCache(bucket, false);
    await cache.put('k', {
      text: 't',
      model: 'm',
      provider: 'p',
      inputTokens: 0,
      outputTokens: 0,
    });
    expect(store.size).toBe(0);
    expect(await cache.get('k')).toBeNull();
  });
});

describe('settings', () => {
  it('defaults to the cheap, safe configuration for an MVP', () => {
    const s = aiSettings({});
    expect(s.quality).toBe('economy');
    expect(s.imageGeneration).toBe(false);
    expect(s.cacheEnabled).toBe(true);
    expect(s.cachePerUser).toBe(false);
    expect(s.limits.monthlyBudgetUsd).toBe(10);
  });

  it('ignores nonsense values rather than disabling the budget', () => {
    const s = aiSettings({ MONTHLY_AI_BUDGET: 'free', WARNING_BUDGET: '-4' });
    expect(s.limits.monthlyBudgetUsd).toBe(10);
    expect(s.limits.warnBudgetUsd).toBe(5);
  });
});

describe('model routing', () => {
  const env: AiEnv = {
    AI_TEXT_PROVIDER: 'workers-ai',
    AI_TEXT_MODEL: 'free/@cf/meta/llama-3.1-8b-instruct',
    AI_VISION_PROVIDER: 'workers-ai',
    AI_VISION_MODEL: 'free/@cf/meta/llama-3.2-11b-vision-instruct',
    AI_FALLBACK_PROVIDER: 'gemini',
    AI_FALLBACK_MODEL: 'gemini-3.5-flash-lite',
    AI_PREMIUM_PROVIDER: 'openrouter',
    AI_PREMIUM_MODEL: 'expensive/model',
  };

  it('puts the free model first and the paid one behind it', () => {
    const chain = candidates(env, 'text', 'economy');
    expect(chain[0].model).toContain('free/');
    expect(chain[1].model).toBe('gemini-3.5-flash-lite');
  });

  it('never reaches the premium model unless quality asks for it', () => {
    expect(candidates(env, 'text', 'economy')).toHaveLength(2);
    expect(candidates(env, 'balanced' as never, 'balanced')).not.toContainEqual({
      provider: 'openrouter',
      model: 'expensive/model',
    });
    expect(candidates(env, 'text', 'quality')).toHaveLength(3);
  });

  it('uses the vision model only for vision work', () => {
    expect(candidates(env, 'vision', 'economy')[0].model).toContain('vision');
    expect(candidates(env, 'text', 'economy')[0].model).not.toContain('vision');
  });

  it('does not try the same pair twice', () => {
    const same: AiEnv = {
      AI_TEXT_PROVIDER: 'gemini',
      AI_TEXT_MODEL: 'gemini-3.5-flash-lite',
      AI_FALLBACK_PROVIDER: 'gemini',
      AI_FALLBACK_MODEL: 'gemini-3.5-flash-lite',
    };
    expect(candidates(same, 'text', 'economy')).toHaveLength(1);
  });
});

describe('fallback', () => {
  function providerEnv(impl: Partial<Record<string, AiProvider>>): AiEnv {
    return {
      GEMINI_API_KEY: 'k',
      OPENROUTER_API_KEY: 'k',
      AI: { run: async () => ({ response: '' }) },
      ...impl,
    } as AiEnv;
  }

  it('moves to the next model when the first is out of quota', async () => {
    const first = vi.fn().mockRejectedValue(new AiQuotaError('429'));
    const second = vi.fn().mockResolvedValue({
      text: 'ok',
      inputTokens: 10,
      outputTokens: 5,
      model: 'b',
      provider: 'openrouter',
    });
    const chain = [
      { provider: 'gemini', model: 'a' },
      { provider: 'openrouter', model: 'b' },
    ];
    const result = await runWithFallback(
      providerEnv({}),
      chain,
      { prompt: 'p', maxOutputTokens: 100 },
      (_e, name) =>
        name === 'gemini'
          ? ({ name, generate: first } as unknown as AiProvider)
          : ({ name, generate: second } as unknown as AiProvider),
    );
    expect(result.response.text).toBe('ok');
    expect(second).toHaveBeenCalledOnce();
    expect(result.attempts).toHaveLength(1);
    expect(result.attempts[0].provider).toBe('gemini');
  });

  it('gives up with every attempt named when all refuse', async () => {
    await expect(
      runWithFallback(
        providerEnv({}),
        [{ provider: 'gemini', model: 'a' }],
        { prompt: 'p', maxOutputTokens: 10 },
        () =>
          ({
            name: 'x',
            generate: vi.fn().mockRejectedValue(new AiUnavailableError('503')),
          }) as unknown as AiProvider,
      ),
    ).rejects.toThrow(/Every configured model refused/);
  });

  it('records an unconfigured provider instead of pretending it failed',
    async () => {
      await expect(
        runWithFallback(
          {},
          [{ provider: 'gemini', model: 'a' }],
          { prompt: 'p', maxOutputTokens: 10 },
          () => null,
        ),
      ).rejects.toThrow(/not configured/);
    });

  it('refuses immediately when nothing is configured', async () => {
    await expect(
      runWithFallback({}, [], { prompt: 'p', maxOutputTokens: 10 }),
    ).rejects.toThrow(/No AI provider is configured/);
  });
});

/** Minimal D1 double: enough SQL shape to drive the budget logic. */
function fakeD1(rows: { usd: number; images: number; cached: number }[]) {
  return {
    prepare(sql: string) {
      return {
        bind() {
          return this;
        },
        async run() {
          return {};
        },
        async first<T>() {
          const live = rows.filter((r) => r.cached === 0);
          if (sql.includes('SUM(usd)')) {
            return {
              total: live.reduce((n, r) => n + r.usd, 0),
            } as T;
          }
          const n = sql.includes('images > 0')
            ? live.filter((r) => r.images > 0).length
            : live.length;
          return { n } as T;
        },
      };
    },
  } as unknown as D1Database;
}

describe('budget', () => {
  it('allows a call that fits inside the month', async () => {
    const store = new UsageStore(fakeD1([{ usd: 1, images: 0, cached: 0 }]));
    const verdict = await store.check('u', limits, 0.01, false);
    expect(verdict.allowed).toBe(true);
  });

  it('blocks the call that would cross the budget, not the one after', async () => {
    const store = new UsageStore(fakeD1([{ usd: 9.99, images: 0, cached: 0 }]));
    const verdict = await store.check('u', limits, 0.02, false);
    expect(verdict.allowed).toBe(false);
    if (!verdict.allowed) expect(verdict.reason).toContain('budget');
  });

  it('warns before it blocks', async () => {
    const store = new UsageStore(fakeD1([{ usd: 6, images: 0, cached: 0 }]));
    const verdict = await store.check('u', limits, 0.01, false);
    expect(verdict.allowed).toBe(true);
    if (verdict.allowed) expect(verdict.warn).toBe(true);
  });

  it('does not count cache hits as spend', async () => {
    const store = new UsageStore(
      fakeD1([{ usd: 99, images: 0, cached: 1 }]),
    );
    const verdict = await store.check('u', limits, 0.01, false);
    expect(verdict.allowed).toBe(true);
    expect(verdict.monthUsd).toBe(0);
  });

  it('stops a single user hammering it, separately from the budget', async () => {
    const many = Array.from({ length: 25 }, () => ({
      usd: 0,
      images: 0,
      cached: 0,
    }));
    const verdict = await new UsageStore(fakeD1(many)).check(
      'u',
      limits,
      0.001,
      false,
    );
    expect(verdict.allowed).toBe(false);
    if (!verdict.allowed) expect(verdict.reason).toContain('Daily limit');
  });

  it('limits vision separately, because it costs more', async () => {
    const visionHeavy = Array.from({ length: 10 }, () => ({
      usd: 0,
      images: 1,
      cached: 0,
    }));
    const store = new UsageStore(fakeD1(visionHeavy));
    expect((await store.check('u', limits, 0.001, false)).allowed).toBe(true);
    const vision = await store.check('u', limits, 0.001, true);
    expect(vision.allowed).toBe(false);
    if (!vision.allowed) expect(vision.reason).toContain('diagram');
  });
});
