/**
 * Spend tracking and the hard stop.
 *
 * Every call is recorded with what it cost, and no paid call is made without
 * first checking the month's total against a configured budget. The point is
 * not bookkeeping: it is that a small app must not be able to run up a bill
 * its owner cannot pay.
 *
 * Counters live in D1 because the budget check has to be atomic. Keeping them
 * as JSON in R2 would race between concurrent requests and overshoot exactly
 * when traffic is highest.
 */

export interface UsageRecord {
  userId: string;
  documentId: string | null;
  operation: string;
  provider: string;
  model: string;
  inputTokens: number;
  outputTokens: number;
  images: number;
  usd: number;
  cached: boolean;
}

export interface BudgetLimits {
  /** Hard stop for the calendar month, in USD. */
  monthlyBudgetUsd: number;
  /** Past this the admin is warned, but calls continue. */
  warnBudgetUsd: number;
  maxRequestsPerUserPerDay: number;
  maxVisionRequestsPerUserPerDay: number;
}

export type BudgetVerdict =
  | { allowed: true; monthUsd: number; warn: boolean }
  | { allowed: false; reason: string; monthUsd: number };

export class UsageStore {
  constructor(private readonly db: D1Database) {}

  /** Idempotent, and cheap enough to call on the request path. */
  async ensureSchema(): Promise<void> {
    await this.db
      .prepare(
        `CREATE TABLE IF NOT EXISTS ai_usage (
           id INTEGER PRIMARY KEY AUTOINCREMENT,
           user_id TEXT NOT NULL,
           document_id TEXT,
           operation TEXT NOT NULL,
           provider TEXT NOT NULL,
           model TEXT NOT NULL,
           input_tokens INTEGER NOT NULL DEFAULT 0,
           output_tokens INTEGER NOT NULL DEFAULT 0,
           images INTEGER NOT NULL DEFAULT 0,
           usd REAL NOT NULL DEFAULT 0,
           cached INTEGER NOT NULL DEFAULT 0,
           created_at TEXT NOT NULL DEFAULT (datetime('now'))
         )`,
      )
      .run();
    await this.db
      .prepare(
        `CREATE INDEX IF NOT EXISTS ai_usage_user_time
           ON ai_usage (user_id, created_at)`,
      )
      .run();
  }

  async record(record: UsageRecord): Promise<void> {
    await this.db
      .prepare(
        `INSERT INTO ai_usage
           (user_id, document_id, operation, provider, model,
            input_tokens, output_tokens, images, usd, cached)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .bind(
        record.userId,
        record.documentId,
        record.operation,
        record.provider,
        record.model,
        record.inputTokens,
        record.outputTokens,
        record.images,
        record.usd,
        record.cached ? 1 : 0,
      )
      .run();
  }

  /** Spend this calendar month. Cache hits cost nothing and are excluded. */
  async monthSpendUsd(): Promise<number> {
    const row = await this.db
      .prepare(
        `SELECT COALESCE(SUM(usd), 0) AS total FROM ai_usage
          WHERE cached = 0 AND created_at >= datetime('now', 'start of month')`,
      )
      .first<{ total: number }>();
    return row?.total ?? 0;
  }

  async requestsToday(userId: string, visionOnly = false): Promise<number> {
    const sql =
      `SELECT COUNT(*) AS n FROM ai_usage
        WHERE user_id = ? AND cached = 0
          AND created_at >= datetime('now', 'start of day')` +
      (visionOnly ? ' AND images > 0' : '');
    const row = await this.db.prepare(sql).bind(userId).first<{ n: number }>();
    return row?.n ?? 0;
  }

  /**
   * Whether a call estimated at [estimatedUsd] may proceed.
   *
   * Checked against the estimate *before* the call, so the budget cannot be
   * breached by the very request that would have discovered it.
   */
  async check(
    userId: string,
    limits: BudgetLimits,
    estimatedUsd: number,
    isVision: boolean,
  ): Promise<BudgetVerdict> {
    const monthUsd = await this.monthSpendUsd();
    if (monthUsd + estimatedUsd > limits.monthlyBudgetUsd) {
      return {
        allowed: false,
        monthUsd,
        reason:
          `This month's AI budget of $${limits.monthlyBudgetUsd.toFixed(2)} is ` +
          `used up ($${monthUsd.toFixed(2)} spent). Quizzes work again next ` +
          `month, or when the budget is raised.`,
      };
    }
    const used = await this.requestsToday(userId, false);
    if (used >= limits.maxRequestsPerUserPerDay) {
      return {
        allowed: false,
        monthUsd,
        reason:
          `Daily limit of ${limits.maxRequestsPerUserPerDay} AI requests ` +
          `reached. Try again tomorrow.`,
      };
    }
    if (isVision) {
      const vision = await this.requestsToday(userId, true);
      if (vision >= limits.maxVisionRequestsPerUserPerDay) {
        return {
          allowed: false,
          monthUsd,
          reason:
            `Daily limit of ${limits.maxVisionRequestsPerUserPerDay} diagram ` +
            `analyses reached. Try again tomorrow.`,
        };
      }
    }
    return { allowed: true, monthUsd, warn: monthUsd >= limits.warnBudgetUsd };
  }
}
