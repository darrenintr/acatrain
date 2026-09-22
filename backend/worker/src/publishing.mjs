import { assert, digest, requireContent, validId } from './content.mjs';
export const activePath = 'config/active';
export async function saveDraft(db, args) {
  assert(validId(args.draftId), 'Invalid draftId');
  requireContent(args.content);
  const path = `drafts/${args.draftId}`;
  const old = await db.get(path);
  assert((old?.version ?? null) === (args.expectedVersion ?? null), 'Draft changed; fetch its current version', 409);
  await db.commit([{ path, version: old?.version, value: { content: args.content, state: 'draft', updatedAt: new Date().toISOString() } }]);
  return db.get(path);
}
export async function publishDraft(db, args) {
  assert(validId(args.draftId) && validId(args.releaseId), 'Invalid draftId or releaseId');
  assert(Object.hasOwn(args, 'expectedActiveReleaseId'), 'expectedActiveReleaseId is required (null for first publish)');
  const draft = await db.get(`drafts/${args.draftId}`);
  assert(draft && draft.version === args.expectedVersion, 'Draft changed; fetch and review it again', 409);
  const content = requireContent(draft.value.content);
  const active = await db.get(activePath);
  assert((active?.value.releaseId ?? null) === args.expectedActiveReleaseId, 'Active release changed; reload before publishing', 409);
  const payload = JSON.stringify(content);
  const manifest = { releaseId: args.releaseId, schemaVersion: content.schemaVersion, minAppBuild: content.minAppBuild, sha256: await digest(payload), activatedAt: new Date().toISOString() };
  await db.commit([
    { path: `releases/${args.releaseId}`, value: { ...manifest, payload } },
    { path: activePath, version: active?.version, value: manifest },
    { path: `drafts/${args.draftId}`, version: draft.version, value: { ...draft.value, state: 'published', releaseId: args.releaseId } },
    { path: `audit/${crypto.randomUUID()}`, value: { action: 'publish', from: active?.value.releaseId ?? null, ...manifest } }
  ]);
  return manifest;
}
export async function rollbackRelease(db, args) {
  assert(validId(args.releaseId), 'Invalid releaseId');
  const target = await db.get(`releases/${args.releaseId}`);
  assert(target, 'Release not found', 404);
  const active = await db.get(activePath);
  assert(active && active.value.releaseId === args.expectedActiveReleaseId, 'Active release changed; reload before rollback', 409);
  const { payload, ...metadata } = target.value;
  requireContent(JSON.parse(payload));
  const manifest = { ...metadata, activatedAt: new Date().toISOString() };
  await db.commit([
    { path: activePath, version: active.version, value: manifest },
    { path: `audit/${crypto.randomUUID()}`, value: { action: 'rollback', from: active.value.releaseId, ...manifest } }
  ]);
  return manifest;
}
