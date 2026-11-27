/**
 * Provider-independent AI access. Credentials stay on the backend (environment only).
 *
 *   AI_PROVIDER    openai-compatible | mock | (empty = not configured)
 *   AI_API_KEY     provider key
 *   AI_BASE_URL    e.g. https://api.groq.com/openai/v1 (any OpenAI-compatible /chat/completions host)
 *   AI_MODEL       default gpt-oss-20b (use the provider's id, e.g. openai/gpt-oss-20b)
 *   AI_TIMEOUT_MS  default 60000
 *   AI_MAX_RETRIES default 3 (transient errors only)
 *
 * `mock` is a development evaluator that never runs in production and labels its results.
 */

export interface ChatMessage {
  role: 'system' | 'user';
  content: string;
}

export interface AiProvider {
  readonly name: string;
  readonly model: string;
  /** True for the development evaluator: its marks must never be presented as AI marks. */
  readonly isMock: boolean;
  complete(messages: ChatMessage[], opts?: { json?: boolean; maxTokens?: number }): Promise<string>;
}

export class AiProviderError extends Error {
  constructor(
    message: string,
    readonly transient: boolean,
    readonly status?: number,
    readonly retryAfterMs?: number,
  ) {
    super(message);
  }
}

export class AiNotConfiguredError extends Error {
  constructor() {
    super('The AI evaluator is not configured (set AI_PROVIDER, AI_API_KEY, AI_BASE_URL and AI_MODEL on the server)');
  }
}

export interface AiConfig {
  provider: string;
  apiKey?: string;
  baseUrl?: string;
  model: string;
  timeoutMs: number;
  maxRetries: number;
  production: boolean;
}

export function readAiConfig(env: NodeJS.ProcessEnv = process.env): AiConfig {
  return {
    provider: (env.AI_PROVIDER ?? '').trim().toLowerCase(),
    apiKey: env.AI_API_KEY?.trim() || undefined,
    baseUrl: env.AI_BASE_URL?.trim().replace(/\/+$/, '') || undefined,
    model: env.AI_MODEL?.trim() || 'gpt-oss-20b',
    timeoutMs: Math.min(Math.max(Number(env.AI_TIMEOUT_MS) || 60_000, 5_000), 300_000),
    maxRetries: Math.min(Math.max(Number(env.AI_MAX_RETRIES ?? 3) || 0, 0), 6),
    production: env.NODE_ENV === 'production',
  };
}

/** OpenAI-compatible chat completions (Groq, OpenRouter, Together, vLLM, Ollama, ... all serve gpt-oss-20b this way). */
export class OpenAiCompatibleProvider implements AiProvider {
  readonly name = 'openai-compatible';
  readonly isMock = false;
  constructor(
    private cfg: AiConfig,
    private fetchImpl: typeof fetch = fetch,
  ) {}
  get model() {
    return this.cfg.model;
  }

  async complete(messages: ChatMessage[], opts: { json?: boolean; maxTokens?: number } = {}): Promise<string> {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), this.cfg.timeoutMs);
    let res: Response;
    try {
      res = await this.fetchImpl(`${this.cfg.baseUrl}/chat/completions`, {
        method: 'POST',
        signal: ctrl.signal,
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${this.cfg.apiKey}` },
        body: JSON.stringify({
          model: this.cfg.model,
          messages,
          temperature: 0,
          max_tokens: opts.maxTokens ?? 2000,
          ...(opts.json && { response_format: { type: 'json_object' } }),
        }),
      });
    } catch (e: any) {
      const timeout = e?.name === 'AbortError';
      throw new AiProviderError(timeout ? `AI request timed out after ${this.cfg.timeoutMs} ms` : 'AI provider unreachable', true);
    } finally {
      clearTimeout(timer);
    }
    if (!res.ok) {
      const retryAfter = Number(res.headers.get('retry-after'));
      const transient = res.status === 429 || res.status === 408 || res.status >= 500;
      // Never include the request or key in errors; only the status.
      throw new AiProviderError(`AI provider returned HTTP ${res.status}`, transient, res.status, Number.isFinite(retryAfter) && retryAfter > 0 ? retryAfter * 1000 : undefined);
    }
    const body: any = await res.json().catch(() => null);
    const content = body?.choices?.[0]?.message?.content;
    if (typeof content !== 'string' || !content.trim()) throw new AiProviderError('AI provider returned an empty response', true);
    return content;
  }
}

/**
 * Development/test evaluator. Scores criteria by word overlap so the workflow can be exercised
 * without a key. Results are stored with method MOCK and shown as "test evaluator", never as AI.
 */
export class MockProvider implements AiProvider {
  readonly name = 'mock';
  readonly model = 'development-mock';
  readonly isMock = true;
  async complete(messages: ChatMessage[]): Promise<string> {
    const user = messages.find((m) => m.role === 'user')?.content ?? '';
    const answer = (user.match(/<student_answer>([\s\S]*?)<\/student_answer>/)?.[1] ?? '').toLowerCase();
    const words = (s: string) => new Set(s.toLowerCase().match(/[a-z]{4,}/g) ?? []);
    const aw = words(answer);
    const criteria = [...user.matchAll(/^\[(\d+)\] \((\d+(?:\.\d+)?) marks?\) (.+)$/gm)].map((m) => {
      const cw = [...words(m[3])];
      const hit = cw.length ? cw.filter((w) => aw.has(w)).length / cw.length : 0;
      return { index: Number(m[1]), awarded: hit >= 0.5 ? Number(m[2]) : hit >= 0.25 ? Number(m[2]) / 2 : 0, comment: `overlap ${Math.round(hit * 100)}%` };
    });
    const max = Number(user.match(/Maximum marks: (\d+(?:\.\d+)?)/)?.[1] ?? 0);
    const total = criteria.length ? criteria.reduce((s, c) => s + c.awarded, 0) : answer.trim() ? max / 2 : 0;
    return JSON.stringify({
      criteria,
      marks_awarded: total,
      overall_assessment: 'Development evaluator (word overlap) - not an AI evaluation',
      correct_points: criteria.filter((c) => c.awarded > 0).map((c) => `Criterion ${c.index + 1} addressed`),
      missing_points: criteria.filter((c) => c.awarded === 0).map((c) => `Criterion ${c.index + 1} not addressed`),
      incorrect_points: [],
      conceptual_errors: [],
      irrelevant_points: [],
      improvement_suggestions: [],
      ideal_answer: '',
      topic_assessment: [],
      confidence: 0.5,
      requires_teacher_review: false,
      manipulation_attempt: false,
    });
  }
}

export function createProvider(cfg: AiConfig = readAiConfig()): AiProvider | null {
  if (cfg.provider === 'mock') return cfg.production ? null : new MockProvider();
  if (!cfg.provider || !cfg.apiKey || !cfg.baseUrl) return null;
  return new OpenAiCompatibleProvider(cfg);
}

/** Public, secret-free description of the configuration. */
export function describeProvider(cfg: AiConfig = readAiConfig()) {
  const p = createProvider(cfg);
  return {
    configured: !!p,
    mock: !!p?.isMock,
    provider: p?.name ?? (cfg.provider || null),
    model: p ? p.model : cfg.model,
    missing: p ? [] : [!cfg.provider && 'AI_PROVIDER', !cfg.apiKey && cfg.provider !== 'mock' && 'AI_API_KEY', !cfg.baseUrl && cfg.provider !== 'mock' && 'AI_BASE_URL'].filter(Boolean),
  };
}

/** Retries transient failures with exponential backoff (honours Retry-After). */
export async function withRetries<T>(fn: () => Promise<T>, maxRetries: number, sleep = (ms: number) => new Promise((r) => setTimeout(r, ms))): Promise<T> {
  let attempt = 0;
  for (;;) {
    try {
      return await fn();
    } catch (e) {
      const transient = e instanceof AiProviderError && e.transient;
      if (!transient || attempt >= maxRetries) throw e;
      const wait = (e as AiProviderError).retryAfterMs ?? Math.min(30_000, 1000 * 2 ** attempt) + Math.floor(Math.random() * 250);
      attempt++;
      await sleep(wait);
    }
  }
}
