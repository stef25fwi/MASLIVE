const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function addCroptopFrangeProduct() {
  try {
    const docRef = await db.collection('products').add({
      title: 'Crop Top Frangé MASLIVE',
      category: 'T-shirts',
      priceCents: 1900, // 19€
      imagePath: 'assets/shop/croptopblackfrange1.png',
      imageUrl: '',
      imageUrl2: '',
      description: 'Crop Top noir frangé MASLIVE Premium',
      availableSizes: ['XS', 'S', 'M', 'L', 'XL'],
      availableColors: ['Noir'],
      stockByVariant: {
        'XS|Noir': 15,
        'S|Noir': 25,
        'M|Noir': 30,
        'L|Noir': 20,
        'XL|Noir': 12,
      },
      moderationStatus: 'approved',
      isActive: true,
      groupId: 'maslive_official',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log('✅ Crop Top Frangé ajouté avec succès!');
    console.log('Document ID:', docRef.id);
    process.exit(0);
  } catch (error) {
    console.error('❌ Erreur:', error);
    process.exit(1);
  }
}

addCroptopFrangeProduct();
