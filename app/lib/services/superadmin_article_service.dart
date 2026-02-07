import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;
import '../models/superadmin_article.dart';

/// Service pour gérer les articles du superadmin
class SuperadminArticleService {
  static final SuperadminArticleService _instance = SuperadminArticleService._internal();

  factory SuperadminArticleService() {
    return _instance;
  }

  SuperadminArticleService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'superadmin_articles';

  /// Catégories valides
  static const List<String> validCategories = ['casquette', 'tshirt', 'porteclé', 'bandana'];

  /// Créer un nouvel article
  Future<SuperadminArticle> createArticle({
    required String name,
    required String description,
    required String category,
    required double price,
    required String imageUrl,
    required int stock,
    String? sku,
    List<String> tags = const [],
    Map<String, dynamic>? metadata,
  }) async {
    if (!validCategories.contains(category)) {
      throw Exception('Catégorie invalide: $category');
    }

    final now = DateTime.now();
    final data = {
      'name': name,
      'description': description,
      'category': category,
      'price': price,
      'imageUrl': imageUrl,
      'stock': stock,
      'isActive': true,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      'sku': sku,
      'tags': tags,
      'metadata': metadata,
    };

    final docRef = await _firestore.collection(_collectionName).add(data);
    
    return SuperadminArticle(
      id: docRef.id,
      name: name,
      description: description,
      category: category,
      price: price,
      imageUrl: imageUrl,
      stock: stock,
      isActive: true,
      createdAt: now,
      updatedAt: now,
      sku: sku,
      tags: tags,
      metadata: metadata,
    );
  }

  /// Récupérer un article par ID
  Future<SuperadminArticle?> getArticle(String id) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(id).get();
      if (!doc.exists) return null;
      return SuperadminArticle.fromMap(doc.data() ?? {}, doc.id);
    } catch (e) {
      developer.log('Erreur lors de la récupération de l\'article: $e');
      return null;
    }
  }

  /// Récupérer tous les articles
  Future<List<SuperadminArticle>> getAllArticles() async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .orderBy('createdAt', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => SuperadminArticle.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      developer.log('Erreur lors de la récupération des articles: $e');
      return [];
    }
  }

  /// Récupérer les articles actifs par catégorie
  Future<List<SuperadminArticle>> getArticlesByCategory(String category) async {
    if (!validCategories.contains(category)) {
      throw Exception('Catégorie invalide: $category');
    }

    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('category', isEqualTo: category)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => SuperadminArticle.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      developer.log('Erreur lors de la récupération des articles de catégorie: $e');
      return [];
    }
  }

  /// Stream d'articles actifs avec filtrage optionnel
  Stream<List<SuperadminArticle>> streamActiveArticles({String? category}) {
    Query query = _firestore
        .collection(_collectionName)
        .where('isActive', isEqualTo: true);
    
    if (category != null && validCategories.contains(category)) {
      query = query.where('category', isEqualTo: category);
    }

    query = query.orderBy('updatedAt', descending: true);

    return query.snapshots().map((snapshot) =>
        snapshot.docs
            .map((doc) => SuperadminArticle.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  /// Mettre à jour un article
  Future<void> updateArticle(String id, SuperadminArticle article) async {
    try {
      final data = article.toMap();
      data['updatedAt'] = Timestamp.fromDate(DateTime.now());
      
      await _firestore.collection(_collectionName).doc(id).update(data);
    } catch (e) {
      developer.log('Erreur lors de la mise à jour de l\'article: $e');
      rethrow;
    }
  }

  /// Mettre à jour le stock d'un article
  Future<void> updateStock(String id, int newStock) async {
    try {
      await _firestore.collection(_collectionName).doc(id).update({
        'stock': newStock,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      developer.log('Erreur lors de la mise à jour du stock: $e');
      rethrow;
    }
  }

  /// Activer/désactiver un article
  Future<void> toggleArticleStatus(String id, bool isActive) async {
    try {
      await _firestore.collection(_collectionName).doc(id).update({
        'isActive': isActive,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      developer.log('Erreur lors du changement de statut: $e');
      rethrow;
    }
  }

  /// Supprimer un article
  Future<void> deleteArticle(String id) async {
    try {
      await _firestore.collection(_collectionName).doc(id).delete();
    } catch (e) {
      developer.log('Erreur lors de la suppression de l\'article: $e');
      rethrow;
    }
  }

  /// Récupérer les statistiques
  Future<Map<String, int>> getArticleStats() async {
    try {
      final allArticles = await getAllArticles();
      
      final stats = <String, int>{};
      for (final category in validCategories) {
        stats[category] = allArticles.where((a) => a.category == category && a.isActive).length;
      }
      stats['total'] = allArticles.where((a) => a.isActive).length;
      
      return stats;
    } catch (e) {
      developer.log('Erreur lors de la récupération des stats: $e');
      return {};
    }
  }
}
