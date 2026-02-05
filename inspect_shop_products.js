// Inspecte un échantillon de shops/{shopId}/products pour voir la forme réelle des docs.
// Usage :
//   export GOOGLE_APPLICATION_CREDENTIALS="/workspaces/MASLIVE/maslive-firebase-adminsdk-fbsvc-c6d30fab6a.json"
//   node inspect_shop_products.js

const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
});

const db = admin.firestore();

async function main() {
  console.log('--- Inspect collectionGroup("products") sample ---');

  const productsSnap = await db.collectionGroup('products').limit(20).get();
  console.log(`Found ${productsSnap.size} products (sample)`);

  for (const pDoc of productsSnap.docs) {
    const d = pDoc.data();
    const path = pDoc.ref.path; // ex: shops/{shopId}/products/{productId} ou groups/{groupId}/products/{productId}
    const segments = path.split('/');

    let shopId = null;
    let parentType = null;
    let parentId = null;

    const shopsIndex = segments.indexOf('shops');
    const groupsIndex = segments.indexOf('groups');

    if (shopsIndex !== -1 && shopsIndex + 1 < segments.length) {
      parentType = 'shop';
      parentId = segments[shopsIndex + 1];
      shopId = parentId;
    } else if (groupsIndex !== -1 && groupsIndex + 1 < segments.length) {
      parentType = 'group';
      parentId = segments[groupsIndex + 1];
    }

    console.log(
      JSON.stringify(
        {
          path,
          parentType,
          parentId,
          shopId,
          productId: pDoc.id,
          name: d.name,
          title: d.title,
          isActive: d.isActive,
          moderationStatus: d.moderationStatus,
          status: d.status,
          isVisible: d.isVisible,
          stock: d.stock,
          stockByVariant: d.stockByVariant,
          stockQty: d.stockQty,
          trackInventory: d.trackInventory,
          category: d.category,
          categoryId: d.categoryId,
          group: d.group,
          availableSizes: d.availableSizes,
          availableColors: d.availableColors,
          tags: d.tags,
        },
        null,
        2,
      ),
    );
  }
}

main().catch((err) => {
  console.error('Error while inspecting products:', err);
  process.exit(1);
});
