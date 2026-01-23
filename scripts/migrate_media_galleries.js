/**
 * Script de migration Firestore
 * Ajoute les champs de filtrage aux galeries existantes
 * 
 * Exécution:
 * node scripts/migrate_media_galleries.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Données de référence pour migration
const DEFAULT_VALUES = {
  country: 'Guadeloupe',
  eventName: 'Carnaval 2026',
  groupName: 'Groupe A',
  photographerName: 'Photographe MasLive',
  pricePerPhoto: 8.0,
};

async function migrateGalleries() {
  console.log('🔄 Migration des galeries média...\n');

  try {
    const snapshot = await db.collection('media_galleries').get();
    
    if (snapshot.empty) {
      console.log('⚠️  Aucune galerie trouvée');
      return;
    }

    console.log(`📸 ${snapshot.size} galerie(s) trouvée(s)\n`);

    let updated = 0;
    let skipped = 0;

    for (const doc of snapshot.docs) {
      const data = doc.data();
      const updates = {};

      // Vérifier chaque champ requis
      if (!data.country) {
        updates.country = DEFAULT_VALUES.country;
      }
      
      if (!data.date) {
        // Utiliser createdAt ou date actuelle
        updates.date = data.createdAt || admin.firestore.Timestamp.now();
      }
      
      if (!data.eventName) {
        updates.eventName = DEFAULT_VALUES.eventName;
      }
      
      if (!data.groupName) {
        // Essayer d'extraire depuis title ou groupId
        updates.groupName = data.title || data.groupId || DEFAULT_VALUES.groupName;
      }
      
      if (!data.photographerName) {
        updates.photographerName = DEFAULT_VALUES.photographerName;
      }
      
      if (typeof data.pricePerPhoto !== 'number') {
        updates.pricePerPhoto = DEFAULT_VALUES.pricePerPhoto;
      }

      // Mettre à jour si nécessaire
      if (Object.keys(updates).length > 0) {
        await doc.ref.update(updates);
        console.log(`✅ ${doc.id}: ${Object.keys(updates).join(', ')}`);
        updated++;
      } else {
        console.log(`⏭️  ${doc.id}: déjà à jour`);
        skipped++;
      }
    }

    console.log('\n✨ Migration terminée!');
    console.log(`   ${updated} galerie(s) mise(s) à jour`);
    console.log(`   ${skipped} galerie(s) déjà à jour`);

  } catch (error) {
    console.error('❌ Erreur:', error);
    process.exit(1);
  }

  process.exit(0);
}

// Exemple: Créer une galerie de test complète
async function createTestGallery() {
  console.log('🧪 Création d\'une galerie de test...\n');

  const testGallery = {
    title: 'Test Carnaval 2026',
    subtitle: 'Galerie de test avec tous les champs',
    coverUrl: 'https://picsum.photos/600/400',
    images: [
      'https://picsum.photos/600/400?1',
      'https://picsum.photos/600/400?2',
      'https://picsum.photos/600/400?3',
    ],
    photoCount: 3,
    
    // Champs de filtrage
    country: 'Martinique',
    date: admin.firestore.Timestamp.fromDate(new Date('2026-02-10')),
    eventName: 'Défilé Fort-de-France',
    groupName: 'Tanbo',
    photographerName: 'Léna Shots',
    pricePerPhoto: 10.0,
    
    // Autres
    groupId: 'tanbo',
    createdAt: admin.firestore.Timestamp.now(),
  };

  try {
    const docRef = await db.collection('media_galleries').add(testGallery);
    console.log(`✅ Galerie de test créée: ${docRef.id}`);
  } catch (error) {
    console.error('❌ Erreur:', error);
    process.exit(1);
  }

  process.exit(0);
}

// Menu
const args = process.argv.slice(2);

if (args.includes('--test')) {
  createTestGallery();
} else {
  migrateGalleries();
}
