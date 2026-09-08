/**
 * Which model answers which request.
 *
 * Two rules drive everything here. A task gets the cheapest model that can
 * actually do it — vision is only used when the question needs to see
 * something — and a provider that runs out of quota falls through to the next
 * one rather than failing the user. Premium models are never reached unless
 * they are explicitly configured and the tier asks for them.
 *
 * All of it is configuration. Prices, free allowances and rate limits move
 * often enough that hard-coding a vendor means redeploying every time the
 * economics change.
 */

import {
  AiProvider,
  AiQuotaError,
  AiRequest,
  AiResponse,
  AiUnavailableError,
  GeminiProvider,
  OpenRouterProvider,
  WorkersAiProvider,
} from './provider';

export type Quality = 'economy' | 'balanced' | 'quality';
export type Task = 'text' | 'vision';

export interface AiEnv {
  AI_TEXT_PROVIDER?: string;
  AI_TEXT_MODEL?: string;
  AI_VISION_PROVIDER?: string;
  AI_VISION_MODEL?: string;
  AI_FALLBACK_PROVIDER?: string;
  AI_FALLBACK_MODEL?: string;
  AI_PREMIUM_PROVIDER?: string;
  AI_PREMIUM_MODEL?: string;
  AI_QUALITY?: string;
  AI_PROMPT_VERSION?: string;
  AI_CACHE_ENABLED?: string;
  AI_CACHE_SCOPE?: string;
  ENABLE_IMAGE_GENERATION?: string;
  MONTHLY_AI_BUDGET?: string;
  WARNING_BUDGET?: string;
  MAX_AI_REQUESTS_PER_USER?: string;
  MAX_VISION_REQUESTS_PER_USER?: string;
  MAX_QUESTIONS_PER_GENERATION?: string;
  MAX_DOCUMENT_PROCESSING_MB?: string;
  GEMINI_API_KEY?: string;
  OPENROUTER_API_KEY?: string;
  AI?: { run: (model: string, input: unknown) => Promise<unknown> };
}

/** One provider/model pair to try, in order. */
export interface Candidate {
  provider: string;
  model: string;
}

function num(value: string | undefined, fallback: number): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : fallback;
}

function flag(value: string | undefined, fallback: boolean): boolean {
  if (value === undefined || value === '') return fallback;
  return value === 'true' || value === '1';
}

/**
 * Defaults chosen for an app with no revenue yet: free tier first, image
 * generation off, caching on, a budget low enough that a mistake is survivable.
 */
export function aiSettings(env: AiEnv) {
  return {
    quality: (env.AI_QUALITY as Quality) || 'economy',
    promptVersion: env.AI_PROMPT_VERSION || 'v1',
    cacheEnabled: flag(env.AI_CACHE_ENABLED, true),
    cachePerUser: (env.AI_CACHE_SCOPE || 'global') === 'user',
    imageGeneration: flag(env.ENABLE_IMAGE_GENERATION, false),
    limits: {
      monthlyBudgetUsd: num(env.MONTHLY_AI_BUDGET, 10),
      warnBudgetUsd: num(env.WARNING_BUDGET, 5),
      maxRequestsPerUserPerDay: num(env.MAX_AI_REQUESTS_PER_USER, 25),
      maxVisionRequestsPerUserPerDay: num(env.MAX_VISION_REQUESTS_PER_USER, 10),
    },
    maxQuestions: num(env.MAX_QUESTIONS_PER_GENERATION, 50),
    maxDocumentMb: num(env.MAX_DOCUMENT_PROCESSING_MB, 50),
  };
}

/**
 * The ordered list of models to try for [task].
 *
 * Economy stops at the fallback: a student gets an answer from a cheap model
 * or none at all, which is the right trade while the budget is this small.
 * Premium is only ever appended when it is both configured and asked for.
 */
export function candidates(env: AiEnv, task: Task, quality: Quality): Candidate[] {
  const out: Candidate[] = [];
  const push = (provider?: string, model?: string) => {
    if (provider && model) out.push({ provider, model });
  };

  if (task === 'vision') {
    push(env.AI_VISION_PROVIDER, env.AI_VISION_MODEL);
  } else {
    push(env.AI_TEXT_PROVIDER, env.AI_TEXT_MODEL);
  }
  push(env.AI_FALLBACK_PROVIDER, env.AI_FALLBACK_MODEL);
  if (quality === 'quality') {
    push(env.AI_PREMIUM_PROVIDER, env.AI_PREMIUM_MODEL);
  }

  // Same pair configured twice is one attempt, not two. Set.add returns the
  // set itself, which is always truthy — filtering on it silently keeps
  // everything, which is how a duplicate got two shots at the same quota.
  const seen = new Set<string>();
  return out.filter((c) => {
    const key = `${c.provider}:${c.model}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

/** Builds a provider by name, or null when its key is not configured. */
export function providerByName(env: AiEnv, name: string): AiProvider | null {
  switch (name) {
    case 'gemini':
      return env.GEMINI_API_KEY ? new GeminiProvider(env.GEMINI_API_KEY) : null;
    case 'openrouter':
      return env.OPENROUTER_API_KEY
        ? new OpenRouterProvider(env.OPENROUTER_API_KEY)
        : null;
    case 'workers-ai':
      return env.AI ? new WorkersAiProvider(env.AI) : null;
    default:
      return null;
  }
}

export interface AttemptLog {
  provider: string;
  model: string;
  error: string;
}

export interface RunResult {
  response: AiResponse;
  attempts: AttemptLog[];
}

/**
 * Tries each candidate until one answers.
 *
 * Only quota and availability failures move to the next candidate. A malformed
 * request fails the same way everywhere, so retrying it just spends the next
 * provider's allowance on the same mistake.
 */
export async function runWithFallback(
  env: AiEnv,
  chain: Candidate[],
  request: AiRequest,
  /**
   * How a name becomes a provider. Injected so tests can run without a
   * network: spying on the module export does not intercept a call made
   * inside the module, and a test that quietly reaches the real API is worse
   * than no test at all.
   */
  resolve: (env: AiEnv, name: string) => AiProvider | null = providerByName,
): Promise<RunResult> {
  const attempts: AttemptLog[] = [];
  if (chain.length === 0) {
    throw new Error('No AI provider is configured.');
  }
  for (const candidate of chain) {
    const provider = resolve(env, candidate.provider);
    if (!provider) {
      attempts.push({
        ...candidate,
        error: 'provider not configured (missing key or binding)',
      });
      continue;
    }
    try {
      const response = await provider.generate(candidate.model, request);
      return { response, attempts };
    } catch (e) {
      if (e instanceof AiQuotaError || e instanceof AiUnavailableError) {
        attempts.push({ ...candidate, error: e.message });
        continue;
      }
      throw e;
    }
  }
  const summary = attempts
    .map((a) => `${a.provider}/${a.model}: ${a.error}`)
    .join('; ');
  throw new AiQuotaError(`Every configured model refused: ${summary}`);
}
