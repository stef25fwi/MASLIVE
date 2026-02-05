/**
 * Migration Firestore:
 *  - Ajout / normalisation des champs sur shops/{shopId}/products :
 *    status, isVisible, stockQty, trackInventory, categoryId, tags
 *
 * Usage:
 *   1) Installer firebase-admin (si besoin) :
 *        npm install firebase-admin
 *   2) Configurer les credentials (GOOGLE_APPLICATION_CREDENTIALS ou autre)
 *   3) Lancer :
 *        node migrate_shop_products.js
 */

const admin = require('firebase-admin');

// Initialise avec Application Default Credentials
// (ou adapte si tu veux utiliser un serviceAccount spécifique)
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
});

const db = admin.firestore();

// Active le mode "dry run" pour tester sans écrire
// Mettre à false une fois validé pour appliquer réellement la migration
const DRY_RUN = false;

// Taille max d'un batch Firestore
const BATCH_SIZE = 400;

async function migrate() {
  console.log('--- Migration collectionGroup("products") ---');
  console.log('DRY_RUN =', DRY_RUN);

  const productsSnap = await db.collectionGroup('products').get();
  console.log(`Found ${productsSnap.size} products (collectionGroup)`);

  let totalProducts = productsSnap.size;
  let totalUpdated = 0;

  let batch = db.batch();
  let batchCount = 0;

  for (const pDoc of productsSnap.docs) {
    const data = pDoc.data();
    const update = {};

    // ------------------------------
    // status
    // ------------------------------
    if (data.status === undefined) {
      const isActive = data.isActive === true;
      const isApproved = data.moderationStatus === 'approved';
      update.status = isActive || isApproved ? 'published' : 'draft';
    }

    // ------------------------------
    // isVisible
    // ------------------------------
    if (data.isVisible === undefined) {
      // Si rien n'est précisé, on rend visible sauf si isActive === false
      update.isVisible = data.isActive !== false;
    }

    // ------------------------------
    // trackInventory
    // ------------------------------
    if (data.trackInventory === undefined) {
      const hasStockField = typeof data.stock === 'number';
      const hasStockByVariant = !!(
        data.stockByVariant &&
        typeof data.stockByVariant === 'object' &&
        Object.keys(data.stockByVariant).length > 0
      );

      update.trackInventory = hasStockField || hasStockByVariant;
    }

    // ------------------------------
    // stockQty (quantité totale)
    // ------------------------------
    if (data.stockQty === undefined) {
      let qty = null;

      if (typeof data.stock === 'number') {
        qty = data.stock;
      } else if (
        data.stockByVariant &&
        typeof data.stockByVariant === 'object'
      ) {
        qty = Object.values(data.stockByVariant).reduce((sum, v) => {
          const n = typeof v === 'number' ? v : 0;
          return sum + n;
        }, 0);
      }

      if (qty !== null) {
        update.stockQty = qty;
      }
    }

    // ------------------------------
    // categoryId
    // ------------------------------
    if (data.categoryId === undefined && typeof data.category === 'string') {
      update.categoryId = data.category;
    }

    // ------------------------------
    // tags (array<string>)
    // ------------------------------
    if (data.tags === undefined) {
      const tags = new Set();

      const catId =
        update.categoryId ??
        (typeof data.categoryId === 'string' ? data.categoryId : null);
      if (catId) tags.add(String(catId).toLowerCase());

      if (typeof data.group === 'string') {
        tags.add(data.group.toLowerCase());
      }

      if (Array.isArray(data.availableSizes)) {
        for (const s of data.availableSizes) {
          tags.add(String(s).toLowerCase());
        }
      }

      if (Array.isArray(data.availableColors)) {
        for (const c of data.availableColors) {
          tags.add(String(c).toLowerCase());
        }
      }

      if (tags.size > 0) {
        update.tags = Array.from(tags);
      }
    }

    // ------------------------------
    // Appliquer l'update si utile
    // ------------------------------
    if (Object.keys(update).length > 0) {
      totalUpdated++;
      console.log(
        `  - product ${pDoc.id} (${pDoc.ref.path}): will update fields ${Object.keys(
          update,
        ).join(', ')}`,
      );

      if (!DRY_RUN) {
        batch.update(pDoc.ref, update);
        batchCount++;

        if (batchCount >= BATCH_SIZE) {
          await batch.commit();
          console.log('  > batch committed');
          batch = db.batch();
          batchCount = 0;
        }
      }
    }
  }

  // Commit final du batch restant
  if (!DRY_RUN && batchCount > 0) {
    await batch.commit();
    console.log('  > final batch committed');
  }

  console.log('\n--- DONE ---');
  console.log('Total products scanned :', totalProducts);
  console.log('Total products updated :', totalUpdated);
}

migrate().catch((err) => {
  console.error('Migration failed:', err);
  process.exit(1);
});
