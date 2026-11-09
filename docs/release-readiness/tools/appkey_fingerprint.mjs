// Compares SHA-256 fingerprints of APP_KEY values. Prints fingerprints (first 16 hex) and match
// results only — never a key value. Reads the Render API key from ~/.render/cli.yaml in memory.
import { readFileSync, existsSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { homedir } from 'node:os';

const fp = (v) => createHash('sha256').update(v).digest('hex').slice(0, 16);
const [testEnvPath, serviceId] = process.argv.slice(2);

const testKey = /^APP_KEY=(.*)$/m.exec(readFileSync(testEnvPath, 'utf8'))?.[1]?.trim().replace(/^["']|["']$/g, '');
console.log('test key (backend/.env.testing) fingerprint:', fp(testKey));

const cli = `${homedir()}/.render/cli.yaml`;
if (!existsSync(cli)) { console.log('render cli.yaml not found: production UNVERIFIED'); process.exit(0); }
const apiKey = /api_?key:\s*["']?([A-Za-z0-9_\-]+)/i.exec(readFileSync(cli, 'utf8'))?.[1];
if (!apiKey) { console.log('no API key in cli.yaml: production UNVERIFIED'); process.exit(0); }

let prodKey = null;
let cursor = '';
for (let page = 0; page < 10 && prodKey === null; page++) {
  const res = await fetch(`https://api.render.com/v1/services/${serviceId}/env-vars?limit=100${cursor ? `&cursor=${cursor}` : ''}`, {
    headers: { Authorization: `Bearer ${apiKey}`, Accept: 'application/json' },
  });
  if (!res.ok) { console.log('Render API answered', res.status, ': production UNVERIFIED'); process.exit(0); }
  const rows = await res.json();
  if (!Array.isArray(rows) || rows.length === 0) break;
  for (const row of rows) {
    if (row?.envVar?.key === 'APP_KEY') prodKey = String(row.envVar.value ?? '').trim();
  }
  cursor = rows.at(-1)?.cursor ?? '';
  if (!cursor) break;
}
if (!prodKey) { console.log('APP_KEY not found among service env vars: production UNVERIFIED'); process.exit(0); }
console.log('production key fingerprint:', fp(prodKey));
console.log('production key equals the committed test key:', fp(prodKey) === fp(testKey) ? 'YES — ROTATION REQUIRED' : 'no');
console.log('production key looks like a Laravel base64 key:', /^base64:[A-Za-z0-9+/=]{40,}$/.test(prodKey));
