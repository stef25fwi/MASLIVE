#!/usr/bin/env node
/**
 * normalize_all_pois.js
 *
 * Parcourt TOUS les circuits de marketMap et normalise les POIs :
 *   - type / layerType / layerId mis en cohérence (food, visit, wc, parking, assistance, market, cashier)
 *   - isVisible défini à true si absent
 *   - aliases de champs hérités remplacés par les noms canoniques
 *
 * Usage :
 *   node normalize_all_pois.js [--dry-run] [--country=XX] [--event=YY] [--circuit=ZZ]
 *
 * Nécessite un fichier ../serviceAccountKey.json (clé de service Firebase).
 *
 * --dry-run : affiche les changements sans rien écrire dans Firestore.
 */

'use strict';

const crypto = require('crypto');
const serviceAccount = require('../serviceAccountKey.json');

// ─── CLI args ─────────────────────────────────────────────────────────────────

const args = process.argv.slice(2);
const DRY_RUN = args.includes('--dry-run');
const FILTER_COUNTRY = (args.find(a => a.startsWith('--country=')) || '').split('=')[1] || null;
const FILTER_EVENT   = (args.find(a => a.startsWith('--event='))   || '').split('=')[1] || null;
const FILTER_CIRCUIT = (args.find(a => a.startsWith('--circuit=')) || '').split('=')[1] || null;

if (DRY_RUN) console.log('🔍  MODE DRY-RUN — aucune écriture Firestore\n');

// ─── Auth ─────────────────────────────────────────────────────────────────────

function b64url(v) {
  return Buffer.from(v).toString('base64').replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
}

function signJwt(claims, key) {
  const h = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const c = b64url(JSON.stringify(claims));
  const s = crypto.createSign('RSA-SHA256');
  s.update(`${h}.${c}`);
  s.end();
  return `${h}.${c}.${s.sign(key, 'base64url')}`;
}

async function getToken() {
  const now = Math.floor(Date.now() / 1000);
  const jwt = signJwt({
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    scope: 'https://www.googleapis.com/auth/datastore',
    iat: now, exp: now + 3600,
  }, serviceAccount.private_key);

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  if (!res.ok) throw new Error(`Auth failed (${res.status}): ${await res.text()}`);
  return (await res.json()).access_token;
}

// ─── Firestore helpers ────────────────────────────────────────────────────────

const PROJECT = serviceAccount.project_id;
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;

function enc(path) { return path.split('/').map(s => encodeURIComponent(s)).join('/'); }

async function listDocs(token, col) {
  const all = [];
  let pageToken = null;
  do {
    const url = `${BASE}/${enc(col)}?pageSize=200${pageToken ? `&pageToken=${pageToken}` : ''}`;
    const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
    if (res.status === 404) return [];
    if (!res.ok) throw new Error(`LIST ${col} → ${res.status}: ${await res.text()}`);
    const body = await res.json();
    (body.documents || []).forEach(doc => {
      const segs = (doc.name || '').split('/');
      all.push({ id: segs[segs.length - 1], fields: doc.fields || {} });
    });
    pageToken = body.nextPageToken || null;
  } while (pageToken);
  return all;
}

async function patchDoc(token, docPath, fields) {
  if (DRY_RUN) return;
  const fieldPaths = Object.keys(fields).map(k => `updateMask.fieldPaths=${encodeURIComponent(k)}`).join('&');
  const url = `${BASE}/${enc(docPath)}?${fieldPaths}&currentDocument.exists=true`;
  const body = { fields: toFsFields(fields) };
  const res = await fetch(url, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const txt = await res.text();
    if (res.status === 404) return; // doc deleted in the meantime
    throw new Error(`PATCH ${docPath} → ${res.status}: ${txt}`);
  }
}

// ─── Firestore value converters ───────────────────────────────────────────────

function toFsValue(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  if (typeof v === 'string') return { stringValue: v };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(toFsValue) } };
  if (typeof v === 'object') {
    const fields = {};
    for (const [k, val] of Object.entries(v)) fields[k] = toFsValue(val);
    return { mapValue: { fields } };
  }
  return { stringValue: String(v) };
}

function toFsFields(obj) {
  const fields = {};
  for (const [k, v] of Object.entries(obj)) fields[k] = toFsValue(v);
  return fields;
}

function fromFsValue(v) {
  if (!v) return null;
  if ('stringValue'  in v) return v.stringValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue'  in v) return Number(v.doubleValue);
  if ('nullValue'    in v) return null;
  if ('timestampValue' in v) return v.timestampValue;
  if ('arrayValue'   in v) return (v.arrayValue?.values || []).map(fromFsValue);
  if ('mapValue'     in v) {
    const out = {};
    for (const [k, val] of Object.entries(v.mapValue?.fields || {})) out[k] = fromFsValue(val);
    return out;
  }
  return null;
}

function fromFsFields(fields) {
  const out = {};
  for (const [k, v] of Object.entries(fields || {})) out[k] = fromFsValue(v);
  return out;
}

// ─── Type normalization (miroir de MarketPoi.fromDoc() dans Dart) ─────────────

const CANONICAL_TYPES = new Set(['visit', 'food', 'assistance', 'parking', 'wc', 'cashier', 'market', 'route']);

function normalizeType(raw) {
  if (!raw || typeof raw !== 'string') return null;
  const n = raw.toLowerCase().trim();
  // Aliases → canoniques
  if (['tour', 'visiter', 'tourisme', 'visit_point', 'visite'].includes(n)) return 'visit';
  if (['toilet', 'toilets', 'toilette', 'toilettes', 'wc_public'].includes(n)) return 'wc';
  if (['restaurant', 'resto', 'bar', 'snack', 'restauration'].includes(n)) return 'food';
  if (['parkings', 'parking_zone', 'parking_zones', 'parking-zone',
       'parking-zones', 'parkingzone', 'zones_parking', 'zone_parking',
       'car_park', 'stationnement'].includes(n)) return 'parking';
  if (['aide', 'help', 'secours', 'first_aid', 'sos'].includes(n)) return 'assistance';
  // Déjà canonique ou inconnu → retourner tel quel
  return CANONICAL_TYPES.has(n) ? n : n;
}

/**
 * Résout le type canonique d'un POI en lisant layerType → type → layerId,
 * dans le même ordre que MarketPoi.fromDoc().
 */
function resolveCanonicalType(data) {
  const candidates = [data.layerType, data.type, data.layerId]
    .map(normalizeType)
    .filter(Boolean);

  // Priorité aux types canoniques
  for (const c of candidates) if (CANONICAL_TYPES.has(c)) return c;
  // Sinon le premier candidat non null
  return candidates[0] || null;
}

// ─── Analyse d'un POI ─────────────────────────────────────────────────────────

/**
 * Retourne les champs à corriger, ou null si le POI est déjà propre.
 */
function computePatch(data) {
  const patch = {};

  const canonical = resolveCanonicalType(data);
  if (!canonical) return null; // pas de type => on ne touche pas

  // type
  if (normalizeType(data.type) !== canonical) patch.type = canonical;
  // layerType
  if (normalizeType(data.layerType) !== canonical) patch.layerType = canonical;
  // layerId : doit être canonique (ou déjà un layerId de couche personnalisé)
  // On ne touche layerId que s'il est parmi les alias → on met le canonique.
  if (data.layerId && normalizeType(data.layerId) !== data.layerId) {
    // layerId était un alias non normalisé
    patch.layerId = canonical;
  }
  if (!data.layerId) {
    patch.layerId = canonical;
  }
  // isVisible : manquant → true
  if (data.isVisible === undefined || data.isVisible === null) {
    patch.isVisible = true;
  }

  return Object.keys(patch).length > 0 ? patch : null;
}

// ─── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  console.log('🔄  Normalisation des POIs marketMap\n');
  const token = await getToken();

  const countries = await listDocs(token, 'marketMap');
  if (countries.length === 0) {
    console.log('⚠️  Collection marketMap vide ou inaccessible.');
    return;
  }

  const stats = { circuits: 0, pois: 0, needFix: 0, fixed: 0, errors: 0 };

  for (const country of countries) {
    if (FILTER_COUNTRY && country.id !== FILTER_COUNTRY) continue;
    const events = await listDocs(token, `marketMap/${country.id}/events`);

    for (const event of events) {
      if (FILTER_EVENT && event.id !== FILTER_EVENT) continue;
      const circuits = await listDocs(token, `marketMap/${country.id}/events/${event.id}/circuits`);

      for (const circuit of circuits) {
        if (FILTER_CIRCUIT && circuit.id !== FILTER_CIRCUIT) continue;
        stats.circuits++;
        const circuitPath = `marketMap/${country.id}/events/${event.id}/circuits/${circuit.id}`;
        const circuitName = fromFsValue(circuit.fields.name)
          || fromFsValue(circuit.fields.circuitName)
          || circuit.id;

        const pois = await listDocs(token, `${circuitPath}/pois`);
        if (pois.length === 0) continue;

        console.log(`\n📍  ${country.id} › ${event.id} › ${circuit.id} («${circuitName}») — ${pois.length} POI(s)`);
        stats.pois += pois.length;

        for (const poi of pois) {
          const data = fromFsFields(poi.fields);
          const patch = computePatch(data);

          if (!patch) {
            process.stdout.write('.');
            continue;
          }

          stats.needFix++;
          const name = data.name || data.title || poi.id;
          console.log(`\n  ✏️  [${poi.id}] «${name}»`);
          console.log(`     Avant : type=${JSON.stringify(data.type)} layerType=${JSON.stringify(data.layerType)} layerId=${JSON.stringify(data.layerId)} isVisible=${data.isVisible}`);
          console.log(`     Après : ${Object.entries(patch).map(([k,v]) => `${k}=${JSON.stringify(v)}`).join('  ')}`);

          if (!DRY_RUN) {
            try {
              await patchDoc(token, `${circuitPath}/pois/${poi.id}`, patch);
              stats.fixed++;
              process.stdout.write('✅');
            } catch (e) {
              stats.errors++;
              console.log(`\n  ❌  Erreur PATCH ${poi.id}: ${e.message}`);
            }
          } else {
            stats.fixed++;
          }
        }
        process.stdout.write('\n');
      }
    }
  }

  console.log('\n─────────────────────────────────────────');
  console.log(`📊  Circuits analysés : ${stats.circuits}`);
  console.log(`    POIs analysés    : ${stats.pois}`);
  console.log(`    POIs à corriger  : ${stats.needFix}`);
  if (DRY_RUN) {
    console.log(`    (dry-run) auraient été corrigés : ${stats.fixed}`);
  } else {
    console.log(`    POIs corrigés    : ${stats.fixed}`);
    if (stats.errors) console.log(`    ❌ Erreurs       : ${stats.errors}`);
  }
  console.log('─────────────────────────────────────────\n');
}

main().catch(e => { console.error('❌  Erreur fatale :', e.message || e); process.exit(1); });
