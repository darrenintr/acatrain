import fs from 'node:fs';
import { requireContent } from '../backend/worker/src/content.mjs';

const source = process.argv.slice(2).find(arg => !arg.startsWith('--'));
if (!source) throw new Error('Usage: node tool/publish-study-set.mjs <study-set.json>');

const studySet = JSON.parse(fs.readFileSync(source, 'utf8'));
requireContent({ schemaVersion: 1, minAppBuild: 1, sets: [studySet] });

const token = process.env.MCP_PUBLISH_TOKEN;
const base = process.env.ACATRAIN_API_URL?.replace(/\/+$/, '');
if (!token || !base) throw new Error('Set ACATRAIN_API_URL and MCP_PUBLISH_TOKEN');

const endpoint = new URL(`${base}/mcp`);
if (endpoint.protocol !== 'https:' && !(endpoint.protocol === 'http:' && ['localhost', '127.0.0.1'].includes(endpoint.hostname))) {
  throw new Error('HTTPS required');
}

let id = 0;
async function call(name, args) {
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      Accept: 'application/json, text/event-stream',
      'MCP-Protocol-Version': '2025-11-25'
    },
    body: JSON.stringify({
      jsonrpc: '2.0',
      id: ++id,
      method: 'tools/call',
      params: { name, arguments: args }
    }),
    signal: AbortSignal.timeout(30000)
  });
  const json = await response.json();
  if (!response.ok || json.error || json.result?.isError) {
    const message = json.result?.content?.[0]?.text ?? JSON.stringify(json);
    throw new Error(message);
  }
  return JSON.parse(json.result.content[0].text);
}

const current = await call('get_release', {});
let content;
if (current.release?.payload) {
  content = requireContent(JSON.parse(current.release.payload));
} else {
  content = { schemaVersion: 1, minAppBuild: 1, sets: [] };
}

const merged = requireContent({
  schemaVersion: content.schemaVersion ?? 1,
  minAppBuild: content.minAppBuild ?? 1,
  sets: [...(content.sets ?? []).filter(set => set.id !== studySet.id), studySet]
});

const stamp = Date.now().toString(36);
const draftId = `review-${stamp}`;
const releaseId = `review-${stamp}`;

const draft = await call('save_draft', { draftId, content: merged });
const published = await call('publish_draft', {
  draftId,
  releaseId,
  expectedVersion: draft.version,
  expectedActiveReleaseId: current.manifest?.releaseId ?? null
});

const verify = await call('get_release', { releaseId: published.releaseId });
const verifiedContent = requireContent(JSON.parse(verify.release.payload));
if (!verifiedContent.sets.some(set => set.id === studySet.id)) {
  throw new Error(`Published release does not contain study set ${studySet.id}`);
}

console.log(`Published study set "${studySet.title}" as ${published.releaseId}. Total sets: ${verifiedContent.sets.length}.`);
