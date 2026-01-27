const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function addTshirtBlackProduct() {
  try {
    const docRef = await db.collection('products').add({
      title: 'T-shirt Noir MASLIVE',
      category: 'T-shirts',
      priceCents: 2000, // 20€
      imagePath: 'assets/shop/tshirtblack.png',
      imageUrl: '',
      imageUrl2: '',
      description: 'T-shirt noir MASLIVE Premium',
      availableSizes: ['XS', 'S', 'M', 'L', 'XL', 'XXL'],
      availableColors: ['Noir'],
      stockByVariant: {
        'XS|Noir': 18,
        'S|Noir': 25,
        'M|Noir': 30,
        'L|Noir': 28,
        'XL|Noir': 20,
        'XXL|Noir': 10,
      },
      moderationStatus: 'approved',
      isActive: true,
      groupId: 'maslive_official',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log('✅ T-shirt Noir ajouté avec succès!');
    console.log('Document ID:', docRef.id);
    process.exit(0);
  } catch (error) {
    console.error('❌ Erreur:', error);
    process.exit(1);
  }
}

addTshirtBlackProduct();
