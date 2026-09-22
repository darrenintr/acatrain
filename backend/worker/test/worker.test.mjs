import test from 'node:test';
import assert from 'node:assert/strict';
import { createWorker } from '../src/index.mjs';
import { validateContent, AppError, digest } from '../src/content.mjs';
import { saveDraft, publishDraft, rollbackRelease } from '../src/publishing.mjs';
import { Firestore } from '../src/firestore.mjs';
const sample = () => ({ schemaVersion: 1, minAppBuild: 1, sets: [{ id: 'econ', title: 'Economics', subject: 'Economics', description: 'Practice', items: [{ id: 'q1', revision: 1, type: 'mcq', prompt: 'Which?', choices: ['A', 'B'], correctIndex: 1, explanation: 'Because B.' }] }] });
class MemoryStore {
  data = new Map(); counter = 0;
  async get(path) { return structuredClone(this.data.get(path) ?? null); }
  async commit(writes) {
    for (const w of writes) {
      const current = this.data.get(w.path);
      if ((current?.version ?? null) !== (w.version ?? null)) throw new AppError(409, 'Content changed; reload before retrying');
    }
    for (const w of writes) this.data.set(w.path, { value: structuredClone(w.value), version: String(++this.counter) });
  }
}
const env = { MCP_EDIT_TOKEN: 'test-editor-secret', MCP_PUBLISH_TOKEN: 'test-publisher-secret', ALLOWED_ORIGINS: 'http://localhost:8080' };
function request(body, token = env.MCP_EDIT_TOKEN, headers = {}) {
  return new Request('https://study.example/mcp', { method: 'POST', headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json', Accept: 'application/json, text/event-stream', ...headers }, body: JSON.stringify(body) });
}
function call(name, args, token) { return request({ jsonrpc: '2.0', id: 1, method: 'tools/call', params: { name, arguments: args } }, token); }
async function publish(db, releaseId, expectedActiveReleaseId = null) {
  const draft = await saveDraft(db, { draftId: releaseId, content: sample() });
  return publishDraft(db, { draftId: releaseId, releaseId, expectedVersion: draft.version, expectedActiveReleaseId });
}

test('valid content accepted; unknown schemas and executable items rejected', () => {
  assert.deepEqual(validateContent(sample()), []);
  const bad = sample(); bad.schemaVersion = 9; bad.sets[0].items[0].type = 'javascript';
  assert.equal(validateContent(bad).length, 2);
});
test('duplicates, answer range, empty items, invalid IDs and oversize bundles rejected', () => {
  const bad = sample(); bad.sets[0].items.push(bad.sets[0].items[0]); bad.sets[0].items[0].correctIndex = 5;
  assert.ok(validateContent(bad).length >= 3);
  const empty = sample(); empty.sets[0].items = []; assert.ok(validateContent(empty).length);
  const unsafe = sample(); unsafe.sets[0].id = '../private'; assert.ok(validateContent(unsafe).length);
  const huge = sample(); huge.extra = 'x'.repeat(140000); assert.ok(validateContent(huge).length);
});
test('atomic publish creates release, pointer, draft state and audit', async () => {
  const db = new MemoryStore(); const manifest = await publish(db, 'r1');
  assert.equal((await db.get('config/active')).value.releaseId, 'r1');
  const release = (await db.get('releases/r1')).value;
  assert.equal(manifest.sha256, await digest(release.payload));
  assert.equal((await db.get('drafts/r1')).value.state, 'published');
  assert.equal([...db.data.keys()].filter(k => k.startsWith('audit/')).length, 1);
});
test('stale draft and stale active pointer are rejected without partial publication', async () => {
  const db = new MemoryStore(); await publish(db, 'r1');
  const draft = await saveDraft(db, { draftId: 'next', content: sample() });
  await assert.rejects(publishDraft(db, { draftId: 'next', releaseId: 'r2', expectedVersion: 'stale', expectedActiveReleaseId: 'r1' }), /Draft changed/);
  await assert.rejects(publishDraft(db, { draftId: 'next', releaseId: 'r2', expectedVersion: draft.version, expectedActiveReleaseId: null }), /Active release changed/);
  assert.equal(await db.get('releases/r2'), null);
});
test('existing releases cannot be overwritten and rollback retains content', async () => {
  const db = new MemoryStore(); await publish(db, 'r1'); await publish(db, 'r2', 'r1');
  const old = await db.get('releases/r1');
  await rollbackRelease(db, { releaseId: 'r1', expectedActiveReleaseId: 'r2' });
  assert.equal((await db.get('config/active')).value.releaseId, 'r1');
  assert.deepEqual(await db.get('releases/r1'), old);
  const draft = await saveDraft(db, { draftId: 'overwrite', content: sample() });
  await assert.rejects(publishDraft(db, { draftId: 'overwrite', releaseId: 'r1', expectedVersion: draft.version, expectedActiveReleaseId: 'r1' }), /Content changed/);
});
test('draft edit requires latest version', async () => {
  const db = new MemoryStore(); const draft = await saveDraft(db, { draftId: 'draft', content: sample() });
  await assert.rejects(saveDraft(db, { draftId: 'draft', content: sample() }), /Draft changed/);
  assert.ok((await saveDraft(db, { draftId: 'draft', content: sample(), expectedVersion: draft.version })).version !== draft.version);
});
test('MCP handshake, tool listing, notifications and GET behavior', async () => {
  const worker = createWorker();
  const init = await worker.fetch(request({ jsonrpc: '2.0', id: 1, method: 'initialize' }), env);
  assert.equal((await init.json()).result.protocolVersion, '2025-11-25');
  const list = await worker.fetch(request({ jsonrpc: '2.0', id: 2, method: 'tools/list' }), env);
  assert.ok(!(await list.json()).result.tools.some(t => t.name === 'publish_draft'));
  assert.equal((await worker.fetch(request({ jsonrpc: '2.0', method: 'notifications/initialized' }), env)).status, 202);
  assert.equal((await worker.fetch(new Request('https://study.example/mcp', { headers: { Authorization: `Bearer ${env.MCP_EDIT_TOKEN}` } }), env)).status, 405);
});
test('auth, CORS, Accept and protocol checks fail closed', async () => {
  const worker = createWorker(); const msg = { jsonrpc: '2.0', id: 1, method: 'ping' };
  assert.equal((await worker.fetch(request(msg, 'wrong'), env)).status, 401);
  assert.equal((await worker.fetch(request(msg, undefined, { Origin: 'https://evil.example' }), env)).status, 403);
  assert.equal((await worker.fetch(request(msg, undefined, { Accept: 'application/json' }), env)).status, 406);
  assert.equal((await worker.fetch(request(msg, undefined, { 'MCP-Protocol-Version': 'invalid' }), env)).status, 400);
});
test('editor cannot publish even by manually calling the tool', async () => {
  const worker = createWorker({ adminStore: new MemoryStore() });
  const res = await worker.fetch(call('publish_draft', { draftId: 'a' }), env);
  const result = (await res.json()).result;
  assert.equal(result.isError, true); assert.match(result.content[0].text, /Publisher permission/);
});
test('complete MCP draft to publisher flow serves hot content', async () => {
  const db = new MemoryStore(); const worker = createWorker({ adminStore: db });
  const saved = await worker.fetch(call('save_draft', { draftId: 'd1', content: sample() }), env);
  const draft = JSON.parse((await saved.json()).result.content[0].text);
  const res = await worker.fetch(call('publish_draft', { draftId: 'd1', releaseId: 'r1', expectedVersion: draft.version, expectedActiveReleaseId: null }, env.MCP_PUBLISH_TOKEN), env);
  assert.equal((await res.json()).result.isError, false);
  const manifest = await worker.fetch(new Request('https://study.example/v1/manifest'), env);
  assert.equal((await manifest.json()).releaseId, 'r1');
  const content = await worker.fetch(new Request('https://study.example/v1/releases/r1'), env);
  assert.deepEqual(await content.json(), sample());
  const notModified = await worker.fetch(new Request('https://study.example/v1/releases/r1', { headers: { 'If-None-Match': content.headers.get('ETag') } }), env);
  assert.equal(notModified.status, 304);
});
test('unpublished content and internal paths are not public', async () => {
  const worker = createWorker({ adminStore: new MemoryStore() });
  for (const path of ['/v1/manifest', '/drafts/private', '/v1/releases/missing', '/audit']) {
    assert.equal((await worker.fetch(new Request(`https://study.example${path}`), env)).status, 404);
  }
});
test('oversized bodies rejected before JSON parsing', async () => {
  const worker = createWorker();
  const res = await worker.fetch(call('validate_content', { content: { padding: 'x'.repeat(150000) } }), env);
  assert.equal(res.status, 413);
});
test('progress uses authenticated user path and optimistic concurrency', async () => {
  const db = new MemoryStore(); const worker = createWorker({ userStore: async () => ({ uid: 'alice', store: db }) });
  const post = (items, version) => new Request('https://study.example/v1/progress', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ items, version, uid: 'bob' }) });
  const items = { 'econ/q1@1': { box: 1, updatedAt: '2026-09-22T00:00:00Z', dueAt: '2026-09-23T00:00:00Z', wrong: false } };
  assert.equal((await worker.fetch(post(items, null), env)).status, 200);
  assert.ok(await db.get('users/alice/state/progress')); assert.equal(await db.get('users/bob/state/progress'), null);
  assert.equal((await worker.fetch(post(items, null), env)).status, 409);
  assert.equal((await worker.fetch(post({ '../bad': {} }, null), env)).status, 400);
});
test('Firestore commit is a single atomic RPC with create/update preconditions', async () => {
  let captured;
  const db = new Firestore({ FIREBASE_PROJECT_ID: 'acatrain-test' }, 'id-token', async (url, init) => { captured = { url, ...init }; return Response.json({ writeResults: [] }); });
  await db.commit([{ path: 'drafts/a', value: { x: 1 } }, { path: 'config/active', version: '2026-09-22T00:00:00Z', value: {} }]);
  const writes = JSON.parse(captured.body).writes;
  assert.ok(captured.url.endsWith('/documents:commit'));
  assert.deepEqual(writes[0].currentDocument, { exists: false });
  assert.deepEqual(writes[1].currentDocument, { updateTime: '2026-09-22T00:00:00Z' });
  assert.equal(captured.headers.Authorization, 'Bearer id-token');
});

test('Firestore write failures are not mistaken for missing documents', async () => {
  const env = { FIREBASE_PROJECT_ID: 'acatrain-test' };
  const missing = new Firestore(env, 'token', async () => Response.json({ error: { status: 'NOT_FOUND' } }, { status: 404 }));
  assert.equal(await missing.get('drafts/missing'), null);
  await assert.rejects(missing.commit([{ path: 'drafts/a', value: {} }]), e => e.status === 502);
  const stale = new Firestore(env, 'token', async () => Response.json({ error: { status: 'FAILED_PRECONDITION' } }, { status: 400 }));
  await assert.rejects(stale.commit([{ path: 'drafts/a', value: {} }]), e => e.status === 409);
});
