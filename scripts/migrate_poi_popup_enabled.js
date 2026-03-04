/**
 * Migration Firestore (POIs MarketMap): ajoute `metadata.popupEnabled` si manquant.
 *
 * Règles:
 * - Ne touche pas aux documents qui ont déjà `metadata.popupEnabled`.
 * - Si un `popupEnabled` existe à la racine, il est copié vers `metadata.popupEnabled`.
 * - Sinon: WC/toilet -> false, autres -> true.
 *
 * Exemples:
 * - node scripts/migrate_poi_popup_enabled.js --dry-run
 * - node scripts/migrate_poi_popup_enabled.js --country=GP --event=foo --circuit=bar
 */

const admin = require('firebase-admin');

function parseArgs(argv) {
  const opts = {
    dryRun: false,
    country: null,
    event: null,
    circuit: null,
    limit: null,
  };

  for (const arg of argv) {
    if (arg === '--dry-run') opts.dryRun = true;
    else if (arg.startsWith('--country=')) opts.country = arg.split('=')[1] || null;
    else if (arg.startsWith('--event=')) opts.event = arg.split('=')[1] || null;
    else if (arg.startsWith('--circuit=')) opts.circuit = arg.split('=')[1] || null;
    else if (arg.startsWith('--limit=')) {
      const v = Number(arg.split('=')[1]);
      opts.limit = Number.isFinite(v) && v > 0 ? v : null;
    }
  }

  return opts;
}

function normalizeType(raw) {
  const v = String(raw || '').trim().toLowerCase();
  if (!v) return 'other';
  if (v === 'wc' || v === 'toilet' || v === 'toilets' || v === 'toilette' || v === 'toilettes' || v.includes('toilet')) return 'wc';
  if (v === 'visit' || v === 'visiter' || v === 'tour' || v === 'tourisme') return 'visit';
  if (v === 'food' || v === 'restaurant' || v === 'resto' || v === 'bar' || v === 'snack') return 'food';
  return v;
}

function parseBool(raw) {
  if (raw === null || raw === undefined) return null;
  if (typeof raw === 'boolean') return raw;
  if (typeof raw === 'number') return raw !== 0;
  if (typeof raw === 'string') {
    const s = raw.trim().toLowerCase();
    if (s === 'true' || s === '1' || s === 'yes' || s === 'y') return true;
    if (s === 'false' || s === '0' || s === 'no' || s === 'n') return false;
  }
  return null;
}

function isUnderMarketMapPoisPath(docPath) {
  // Attendu: marketMap/{countryId}/events/{eventId}/circuits/{circuitId}/pois/{poiId}
  const seg = String(docPath || '').split('/');
  const idx = seg.indexOf('marketMap');
  if (idx === -1) return null;
  const ok = seg.length >= idx + 8 && seg[idx + 2] === 'events' && seg[idx + 4] === 'circuits' && seg[idx + 6] === 'pois';
  if (!ok) return null;
  return {
    countryId: seg[idx + 1],
    eventId: seg[idx + 3],
    circuitId: seg[idx + 5],
    poiId: seg[idx + 7],
  };
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));

  // Init admin app
  try {
    // Prefer explicit service account if present (comme les autres scripts du repo)
    // Fallback: application default credentials
    // eslint-disable-next-line global-require, import/no-unresolved
    const serviceAccount = require('../serviceAccountKey.json');
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  } catch (_) {
    admin.initializeApp();
  }

  const db = admin.firestore();
  console.log('🔄 Migration POIs: metadata.popupEnabled');
  console.log(`   dry-run: ${opts.dryRun}`);
  if (opts.country || opts.event || opts.circuit) {
    console.log(`   scope: country=${opts.country || '*'} event=${opts.event || '*'} circuit=${opts.circuit || '*'}`);
  }
  if (opts.limit) console.log(`   limit: ${opts.limit}`);
  console.log('');

  const snap = await db.collectionGroup('pois').get();
  console.log(`📄 docs trouvés (collectionGroup pois): ${snap.size}`);

  let scanned = 0;
  let eligible = 0;
  let updated = 0;
  let skipped = 0;

  let batch = db.batch();
  let batchCount = 0;

  async function commitBatch() {
    if (batchCount === 0) return;
    if (!opts.dryRun) {
      await batch.commit();
    }
    batch = db.batch();
    batchCount = 0;
  }

  for (const doc of snap.docs) {
    scanned++;
    const scope = isUnderMarketMapPoisPath(doc.ref.path);
    if (!scope) {
      skipped++;
      continue;
    }

    if (opts.country && scope.countryId !== opts.country) {
      skipped++;
      continue;
    }
    if (opts.event && scope.eventId !== opts.event) {
      skipped++;
      continue;
    }
    if (opts.circuit && scope.circuitId !== opts.circuit) {
      skipped++;
      continue;
    }

    eligible++;
    const data = doc.data() || {};
    const metaRaw = data.metadata;
    const meta = (metaRaw && typeof metaRaw === 'object' && !Array.isArray(metaRaw)) ? { ...metaRaw } : {};

    if (Object.prototype.hasOwnProperty.call(meta, 'popupEnabled')) {
      skipped++;
      continue;
    }

    const rootPopup = parseBool(data.popupEnabled);
    const typeRaw = data.type || data.layerType || data.layerId || meta.type || '';
    const type = normalizeType(typeRaw);

    const value = (rootPopup !== null) ? rootPopup : (type === 'wc' ? false : true);
    meta.popupEnabled = value;

    if (opts.dryRun) {
      updated++;
      continue;
    }

    batch.update(doc.ref, { metadata: meta });
    batchCount++;
    updated++;

    if (batchCount >= 400) {
      await commitBatch();
    }

    if (opts.limit && updated >= opts.limit) {
      break;
    }
  }

  await commitBatch();

  console.log('');
  console.log('✅ Migration terminée');
  console.log(`   scanned:  ${scanned}`);
  console.log(`   eligible: ${eligible}`);
  console.log(`   updated:  ${updated}${opts.dryRun ? ' (dry-run)' : ''}`);
  console.log(`   skipped:  ${skipped}`);
}

main().catch((e) => {
  console.error('❌ Erreur migration:', e);
  process.exit(1);
});
