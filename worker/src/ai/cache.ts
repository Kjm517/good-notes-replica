/**
 * Content-addressed cache for AI answers, kept in the bucket that already
 * exists rather than adding another store.
 *
 * The key hashes everything that could change the answer — prompt, model,
 * images, prompt version — so a hit is only returned for genuinely identical
 * work. That is also what makes sharing an entry between users safe: a
 * collision means the input bytes matched, not that one user can read
 * another's document.
 *
 * Set AI_CACHE_SCOPE=user to key per account instead. That is the cautious
 * setting, and it gives up most of the saving, so it is not the default.
 */

export interface CachedAnswer {
  text: string;
  model: string;
  provider: string;
  inputTokens: number;
  outputTokens: number;
  storedAt: string;
}

const PREFIX = 'ai-cache';

async function sha256Hex(input: string): Promise<string> {
  const bytes = new TextEncoder().encode(input);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(digest)]
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

/** Hash of an image, so the same diagram is never analysed twice. */
export async function hashImage(base64: string): Promise<string> {
  return sha256Hex(base64);
}

export interface CacheKeyParts {
  /** Bumped by hand when a prompt changes meaning, retiring old answers. */
  promptVersion: string;
  model: string;
  prompt: string;
  imageHashes?: string[];
  /** Only set when AI_CACHE_SCOPE=user. */
  userId?: string;
}

export async function cacheKey(parts: CacheKeyParts): Promise<string> {
  const canonical = [
    parts.userId ?? 'global',
    parts.promptVersion,
    parts.model,
    ...(parts.imageHashes ?? []),
    parts.prompt,
  ].join(' ');
  return sha256Hex(canonical);
}

export class AiCache {
  constructor(
    private readonly bucket: R2Bucket,
    private readonly enabled = true,
  ) {}

  async get(key: string): Promise<CachedAnswer | null> {
    if (!this.enabled) return null;
    const object = await this.bucket.get(`${PREFIX}/${key}.json`);
    if (!object) return null;
    try {
      return JSON.parse(await object.text()) as CachedAnswer;
    } catch {
      // A corrupt entry is a miss, not a failure: the cost is one extra call,
      // which beats failing the request.
      return null;
    }
  }

  async put(
    key: string,
    answer: Omit<CachedAnswer, 'storedAt'>,
  ): Promise<void> {
    if (!this.enabled) return;
    const body: CachedAnswer = {
      ...answer,
      storedAt: new Date().toISOString(),
    };
    await this.bucket.put(`${PREFIX}/${key}.json`, JSON.stringify(body), {
      httpMetadata: { contentType: 'application/json' },
    });
  }
}
