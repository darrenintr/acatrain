import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { verifyDeployment } from '../../../tool/verify-deployment.mjs';
import { digest } from '../src/content.mjs';

const base = 'https://acatrain.example';
const origin = 'https://acatrain-test.web.app';
const payload = await readFile(new URL('../../../assets/seed.json', import.meta.url), 'utf8');
const manifest = { releaseId: 'r1', schemaVersion: 1, minAppBuild: 1, sha256: await digest(payload) };
function server({ status = 200, hash = manifest.sha256, cors = origin } = {}) {
  return async (url, init) => {
    assert.equal(init.headers.Origin, origin);
    const headers = { 'Access-Control-Allow-Origin': cors };
    if (url.endsWith('/health')) return Response.json({ ok: true, configured: true }, { headers });
    if (url.endsWith('/v1/manifest')) return Response.json(status === 200 ? { ...manifest, sha256: hash }
      : { error: status === 404 ? 'No published content yet' : 'Internal server error' }, { status, headers });
    assert.ok(url.endsWith('/v1/releases/r1'));
    return new Response(payload, { headers });
  };
}
test('deployment verification reads the release and checks its checksum and CORS', async () => {
  assert.deepEqual(await verifyDeployment({ base, origin, fetcher: server() }),
    { ok: true, empty: false, releaseId: 'r1', sets: 5 });
  await assert.rejects(verifyDeployment({ base, origin, fetcher: server({ hash: 'wrong' }) }), /checksum/);
  await assert.rejects(verifyDeployment({ base, origin, fetcher: server({ cors: '*' }) }), /CORS/);
});
test('a healthy process cannot hide a broken content backend', async () => {
  await assert.rejects(verifyDeployment({ base, origin, allowEmpty: true, fetcher: server({ status: 500 }) }), /HTTP 500/);
  await assert.rejects(verifyDeployment({ base, origin, fetcher: server({ status: 404 }) }), /HTTP 404/);
  assert.deepEqual(await verifyDeployment({ base, origin, allowEmpty: true, fetcher: server({ status: 404 }) }),
    { ok: true, empty: true });
});

test('deploy installs profile rules before serving account-data cleanup', async () => {
  const workflow = await readFile(
    new URL('../../../.github/workflows/deploy-cloud.yml', import.meta.url),
    'utf8',
  );
  const rules = workflow.indexOf('- name: Deploy Firestore rules and indexes');
  const worker = workflow.indexOf('- name: Deploy Cloudflare Worker with secrets');
  const hosting = workflow.indexOf('- name: Deploy Firebase Hosting');
  assert.ok(rules >= 0 && worker > rules && hosting > worker);
  assert.match(workflow, /--var "REQUIRE_VERIFIED_EMAIL:\$REQUIRE_VERIFIED_EMAIL"/);
  const config = await readFile(new URL('../wrangler.toml', import.meta.url), 'utf8');
  for (const name of ['AUTH_LOOKUP_RATE_LIMITER', 'USER_RATE_LIMITER', 'MCP_RATE_LIMITER']) {
    assert.ok(config.includes('name = "' + name + '"'));
  }
  const rulesText = await readFile(
    new URL('../../../firebase/firestore.rules', import.meta.url), 'utf8',
  );
  assert.match(rulesText, /match \/users\/\{uid\}\/state\/profile/);
  assert.match(rulesText, /allow get, delete: if owner\(\)/);
});
