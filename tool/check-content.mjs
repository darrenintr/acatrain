import fs from 'node:fs';
import { requireContent } from '../backend/worker/src/content.mjs';
const content = requireContent(JSON.parse(fs.readFileSync(process.argv[2] ?? 'assets/seed.json', 'utf8')));
console.log(`Valid schema-v1 bundle: ${content.sets.length} sets, ${content.sets.reduce((n, s) => n + s.items.length, 0)} items`);
