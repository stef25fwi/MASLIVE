// ⚠️ Ce script doit être exécuté depuis /functions (ou utilisez plutôt
// /functions/scripts/check_or_init_superadmin_articles.js).
// Ici, on charge firebase-admin depuis les node_modules de /functions
// afin d’éviter: "Cannot find module 'firebase-admin'".

const path = require('path');
const { createRequire } = require('module');

const requireFromFunctions = createRequire(
  path.join(__dirname, 'functions', 'package.json'),
);

const admin = requireFromFunctions('firebase-admin');

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();

// Données des articles
const articles = [
  {
    name: "Casquette MAS'LIVE",
    description: "Casquette officiellement siglée MAS'LIVE. Tissu respirant, ajustable.",
    category: 'casquette',
    price: 19.99,
    imageUrl: '',
    stock: 100,
    isActive: true,
    sku: 'CASQUETTE-001',
    tags: ['casquette', 'accessoire', 'outdoor'],
  },
  {
    name: "T-shirt MAS'LIVE",
    description: "T-shirt 100% coton de qualité premium avec logo MAS'LIVE.",
    category: 'tshirt',
    price: 24.99,
    imageUrl: '',
    stock: 150,
    isActive: true,
    sku: 'TSHIRT-001',
    tags: ['t-shirt', 'vêtement', 'coton'],
  },
  {
    name: "Porte-clé MAS'LIVE",
    description: "Porte-clé en acier inoxydable avec gravure MAS'LIVE.",
    category: 'porteclé',
    price: 9.99,
    imageUrl: '',
    stock: 200,
    isActive: true,
    sku: 'PORTECLE-001',
    tags: ['porte-clé', 'accessoire', 'acier'],
  },
  {
    name: "Bandana MAS'LIVE",
    description: "Bandana coloré multi-usage avec motif MAS'LIVE.",
    category: 'bandana',
    price: 14.99,
    imageUrl: '',
    stock: 120,
    isActive: true,
    sku: 'BANDANA-001',
    tags: ['bandana', 'accessoire', 'outdoor', 'sport'],
  },
];

async function init() {
  try {
    console.log('🔍 Vérification articles existants...');
    const existing = await db.collection('superadmin_articles').get();
    
    if (existing.size > 0) {
      console.log('❌ Articles déjà initialisés. Count:', existing.size);
      existing.forEach(doc => {
        const data = doc.data();
        console.log('  -', data.name, '(' + data.category + ')');
      });
      process.exit(0);
      return;
    }

    console.log('✅ Aucun article trouvé. Initialisation...');

    // Créer en batch
    const batch = db.batch();
    let count = 0;

    for (const article of articles) {
      const ref = db.collection('superadmin_articles').doc();
      batch.set(ref, {
        ...article,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      count++;
      console.log('  + Ajout:', article.name);
    }

    await batch.commit();
    console.log('\n✅ Succès! Articles créés:', count);
    
    // Vérifier
    const check = await db.collection('superadmin_articles').get();
    console.log('\n📊 Total articles dans Firestore:', check.size);
    check.forEach(doc => {
      const data = doc.data();
      console.log('  -', data.name, '(' + data.category + ')', data.price + '€', 'stock:' + data.stock);
    });
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Erreur:', error.message);
    console.error(error);
    process.exit(1);
  }
}

init();
