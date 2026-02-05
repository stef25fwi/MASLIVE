#!/usr/bin/env node
/**
 * cleanup_test_products.js
 * Supprime les produits de test/vides de Firestore
 */

const admin = require('firebase-admin');

// Initialiser Firebase Admin
if (admin.apps.length === 0) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });
}

const db = admin.firestore();

// Produits à supprimer (IDs identifiés lors de l'inspection)
const TEST_PRODUCTS = [
  { path: 'products/R2y2Yq8o7uUpUqXwKw5m', reason: 'Empty title/name' },
  { path: 'products/aEVd4h2NhWrIM4KqBDiN', reason: 'Empty title/name, 0 stock' },
  { path: 'products/tFxaXBIX2oY9QXoh7NQR', reason: 'Duplicate of cap-maslive-black' },
  { path: 'shops/global/products/CLylx4JINODvqiuYd3Uu', reason: 'Test product' },
];

async function cleanupTestProducts() {
  console.log('--- Cleanup Test Products ---\n');
  
  for (const { path, reason } of TEST_PRODUCTS) {
    try {
      const docRef = db.doc(path);
      const doc = await docRef.get();
      
      if (!doc.exists) {
        console.log(`⚠️  ${path} - already deleted or not found`);
        continue;
      }
      
      console.log(`🗑️  Deleting: ${path}`);
      console.log(`   Reason: ${reason}`);
      console.log(`   Title: ${doc.data().title || doc.data().name || '(empty)'}`);
      
      await docRef.delete();
      console.log(`✅ Deleted successfully\n`);
      
    } catch (error) {
      console.error(`❌ Error deleting ${path}:`, error.message);
    }
  }
  
  console.log('--- Cleanup Complete ---');
  console.log('Remaining products should be:');
  console.log('  - cap-maslive-black (Casquette)');
  console.log('  - tshirt-maslive-black (T-shirt)');
  console.log('  - keyring-maslive-black (Porte-clé)');
  console.log('  - bandana-maslive-logo (Bandana Logo)');
  console.log('  - bandana-maslive-white (Bandana White - 0 stock)');
  console.log('\nRun inspect_shop_products.js to verify.');
}

cleanupTestProducts()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
