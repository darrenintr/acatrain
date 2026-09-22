import test from 'node:test';
import http from 'node:http';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { fileURLToPath } from 'node:url';
import { createWorker } from '../src/index.mjs';
import { AppError } from '../src/content.mjs';

// Exercise the shipped CLI and stdio transport through a real loopback HTTP server.
// Only the persistence adapter is mocked; no cloud credentials or network access are needed.
test('CLI and stdio publishing integration', { timeout: 20000 }, async t => {
  const data = new Map(); let sequence = 0;
  const store = {
    async get(path) { return structuredClone(data.get(path) ?? null); },
    async commit(writes) {
      for (const w of writes) if ((data.get(w.path)?.version ?? null) !== (w.version ?? null)) throw new AppError(409, 'Conflict');
      for (const w of writes) data.set(w.path, { value: structuredClone(w.value), version: String(++sequence) });
    }
  };
  const worker = createWorker({ adminStore: store });
  const env = { MCP_EDIT_TOKEN: 'test-editor-token-longer-than-32-characters', MCP_PUBLISH_TOKEN: 'test-publisher-token-longer-than-32-characters' };
  const server = http.createServer(async (req, res) => {
    try {
      const chunks = []; for await (const chunk of req) chunks.push(chunk);
      const request = new Request(`http://127.0.0.1:${server.address().port}${req.url}`, {
        method: req.method, headers: req.headers,
        ...(['GET', 'HEAD'].includes(req.method) ? {} : { body: Buffer.concat(chunks) })
      });
      const result = await worker.fetch(request, env);
      res.writeHead(result.status, Object.fromEntries(result.headers));
      res.end(Buffer.from(await result.arrayBuffer()));
    } catch (error) { res.writeHead(500); res.end(error.message); }
  });
  server.listen(0, '127.0.0.1'); await once(server, 'listening');
  const base = `http://127.0.0.1:${server.address().port}`;
  async function run(args, input = '') {
    const child = spawn(process.execPath, args, {
      cwd: fileURLToPath(new URL('../../../', import.meta.url)),
      env: { ...process.env, ...env, ACATRAIN_API_URL: base, ACATRAIN_MCP_TOKEN: env.MCP_EDIT_TOKEN },
      stdio: ['pipe', 'pipe', 'pipe'], timeout: 15000
    });
    let out = '', err = '';
    child.stdout.on('data', d => out += d); child.stderr.on('data', d => err += d);
    child.stdin.end(input);
    const [code] = await once(child, 'close');
    assert.equal(code, 0, err); return out;
  }
  try {
    await t.test('bridge negotiates and filters publisher tools', async () => {
      const messages = [
        { jsonrpc: '2.0', id: 1, method: 'initialize', params: { protocolVersion: '2025-11-25', capabilities: {}, clientInfo: { name: 'smoke', version: '1.0' } } },
        { jsonrpc: '2.0', method: 'notifications/initialized' },
        { jsonrpc: '2.0', id: 2, method: 'tools/list' }
      ];
      const output = await run(['tool/mcp-bridge.mjs'], messages.map(m => JSON.stringify(m)).join('\n') + '\n');
      const replies = output.trim().split('\n').map(s => JSON.parse(s));
      assert.equal(replies.length, 2);
      assert.equal(replies[0].result.protocolVersion, '2025-11-25');
      assert.equal(replies[1].result.tools.length, 4);
    });
    await t.test('CLI defaults to draft only', async () => {
      await run(['tool/publish.mjs', 'assets/seed.json']);
      assert.equal(await store.get('config/active'), null);
    });
    await t.test('explicit publish becomes available over public HTTP', async () => {
      await run(['tool/publish.mjs', '--publish', 'assets/seed.json']);
      const manifest = await (await fetch(`${base}/v1/manifest`)).json();
      const release = await (await fetch(`${base}/v1/releases/${manifest.releaseId}`)).json();
      assert.equal(release.sets.length, 3);
      assert.equal(release.sets.reduce((n, s) => n + s.items.length, 0), 19);
    });
  } finally { server.close(); server.closeAllConnections(); }
});
