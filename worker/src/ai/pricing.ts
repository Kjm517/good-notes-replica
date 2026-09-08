/**
 * What each model costs, and what a call is expected to cost before it runs.
 *
 * Prices are USD per million tokens and change without notice, so they live in
 * one table rather than being scattered through the routing code. A model with
 * no entry is treated as expensive, not free: an unknown price must never be
 * the reason a budget check passes.
 */

export interface ModelPrice {
  /** USD per 1M input tokens. */
  inPerM: number;
  /** USD per 1M output tokens. */
  outPerM: number;
  /** Roughly what one image costs in input tokens, for vision models. */
  tokensPerImage?: number;
}

/**
 * Known prices. Deliberately conservative — rounded up, never down.
 *
 * `free/*` entries are providers with a genuine free allowance. They are
 * costed at zero for budgeting but still counted as requests, because the
 * allowance runs out and the fallback after it is not free.
 */
export const MODEL_PRICES: Record<string, ModelPrice> = {
  // Google — the current provider. Flash-lite is the cheap tier.
  'gemini-3.5-flash-lite': { inPerM: 0.10, outPerM: 0.40, tokensPerImage: 260 },
  'gemini-3.5-flash': { inPerM: 0.30, outPerM: 2.50, tokensPerImage: 260 },
  'gemini-3.6-flash': { inPerM: 0.30, outPerM: 2.50, tokensPerImage: 260 },

  // Cloudflare Workers AI — billed in neurons with a daily free allowance.
  // Treated as free up to the allowance, then cheap.
  'free/@cf/meta/llama-3.1-8b-instruct': { inPerM: 0, outPerM: 0 },
  'free/@cf/meta/llama-3.2-11b-vision-instruct': {
    inPerM: 0,
    outPerM: 0,
    tokensPerImage: 0,
  },
};

/** Anything unpriced is assumed dear, so it cannot slip past a budget check. */
export const UNKNOWN_MODEL_PRICE: ModelPrice = {
  inPerM: 5,
  outPerM: 15,
  tokensPerImage: 1500,
};

export function priceFor(model: string): ModelPrice {
  return MODEL_PRICES[model] ?? UNKNOWN_MODEL_PRICE;
}

/** Rough token count for text. Deliberately over-estimates. */
export function estimateTokens(text: string): number {
  // ~4 chars per token for English prose; ceil so short strings never round
  // to zero and make a call look free.
  return Math.ceil(text.length / 3.5);
}

export interface CostEstimate {
  inputTokens: number;
  outputTokens: number;
  usd: number;
}

/**
 * What a call should cost, before making it.
 *
 * Used both for the budget gate and for telling the user "this will cost about
 * X" before a big job, so the same arithmetic backs both.
 */
export function estimateCost(args: {
  model: string;
  promptText: string;
  images?: number;
  maxOutputTokens: number;
}): CostEstimate {
  const price = priceFor(args.model);
  const imageTokens = (args.images ?? 0) * (price.tokensPerImage ?? 0);
  const inputTokens = estimateTokens(args.promptText) + imageTokens;
  const outputTokens = args.maxOutputTokens;
  const usd =
    (inputTokens / 1_000_000) * price.inPerM +
    (outputTokens / 1_000_000) * price.outPerM;
  return { inputTokens, outputTokens, usd };
}

/** Actual cost once the provider has reported real token counts. */
export function actualCost(
  model: string,
  inputTokens: number,
  outputTokens: number,
): number {
  const price = priceFor(model);
  return (
    (inputTokens / 1_000_000) * price.inPerM +
    (outputTokens / 1_000_000) * price.outPerM
  );
}
