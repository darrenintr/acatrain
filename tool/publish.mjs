import fs from 'node:fs';
import { requireContent } from '../backend/worker/src/content.mjs';
const source = process.argv.slice(2).find(arg => !arg.startsWith('--')) ?? 'assets/seed.json';
const content = requireContent(JSON.parse(fs.readFileSync(source, 'utf8')));
const publish = process.argv.includes('--publish');
const token = publish ? process.env.MCP_PUBLISH_TOKEN : process.env.MCP_EDIT_TOKEN;
const base = process.env.ACATRAIN_API_URL?.replace(/\/+$/, '');
if (!token || !base) throw new Error('Set ACATRAIN_API_URL and the appropriate MCP_EDIT_TOKEN or MCP_PUBLISH_TOKEN');
const endpoint = new URL(`${base}/mcp`);
if (endpoint.protocol !== 'https:' && !(endpoint.protocol === 'http:' && ['localhost', '127.0.0.1'].includes(endpoint.hostname))) throw new Error('HTTPS required');
let id = 0;
async function call(name, args) {
  const response = await fetch(endpoint, { method: 'POST', headers: {
    Authorization: `Bearer ${token}`, 'Content-Type': 'application/json',
    Accept: 'application/json, text/event-stream', 'MCP-Protocol-Version': '2025-11-25'
  }, body: JSON.stringify({ jsonrpc: '2.0', id: ++id, method: 'tools/call', params: { name, arguments: args } }), signal: AbortSignal.timeout(30000) });
  const json = await response.json();
  if (!response.ok || json.error || json.result?.isError) throw new Error(JSON.stringify(json));
  return JSON.parse(json.result.content[0].text);
}
const draftId = `import-${Date.now()}`;
const draft = await call('save_draft', { draftId, content });
console.log(`Saved draft ${draftId}, version ${draft.version}`);
if (publish) {
  const current = await call('get_release', {});
  const result = await call('publish_draft', { draftId, releaseId: draftId,
    expectedVersion: draft.version, expectedActiveReleaseId: current.manifest?.releaseId ?? null });
  console.log(`Published ${result.releaseId}. Manifest caches expire after 30 seconds; clients fetch on launch, resume or manual sync.`);
} else console.log('Draft only. No live content was changed.');
