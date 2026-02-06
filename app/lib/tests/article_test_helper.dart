import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../services/storage_service.dart';

/// SCRIPT TEST: Créer article complet avec photo depuis assets
/// Objectif: Vérifier 100% fonctionnalité
/// Exécution: Run depuis main.dart ou test widget

class ArticleTestHelper {
  static final ArticleTestHelper _instance = ArticleTestHelper._internal();
  
  factory ArticleTestHelper() => _instance;
  ArticleTestHelper._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final StorageService _storage = StorageService.instance;

  /// TEST 1: Créer article avec photo depuis asset
  /// 
  /// Chemin asset: assets/images/logo_maslive.png (ou autre logo)
  /// Objectif: Tester workflow complet
  Future<Map<String, dynamic>> testCreateArticleWithAssetPhoto({
    required String assetPath,
    String articleName = 'TEST CASQUETTE MASLIVE',
    String category = 'casquette',
    double price = 29.99,
    int stock = 50,
  }) async {
    print('🧪 ========== TEST: Créer Article Depuis Asset ==========');
    print('📦 Asset: $assetPath');
    
    try {
      // Step 1: Vérifier authentification
      print('1️⃣  Vérification authentification...');
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('❌ Utilisateur non connecté');
      }
      print('   ✅ Connecté: ${user.email ?? user.uid}');

      // Step 2: Réserver un ID Firestore (sert aussi de parentId en Storage)
      print('2️⃣  Génération ID Firestore...');
      final docRef = _firestore.collection('superadmin_articles').doc();
      final articleId = docRef.id;
      print('   ✅ Article ID: $articleId');

      // Step 3: Upload image depuis asset vers Storage
      print('3️⃣  Upload image Storage (asset)...');
      final imageUrl = await _storage.uploadArticleFromAsset(
        articleId: articleId,
        assetPath: assetPath,
      );
      print('   ✅ Image uploadée: $imageUrl');

      // Step 4: Créer document Firestore avec le même ID
      print('4️⃣  Création document Firestore...');
      final now = DateTime.now();
      final articleData = {
        'name': articleName,
        'description': 'Article TEST pour vérification upload photos',
        'category': category,
        'price': price,
        'imageUrl': imageUrl,
        'stock': stock,
        'isActive': true,
        'sku': 'TEST-${DateTime.now().millisecondsSinceEpoch}',
        'tags': ['test', 'automation', 'photo-upload'],
        'metadata': {
          'testTimestamp': now.toIso8601String(),
          'assetSource': assetPath,
          'uploadSource': 'test_automation',
        },
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };

      await docRef.set(articleData);
      print('   ✅ Document créé: $articleId');

      // Step 5: Vérification
      print('5️⃣  Vérification données...');
      final createdDoc = await docRef.get();
      final createdData = createdDoc.data() ?? {};

      print('   ✅ Données vérifiées:');
      print('     - Nom: ${createdData['name']}');
      print('     - Catégorie: ${createdData['category']}');
      print('     - Prix: €${createdData['price']}');
      print('     - Stock: ${createdData['stock']}');
      print('     - Image URL: ${createdData['imageUrl']}');
      print('     - Métadonnées: ${createdData['metadata']}');

      final result = {
        'success': true,
        'articleId': articleId,
        'imageUrl': imageUrl,
        'data': createdData,
        'timestamp': now,
      };

      print('✅ ========== TEST RÉUSSI ==========\n');
      return result;
    } catch (e) {
      print('❌ ERREUR: $e\n');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// TEST 2: Vérifier intégrité article créé
  Future<bool> verifyArticleIntegrity(String articleId) async {
    print('🔍 Vérification intégrité article: $articleId');
    
    try {
      // Récupérer doc Firestore
      final doc = await _firestore
          .collection('superadmin_articles')
          .doc(articleId)
          .get();
      
      if (!doc.exists) {
        print('❌ Document introuvable');
        return false;
      }
      
      final data = doc.data() ?? {};
      
      // Vérifications
      final checks = <String, bool>{
        'Nom présent': (data['name'] as String?)?.isNotEmpty ?? false,
        'Catégorie valide': ['casquette', 'tshirt', 'porteclé', 'bandana']
            .contains(data['category']),
        'Prix valide': (data['price'] as num?) != null && (data['price'] as num) > 0,
        'Stock valide': (data['stock'] as int?) != null,
        'Image URL présente': (data['imageUrl'] as String?)?.isNotEmpty ?? false,
        'Active': data['isActive'] == true,
        'Timestamps présents': 
          data['createdAt'] != null && data['updatedAt'] != null,
      };
      
      print('📋 Résultats vérification:');
      var allPassed = true;
      for (final check in checks.entries) {
        final status = check.value ? '✅' : '❌';
        print('   $status ${check.key}');
        if (!check.value) allPassed = false;
      }
      
      if (allPassed) print('\n✅ Tous les tests passés!');
      return allPassed;
      
    } catch (e) {
      print('❌ Erreur vérification: $e');
      return false;
    }
  }

  /// TEST 3: Télécharger et vérifier image Storage
  Future<bool> verifyImageStorage(String articleId) async {
    print('🖼️  Vérification image Storage: $articleId');
    
    try {
      final storage = FirebaseStorage.instance;
      final folderRef = storage.ref('articles/$articleId/original');

      final listing = await folderRef.listAll();
      final coverItem = listing.items.where((i) => i.name.startsWith('cover.')).toList();

      if (coverItem.isEmpty) {
        print('   ❌ Aucun fichier cover.* trouvé');
        return false;
      }

      final coverRef = coverItem.first;
      final metadata = await coverRef.getMetadata();
      print('   ✅ Image existe: ${coverRef.name}');
      print('   📊 Taille: ${metadata.size} bytes');
      print('   📝 Content-Type: ${metadata.contentType}');

      final url = await coverRef.getDownloadURL();
      print('   🔗 URL: $url');
      return true;
      
    } catch (e) {
      print('❌ Erreur vérification Storage: $e');
      return false;
    }
  }

  /// TEST 4: Nettoyer article test
  Future<bool> deleteTestArticle(String articleId) async {
    print('\n🗑️  Suppression article test: $articleId');
    
    try {
      // Récupérer d'abord l'article pour voir l'image
      final doc = await _firestore
          .collection('superadmin_articles')
          .doc(articleId)
          .get();
      
      if (!doc.exists) {
        print('   ⚠️  Article inexistant');
        return true;
      }
      
      // Supprimer Firestore
      await _firestore
          .collection('superadmin_articles')
          .doc(articleId)
          .delete();
      print('   ✅ Document Firestore supprimé');
      
      // Supprimer Storage
      try {
        await _storage.deleteArticleMedia(articleId: articleId);
        print('   ✅ Dossier Storage supprimé');
      } catch (e) {
        print('   ⚠️  Erreur suppression Storage: $e (non-critique)');
      }
      
      print('✅ Article test supprimé complètement');
      return true;
      
    } catch (e) {
      print('❌ Erreur suppression: $e');
      return false;
    }
  }

  /// TEST 5: Workflow complet
  Future<void> runCompleteTestWorkflow({
    String assetPath = 'assets/images/logo_maslive.png',
    bool cleanup = false,
  }) async {
    print('\n\n🚀 ========== WORKFLOW TEST COMPLET ==========\n');
    
    try {
      // 1. Créer
      print('📌 ÉTAPE 1: Créer article avec photo asset...\n');
      final createResult = await testCreateArticleWithAssetPhoto(
        assetPath: assetPath,
        articleName: 'TEST COMPLET ${DateTime.now().millisecondsSinceEpoch}',
      );
      
      if (createResult['success'] != true) {
        print('❌ Création échouée');
        return;
      }
      
      final articleId = createResult['articleId'] as String;
      
      // 2. Vérifier intégrité
      print('\n📌 ÉTAPE 2: Vérifier intégrité...\n');
      final integrityOk = await verifyArticleIntegrity(articleId);
      
      // 3. Vérifier image Storage
      print('\n📌 ÉTAPE 3: Vérifier image Storage...\n');
      final storageOk = await verifyImageStorage(articleId);
      
      // 4. Résumé
      print('\n\n📊 ========== RÉSUMÉ FINAL ==========');
      print('✅ Article créé: $articleId');
      print('✅ Intégrité Firestore: ${integrityOk ? "OK" : "KO"}');
      print('✅ Intégrité Storage: ${storageOk ? "OK" : "KO"}');
      print('✅ WORKFLOW: ${integrityOk && storageOk ? "100% RÉUSSI" : "ÉCHEC"}');
      
      // 5. Cleanup optionnel
      if (cleanup) {
        print('\n📌 ÉTAPE 4: Nettoyage...\n');
        await deleteTestArticle(articleId);
      } else {
        print('\n📌 Article reste en BD pour inspectionmanuelle');
        print('   Supprimer via: ArticleTestHelper().deleteTestArticle(\'$articleId\')');
      }
      
      print('\n🏁 ========== FIN TEST ==========\n');
      
    } catch (e) {
      print('\n❌ ERREUR WORKFLOW: $e');
    }
  }
}

// ========== UTILISATION ==========

/// Dans main.dart ou test widget
/* 
  // Exécution simple
  await ArticleTestHelper().runCompleteTestWorkflow(
    assetPath: 'assets/images/logo_maslive.png',
    cleanup: false,  // Garder article pour inspection
  );

  // Ou test spécifique
  final result = await ArticleTestHelper().testCreateArticleWithAssetPhoto(
    assetPath: 'assets/images/casquette_test.png',
    articleName: 'Casquette TEST',
    price: 19.99,
  );
  
  if (result['success'] as bool) {
    print('✅ Article: ${result['articleId']}');
  }
*/
