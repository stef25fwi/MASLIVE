const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function addPackChaineHanches() {
  try {
    const docRef = await db.collection('products').add({
      title: 'Pack Chaine de hanches + T-shirt frangé blanc + Bandana blanc',
      category: 'Packs',
      priceCents: 3900, // 39€
      imagePath: 'assets/shop/modelmaslivewhite2.png',
      imageUrl: '',
      imageUrl2: '',
      description: 'Pack MASLIVE : Chaine de hanches, T-shirt frangé blanc, Bandana blanc',
      availableSizes: ['XS', 'S', 'M', 'L', 'XL'],
      availableColors: ['Blanc'],
      stockByVariant: {
        'XS|Blanc': 10,
        'S|Blanc': 15,
        'M|Blanc': 20,
        'L|Blanc': 15,
        'XL|Blanc': 8,
      },
      moderationStatus: 'approved',
      isActive: true,
      groupId: 'maslive_official',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log('✅ Pack Chaine de hanches ajouté avec succès!');
    console.log('Document ID:', docRef.id);
    process.exit(0);
  } catch (error) {
    console.error('❌ Erreur:', error);
    process.exit(1);
  }
}

addPackChaineHanches();
