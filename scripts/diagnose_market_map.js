// Diagnostic: dump de l'arborescence marketMap (pays > events > circuits > layers/pois)
// Usage: node diagnose_market_map.js [--country-id=guadeloupe]
// Requiert ../serviceAccountKey.json

const crypto = require('crypto');

// eslint-disable-next-line import/no-unresolved, global-require
const serviceAccount = require('../serviceAccountKey.json');

function parseArgs(argv) {
  const opts = { countryId: null };
  for (const arg of argv) {
    if (arg.startsWith('--country-id=')) opts.countryId = arg.split('=')[1] || null;
  }
  return opts;
}

function b64url(input) {
  return Buffer.from(input)
    .toString('base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
}

function signJwt(claims, privateKey) {
  const header = { alg: 'RS256', typ: 'JWT' };
  const data = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(claims))}`;
  const signer = crypto.createSign('RSA-SHA256');
  signer.update(data);
  signer.end();
  const signature = signer.sign(privateKey, 'base64url');
  return `${data}.${signature}`;
}

async function getAccessToken() {
  const now = Math.floor(Date.now() / 1000);
  const claims = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    scope: 'https://www.googleapis.com/auth/datastore',
    iat: now,
    exp: now + 3600,
  };
  const assertion = signJwt(claims, serviceAccount.private_key);
  const body = new URLSearchParams({
    grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
    assertion,
  });
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  });
  if (!res.ok) throw new Error(`Token OAuth impossible (${res.status}): ${await res.text()}`);
  return (await res.json()).access_token;
}

function fromFirestoreValue(value) {
  if (!value || typeof value !== 'object') return null;
  if ('stringValue' in value) return value.stringValue;
  if ('booleanValue' in value) return value.booleanValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return Number(value.doubleValue);
  if ('nullValue' in value) return null;
  if ('timestampValue' in value) return value.timestampValue;
  if ('arrayValue' in value) return (value.arrayValue?.values || []).map(fromFirestoreValue);
  if ('mapValue' in value) {
    const out = {};
    for (const [k, v] of Object.entries(value.mapValue?.fields || {})) {
      out[k] = fromFirestoreValue(v);
    }
    return out;
  }
  return null;
}

function fromFirestoreFields(fields) {
  const out = {};
  for (const [k, v] of Object.entries(fields || {})) out[k] = fromFirestoreValue(v);
  return out;
}

async function listDocuments({ projectId, accessToken, relativeCollectionPath }) {
  const encodedPath = relativeCollectionPath
    .split('/')
    .map((s) => encodeURIComponent(s))
    .join('/');
  const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${encodedPath}?pageSize=300`;
  const res = await fetch(url, {
    method: 'GET',
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (res.status === 404) return [];
  if (!res.ok) {
    throw new Error(`LIST ${relativeCollectionPath} en echec (${res.status}): ${await res.text()}`);
  }
  const json = await res.json();
  return (json.documents || []).map((doc) => {
    const segments = String(doc.name || '').split('/');
    return { id: segments[segments.length - 1], data: fromFirestoreFields(doc.fields || {}) };
  });
}

function fmt(v) {
  if (v === null || v === undefined) return '∅';
  return String(v);
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  const projectId = serviceAccount.project_id;
  const accessToken = await getAccessToken();

  const countries = await listDocuments({
    projectId,
    accessToken,
    relativeCollectionPath: 'marketMap',
  });

  console.log(`\n=== marketMap: ${countries.length} pays ===`);

  for (const country of countries) {
    if (opts.countryId && country.id !== opts.countryId) continue;
    console.log(`\n🌍 PAYS: ${country.id}  (name=${fmt(country.data.name)}, isVisible=${fmt(country.data.isVisible)})`);

    const events = await listDocuments({
      projectId,
      accessToken,
      relativeCollectionPath: `marketMap/${country.id}/events`,
    });

    for (const ev of events) {
      console.log(`  📅 EVENT: ${ev.id}  (name=${fmt(ev.data.name)}, isVisible=${fmt(ev.data.isVisible)})`);

      const circuits = await listDocuments({
        projectId,
        accessToken,
        relativeCollectionPath: `marketMap/${country.id}/events/${ev.id}/circuits`,
      });

      for (const c of circuits) {
        const d = c.data;
        const routeLen = Array.isArray(d.route) ? d.route.length : 0;
        console.log(
          `    🗺️  CIRCUIT: ${c.id}\n` +
          `        name=${fmt(d.name)}  status=${fmt(d.status)}  isVisible=${fmt(d.isVisible)}\n` +
          `        center=${d.center ? `${d.center.lat},${d.center.lng}` : '∅'}  route=${routeLen} pts  styleUrl=${d.styleUrl ? 'oui' : '∅'}`,
        );

        const layers = await listDocuments({
          projectId,
          accessToken,
          relativeCollectionPath: `marketMap/${country.id}/events/${ev.id}/circuits/${c.id}/layers`,
        });
        const layersDesc = layers
          .map((l) => `${l.id}(type=${fmt(l.data.type)},visible=${fmt(l.data.isVisible)})`)
          .join(', ');
        console.log(`        layers[${layers.length}]: ${layersDesc || '∅'}`);

        const pois = await listDocuments({
          projectId,
          accessToken,
          relativeCollectionPath: `marketMap/${country.id}/events/${ev.id}/circuits/${c.id}/pois`,
        });
        console.log(`        pois[${pois.length}]:`);
        for (const p of pois) {
          const pd = p.data;
          const perim = pd.metadata && Array.isArray(pd.metadata.perimeter)
            ? `perimeter=${pd.metadata.perimeter.length}pts`
            : 'point';
          console.log(
            `          • ${p.id}: name=${fmt(pd.name)} type=${fmt(pd.type)} layerId=${fmt(pd.layerId)} ` +
            `layerType=${fmt(pd.layerType)} isVisible=${fmt(pd.isVisible)} lat=${fmt(pd.lat)} lng=${fmt(pd.lng)} [${perim}]`,
          );
        }
      }
    }
  }

  console.log('\n=== Fin du diagnostic ===\n');
}

main().catch((error) => {
  console.error('❌ Erreur diagnostic:', error);
  process.exit(1);
});
