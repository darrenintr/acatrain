import test from 'node:test';
import assert from 'node:assert/strict';
import { createWorker } from '../src/index.mjs';
import { validateProfile, enforceRateLimit } from '../src/account.mjs';
import { AppError } from '../src/content.mjs';
import { Firestore, userStore } from '../src/firestore.mjs';

class MemoryStore {
  data = new Map();
  seq = 0;
  async get(path) { return structuredClone(this.data.get(path) ?? null); }
  async commit(writes) {
    for (const write of writes) {
      if ((this.data.get(write.path)?.version ?? null) !== (write.version ?? null)) {
        throw new AppError(409, 'Content changed; reload before retrying');
      }
    }
    for (const write of writes) {
      this.data.set(write.path, { value: structuredClone(write.value), version: 'v' + (++this.seq) });
    }
  }
  async deleteMany(paths) {
    for (const path of paths) this.data.delete(path);
  }
}
const env = { ALLOWED_ORIGINS: 'https://app.example' };
const profile = { displayName: ' Learner ', languageCode: 'zh', appearance: 'system' };
function request(path, method = 'GET', body, token = 'alice', extras = {}) {
  return new Request('https://study.example' + path, {
    method,
    headers: {
      Authorization: 'Bearer ' + token,
      Origin: 'https://app.example',
      ...(body === undefined ? {} : { 'Content-Type': 'application/json' }),
      ...extras,
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
}
function workerFor(db) {
  return createWorker({
    userStore: async req => {
      const bearer = req.headers.get('Authorization');
      if (bearer !== 'Bearer alice' && bearer !== 'Bearer bob') {
        throw new AppError(401, 'Sign in is required');
      }
      const uid = bearer.slice(7);
      return {
        uid, store: db, email: uid + '@example.test',
        displayName: uid, emailVerified: true, providers: ['google.com'],
      };
    },
  });
}

test('profile validation accepts presentation settings, never roles or billing', () => {
  assert.deepEqual(validateProfile(profile), {
    displayName: 'Learner', languageCode: 'zh', appearance: 'system',
  });
  assert.throws(() => validateProfile({ ...profile, role: 'admin' }), /only displayName/);
  assert.throws(() => validateProfile({ ...profile, plan: 'pro' }), /only displayName/);
  assert.throws(() => validateProfile({ ...profile, displayName: '   ' }), /displayName/);
  assert.throws(() => validateProfile({ ...profile, displayName: 'a\nb' }), /control/);
  assert.throws(() => validateProfile({ ...profile, languageCode: 'unsupported' }), /languageCode/);
  assert.throws(() => validateProfile({ ...profile, appearance: 'purple' }), /appearance/);
});

test('profile uses optimistic concurrency and keeps users isolated', async () => {
  const db = new MemoryStore();
  const worker = workerFor(db);
  const response = await worker.fetch(request('/v1/profile', 'PUT', { profile, version: null }), env);
  assert.equal(response.status, 200, await response.text());
  const got = await worker.fetch(request('/v1/profile'), env);
  assert.equal(got.headers.get('Cache-Control'), 'no-store');
  const state = await got.json();
  assert.equal(state.profile.displayName, 'Learner');
  assert.equal(state.version, 'v1');
  const other = await worker.fetch(request('/v1/profile', 'GET', undefined, 'bob'), env);
  assert.deepEqual(await other.json(), { profile: null, version: null });
  const stale = await worker.fetch(request('/v1/profile', 'PUT', { profile, version: null }), env);
  assert.equal(stale.status, 409);
  const updated = await worker.fetch(request('/v1/profile', 'PUT', {
    profile: { ...profile, appearance: 'dark' }, version: state.version,
  }), env);
  assert.equal(updated.status, 200);
  assert.equal((await (await worker.fetch(request('/v1/profile'), env)).json()).profile.appearance, 'dark');
  assert.equal((await worker.fetch(request('/v1/profile', 'POST', { profile }), env)).status, 405);
  assert.equal((await worker.fetch(request('/v1/profile', 'PUT', {
    profile: { ...profile, role: 'admin' }, version: 'v2',
  }), env)).status, 400);
  assert.equal((await worker.fetch(request('/v1/profile', 'PUT', {
    profile, version: 'v2', uid: 'bob',
  }), env)).status, 400);
});

test('profile body bounds and content type reject malformed input', async () => {
  const worker = workerFor(new MemoryStore());
  const oversized = request('/v1/profile', 'PUT', {
    profile: { ...profile, displayName: 'a'.repeat(5000) }, version: null,
  });
  assert.equal((await worker.fetch(oversized, env)).status, 413);
  const wrong = request('/v1/profile', 'PUT', { profile, version: null },
    'alice', { 'Content-Type': 'application/json-bogus' });
  assert.equal((await worker.fetch(wrong, env)).status, 415);
  const missing = await worker.fetch(new Request('https://study.example/v1/profile'), env);
  assert.equal(missing.status, 401);
});

test('identity response excludes bearer token and private account properties', async () => {
  const worker = workerFor(new MemoryStore());
  const response = await worker.fetch(request('/v1/me'), env);
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    uid: 'alice', email: 'alice@example.test', displayName: 'alice',
    emailVerified: true, providers: ['google.com'],
  });
  assert.equal(response.headers.get('Cache-Control'), 'no-store');
});

test('full account export and legacy delete remove only owner documents', async () => {
  const db = new MemoryStore();
  for (const uid of ['alice', 'bob']) {
    await db.commit([
      { path: 'users/' + uid + '/state/profile', value: { ...profile, displayName: uid } },
      { path: 'users/' + uid + '/state/progress', value: { key: uid } },
    ]);
  }
  const worker = workerFor(db);
  const exportData = await worker.fetch(request('/v1/account/data'), env);
  assert.equal(exportData.status, 200);
  const payload = await exportData.json();
  assert.equal(payload.uid, 'alice');
  assert.equal(payload.profile.displayName, 'alice');
  assert.equal(payload.progress.key, 'alice');
  assert.equal(payload.versions.profile, 'v1');
  const deleted = await worker.fetch(request('/v1/progress', 'DELETE'), env);
  assert.equal(deleted.status, 200);
  assert.equal(await db.get('users/alice/state/progress'), null);
  assert.equal(await db.get('users/alice/state/profile'), null);
  assert.ok(await db.get('users/bob/state/progress'));
  assert.ok(await db.get('users/bob/state/profile'));
  assert.equal((await worker.fetch(request('/v1/account/data', 'DELETE'), env)).status, 200);
  assert.equal((await worker.fetch(request('/v1/account/data', 'DELETE',
    undefined, 'bob'), env)).status, 200);
  assert.equal(await db.get('users/bob/state/profile'), null);
  assert.equal(await db.get('users/bob/state/progress'), null);
  assert.equal((await worker.fetch(request('/v1/account/data', 'PUT', {}), env)).status, 405);
});

test('Firestore account-data batch is one owner-authorized atomic commit', async () => {
  const captured = [];
  const db = new Firestore({ FIREBASE_PROJECT_ID: 'acatrain-test' }, 'owner-id-token',
    async (url, opts) => {
      captured.push({ url, opts });
      return Response.json({ writeResults: [{}, {}] });
    });
  await db.deleteMany(['users/alice/state/progress', 'users/alice/state/profile']);
  assert.equal(captured.length, 1);
  assert.ok(captured[0].url.endsWith('/documents:commit'));
  assert.equal(captured[0].opts.headers.Authorization, 'Bearer owner-id-token');
  const writes = JSON.parse(captured[0].opts.body).writes;
  assert.deepEqual(writes.map(w => w.delete), [
    'projects/acatrain-test/databases/(default)/documents/users/alice/state/progress',
    'projects/acatrain-test/databases/(default)/documents/users/alice/state/profile',
  ]);
});

test('Firebase lookup rejects bad sessions, malformed upstream responses and network failures', async () => {
  const config = { FIREBASE_WEB_API_KEY: 'public-test', FIREBASE_PROJECT_ID: 'acatrain-test' };
  const req = request('/v1/me');
  const account = async () => Response.json({
    users: [{ localId: 'alice', displayName: 'Name', email: 'alice@example.test',
      emailVerified: true, providerUserInfo: [
        { providerId: 'google.com', federatedId: 'private-id' },
        { providerId: 'google.com' },
      ] }],
  });
  const identity = await userStore(req, config, account);
  assert.equal(identity.uid, 'alice');
  assert.deepEqual(identity.providers, ['google.com']);
  assert.equal(identity.email, 'alice@example.test');
  await assert.rejects(userStore(new Request('https://study.example/v1/me'),
    config, account), e => e.status === 401);
  await assert.rejects(userStore(request('/v1/me', 'GET', undefined,
    'x'.repeat(8193)), config, account), e => e.status === 401);
  await assert.rejects(userStore(req, config, async () => { throw Error('offline'); }),
    e => e.status === 502);
  await assert.rejects(userStore(req, config, async () => new Response('not JSON')),
    e => e.status === 502);
  await assert.rejects(userStore(req, config, async () => Response.json({ error: {} },
    { status: 400 })), e => e.status === 401);
  await assert.rejects(userStore(req, config, async () => Response.json({
    users: [{ localId: '../other' }],
  })), e => e.status === 401);
});

test('verified-email policy covers profile PUT as well as progress POST', async () => {
  const config = {
    FIREBASE_WEB_API_KEY: 'public-test', FIREBASE_PROJECT_ID: 'acatrain-test',
    REQUIRE_VERIFIED_EMAIL: 'true',
  };
  const unverified = async () => Response.json({
    users: [{ localId: 'alice', emailVerified: false }],
  });
  for (const method of ['PUT', 'POST']) {
    await assert.rejects(userStore(request('/v1/profile', method, {}), config,
      unverified), e => e.status === 403);
  }
  for (const method of ['GET', 'DELETE']) {
    assert.equal((await userStore(request('/v1/account/data', method),
      config, unverified)).uid, 'alice');
  }
});

test('native rate limiter returns 429 and Retry-After without leaking data', async () => {
  const db = new MemoryStore();
  const worker = workerFor(db);
  const limited = {
    ...env,
    USER_RATE_LIMITER: { limit: async ({ key }) => {
      assert.equal(key, 'user:alice');
      return { success: false };
    } },
  };
  const response = await worker.fetch(request('/v1/profile'), limited);
  assert.equal(response.status, 429);
  assert.equal(response.headers.get('Retry-After'), '60');
  assert.equal(response.headers.get('Cache-Control'), 'no-store');
  assert.ok((await response.json()).error.includes('Too many'));
  let lookedUp = false;
  const ingress = createWorker({
    userStore: async () => { lookedUp = true; throw Error('should not run'); },
  });
  const preAuth = await ingress.fetch(request('/v1/me', 'GET', undefined,
    'alice', { 'CF-Connecting-IP': '192.0.2.1' }), {
    ...env,
    AUTH_LOOKUP_RATE_LIMITER: { limit: async ({ key }) => {
      assert.equal(key, 'lookup:192.0.2.1');
      return { success: false };
    } },
  });
  assert.equal(preAuth.status, 429);
  assert.equal(lookedUp, false);
  assert.equal(await enforceRateLimit(undefined, 'offline'), undefined);
});

test('progress rejects null body and invalid version instead of an internal error', async () => {
  const worker = workerFor(new MemoryStore());
  const nullBody = await worker.fetch(request('/v1/progress', 'POST', null), env);
  assert.equal(nullBody.status, 400);
  const malformedVersion = await worker.fetch(request('/v1/progress', 'POST', {
    items: {}, version: 'v'.repeat(129),
  }), env);
  assert.equal(malformedVersion.status, 400);
});

test('Firestore upstream timeout/invalid response/auth/rate limit surface appropriate errors', async () => {
  const config = { FIREBASE_PROJECT_ID: 'acatrain-test' };
  const path = 'users/alice/state/progress';
  const offline = new Firestore(config, 'token', async () => { throw Error('network'); });
  await assert.rejects(offline.get(path), e => e.status === 502);
  const invalid = new Firestore(config, 'token', async () => new Response('invalid'));
  await assert.rejects(invalid.get(path), e => e.status === 502);
  const expired = new Firestore(config, 'token',
    async () => Response.json({ error: {} }, { status: 401 }));
  await assert.rejects(expired.get(path), e => e.status === 401);
  const quota = new Firestore(config, 'token',
    async () => Response.json({ error: {} }, { status: 429 }));
  await assert.rejects(quota.get(path), e => e.status === 429);
});
