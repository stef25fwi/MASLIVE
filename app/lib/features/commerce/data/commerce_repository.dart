import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/commerce_models.dart';

class CommerceRepository {
  final FirebaseFirestore _db;

  CommerceRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _shopDoc(String shopId) =>
      _db.collection('shops').doc(shopId);

  CollectionReference<Map<String, dynamic>> _productsCol(String shopId) =>
      _db.collection('shops').doc(shopId).collection('products');

  CollectionReference<Map<String, dynamic>> _categoriesCol(String shopId) =>
      _db.collection('shops').doc(shopId).collection('categories');

  CollectionReference<Map<String, dynamic>> _ordersCol(String shopId) =>
      _db.collection('shops').doc(shopId).collection('orders');

  CollectionReference<Map<String, dynamic>> _mediaCol(String shopId) =>
      _db.collection('shops').doc(shopId).collection('media');

  Future<Shop?> fetchShop(String shopId) async {
    final snap = await _shopDoc(shopId).get();
    if (!snap.exists) return null;
    return Shop.fromDoc(snap);
  }

  Stream<Shop?> streamShop(String shopId) {
    return _shopDoc(shopId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return Shop.fromDoc(snap);
    });
  }

  Future<void> saveShop(Shop shop) async {
    await _shopDoc(shop.id).set(shop.toJson(), SetOptions(merge: true));
  }

  Stream<List<Category>> streamCategories(String shopId) {
    return _categoriesCol(shopId).orderBy('sortOrder').snapshots().map((snap) {
      return snap.docs.map((doc) => Category.fromDoc(doc)).toList();
    });
  }

  Stream<List<ShopMedia>> streamShopMedia(
    String shopId, {
    bool onlyVisible = true,
    String? countryCode,
    String? eventId,
    String? circuitId,
    String? photographerId,
  }) {
    Query<Map<String, dynamic>> query = _mediaCol(shopId);

    if (onlyVisible) {
      query = query.where('isVisible', isEqualTo: true);
    }
    if (countryCode != null && countryCode.isNotEmpty) {
      query = query.where('countryCode', isEqualTo: countryCode);
    }
    if (eventId != null && eventId.isNotEmpty) {
      query = query.where('eventId', isEqualTo: eventId);
    }
    if (circuitId != null && circuitId.isNotEmpty) {
      query = query.where('circuitId', isEqualTo: circuitId);
    }
    if (photographerId != null && photographerId.isNotEmpty) {
      query = query.where('photographerId', isEqualTo: photographerId);
    }

    query = query.orderBy('takenAt', descending: true);

    return query.snapshots().map((snap) {
      return snap.docs.map(ShopMedia.fromDoc).toList();
    });
  }

  Stream<List<Product>> streamProducts(
    String shopId,
    ProductFilter filter,
    String searchText,
  ) {
    Query<Map<String, dynamic>> query = _productsCol(shopId);

    if (filter.onlyActive != null) {
      query = query.where('isActive', isEqualTo: filter.onlyActive);
    }
    if (filter.categoryId != null && filter.categoryId!.isNotEmpty) {
      query = query.where('categoryId', isEqualTo: filter.categoryId);
    }
    if (filter.stockStatus != null && filter.stockStatus!.isNotEmpty) {
      query = query.where('stockStatus', isEqualTo: filter.stockStatus);
    }
    if (filter.country != null && filter.country!.isNotEmpty) {
      query = query.where('country', isEqualTo: filter.country);
    }
    if (filter.event != null && filter.event!.isNotEmpty) {
      query = query.where('event', isEqualTo: filter.event);
    }
    if (filter.circuit != null && filter.circuit!.isNotEmpty) {
      query = query.where('circuit', isEqualTo: filter.circuit);
    }

    query = query.orderBy('updatedAt', descending: true);

    final token = _firstToken(searchText);
    if (token != null && token.isNotEmpty) {
      query = query.where('searchTokens', arrayContains: token);
    }

    return query.snapshots().map((snap) {
      final list = snap.docs.map((doc) => Product.fromDoc(doc)).toList();
      return list.where((product) {
        if (filter.minPrice != null && product.price < filter.minPrice!) {
          return false;
        }
        if (filter.maxPrice != null && product.price > filter.maxPrice!) {
          return false;
        }
        if (filter.tag != null && filter.tag!.isNotEmpty) {
          final loweredTag = filter.tag!.toLowerCase().trim();
          if (!product.tags
              .map((tag) => tag.toLowerCase())
              .contains(loweredTag)) {
            return false;
          }
        }
        return true;
      }).toList();
    });
  }

  Future<String> createMedia(String shopId, ShopMedia media) async {
    final now = DateTime.now();
    final doc = _mediaCol(shopId).doc();

    final payload = media.copyWith(
      id: doc.id,
      shopId: shopId,
      createdAt: now,
      updatedAt: now,
    );

    await doc.set(payload.toJson());
    return doc.id;
  }

  Future<void> updateMedia(String shopId, ShopMedia media) async {
    final payload = media.copyWith(updatedAt: DateTime.now());
    await _mediaCol(shopId).doc(media.id).update(payload.toJson());
  }

  Future<void> deleteMedia(String shopId, String mediaId) async {
    await _mediaCol(shopId).doc(mediaId).delete();
  }

  Future<String> createProduct(String shopId, Product product) async {
    final now = DateTime.now();
    final doc = _productsCol(shopId).doc();
    final computed = computeStockStatus(
      product.stockQty,
      product.stockAlertQty,
    );

    final payload = product.copyWith(
      id: doc.id,
      createdAt: now,
      updatedAt: now,
      stockStatus: computed,
      searchTokens: _buildSearchTokens(product.name, product.tags),
    );

    await doc.set(payload.toJson());
    return doc.id;
  }

  Future<void> updateProduct(String shopId, Product product) async {
    final computed = computeStockStatus(
      product.stockQty,
      product.stockAlertQty,
    );

    final payload = product.copyWith(
      updatedAt: DateTime.now(),
      stockStatus: computed,
      searchTokens: _buildSearchTokens(product.name, product.tags),
    );

    await _productsCol(shopId).doc(product.id).update(payload.toJson());
  }

  Future<void> setActive(String shopId, String productId, bool isActive) async {
    await _productsCol(shopId).doc(productId).update({
      'isActive': isActive,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> deleteProduct(String shopId, String productId) async {
    await _productsCol(shopId).doc(productId).delete();
  }

  Future<String> duplicateProduct(
    String shopId,
    Product product, {
    bool keepImages = true,
  }) async {
    final now = DateTime.now();
    final newDoc = _productsCol(shopId).doc();
    final images = keepImages ? product.images : <ProductImage>[];
    final mainUrl = keepImages ? product.mainImageUrl : null;

    final copied = product.copyWith(
      id: newDoc.id,
      name: '${product.name} (copie)',
      createdAt: now,
      updatedAt: now,
      images: images,
      imageCount: images.length,
      mainImageUrl: mainUrl,
      searchTokens: _buildSearchTokens('${product.name} copie', product.tags),
    );

    await newDoc.set(copied.toJson());
    return newDoc.id;
  }

  Future<void> adjustStock(String shopId, String productId, int delta) async {
    final ref = _productsCol(shopId).doc(productId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Produit introuvable');

      final data = snap.data() ?? {};
      final qty = (data['stockQty'] ?? 0) as int;
      final alert = (data['stockAlertQty'] ?? 3) as int;

      final next = qty + delta;
      if (next < 0) throw Exception('Stock insuffisant');

      tx.update(ref, {
        'stockQty': next,
        'stockStatus': computeStockStatus(next, alert),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    });
  }

  Future<String> checkoutCreateOrder({
    required String shopId,
    required String userId,
    required List<CartItem> items,
  }) async {
    final orderRef = _ordersCol(shopId).doc();
    final now = DateTime.now();

    await _db.runTransaction((tx) async {
      for (final item in items) {
        final prodRef = _productsCol(shopId).doc(item.product.id);
        final prodSnap = await tx.get(prodRef);
        if (!prodSnap.exists) {
          throw Exception('Produit introuvable');
        }

        final data = prodSnap.data() ?? {};
        final qty = (data['stockQty'] ?? 0) as int;
        final alert = (data['stockAlertQty'] ?? 3) as int;

        if (qty < item.qty) {
          throw Exception('Stock insuffisant pour ${item.product.name}');
        }

        final next = qty - item.qty;
        tx.update(prodRef, {
          'stockQty': next,
          'stockStatus': computeStockStatus(next, alert),
          'updatedAt': Timestamp.fromDate(now),
        });
      }

      final total = items.fold<double>(
        0,
        (sum, item) => sum + (item.product.price * item.qty),
      );

      tx.set(orderRef, {
        'status': 'created',
        'userId': userId,
        'items': items.map((item) => item.toJson()).toList(),
        'total': total,
        'currency': items.isNotEmpty ? items.first.product.currency : 'EUR',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });
    });

    return orderRef.id;
  }

  static String computeStockStatus(int stockQty, int alertQty) {
    if (stockQty <= 0) return 'out';
    if (stockQty <= alertQty) return 'low';
    return 'ok';
  }

  static List<String> _buildSearchTokens(String name, List<String> tags) {
    final tokens = <String>{};

    void addAll(String value) {
      final parts = value
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9àâçéèêëîïôûùüÿñæœ\s-]'), ' ')
          .split(RegExp(r'\s+'))
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList();
      for (final word in parts) {
        if (word.length >= 2) {
          tokens.add(word);
        }
      }
    }

    addAll(name);
    for (final tag in tags) {
      addAll(tag);
    }
    return tokens.toList();
  }

  static String? _firstToken(String searchText) {
    final lowered = searchText.trim().toLowerCase();
    if (lowered.isEmpty) return null;
    final parts = lowered
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;
    return parts.first;
  }
}
