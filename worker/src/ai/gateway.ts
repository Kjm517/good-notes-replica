/**
 * The one place the app is allowed to reach a model.
 *
 * Every request arrives authenticated, is answered from cache when the same
 * work has been done before, is costed and checked against a budget before
 * anything is spent, and is recorded afterwards. The client never sees a
 * vendor key: before this existed, GEMINI_API_KEY shipped inside the Android
 * bundle and could be read with `unzip`.
 *
 * Order matters and is deliberate:
 *   cache  ->  budget  ->  cheapest model that can do the job  ->  record
 */

import { isStaffUid } from '../admin-store';
import { requireUid, requireUser } from '../auth';
import { AiCache, cacheKey, hashImage } from './cache';
import { actualCost, estimateCost } from './pricing';
import { AiQuotaError, type AiImage } from './provider';
import {
  aiSettings,
  candidates,
  runWithFallback,
  type AiEnv,
  type Quality,
  type Task,
} from './router';
import { UsageStore } from './usage';

export interface GatewayEnv extends AiEnv {
  BUCKET: R2Bucket;
  AI_USAGE?: D1Database;
  SUPABASE_URL: string;
  SUPABASE_JWT_SECRET?: string;
  SUPABASE_ANON_KEY?: string;
  SUPABASE_SERVICE_ROLE_KEY?: string;
  ADMIN_UIDS?: string;
}

/** Guards against a client sending something huge and expensive. */
const MAX_PROMPT_CHARS = 200_000;
const MAX_IMAGES = 16;
const MAX_OUTPUT_TOKENS = 32_000;

interface GenerateBody {
  operation?: string;
  documentId?: string | null;
  prompt?: string;
  images?: { data?: string; mimeType?: string }[];
  maxOutputTokens?: number;
  json?: boolean;
  quality?: string;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

/**
 * The tier actually used.
 *
 * A client may ask for less than the server allows but never more — otherwise
 * "quality" becomes a way for any user to spend the owner's money on the
 * premium model.
 */
function effectiveQuality(requested: string | undefined, ceiling: Quality): Quality {
  const order: Quality[] = ['economy', 'balanced', 'quality'];
  const want = order.indexOf((requested ?? '') as Quality);
  const max = order.indexOf(ceiling);
  if (want < 0) return ceiling;
  return order[Math.min(want, max)];
}

export async function handleAiGenerate(
  request: Request,
  env: GatewayEnv,
): Promise<Response> {
  const uid = await requireUid(request, env);

  let body: GenerateBody;
  try {
    body = (await request.json()) as GenerateBody;
  } catch {
    return json({ error: 'Body must be JSON.' }, 400);
  }

  const prompt = (body.prompt ?? '').trim();
  if (!prompt) return json({ error: 'A prompt is required.' }, 400);
  if (prompt.length > MAX_PROMPT_CHARS) {
    return json(
      { error: `Prompt is too long (max ${MAX_PROMPT_CHARS} characters).` },
      413,
    );
  }

  const images: AiImage[] = [];
  for (const raw of body.images ?? []) {
    if (!raw?.data || !raw.mimeType) continue;
    images.push({ data: raw.data, mimeType: raw.mimeType });
  }
  if (images.length > MAX_IMAGES) {
    return json(
      { error: `Too many images (max ${MAX_IMAGES} per request).` },
      413,
    );
  }

  const maxOutputTokens = Math.min(
    Math.max(Math.floor(body.maxOutputTokens ?? 4096), 1),
    MAX_OUTPUT_TOKENS,
  );

  const settings = aiSettings(env);
  const quality = effectiveQuality(body.quality, settings.quality);
  // Vision is decided by the request, not asked for: sending no images means
  // the cheaper text model, whatever the caller said.
  const task: Task = images.length > 0 ? 'vision' : 'text';
  const chain = candidates(env, task, quality);
  if (chain.length === 0) {
    return json({ error: 'No AI provider is configured on the server.' }, 503);
  }

  const cache = new AiCache(env.BUCKET, settings.cacheEnabled);
  const imageHashes = await Promise.all(images.map((i) => hashImage(i.data)));
  const scopedUser = settings.cachePerUser ? uid : undefined;

  // Every model in the chain is checked, not just the first: when the primary
  // is out of quota the answer that exists is the fallback's, and missing it
  // would pay for the same work twice.
  for (const candidate of chain) {
    const key = await cacheKey({
      promptVersion: settings.promptVersion,
      model: candidate.model,
      prompt,
      imageHashes,
      userId: scopedUser,
    });
    const hit = await cache.get(key);
    if (hit) {
      const usage = env.AI_USAGE ? new UsageStore(env.AI_USAGE) : null;
      if (usage) {
        await usage.ensureSchema();
        await usage.record({
          userId: uid,
          documentId: body.documentId ?? null,
          operation: body.operation ?? 'generate',
          provider: hit.provider,
          model: hit.model,
          inputTokens: 0,
          outputTokens: 0,
          images: images.length,
          usd: 0,
          cached: true,
        });
      }
      return json({
        text: hit.text,
        model: hit.model,
        provider: hit.provider,
        cached: true,
        usd: 0,
      });
    }
  }

  // Costed against the dearest model that could answer, not the cheapest.
  // Estimating with the free tier would wave through a request that ends up
  // being served by the paid fallback.
  const worstCase = chain.reduce((worst, c) => {
    const cost = estimateCost({
      model: c.model,
      promptText: prompt,
      images: images.length,
      maxOutputTokens,
    });
    return cost.usd > worst.usd ? cost : worst;
  }, estimateCost({ model: chain[0].model, promptText: prompt, images: images.length, maxOutputTokens }));

  const usage = env.AI_USAGE ? new UsageStore(env.AI_USAGE) : null;
  if (usage) {
    await usage.ensureSchema();
    const verdict = await usage.check(uid, settings.limits, worstCase.usd, task === 'vision');
    if (!verdict.allowed) {
      // 429 rather than 403: this is a limit that lifts with time, and the
      // client already knows how to queue and retry on 429.
      return json(
        { error: verdict.reason, budgetExceeded: true, monthUsd: verdict.monthUsd },
        429,
      );
    }
    if (verdict.warn) {
      console.warn(
        `AI spend $${verdict.monthUsd.toFixed(2)} has passed the warning ` +
          `threshold of $${settings.limits.warnBudgetUsd.toFixed(2)}`,
      );
    }
  }

  let result;
  try {
    result = await runWithFallback(env, chain, {
      prompt,
      images,
      maxOutputTokens,
      json: body.json ?? false,
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    const status = e instanceof AiQuotaError ? 429 : 502;
    return json({ error: message }, status);
  }

  const { response, attempts } = result;
  // Providers do not all report token counts; fall back to the estimate so a
  // silent provider cannot make its calls look free.
  const inputTokens = response.inputTokens || worstCase.inputTokens;
  const outputTokens = response.outputTokens || 0;
  const usd = actualCost(response.model, inputTokens, outputTokens);

  const storeKey = await cacheKey({
    promptVersion: settings.promptVersion,
    model: response.model,
    prompt,
    imageHashes,
    userId: scopedUser,
  });
  await cache.put(storeKey, {
    text: response.text,
    model: response.model,
    provider: response.provider,
    inputTokens,
    outputTokens,
  });

  if (usage) {
    await usage.record({
      userId: uid,
      documentId: body.documentId ?? null,
      operation: body.operation ?? 'generate',
      provider: response.provider,
      model: response.model,
      inputTokens,
      outputTokens,
      images: images.length,
      usd,
      cached: false,
    });
  }

  return json({
    text: response.text,
    model: response.model,
    provider: response.provider,
    cached: false,
    usd,
    attempts,
  });
}

/**
 * What the AI has cost and how much of it was avoided.
 *
 * The number that matters is the cache hit rate: it is the difference between
 * a bill that grows with usage and one that grows with *new* content.
 */
export async function handleAiUsage(
  request: Request,
  env: GatewayEnv,
): Promise<Response> {
  // Staff only. This reports what the owner is spending, which is nobody
  // else's business — an earlier version let any signed-in user read it.
  const user = await requireUser(request, env);
  const header = request.headers.get('Authorization') ?? '';
  const token = header.startsWith('Bearer ') ? header.slice(7).trim() : '';
  if (!(await isStaffUid(user.uid, env, token))) {
    return json({ error: 'Admin access required.' }, 403);
  }
  if (!env.AI_USAGE) {
    return json({ error: 'Usage tracking is not configured.' }, 503);
  }
  const store = new UsageStore(env.AI_USAGE);
  await store.ensureSchema();
  const rows = await env.AI_USAGE.prepare(
    `SELECT
       COUNT(*) AS total,
       SUM(cached) AS cached,
       SUM(CASE WHEN images > 0 AND cached = 0 THEN 1 ELSE 0 END) AS vision,
       COALESCE(SUM(usd), 0) AS usd
     FROM ai_usage
     WHERE created_at >= datetime('now', 'start of month')`,
  ).first<{ total: number; cached: number; vision: number; usd: number }>();

  const byModel = await env.AI_USAGE.prepare(
    `SELECT model, provider, COUNT(*) AS calls, COALESCE(SUM(usd), 0) AS usd
       FROM ai_usage
      WHERE cached = 0 AND created_at >= datetime('now', 'start of month')
      GROUP BY model, provider
      ORDER BY usd DESC
      LIMIT 10`,
  ).all<{ model: string; provider: string; calls: number; usd: number }>();

  const topDocuments = await env.AI_USAGE.prepare(
    `SELECT document_id, COUNT(*) AS calls, COALESCE(SUM(usd), 0) AS usd
       FROM ai_usage
      WHERE cached = 0 AND document_id IS NOT NULL
        AND created_at >= datetime('now', 'start of month')
      GROUP BY document_id
      ORDER BY usd DESC
      LIMIT 10`,
  ).all<{ document_id: string; calls: number; usd: number }>();

  const total = rows?.total ?? 0;
  const cached = rows?.cached ?? 0;
  const settings = aiSettings(env);
  return json({
    byModel: byModel.results ?? [],
    topDocuments: topDocuments.results ?? [],
    month: {
      requests: total,
      servedFromCache: cached,
      cacheHitRate: total > 0 ? cached / total : 0,
      visionRequests: rows?.vision ?? 0,
      estimatedUsd: rows?.usd ?? 0,
    },
    limits: settings.limits,
    imageGenerationEnabled: settings.imageGeneration,
  });
}
