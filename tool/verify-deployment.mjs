import { pathToFileURL } from 'node:url';
import { digest, requireContent, validId } from '../backend/worker/src/content.mjs';

export async function verifyDeployment({ base, origin, allowEmpty = false, fetcher = fetch }) {
  const url = new URL(base);
  if (url.protocol !== 'https:' || url.username || url.password || url.pathname !== '/' || url.search || url.hash) {
    throw new Error('ACATRAIN_API_URL must be an HTTPS origin');
  }
  const headers = origin ? { Origin: origin } : {};
  async function get(path) {
    const response = await fetcher(`${url.origin}${path}`, { headers, signal: AbortSignal.timeout(30000) });
    if (origin && response.headers.get('Access-Control-Allow-Origin') !== origin) {
      throw new Error(`CORS is not configured for ${origin} on ${path}`);
    }
    return response;
  }
  const health = await get('/health');
  if (!health.ok) throw new Error(`Worker health returned HTTP ${health.status}`);
  const state = await health.json();
  if (!state.ok || !state.configured) throw new Error('Worker is not configured');

  // /health alone never exercises OAuth or the Firestore adapter.
  const response = await get('/v1/manifest');
  if (allowEmpty && response.status === 404) {
    const error = await response.json();
    if (error.error === 'No published content yet') return { ok: true, empty: true };
  }
  if (!response.ok) throw new Error(`Published manifest returned HTTP ${response.status}`);
  const manifest = await response.json();
  if (!validId(manifest.releaseId) || manifest.schemaVersion !== 1 || manifest.minAppBuild !== 1) {
    throw new Error('Published manifest is invalid or incompatible');
  }
  const release = await get(`/v1/releases/${manifest.releaseId}`);
  if (!release.ok) throw new Error(`Published release returned HTTP ${release.status}`);
  const payload = await release.text();
  if (await digest(payload) !== manifest.sha256) throw new Error('Published release checksum mismatch');
  const content = requireContent(JSON.parse(payload));
  return { ok: true, empty: false, releaseId: manifest.releaseId, sets: content.sets.length };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const result = await verifyDeployment({
      base: process.env.ACATRAIN_API_URL,
      origin: process.env.FIREBASE_PROJECT_ID ? `https://${process.env.FIREBASE_PROJECT_ID}.web.app` : undefined,
      allowEmpty: process.argv.includes('--allow-empty')
    });
    console.log(JSON.stringify(result));
  } catch (error) {
    console.error(`Deployment verification failed: ${error.message}`);
    process.exitCode = 1;
  }
}
