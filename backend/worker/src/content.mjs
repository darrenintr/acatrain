export const MAX_BYTES = 128 * 1024;
export const ID = /^[a-z0-9][a-z0-9_-]{0,63}$/;
export class AppError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}
export function assert(condition, message, status = 400) {
  if (!condition) throw new AppError(status, message);
}
export function validId(value) { return typeof value === 'string' && ID.test(value); }
export function validateContent(data) {
  const errors = [];
  const check = (ok, msg) => { if (!ok) errors.push(msg); };
  const text = (s, n = 8000) => typeof s === 'string' && s.trim().length > 0 && s.length <= n;
  if (!data || typeof data !== 'object' || Array.isArray(data)) return ['Content must be an object'];
  check(data.schemaVersion === 1, 'schemaVersion must be 1');
  check(Number.isInteger(data.minAppBuild) && data.minAppBuild === 1, 'minAppBuild must be 1 for schema v1');
  check(Array.isArray(data.sets) && data.sets.length > 0 && data.sets.length <= 30, 'sets must contain 1-30 study sets');
  if (!Array.isArray(data.sets)) return errors;
  const setIds = new Set();
  let count = 0;
  for (const set of data.sets) {
    if (!set || typeof set !== 'object') { errors.push('Invalid study set'); continue; }
    check(validId(set.id) && !setIds.has(set.id), 'Set IDs must be valid and unique'); setIds.add(set.id);
    check(text(set.title, 160), `${set.id}: title is required (max 160)`);
    check(text(set.subject, 60), `${set.id}: subject is required (max 60)`);
    check(typeof set.description === 'string' && set.description.length <= 2000, `${set.id}: invalid description`);
    check(Array.isArray(set.items) && set.items.length > 0, `${set.id}: items cannot be empty`);
    if (!Array.isArray(set.items)) continue;
    const ids = new Set();
    for (const item of set.items) {
      count++;
      if (!item || typeof item !== 'object') { errors.push('Invalid study item'); continue; }
      check(validId(item.id) && !ids.has(item.id), `${set.id}: item IDs must be valid and unique`); ids.add(item.id);
      check(Number.isInteger(item.revision) && item.revision >= 1 && item.revision <= 1000000, `${item.id}: invalid revision`);
      check(text(item.prompt), `${item.id}: prompt is required`);
      check(['flashcard', 'mcq'].includes(item.type), `${item.id}: unsupported item type`);
      if (item.type === 'flashcard') check(text(item.answer), `${item.id}: answer is required`);
      if (item.type === 'mcq') {
        check(Array.isArray(item.choices) && item.choices.length >= 2 && item.choices.length <= 6 && item.choices.every(c => text(c, 2000)), `${item.id}: choices must contain 2-6 strings`);
        check(Number.isInteger(item.correctIndex) && item.correctIndex >= 0 && item.correctIndex < (item.choices?.length ?? 0), `${item.id}: correctIndex is outside choices`);
        check(text(item.explanation), `${item.id}: explanation is required`);
      }
    }
  }
  check(count <= 200, 'This MVP supports at most 200 items per release');
  check(new TextEncoder().encode(JSON.stringify(data)).length <= MAX_BYTES, 'Content exceeds 128 KiB');
  return errors;
}
export function requireContent(data) {
  const errors = validateContent(data);
  assert(errors.length === 0, errors.join('; '));
  return data;
}
export function validateProgress(items) {
  assert(items && typeof items === 'object' && !Array.isArray(items), 'items must be an object');
  assert(Object.keys(items).length <= 2000, 'Progress exceeds 2000 item revisions');
  for (const [key, value] of Object.entries(items)) {
    assert(/^[a-z0-9_-]{1,64}\/[a-z0-9_-]{1,64}@[1-9][0-9]{0,6}$/.test(key), 'Invalid progress key');
    assert(value && typeof value === 'object', 'Invalid progress');
    assert(Number.isInteger(value.box) && value.box >= 0 && value.box <= 5, 'Invalid review box');
    assert(typeof value.updatedAt === 'string' && Number.isFinite(Date.parse(value.updatedAt)), 'Invalid update time');
    assert(typeof value.dueAt === 'string' && Number.isFinite(Date.parse(value.dueAt)), 'Invalid due time');
    assert(typeof value.wrong === 'boolean', 'Invalid mistake state');
  }
  assert(new TextEncoder().encode(JSON.stringify(items)).length <= MAX_BYTES, 'Progress exceeds 128 KiB');
  return items;
}
export async function digest(text) {
  const bytes = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return [...new Uint8Array(bytes)].map(b => b.toString(16).padStart(2, '0')).join('');
}
