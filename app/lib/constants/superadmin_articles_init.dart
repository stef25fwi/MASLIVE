/// Données d'initialisation pour les articles superadmin
/// 
/// Cet objet contient les articles de base (casquette, t-shirt, porteclé, bandana)
/// qui seront pré-créés dans Firestore lors de la première utilisation
library;

const List<Map<String, dynamic>> SUPERADMIN_ARTICLES_INIT_DATA = [
  {
    'name': 'Casquette MAS\'LIVE',
    'description': 'Casquette officiellement siglée MAS\'LIVE. Tissu respirant, ajustable.',
    'category': 'casquette',
    'price': 19.99,
    'imageUrl': '', // À remplir avec URL réelle
    'stock': 100,
    'isActive': true,
    'sku': 'CASQUETTE-001',
    'tags': ['casquette', 'accessoire', 'outdoor'],
  },
  {
    'name': 'T-shirt MAS\'LIVE',
    'description': 'T-shirt 100% coton de qualité premium avec logo MAS\'LIVE. Confortable et durable.',
    'category': 'tshirt',
    'price': 24.99,
    'imageUrl': '', // À remplir avec URL réelle
    'stock': 150,
    'isActive': true,
    'sku': 'TSHIRT-001',
    'tags': ['t-shirt', 'vêtement', 'coton'],
  },
  {
    'name': 'Porte-clé MAS\'LIVE',
    'description': 'Porte-clé en acier inoxydable avec gravure MAS\'LIVE. Compact et élégant.',
    'category': 'porteclé',
    'price': 9.99,
    'imageUrl': '', // À remplir avec URL réelle
    'stock': 200,
    'isActive': true,
    'sku': 'PORTECLE-001',
    'tags': ['porte-clé', 'accessoire', 'acier'],
  },
  {
    'name': 'Bandana MAS\'LIVE',
    'description': 'Bandana coloré multi-usage avec motif MAS\'LIVE. Parfait pour le trail et les sports outdoor.',
    'category': 'bandana',
    'price': 14.99,
    'imageUrl': '', // À remplir avec URL réelle
    'stock': 120,
    'isActive': true,
    'sku': 'BANDANA-001',
    'tags': ['bandana', 'accessoire', 'outdoor', 'sport'],
  },
];

/// Fonction pour initialiser les articles superadmin
/// À appeler une seule fois lors du premier setup
///
/// Usage dans Cloud Functions:
/// ```dart
/// exports.initSuperadminArticles = onCall(async (request) => {
///   const db = admin.firestore();
///   const batch = db.batch();
///   
///   for (const article of SUPERADMIN_ARTICLES_INIT_DATA) {
///     const ref = db.collection('superadmin_articles').doc();
///     batch.set(ref, {
///       ...article,
///       createdAt: admin.firestore.FieldValue.serverTimestamp(),
///       updatedAt: admin.firestore.FieldValue.serverTimestamp(),
///     });
///   }
///   
///   await batch.commit();
///   return { success: true };
/// });
/// ```
