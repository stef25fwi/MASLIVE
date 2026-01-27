const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function addCapblackProduct() {
  try {
    const docRef = await db.collection('products').add({
      title: 'Casquette MASLIVE',
      category: 'Casquettes',
      priceCents: 1500, // 15€
      imagePath: 'assets/shop/capblack1.png',
      imageUrl: '',
      imageUrl2: '',
      description: 'Casquette noire MASLIVE Premium',
      availableSizes: ['One Size'],
      availableColors: ['Noir'],
      stockByVariant: {
        'One Size|Noir': 50,
      },
      moderationStatus: 'approved',
      isActive: true,
      groupId: 'maslive_official',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log('✅ Casquette ajoutée avec succès!');
    console.log('Document ID:', docRef.id);
    process.exit(0);
  } catch (error) {
    console.error('❌ Erreur:', error);
    process.exit(1);
  }
}

addCapblackProduct();
