import { AppError, assert } from './content.mjs';
const tokenCache = new Map();
const enc = new TextEncoder();
const b64url = bytes => btoa(String.fromCharCode(...bytes)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');

export function parseServiceAccount(raw, projectId) {
  assert(typeof raw === 'string' && raw.trim(), 'Firebase service account is not configured', 503);
  let service;
  try {
    service = JSON.parse(raw);
    // Be tolerant of a JSON document that was accidentally stored as a quoted JSON string.
    if (typeof service === 'string') service = JSON.parse(service);
  } catch {
    throw new AppError(503, 'FIREBASE_SERVICE_ACCOUNT is not valid JSON');
  }
  assert(service && typeof service === 'object' && !Array.isArray(service), 'FIREBASE_SERVICE_ACCOUNT must contain a JSON object', 503);
  assert(service.project_id === projectId, 'Service account project mismatch', 503);
  assert(typeof service.client_email === 'string' && service.client_email.includes('@'), 'Service account client_email is missing', 503);
  assert(typeof service.private_key === 'string' && service.private_key.includes('PRIVATE KEY'), 'Service account private_key is missing', 503);
  service.private_key = service.private_key.replace(/\\n/g, '\n');
  return service;
}

// Service-account credentials never leave the Worker. User requests use their own ID token.
export async function accessToken(env, fetcher = fetch) {
  const raw = env.FIREBASE_SERVICE_ACCOUNT;
  const service = parseServiceAccount(raw, env.FIREBASE_PROJECT_ID);
  const cached = tokenCache.get(raw);
  if (cached && cached.until > Date.now()) return cached.token;

  const now = Math.floor(Date.now() / 1000);
  const header = b64url(enc.encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' })));
  const claims = b64url(enc.encode(JSON.stringify({ iss: service.client_email, scope: 'https://www.googleapis.com/auth/datastore', aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600 })));

  let key;
  try {
    const binary = atob(service.private_key.replace(/-----[^-]+-----/g, '').replace(/\s/g, ''));
    key = await crypto.subtle.importKey('pkcs8', Uint8Array.from(binary, c => c.charCodeAt(0)), { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  } catch {
    throw new AppError(503, 'Firebase service account private key is invalid');
  }

  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, enc.encode(`${header}.${claims}`));
  let response;
  try {
    response = await fetcher('https://oauth2.googleapis.com/token', { method: 'POST', body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: `${header}.${claims}.${b64url(new Uint8Array(signature))}` }) });
  } catch {
    throw new AppError(502, 'Could not reach Google OAuth for Firebase authorization');
  }

  let json;
  try { json = await response.json(); }
  catch { throw new AppError(502, 'Google OAuth returned an invalid response'); }

  assert(response.ok && json.access_token, 'Firebase authorization failed; check that the service-account key is active', 502);
  tokenCache.set(raw, { token: json.access_token, until: Date.now() + ((Number(json.expires_in) || 3600) - 120) * 1000 });
  return json.access_token;
}

export class Firestore {
  constructor(env, token, fetcher = fetch) {
    assert(/^[a-z][a-z0-9-]{4,61}[a-z0-9]$/.test(env.FIREBASE_PROJECT_ID ?? ''), 'Firebase project ID is not configured', 503);
    this.root = `projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents`;
    // Workers requires the global fetch receiver, not a Firestore instance.
    // Call through a closure so injected functions also remain standalone calls.
    this.token = token; this.fetcher = (...args) => fetcher(...args);
  }
  async request(path, method = 'GET', body) {
    let response;
    try {
      response = await this.fetcher(`https://firestore.googleapis.com/v1/${path}`, {
        method,
        headers: { Authorization: `Bearer ${this.token}`, 'Content-Type': 'application/json' },
        ...(body ? { body: JSON.stringify(body) } : {}),
        signal: AbortSignal.timeout(15000),
      });
    } catch {
      throw new AppError(502, 'Firestore service is unavailable');
    }
    if (response.status === 404 && (method === 'GET' || method === 'DELETE')) return null;
    if (!response.ok) {
      const error = await response.json().catch(() => ({}));
      if ([409, 412].includes(response.status) || ['FAILED_PRECONDITION', 'ABORTED', 'ALREADY_EXISTS'].includes(error.error?.status)) {
        throw new AppError(409, 'Content changed; reload before retrying');
      }
      if (response.status === 401) throw new AppError(401, 'Session expired; sign in again');
      if (response.status === 429) throw new AppError(429, 'Firestore rate limit exceeded');
      throw new AppError(response.status === 403 ? 403 : 502,
        response.status === 403 ? 'Firestore access denied' : 'Firestore request failed');
    }
    if (method === 'DELETE') return null;
    try {
      return await response.json();
    } catch {
      throw new AppError(502, 'Firestore service returned an invalid response');
    }
  }
  async delete(path) {
    await this.request(`${this.root}/${path}`, 'DELETE');
  }
  async deleteMany(paths) {
    assert(Array.isArray(paths) && paths.length > 0 && paths.length <= 10,
      'Invalid deletion batch');
    // Firestore commits all deletes together or none. The caller supplies
    // only paths assembled from the authenticated Firebase UID.
    await this.request(`${this.root}:commit`, 'POST', {
      writes: paths.map(path => ({ delete: `${this.root}/${path}` })),
    });
  }
  async get(path) {
    const result = await this.request(`${this.root}/${path}`);
    if (!result) return null;
    try {
      return { value: JSON.parse(result.fields.payload.stringValue), version: result.updateTime };
    } catch {
      throw new AppError(502, 'Stored Firestore document is invalid');
    }
  }
  async commit(writes) {
    return this.request(`${this.root}:commit`, 'POST', { writes: writes.map(w => ({
      update: { name: `${this.root}/${w.path}`, fields: { payload: { stringValue: JSON.stringify(w.value) } } },
      currentDocument: w.version ? { updateTime: w.version } : { exists: false }
    })) });
  }
}

export async function userStore(request, env, fetcher = fetch) {
  const token = request.headers.get('Authorization')?.match(/^Bearer (\S{1,8192})$/)?.[1];
  assert(token, 'Sign in is required', 401);
  assert(env.FIREBASE_WEB_API_KEY, 'Firebase Authentication is not configured', 503);
  let response;
  try {
    response = await fetcher(`https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${encodeURIComponent(env.FIREBASE_WEB_API_KEY)}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ idToken: token }),
      signal: AbortSignal.timeout(10000),
    });
  } catch {
    throw new AppError(502, 'Authentication service is unavailable');
  }
  let json;
  try {
    json = await response.json();
  } catch {
    throw new AppError(502, 'Authentication service returned an invalid response');
  }
  if (!response.ok) {
    if ([400, 401, 403].includes(response.status)) {
      throw new AppError(401, 'Session expired; sign in again');
    }
    throw new AppError(502, 'Authentication service is unavailable');
  }
  const account = Array.isArray(json?.users) ? json.users[0] : null;
  const uid = account?.localId;
  assert(typeof uid === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(uid),
    'Session expired; sign in again', 401);
  // Enforce verified email for writes only, without blocking read/export/deletion.
  if (env.REQUIRE_VERIFIED_EMAIL === 'true' && ['POST', 'PUT'].includes(request.method)) {
    assert(account.emailVerified === true,
      'Verify your email address before syncing account data', 403);
  }
  const providers = Array.isArray(account.providerUserInfo)
    ? account.providerUserInfo.map(value => value?.providerId)
      .filter(id => typeof id === 'string' && id.length <= 64)
    : [];
  return {
    uid,
    email: typeof account.email === 'string' ? account.email : null,
    displayName: typeof account.displayName === 'string' ? account.displayName : null,
    emailVerified: account.emailVerified === true,
    providers: [...new Set(providers)],
    store: new Firestore(env, token, fetcher),
  };
}
