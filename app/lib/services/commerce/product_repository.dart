import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/group_product.dart';

/// Repository centralisé pour la gestion des produits (CRUD + stock)
/// 
/// Sources de vérité:
/// - Root collection: `/products` (admin + recherche globale)
/// - Miroir boutique: `/shops/{shopId}/products` (compatibilité existante)
/// 
/// Transactions de stock:
/// - updateStock() utilise FieldValue.increment() en transaction
/// - alertQty/stockStatus auto-mis à jour si présents dans le produit
class ProductRepository {
  static final ProductRepository instance = ProductRepository._internal();
  ProductRepository._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== STREAM ====================

  /// Stream de tous les produits d'une boutique (actifs uniquement)
  Stream<List<GroupProduct>> streamProducts({
    required String shopId,
    bool activeOnly = true,
    String? categoryId,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('shops')
        .doc(shopId)
        .collection('products');

    if (activeOnly) {
      query = query.where('isActive', isEqualTo: true);
    }

    if (categoryId != null && categoryId.isNotEmpty) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }

    return query
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) {
            try {
              return GroupProduct.fromMap(doc.id, doc.data());
            } catch (e) {
              return null;
            }
          })
          .whereType<GroupProduct>()
          .toList();
    });
  }

  /// Stream de tous les produits globaux (recherche admin)
  Stream<List<GroupProduct>> streamGlobalProducts({
    String? groupId,
    bool activeOnly = true,
    String? moderationStatus,
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection('products');

    if (groupId != null && groupId.isNotEmpty) {
      query = query.where('groupId', isEqualTo: groupId);
    }

    if (activeOnly) {
      query = query.where('isActive', isEqualTo: true);
    }

    if (moderationStatus != null && moderationStatus.isNotEmpty) {
      query = query.where('moderationStatus', isEqualTo: moderationStatus);
    }

    return query
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) {
            try {
              return GroupProduct.fromMap(doc.id, doc.data());
            } catch (e) {
              return null;
            }
          })
          .whereType<GroupProduct>()
          .toList();
    });
  }

  /// Récupère un seul produit par ID
  Future<GroupProduct?> getProduct({
    required String shopId,
    required String productId,
  }) async {
    final doc = await _firestore
        .collection('shops')
        .doc(shopId)
        .collection('products')
        .doc(productId)
        .get();

    if (!doc.exists) return null;

    try {
      return GroupProduct.fromMap(doc.id, doc.data()!);
    } catch (e) {
      return null;
    }
  }

  // ==================== CRUD ====================

  /// Crée un nouveau produit
  /// Écrit dans les 2 collections: root /products ET /shops/{shopId}/products
  Future<String> createProduct({
    required String shopId,
    required Map<String, dynamic> data,
  }) async {
    final timestamp = FieldValue.serverTimestamp();

    // Valider données minimales
    if (data['title'] == null || data['title'].toString().trim().isEmpty) {
      throw Exception('Le titre du produit est obligatoire');
    }

    if (data['priceCents'] == null || (data['priceCents'] as num) < 0) {
      throw Exception('Le prix du produit doit être >= 0');
    }

    // Générer ID unique
    final productId = _firestore.collection('products').doc().id;

    // Données enrichies
    final enrichedData = {
      ...data,
      'shopId': shopId,
      'isActive': data['isActive'] ?? true,
      'moderationStatus': data['moderationStatus'] ?? 'approved',
      'createdAt': timestamp,
      'updatedAt': timestamp,
      // Stock par défaut si non fourni
      'stock': data['stock'] ?? 0,
      'alertQty': data['alertQty'],
      'stockStatus': data['stockStatus'],
    };

    // Batch write dans les 2 collections (cohérence)
    final batch = _firestore.batch();

    // 1. Collection root /products (source de vérité globale)
    batch.set(
      _firestore.collection('products').doc(productId),
      enrichedData,
    );

    // 2. Miroir /shops/{shopId}/products (compatibilité existante)
    batch.set(
      _firestore
          .collection('shops')
          .doc(shopId)
          .collection('products')
          .doc(productId),
      enrichedData,
    );

    await batch.commit();
    return productId;
  }

  /// Met à jour un produit existant (patch partiel)
  Future<void> updateProduct({
    required String shopId,
    required String productId,
    required Map<String, dynamic> patch,
  }) async {
    final timestamp = FieldValue.serverTimestamp();

    final updateData = {
      ...patch,
      'updatedAt': timestamp,
    };

    // Batch update dans les 2 collections
    final batch = _firestore.batch();

    batch.update(
      _firestore.collection('products').doc(productId),
      updateData,
    );

    batch.update(
      _firestore
          .collection('shops')
          .doc(shopId)
          .collection('products')
          .doc(productId),
      updateData,
    );

    await batch.commit();
  }

  /// Supprime un produit (soft delete: isActive = false)
  Future<void> deleteProduct({
    required String shopId,
    required String productId,
    bool hardDelete = false,
  }) async {
    if (hardDelete) {
      // Hard delete: suppression physique des 2 documents
      final batch = _firestore.batch();

      batch.delete(_firestore.collection('products').doc(productId));
      batch.delete(
        _firestore
            .collection('shops')
            .doc(shopId)
            .collection('products')
            .doc(productId),
      );

      await batch.commit();
    } else {
      // Soft delete: marquer comme inactif
      await updateProduct(
        shopId: shopId,
        productId: productId,
        patch: {
          'isActive': false,
          'moderationStatus': 'deleted',
        },
      );
    }
  }

  // ==================== STOCK TRANSACTIONNEL ====================

  /// Met à jour le stock d'un produit de manière transactionnelle
  /// 
  /// - delta: quantité à ajouter/retirer (ex: -2 pour retirer 2 unités)
  /// - preventNegative: si true, empêche stock négatif (annule transaction)
  /// - updateAlertQty: si true, met à jour alertQty/stockStatus selon règles métier
  /// 
  /// Returns: nouveau stock après transaction
  Future<int> updateStock({
    required String shopId,
    required String productId,
    required int delta,
    bool preventNegative = true,
    bool updateAlertQty = true,
  }) async {
    // Transaction Firestore pour garantir cohérence
    return await _firestore.runTransaction<int>((transaction) async {
      // Lire les 2 refs (root + miroir)
      final rootRef = _firestore.collection('products').doc(productId);
      final shopRef = _firestore
          .collection('shops')
          .doc(shopId)
          .collection('products')
          .doc(productId);

      final rootSnap = await transaction.get(rootRef);
      final shopSnap = await transaction.get(shopRef);

      if (!rootSnap.exists || !shopSnap.exists) {
        throw Exception('Produit $productId introuvable');
      }

      final rootData = rootSnap.data()!;
      final currentStock = (rootData['stock'] as num?)?.toInt() ?? 0;
      final newStock = currentStock + delta;

      // Empêcher stock négatif si demandé
      if (preventNegative && newStock < 0) {
        throw Exception(
          'Stock insuffisant : $currentStock disponible(s), tentative de retirer ${-delta}',
        );
      }

      final updateData = <String, dynamic>{
        'stock': newStock,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Auto-update stockStatus si alertQty présent
      if (updateAlertQty) {
        final alertQty = (rootData['alertQty'] as num?)?.toInt();
        if (alertQty != null && alertQty > 0) {
          if (newStock == 0) {
            updateData['stockStatus'] = 'out_of_stock';
          } else if (newStock <= alertQty) {
            updateData['stockStatus'] = 'low_stock';
          } else {
            updateData['stockStatus'] = 'in_stock';
          }
        }
      }

      // Appliquer updates dans les 2 collections
      transaction.update(rootRef, updateData);
      transaction.update(shopRef, updateData);

      return newStock;
    });
  }

  /// Décrémente le stock de plusieurs produits (après paiement)
  /// 
  /// items: List<Map> avec keys 'productId' et 'quantity'
  /// Returns: Map<productId, newStock>
  Future<Map<String, int>> decrementStockBatch({
    required String shopId,
    required List<Map<String, dynamic>> items,
    bool preventNegative = true,
  }) async {
    final results = <String, int>{};

    // Transaction globale pour tous les produits
    await _firestore.runTransaction((transaction) async {
      // 1. Lire tous les produits
      final reads = <String, DocumentSnapshot>{};
      for (final item in items) {
        final productId = item['productId'] as String?;
        if (productId == null || productId.isEmpty) continue;

        final rootRef = _firestore.collection('products').doc(productId);
        final snap = await transaction.get(rootRef);
        reads[productId] = snap;
      }

      // 2. Calculer nouveaux stocks et valider
      final updates = <String, Map<String, dynamic>>{};
      for (final item in items) {
        final productId = item['productId'] as String?;
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;

        if (productId == null || !reads.containsKey(productId)) continue;

        final snap = reads[productId]!;
        if (!snap.exists) {
          throw Exception('Produit $productId introuvable');
        }

        final data = snap.data() as Map<String, dynamic>;
        final currentStock = (data['stock'] as num?)?.toInt() ?? 0;
        final newStock = currentStock - qty;

        if (preventNegative && newStock < 0) {
          throw Exception(
            'Stock insuffisant pour $productId : $currentStock disponible(s), demandé $qty',
          );
        }

        updates[productId] = {
          'stock': newStock,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Auto-update stockStatus
        final alertQty = (data['alertQty'] as num?)?.toInt();
        if (alertQty != null && alertQty > 0) {
          if (newStock == 0) {
            updates[productId]!['stockStatus'] = 'out_of_stock';
          } else if (newStock <= alertQty) {
            updates[productId]!['stockStatus'] = 'low_stock';
          } else {
            updates[productId]!['stockStatus'] = 'in_stock';
          }
        }

        results[productId] = newStock;
      }

      // 3. Appliquer tous les updates (root + miroir)
      for (final entry in updates.entries) {
        final productId = entry.key;
        final updateData = entry.value;

        transaction.update(
          _firestore.collection('products').doc(productId),
          updateData,
        );

        transaction.update(
          _firestore
              .collection('shops')
              .doc(shopId)
              .collection('products')
              .doc(productId),
          updateData,
        );
      }
    });

    return results;
  }

  /// Set stock absolu (non transactionnel, pour admin)
  Future<void> setStock({
    required String shopId,
    required String productId,
    required int stock,
  }) async {
    if (stock < 0) {
      throw Exception('Le stock doit être >= 0');
    }

    await updateProduct(
      shopId: shopId,
      productId: productId,
      patch: {'stock': stock},
    );
  }

  // ==================== CATÉGORIES ====================

  /// Récupère toutes les catégories distinctes d'une boutique
  Future<List<String>> getCategories({required String shopId}) async {
    final snapshot = await _firestore
        .collection('shops')
        .doc(shopId)
        .collection('products')
        .where('isActive', isEqualTo: true)
        .get();

    final categories = <String>{};
    for (final doc in snapshot.docs) {
      final categoryId = doc.data()['categoryId'] as String?;
      if (categoryId != null && categoryId.isNotEmpty) {
        categories.add(categoryId);
      }
    }

    return categories.toList()..sort();
  }

  // ==================== MODÉRATION ====================

  /// Approuve produit (admin)
  Future<void> approveProduct({
    required String shopId,
    required String productId,
  }) async {
    await updateProduct(
      shopId: shopId,
      productId: productId,
      patch: {
        'moderationStatus': 'approved',
        'isActive': true,
      },
    );
  }

  /// Rejette produit (admin)
  Future<void> rejectProduct({
    required String shopId,
    required String productId,
    String? reason,
  }) async {
    final patch = {
      'moderationStatus': 'rejected',
      'isActive': false,
    };

    if (reason != null) {
      patch['rejectionReason'] = reason;
    }

    await updateProduct(
      shopId: shopId,
      productId: productId,
      patch: patch,
    );
  }
}
