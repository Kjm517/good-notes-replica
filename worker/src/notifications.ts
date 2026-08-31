/**
 * Push delivery via Firebase Cloud Messaging.
 *
 * FCM v1 needs an OAuth token minted from a service account, not a static key.
 * The service account JSON is stored whole as FIREBASE_SERVICE_ACCOUNT so the
 * project id, client email and private key all travel together.
 */

export interface NotificationsEnv {
  BUCKET: R2Bucket;
  /** Full service-account JSON from the Firebase console. */
  FIREBASE_SERVICE_ACCOUNT?: string;
}

/** One device that may receive push. */
export interface DeviceToken {
  token: string;
  platform: 'android' | 'ios' | 'web';
  updatedAt: string;
}

/** An announcement an admin sent. Kept so the console can show what went out. */
export interface SentNotification {
  id: string;
  title: string;
  body: string;
  audience: 'all' | 'premium' | 'free';
  sentAt: string;
  sentBy?: string;
  delivered: number;
  failed: number;
}

const SENT_KEY = 'notifications/sent.json';

function tokensKey(uid: string): string {
  return `users/${uid}/devices.json`;
}

export function firebaseConfigured(env: NotificationsEnv): boolean {
  return Boolean(env.FIREBASE_SERVICE_ACCOUNT?.trim());
}

export async function readDeviceTokens(
  bucket: R2Bucket,
  uid: string,
): Promise<DeviceToken[]> {
  const object = await bucket.get(tokensKey(uid));
  if (!object) return [];
  try {
    const parsed = JSON.parse(await object.text());
    return Array.isArray(parsed) ? (parsed as DeviceToken[]) : [];
  } catch {
    return [];
  }
}

/** Upserts by token so reinstalls do not accumulate dead entries forever. */
export async function saveDeviceToken(
  bucket: R2Bucket,
  uid: string,
  token: string,
  platform: DeviceToken['platform'],
): Promise<void> {
  const tokens = await readDeviceTokens(bucket, uid);
  const now = new Date().toISOString();
  const existing = tokens.find((t) => t.token === token);
  if (existing) {
    existing.updatedAt = now;
    existing.platform = platform;
  } else {
    tokens.push({ token, platform, updatedAt: now });
  }
  await bucket.put(tokensKey(uid), JSON.stringify(tokens), {
    httpMetadata: { contentType: 'application/json' },
  });
}

export async function deleteDeviceToken(
  bucket: R2Bucket,
  uid: string,
  token: string,
): Promise<void> {
  const tokens = await readDeviceTokens(bucket, uid);
  const kept = tokens.filter((t) => t.token !== token);
  await bucket.put(tokensKey(uid), JSON.stringify(kept), {
    httpMetadata: { contentType: 'application/json' },
  });
}

export async function readSentNotifications(
  bucket: R2Bucket,
): Promise<SentNotification[]> {
  const object = await bucket.get(SENT_KEY);
  if (!object) return [];
  try {
    const parsed = JSON.parse(await object.text());
    return Array.isArray(parsed) ? (parsed as SentNotification[]) : [];
  } catch {
    return [];
  }
}

export async function appendSentNotification(
  bucket: R2Bucket,
  entry: SentNotification,
): Promise<void> {
  const entries = await readSentNotifications(bucket);
  entries.unshift(entry);
  // Keep the log bounded; this is an activity feed, not an archive.
  await bucket.put(SENT_KEY, JSON.stringify(entries.slice(0, 200)), {
    httpMetadata: { contentType: 'application/json' },
  });
}

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

function parseServiceAccount(env: NotificationsEnv): ServiceAccount {
  const raw = env.FIREBASE_SERVICE_ACCOUNT?.trim();
  if (!raw) throw new Error('Firebase is not configured on this worker.');
  let parsed: ServiceAccount;
  try {
    parsed = JSON.parse(raw) as ServiceAccount;
  } catch {
    throw new Error('FIREBASE_SERVICE_ACCOUNT is not valid JSON.');
  }
  if (!parsed.project_id || !parsed.client_email || !parsed.private_key) {
    throw new Error('FIREBASE_SERVICE_ACCOUNT is missing required fields.');
  }
  return parsed;
}

function base64Url(input: ArrayBuffer | string): string {
  const bytes =
    typeof input === 'string'
      ? new TextEncoder().encode(input)
      : new Uint8Array(input);
  let binary = '';
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/** PEM -> ArrayBuffer for WebCrypto import. */
function pemToPkcs8(pem: string): ArrayBuffer {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    // Secrets often arrive with literal \n rather than real newlines.
    .replace(/\\n/g, '')
    .replace(/\s/g, '');
  const binary = atob(body);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

/** Mints a short-lived OAuth access token for the FCM scope. */
async function getAccessToken(account: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = base64Url(
    JSON.stringify({
      iss: account.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    }),
  );

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToPkcs8(account.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(`${header}.${claims}`),
  );

  const assertion = `${header}.${claims}.${base64Url(signature)}`;
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });

  const body = (await response.json()) as {
    access_token?: string;
    error_description?: string;
  };
  if (!response.ok || !body.access_token) {
    throw new Error(body.error_description ?? 'Could not authenticate to FCM.');
  }
  return body.access_token;
}

/**
 * Sends one message per token.
 *
 * FCM v1 has no multicast endpoint, so this fans out. Individual failures are
 * counted rather than thrown: one dead token must not sink a broadcast.
 */
export async function sendPush(
  env: NotificationsEnv,
  tokens: string[],
  message: { title: string; body: string },
): Promise<{ delivered: number; failed: number; staleTokens: string[] }> {
  if (tokens.length === 0) return { delivered: 0, failed: 0, staleTokens: [] };

  const account = parseServiceAccount(env);
  const accessToken = await getAccessToken(account);
  const url = `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`;

  let delivered = 0;
  let failed = 0;
  const staleTokens: string[] = [];

  for (const token of tokens) {
    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title: message.title, body: message.body },
            android: { priority: 'HIGH' },
            apns: {
              payload: { aps: { sound: 'default', badge: 1 } },
            },
          },
        }),
      });

      if (response.ok) {
        delivered++;
        continue;
      }
      failed++;
      // 404/400 from FCM means the token is dead — collect for cleanup.
      if (response.status === 404 || response.status === 400) {
        staleTokens.push(token);
      }
    } catch {
      failed++;
    }
  }

  return { delivered, failed, staleTokens };
}
