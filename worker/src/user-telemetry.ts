import { requireUser, type AuthEnv } from './auth';
import { recordAiUsage, submitBugReport, upsertUserHeartbeat } from './admin-data';

export async function handleUserTelemetry(
  request: Request,
  env: AuthEnv & { BUCKET: R2Bucket },
  url: URL,
): Promise<Response> {
  const route = `${request.method} ${url.pathname}`;

  if (route === 'POST /user/heartbeat') {
    const user = await requireUser(request, env);
    const body = (await request.json()) as {
      displayName?: string;
    };
    const entry = await upsertUserHeartbeat(env.BUCKET, user.uid, {
      email: user.email,
      displayName: body.displayName,
    });
    return json({ ok: true, user: entry });
  }

  if (route === 'POST /user/bug-report') {
    const user = await requireUser(request, env);
    const body = (await request.json()) as {
      category?: string;
      subject?: string;
      description?: string;
      device?: string;
    };
    if (!body.description?.trim()) {
      return json({ error: 'description is required.' }, 400);
    }
    const report = await submitBugReport(env.BUCKET, {
      uid: user.uid,
      email: user.email,
      category: body.category?.trim() || 'other',
      subject: body.subject?.trim() || 'Notably bug report',
      description: body.description,
      device: body.device?.trim() || 'unknown',
    });
    return json({ report });
  }

  if (route === 'POST /user/ai-usage') {
    const user = await requireUser(request, env);
    const body = (await request.json()) as {
      feature?: string;
      promptTokens?: number;
      outputTokens?: number;
    };
    const event = await recordAiUsage(env.BUCKET, {
      uid: user.uid,
      feature: body.feature?.trim() || 'quiz',
      promptTokens: Math.max(0, body.promptTokens ?? 0),
      outputTokens: Math.max(0, body.outputTokens ?? 0),
    });
    return json({ ok: true, event });
  }

  return json({ error: 'Not found' }, 404);
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}
