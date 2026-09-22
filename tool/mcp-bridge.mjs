import readline from 'node:readline';
const base = process.env.ACATRAIN_API_URL?.replace(/\/+$/, '');
const token = process.env.ACATRAIN_MCP_TOKEN;
if (!base || !token) { console.error('Set ACATRAIN_API_URL and ACATRAIN_MCP_TOKEN. Use the EDIT token for AI clients.'); process.exit(1); }
const url = new URL(`${base}/mcp`);
if (url.protocol !== 'https:' && !(url.protocol === 'http:' && ['127.0.0.1', 'localhost'].includes(url.hostname))) {
  console.error('The MCP endpoint must use HTTPS except on localhost.'); process.exit(1);
}
for await (const line of readline.createInterface({ input: process.stdin })) {
  if (!line.trim()) continue;
  let message;
  try {
    message = JSON.parse(line);
    const response = await fetch(url, { method: 'POST', headers: {
      Authorization: `Bearer ${token}`, 'Content-Type': 'application/json',
      Accept: 'application/json, text/event-stream', 'MCP-Protocol-Version': '2025-11-25'
    }, body: JSON.stringify(message), signal: AbortSignal.timeout(30000) });
    if (response.status === 202) continue;
    if (!response.ok) throw new Error(`MCP HTTP ${response.status}`);
    process.stdout.write(`${JSON.stringify(await response.json())}\n`);
  } catch (error) {
    if (message && Object.hasOwn(message, 'id')) process.stdout.write(`${JSON.stringify({ jsonrpc: '2.0', id: message.id, error: { code: -32603, message: error.message } })}\n`);
    else console.error('MCP bridge: invalid input or notification failure');
  }
}
