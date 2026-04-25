#!/usr/bin/env node
/**
 * seed_food_pois_circuit1.js
 *
 * 1) Autodécouvre l'arborescence marketMap pour trouver le circuit "circuit 1".
 * 2) Lit TOUS les POIs existants de ce circuit (quelle que soit leur structure actuelle).
 * 3) Isole les food POIs (type|layerType|layerId contient "food", ou name/description le mentionne).
 * 4) Réécrit chaque food POI avec la structure canonique attendue par default_map_page.dart :
 *    { type, layerType, layerId, name, lat, lng, isVisible, updatedAt }
 *
 * Usage :
 *   export GOOGLE_APPLICATION_CREDENTIALS="/workspaces/MASLIVE/maslive-firebase-adminsdk-fbsvc-c6d30fab6a.json"
 *   node seed_food_pois_circuit1.js [--dry-run]
 *
 * --dry-run : affiche ce qui serait écrit sans toucher Firestore.
 */

'use strict';

const admin = require('firebase-admin');

// ─── Init ────────────────────────────────────────────────────────────────────
if (admin.apps.length === 0) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });
}

const db = admin.firestore();
const DRY_RUN = process.argv.includes('--dry-run');

if (DRY_RUN) {
  console.log('🔍  MODE DRY-RUN — aucune écriture Firestore\n');
}

// ─── Structure canonique d'un food POI ───────────────────────────────────────
//
// Telle que lue par MarketPoi.fromDoc() et filtrée par _visibleMarketPoisForCurrentAction() :
//   poi.type   == 'food'   (via data['type'])
//   poi.layerType == 'food'
//   poi.layerId   == 'food'
//   poi.isVisible == true
//   poi.lat / poi.lng  != 0
//
function buildCanonicalFoodPoi(source) {
  // Conserver tous les champs de la fiche (nom, description, horaires, etc.)
  // et normaliser les champs de routage.
  return {
    // ── Champs de routage (obligatoires pour le filtrage carte) ──
    type:      'food',
    layerType: 'food',
    layerId:   'food',
    isVisible: true,

    // ── Coordonnées GPS (inchangées) ──
    lat: source.lat ?? source.latitude ?? 0,
    lng: source.lng ?? source.longitude ?? 0,

    // ── Fiche POI (préservée intégralement) ──
    name:         source.name         ?? source.title  ?? '',
    description:  source.description  ?? source.desc   ?? '',
    imageUrl:     source.imageUrl     ?? source.photoUrl ?? source.image ?? '',
    address:      source.address      ?? source.adresse ?? source.locationLabel ?? '',
    openingHours: source.openingHours ?? source.hours  ?? source.horaires ?? null,
    phone:        source.phone        ?? source.tel    ?? source.telephone ?? '',
    website:      source.website      ?? source.site   ?? '',
    instagram:    source.instagram    ?? source.ig     ?? '',
    facebook:     source.facebook     ?? source.fb     ?? '',
    whatsapp:     source.whatsapp     ?? '',
    email:        source.email        ?? '',
    mapsUrl:      source.mapsUrl      ?? source.googleMapsUrl ?? source.mapUrl ?? '',
    metadata:     source.metadata     ?? source.meta   ?? null,

    // ── Audit ──
    createdByUid: source.createdByUid ?? null,
    createdAt:    source.createdAt    ?? admin.firestore.FieldValue.serverTimestamp(),
    updatedAt:    admin.firestore.FieldValue.serverTimestamp(),
  };
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

/** Normalise un type éventuel en cherchant dans plusieurs champs. */
function resolveRawType(data) {
  return (
    data.type       ??
    data.layerType  ??
    data.layerId    ??
    ''
  ).toString().trim().toLowerCase();
}

/** Vérifie si ce POI est un food POI selon n'importe quel champ. */
function isFoodPoi(data) {
  const t = resolveRawType(data);
  return t === 'food' || t === 'restaurant' || t === 'restauration';
}

/** Cherche "circuit 1" (insensible à la casse, insensible aux espaces/tirets). */
function matchesCircuit1(name) {
  if (!name) return false;
  const n = name.toString().toLowerCase().replace(/[\s_-]/g, '');
  return n.includes('circuit1') || n === '1' || n === 'circuit-1';
}

// ─── Autodiscovery ───────────────────────────────────────────────────────────

async function discoverCircuit1() {
  console.log('🔎  Découverte de l\'arborescence marketMap…\n');

  const countries = await db.collection('marketMap').listDocuments();
  if (countries.length === 0) {
    throw new Error('Collection marketMap introuvable ou vide.');
  }

  for (const countryRef of countries) {
    const events = await countryRef.collection('events').listDocuments();
    for (const eventRef of events) {
      const circuits = await eventRef.collection('circuits').get();
      for (const circuitDoc of circuits.docs) {
        const data = circuitDoc.data() ?? {};
        const circuitName = data.name ?? data.circuitName ?? circuitDoc.id ?? '';
        console.log(`  country=${countryRef.id}  event=${eventRef.id}  circuit=${circuitDoc.id}  name="${circuitName}"`);

        if (
          matchesCircuit1(circuitName) ||
          matchesCircuit1(circuitDoc.id)
        ) {
          console.log(`\n  ✅  Circuit 1 trouvé : ${circuitDoc.ref.path}\n`);
          return {
            countryId: countryRef.id,
            eventId:   eventRef.id,
            circuitId: circuitDoc.id,
            circuitRef: circuitDoc.ref,
          };
        }
      }
    }
  }

  // Fallback : prendre le premier circuit trouvé et demander à l'utilisateur
  console.warn('\n⚠️  Aucun circuit nommé "circuit 1" trouvé.');
  console.warn('   Relancez avec CIRCUIT_ID=<id> pour forcer le circuit.\n');
  process.exit(1);
}

// ─── Lecture + réécriture des food POIs ──────────────────────────────────────

async function migrateFoodPois({ countryId, eventId, circuitId, circuitRef }) {
  const poisCol = circuitRef.collection('pois');
  const snapshot = await poisCol.get();

  console.log(`📦  ${snapshot.size} POI(s) total dans le circuit.\n`);

  const foodPois = snapshot.docs.filter(doc => isFoodPoi(doc.data()));

  if (foodPois.length === 0) {
    console.log('ℹ️  Aucun food POI existant dans ce circuit.');
    console.log('   Vérifiez que des POIs avec type/layerType/layerId="food" existent.\n');

    // Afficher un aperçu des types présents
    const types = [...new Set(snapshot.docs.map(d => resolveRawType(d.data()) || '(vide)'))];
    console.log('   Types présents :', types.join(', '));
    return;
  }

  console.log(`🍽️  ${foodPois.length} food POI(s) trouvé(s) :\n`);

  const batch = db.batch();

  for (const doc of foodPois) {
    const src = doc.data();
    const canonical = buildCanonicalFoodPoi(src);

    console.log(`  POI id=${doc.id}`);
    console.log(`    Avant  → type="${src.type}" layerType="${src.layerType}" layerId="${src.layerId}" isVisible=${src.isVisible}`);
    console.log(`    Après  → type="food"  layerType="food"  layerId="food"  isVisible=true`);
    console.log(`    GPS    → lat=${canonical.lat}  lng=${canonical.lng}`);
    console.log(`    Nom    → "${canonical.name}"`);
    console.log('');

    if (!DRY_RUN) {
      // setMerge : on écrase les champs de routage mais on préserve tout le reste
      batch.set(doc.ref, canonical, { merge: true });
    }
  }

  if (DRY_RUN) {
    console.log('🔍  Dry-run : aucune écriture effectuée.\n');
    return;
  }

  await batch.commit();
  console.log(`\n✅  ${foodPois.length} food POI(s) réécrits avec la structure canonique.`);
  console.log(`\n   Collection : marketMap/${countryId}/events/${eventId}/circuits/${circuitId}/pois`);
  console.log('\n   Structure canonique appliquée :');
  console.log('     type:      "food"');
  console.log('     layerType: "food"');
  console.log('     layerId:   "food"');
  console.log('     isVisible: true');
  console.log('     lat/lng:   coordonnées GPS préservées');
  console.log('     + tous les champs de fiche (name, description, phone, etc.)\n');
}

// ─── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  try {
    // Permettre de forcer le circuit via variable d'environnement
    let circuit;
    const forcedCircuitId = process.env.CIRCUIT_ID;
    const forcedCountryId = process.env.COUNTRY_ID;
    const forcedEventId   = process.env.EVENT_ID;

    if (forcedCircuitId && forcedCountryId && forcedEventId) {
      const circuitRef = db
        .collection('marketMap').doc(forcedCountryId)
        .collection('events').doc(forcedEventId)
        .collection('circuits').doc(forcedCircuitId);
      circuit = { countryId: forcedCountryId, eventId: forcedEventId, circuitId: forcedCircuitId, circuitRef };
      console.log(`🎯  Circuit forcé : ${circuitRef.path}\n`);
    } else {
      circuit = await discoverCircuit1();
    }

    await migrateFoodPois(circuit);
  } catch (err) {
    console.error('❌  Erreur :', err.message ?? err);
    process.exit(1);
  }
}

main();
