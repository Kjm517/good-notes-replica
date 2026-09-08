/**
 * One interface, several vendors.
 *
 * Which vendor and model answer a request is configuration, not code: prices,
 * rate limits and free allowances change often enough that hard-coding a
 * provider means a redeploy every time the economics move.
 */

export interface AiImage {
  /** base64, no data: prefix. */
  data: string;
  mimeType: string;
}

export interface AiRequest {
  prompt: string;
  images?: AiImage[];
  maxOutputTokens: number;
  /** Providers that support it will refuse to answer with anything else. */
  json?: boolean;
}

export interface AiResponse {
  text: string;
  /** Reported by the provider where available; estimated otherwise. */
  inputTokens: number;
  outputTokens: number;
  model: string;
  provider: string;
}

/** Thrown when a provider is out of quota, so routing can try the next one. */
export class AiQuotaError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'AiQuotaError';
  }
}

/** Thrown when a provider is temporarily unavailable (5xx, overloaded). */
export class AiUnavailableError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'AiUnavailableError';
  }
}

export interface AiProvider {
  readonly name: string;
  generate(model: string, request: AiRequest): Promise<AiResponse>;
}

/** Turns an HTTP failure into the shape routing can act on. */
function throwForStatus(provider: string, status: number, body: string): never {
  const brief = body.slice(0, 300);
  if (status === 429) {
    throw new AiQuotaError(`${provider} quota exhausted: ${brief}`);
  }
  if (status === 402) {
    throw new AiQuotaError(`${provider} credits depleted: ${brief}`);
  }
  if (status >= 500) {
    throw new AiUnavailableError(`${provider} unavailable (${status})`);
  }
  throw new Error(`${provider} rejected the request (${status}): ${brief}`);
}

/** Google Generative Language — what the app used directly before. */
export class GeminiProvider implements AiProvider {
  readonly name = 'gemini';
  constructor(private readonly apiKey: string) {}

  async generate(model: string, request: AiRequest): Promise<AiResponse> {
    const parts: unknown[] = [{ text: request.prompt }];
    for (const image of request.images ?? []) {
      parts.push({
        inline_data: { mime_type: image.mimeType, data: image.data },
      });
    }
    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': this.apiKey,
        },
        body: JSON.stringify({
          contents: [{ parts }],
          generationConfig: {
            maxOutputTokens: request.maxOutputTokens,
            ...(request.json
              ? { responseMimeType: 'application/json' }
              : {}),
          },
        }),
      },
    );
    if (!res.ok) throwForStatus(this.name, res.status, await res.text());
    const body = (await res.json()) as {
      candidates?: { content?: { parts?: { text?: string }[] } }[];
      usageMetadata?: { promptTokenCount?: number; candidatesTokenCount?: number };
    };
    const text =
      body.candidates?.[0]?.content?.parts?.map((p) => p.text ?? '').join('') ??
      '';
    return {
      text,
      inputTokens: body.usageMetadata?.promptTokenCount ?? 0,
      outputTokens: body.usageMetadata?.candidatesTokenCount ?? 0,
      model,
      provider: this.name,
    };
  }
}

/** OpenRouter — one key, many models, useful as the paid fallback. */
export class OpenRouterProvider implements AiProvider {
  readonly name = 'openrouter';
  constructor(
    private readonly apiKey: string,
    private readonly baseUrl = 'https://openrouter.ai/api',
  ) {}

  async generate(model: string, request: AiRequest): Promise<AiResponse> {
    const content: unknown[] = [{ type: 'text', text: request.prompt }];
    for (const image of request.images ?? []) {
      content.push({
        type: 'image_url',
        image_url: { url: `data:${image.mimeType};base64,${image.data}` },
      });
    }
    const res = await fetch(`${this.baseUrl}/v1/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${this.apiKey}`,
      },
      body: JSON.stringify({
        model,
        messages: [{ role: 'user', content }],
        max_tokens: request.maxOutputTokens,
        ...(request.json ? { response_format: { type: 'json_object' } } : {}),
      }),
    });
    if (!res.ok) throwForStatus(this.name, res.status, await res.text());
    const body = (await res.json()) as {
      choices?: { message?: { content?: string } }[];
      usage?: { prompt_tokens?: number; completion_tokens?: number };
    };
    return {
      text: body.choices?.[0]?.message?.content ?? '',
      inputTokens: body.usage?.prompt_tokens ?? 0,
      outputTokens: body.usage?.completion_tokens ?? 0,
      model,
      provider: this.name,
    };
  }
}

/**
 * Cloudflare Workers AI — runs on the same platform as this Worker and has a
 * daily free allowance, which makes it the natural first choice for an MVP.
 */
export class WorkersAiProvider implements AiProvider {
  readonly name = 'workers-ai';
  constructor(private readonly binding: { run: (model: string, input: unknown) => Promise<unknown> }) {}

  async generate(model: string, request: AiRequest): Promise<AiResponse> {
    // The binding takes the bare model id; the free/ prefix is ours, for
    // pricing, and must not be sent on.
    const id = model.startsWith('free/') ? model.slice(5) : model;
    const input: Record<string, unknown> = request.images?.length
      ? {
          prompt: request.prompt,
          image: [...atob(request.images[0].data)].map((c) => c.charCodeAt(0)),
        }
      : { prompt: request.prompt, max_tokens: request.maxOutputTokens };
    let out: unknown;
    try {
      out = await this.binding.run(id, input);
    } catch (e) {
      const message = e instanceof Error ? e.message : String(e);
      if (/quota|limit|429/i.test(message)) throw new AiQuotaError(message);
      throw new AiUnavailableError(message);
    }
    const text =
      typeof out === 'string'
        ? out
        : ((out as { response?: string })?.response ?? '');
    return {
      text,
      inputTokens: 0,
      outputTokens: 0,
      model,
      provider: this.name,
    };
  }
}
