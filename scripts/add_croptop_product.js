const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function addCroptopProduct() {
  try {
    const docRef = await db.collection('products').add({
      title: 'Crop Top MASLIVE',
      category: 'T-shirts',
      priceCents: 1800, // 18€
      imagePath: 'assets/shop/croptopblack1.png',
      imageUrl: '',
      imageUrl2: '',
      description: 'Crop Top noir MASLIVE Premium',
      availableSizes: ['XS', 'S', 'M', 'L', 'XL'],
      availableColors: ['Noir'],
      stockByVariant: {
        'XS|Noir': 20,
        'S|Noir': 30,
        'M|Noir': 35,
        'L|Noir': 25,
        'XL|Noir': 15,
      },
      moderationStatus: 'approved',
      isActive: true,
      groupId: 'maslive_official',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log('✅ Crop Top ajouté avec succès!');
    console.log('Document ID:', docRef.id);
    process.exit(0);
  } catch (error) {
    console.error('❌ Erreur:', error);
    process.exit(1);
  }
}

addCroptopProduct();
