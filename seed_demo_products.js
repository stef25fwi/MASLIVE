/**
 * Seed de produits de démo pour la boutique MASLIVE.
 *
 * Objectif : créer quelques produits cohérents à partir des assets
 * afin de tester la structure "boutique idéale".
 *
 * Collection ciblée : shops/global/products/{productId}
 *
 * Prérequis :
 *   - npm install firebase-admin
 *   - export GOOGLE_APPLICATION_CREDENTIALS="/workspaces/MASLIVE/maslive-firebase-adminsdk-fbsvc-c6d30fab6a.json"
 *
 * Usage :
 *   cd /workspaces/MASLIVE
 *   node seed_demo_products.js
 */

const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
});

const db = admin.firestore();

const SHOP_ID = 'global';
const GROUP_ID = 'MASLIVE';

const PRODUCTS = [
  {
    id: 'cap-maslive-black',
    title: 'Casquette MASLIVE',
    priceCents: 2500,
    imagePath: 'assets/shop/capblack1.png',
    category: 'Casquettes',
    stockByVariant: { 'One Size|Noir': 50 },
    availableSizes: ['One Size'],
    availableColors: ['Noir'],
  },
  {
    id: 'tshirt-maslive-black',
    title: 'T-shirt MASLIVE',
    priceCents: 2500,
    imagePath: 'assets/shop/tshirtblack.png',
    category: 'Vêtements',
    stockByVariant: {
      'XS|Noir': 10,
      'S|Noir': 10,
      'M|Noir': 10,
      'L|Noir': 10,
      'XL|Noir': 10,
    },
    availableSizes: ['XS', 'S', 'M', 'L', 'XL'],
    availableColors: ['Noir'],
  },
  {
    id: 'keyring-maslive-black',
    title: 'Porte-clé MASLIVE',
    priceCents: 800,
    imagePath: 'assets/shop/porteclésblack01.png',
    category: 'Accessoires',
    stockByVariant: { 'default|Noir': 100 },
    availableSizes: ['Unique'],
    availableColors: ['Noir'],
  },
  {
    id: 'bandana-maslive-logo',
    title: 'Bandana MASLIVE Logo',
    priceCents: 2000,
    imagePath: 'assets/shop/logomockup.jpeg',
    category: 'Accessoires',
    stockByVariant: { 'Unique|Multicolore': 40 },
    availableSizes: ['Unique'],
    availableColors: ['Multicolore'],
  },
  {
    id: 'bandana-maslive-white',
    title: 'Bandana MASLIVE White',
    priceCents: 1000,
    imagePath: 'assets/shop/modelmaslivewhite.png',
    category: 'Accessoires',
    stockByVariant: { 'Unique|Blanc': 0 }, // volontairement en rupture
    availableSizes: ['Unique'],
    availableColors: ['Blanc'],
  },
];

function buildProductDoc(def) {
  // Calcul du stock total à partir des variantes
  const stockByVariant = def.stockByVariant || {};
  const stockQty = Object.values(stockByVariant).reduce((sum, v) => {
    const n = typeof v === 'number' ? v : 0;
    return sum + n;
  }, 0);

  const tags = new Set();
  if (def.category) tags.add(String(def.category).toLowerCase());
  if (GROUP_ID) tags.add(GROUP_ID.toLowerCase());
  if (Array.isArray(def.availableSizes)) {
    for (const s of def.availableSizes) tags.add(String(s).toLowerCase());
  }
  if (Array.isArray(def.availableColors)) {
    for (const c of def.availableColors) tags.add(String(c).toLowerCase());
  }

  return {
    // Champs modèle GroupProduct
    title: def.title,
    priceCents: def.priceCents,
    imageUrl: '',
    imagePath: def.imagePath,
    category: def.category,
    isActive: true,
    moderationStatus: 'approved',
    stockByVariant,
    availableSizes: def.availableSizes,
    availableColors: def.availableColors,

    // Champs de structure boutique idéale
    shopId: SHOP_ID,
    groupId: GROUP_ID,
    status: 'published',
    isVisible: true,
    trackInventory: true,
    stockQty,
    categoryId: def.category,
    tags: Array.from(tags),

    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

async function main() {
  console.log('--- Seeding demo products into shops/global/products ---');

  const col = db.collection('shops').doc(SHOP_ID).collection('products');

  for (const def of PRODUCTS) {
    const docRef = col.doc(def.id);
    const payload = buildProductDoc(def);
    await docRef.set(payload, { merge: true });
    console.log(`✔ Seeded product ${def.id} at ${docRef.path}`);
  }

  console.log('--- DONE ---');
}

main().catch((err) => {
  console.error('Seeding failed:', err);
  process.exit(1);
});
