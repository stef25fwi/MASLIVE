/*
  Usage:
    cd /workspaces/MASLIVE/functions
    node scripts/check_or_init_superadmin_articles.js

  ⚠️ Attention: utilise vos credentials Firebase (ADC). Si vous n’avez pas les emulators,
  cela lit/écrit en PRODUCTION (comme le warning de firebase functions:shell).
*/

const admin = require('firebase-admin');

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();

const ARTICLES = [
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
    metadata: {},
  },
  {
    name: "T-shirt MAS'LIVE",
    description: "T-shirt 100% coton de qualité premium avec logo MAS'LIVE. Confortable et durable.",
    category: 'tshirt',
    price: 24.99,
    imageUrl: '',
    stock: 150,
    isActive: true,
    sku: 'TSHIRT-001',
    tags: ['t-shirt', 'vêtement', 'coton'],
    metadata: {},
  },
  {
    name: "Porte-clé MAS'LIVE",
    description: "Porte-clé en acier inoxydable avec gravure MAS'LIVE. Compact et élégant.",
    category: 'porteclé',
    price: 9.99,
    imageUrl: '',
    stock: 200,
    isActive: true,
    sku: 'PORTECLE-001',
    tags: ['porte-clé', 'accessoire', 'acier'],
    metadata: {},
  },
  {
    name: "Bandana MAS'LIVE",
    description: "Bandana coloré multi-usage avec motif MAS'LIVE. Parfait pour le trail et les sports outdoor.",
    category: 'bandana',
    price: 14.99,
    imageUrl: '',
    stock: 120,
    isActive: true,
    sku: 'BANDANA-001',
    tags: ['bandana', 'accessoire', 'outdoor', 'sport'],
    metadata: {},
  },
];

async function listArticles() {
  const snap = await db.collection('superadmin_articles').get();
  console.log(`\n📦 superadmin_articles: ${snap.size} document(s)`);
  snap.forEach((doc) => {
    const d = doc.data() || {};
    console.log(`- ${doc.id} | ${d.name || '(no name)'} | ${d.category || '-'} | active=${d.isActive} | stock=${d.stock}`);
  });
  return snap.size;
}

async function initIfEmpty() {
  const count = await listArticles();
  if (count > 0) {
    console.log('\n✅ Déjà initialisé (rien à faire).');
    return;
  }

  console.log('\n⚠️ Aucun article trouvé. Initialisation des 4 articles...');

  const batch = db.batch();
  for (const article of ARTICLES) {
    const ref = db.collection('superadmin_articles').doc();
    batch.set(ref, {
      ...article,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  await batch.commit();
  console.log('✅ Initialisation OK.');

  await listArticles();
}

initIfEmpty()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('\n❌ Erreur:', err);
    process.exit(1);
  });
