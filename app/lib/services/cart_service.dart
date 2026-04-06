import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/cart_item_model.dart';
import '../models/product_model.dart';
import '../utils/cart_constants.dart';
import '../utils/cart_extensions.dart';

class CartService extends ChangeNotifier {
  CartService._({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestoreOverride = firestore,
       _authOverride = auth;

  static final CartService instance = CartService._();

  // Lazy: construit sans accéder Firebase, évite crash avant initializeApp().
  final FirebaseFirestore? _firestoreOverride;
  final FirebaseAuth? _authOverride;
  FirebaseFirestore get _firestore => _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  final List<CartItemModel> _items = <CartItemModel>[];
  final List<CartItemModel> _anonymousItems = <CartItemModel>[];
  final Set<String> _migratedUids = <String>{};

  StreamSubscription<User?>? _authSub;
  StreamSubscription<List<CartItemModel>>? _cartSub;

  String? _uid;
  bool _started = false;
  bool loading = false;
  Object? error;

  List<CartItemModel> get unifiedItems => List<CartItemModel>.unmodifiable(_items);

  List<CartItemModel> get merchUnifiedItems => unifiedItems.byType(CartItemType.merch);

  List<CartItemModel> get mediaUnifiedItems => unifiedItems.byType(CartItemType.media);

  List<CartItem> get items =>
      merchUnifiedItems.map(_toLegacyMerchItem).toList(growable: false);

  int get totalCents => merchUnifiedItems.fold<int>(
        0,
        (total, item) => total + (item.unitPrice * 100).round() * item.safeQuantity,
      );

  String get totalLabel => '€${(totalCents / 100).toStringAsFixed(0)}';

  String? get currentUid => _uid;

  void start() {
    if (_started) return;
    // Firebase pas encore initialisé → on retente lors du prochain rebuild.
    if (Firebase.apps.isEmpty) return;
    _started = true;
    _authSub = _auth.authStateChanges().listen(_handleAuthStateChanged);
    unawaited(_handleAuthStateChanged(_auth.currentUser));
  }

  Future<void> init(String uid) async {
    start();
    if (_auth.currentUser?.uid == uid && _uid != uid) {
      await _handleAuthStateChanged(_auth.currentUser);
    }
  }

  Stream<List<CartItemModel>> watchCartItems(String uid) {
    return _cartCollection(uid).snapshots().map((snapshot) {
      final items = snapshot.docs
          .map(CartItemModel.fromDocument)
          .toList(growable: false)
        ..sort(_sortCartItems);
      return items;
    });
  }

  Future<void> addCartItem(CartItemModel item) async {
    start();
    final uid = _uid;
    if (uid == null) {
      _upsertLocalAnonymousItem(item);
      return;
    }
    await addItem(uid, item);
  }

  Future<void> removeCartItem(String cartItemId) async {
    start();
    final uid = _uid;
    if (uid == null) {
      _anonymousItems.removeWhere((item) => item.id == cartItemId);
      _items
        ..clear()
        ..addAll(_anonymousItems);
      notifyListeners();
      return;
    }
    await removeItem(uid, cartItemId);
  }

  Future<void> updateCartItemQuantity(String cartItemId, int quantity) async {
    start();
    final uid = _uid;
    if (uid == null) {
      _updateLocalAnonymousQuantity(cartItemId, quantity);
      return;
    }
    await updateQuantity(uid, cartItemId, quantity);
  }

  Future<void> incrementCartItem(String cartItemId) async {
    await incrementQuantity(_uid ?? '', cartItemId);
  }

  Future<void> decrementCartItem(String cartItemId) async {
    await decrementQuantity(_uid ?? '', cartItemId);
  }

  Future<void> clearCart() async {
    start();
    final uid = _uid;
    if (uid == null) {
      _anonymousItems.clear();
      _items.clear();
      notifyListeners();
      return;
    }
    await clearCartRemote(uid);
  }

  Future<void> clearItemsByType(CartItemType type) async {
    start();
    final uid = _uid;
    if (uid == null) {
      _anonymousItems.removeWhere((item) => item.itemType == type);
      _items
        ..clear()
        ..addAll(_anonymousItems);
      notifyListeners();
      return;
    }
    await clearItemsByTypeRemote(uid, type);
  }

  Future<void> addItem(String uid, CartItemModel item) async {
    final normalized = _normalizeCartItem(item);
    final cartItemId = _resolveCartItemId(normalized);
    final ref = _cartCollection(uid).doc(cartItemId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (snapshot.exists) {
        final existing = CartItemModel.fromMap(
          snapshot.data() ?? const <String, dynamic>{},
          id: snapshot.id,
        );
        final merged = _mergeExistingItem(existing, normalized).copyWith(id: cartItemId);
        transaction.set(ref, _buildFirestorePayload(merged, preserveCreatedAt: true));
        return;
      }

      transaction.set(
        ref,
        _buildFirestorePayload(normalized.copyWith(id: cartItemId)),
      );
    });
  }

  Future<void> removeItem(String uid, String cartItemId) async {
    await _cartCollection(uid).doc(cartItemId).delete();
  }

  Future<void> updateQuantity(String uid, String cartItemId, int quantity) async {
    if (uid.isEmpty) {
      _updateLocalAnonymousQuantity(cartItemId, quantity);
      return;
    }

    if (quantity <= 0) {
      await removeItem(uid, cartItemId);
      return;
    }

    final ref = _cartCollection(uid).doc(cartItemId);
    final snapshot = await ref.get();
    if (!snapshot.exists) return;

    final item = CartItemModel.fromMap(snapshot.data() ?? const <String, dynamic>{}, id: snapshot.id);
    final safeQuantity = item.canAdjustQuantity ? quantity.clamp(1, 999) : 1;
    await ref.set(
      <String, dynamic>{
        'quantity': safeQuantity,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> clearCartRemote(String uid) async {
    final batch = _firestore.batch();
    final snapshot = await _cartCollection(uid).get();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> clearItemsByTypeRemote(String uid, CartItemType type) async {
    final batch = _firestore.batch();
    final snapshot = await _cartCollection(uid)
        .where('itemType', isEqualTo: type.name)
        .get();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> incrementQuantity(String uid, String cartItemId) async {
    final current = unifiedItems.firstWhere(
      (item) => item.id == cartItemId,
      orElse: () => const CartItemModel(
        id: '',
        itemType: CartItemType.merch,
        productId: '',
        sellerId: '',
        eventId: '',
        title: '',
        imageUrl: '',
        unitPrice: 0,
        quantity: 1,
        currency: 'EUR',
        isDigital: false,
        requiresShipping: false,
      ),
    );
    if (current.id.isEmpty) return;
    await updateQuantity(uid, cartItemId, current.safeQuantity + 1);
  }

  Future<void> decrementQuantity(String uid, String cartItemId) async {
    final current = unifiedItems.firstWhere(
      (item) => item.id == cartItemId,
      orElse: () => const CartItemModel(
        id: '',
        itemType: CartItemType.merch,
        productId: '',
        sellerId: '',
        eventId: '',
        title: '',
        imageUrl: '',
        unitPrice: 0,
        quantity: 1,
        currency: 'EUR',
        isDigital: false,
        requiresShipping: false,
      ),
    );
    if (current.id.isEmpty) return;
    await updateQuantity(uid, cartItemId, current.safeQuantity - 1);
  }

  Future<void> migrateLegacyCartsToUnifiedCart(String uid) async {
    if (uid.isEmpty || _migratedUids.contains(uid)) return;

    try {
      await _migrateLegacyMerchCollection(uid, CartConstants.legacyMerchCartCollection);
      await _migrateLegacyMerchCollection(uid, CartConstants.legacyMerchNamedCollection);
      await _migrateLegacyMediaCollection(uid, CartConstants.legacyMediaNamedCollection);
      await _migrateLegacyMediaDocument(uid);
      _migratedUids.add(uid);
    } catch (err, stackTrace) {
      debugPrint('Cart migration failed for $uid: $err');
      debugPrintStack(stackTrace: stackTrace);
      error = err;
      notifyListeners();
    }
  }

  void addProduct({
    required String groupId,
    required GroupProduct product,
    required String size,
    required String color,
    int quantity = 1,
  }) {
    unawaited(
      addCartItem(
        CartItemModel(
          id: '',
          itemType: CartItemType.merch,
          productId: product.id,
          sellerId: '',
          eventId: '',
          title: product.title,
          subtitle: '$size - $color',
          imageUrl: product.imagePath?.trim().isNotEmpty == true
              ? product.imagePath!.trim()
              : product.imageUrl,
          unitPrice: product.priceCents / 100,
          quantity: quantity,
          currency: 'EUR',
          isDigital: false,
          requiresShipping: true,
          sourceType: CartConstants.merchSourceType,
          metadata: <String, dynamic>{
            'groupId': groupId,
            'size': size,
            'color': color,
            if (product.category.trim().isNotEmpty) 'category': product.category,
            if (product.imagePath?.trim().isNotEmpty == true)
              'imagePath': product.imagePath!.trim(),
          },
        ),
      ),
    );
  }

  void addItemFromFields({
    required String groupId,
    required String productId,
    required String title,
    required int priceCents,
    String imageUrl = '',
    String? imagePath,
    String size = 'M',
    String color = 'Noir',
    int quantity = 1,
  }) {
    unawaited(
      addCartItem(
        CartItemModel(
          id: '',
          itemType: CartItemType.merch,
          productId: productId,
          sellerId: '',
          eventId: '',
          title: title,
          subtitle: '$size - $color',
          imageUrl: (imagePath ?? '').trim().isNotEmpty ? imagePath!.trim() : imageUrl,
          unitPrice: priceCents / 100,
          quantity: quantity,
          currency: 'EUR',
          isDigital: false,
          requiresShipping: true,
          sourceType: CartConstants.merchSourceType,
          metadata: <String, dynamic>{
            'groupId': groupId,
            'size': size,
            'color': color,
            if ((imagePath ?? '').trim().isNotEmpty) 'imagePath': imagePath!.trim(),
          },
        ),
      ),
    );
  }

  void removeKey(String key) {
    final item = merchUnifiedItems.firstWhere(
      (entry) => _legacyKeyForMerchItem(entry) == key,
      orElse: () => const CartItemModel(
        id: '',
        itemType: CartItemType.merch,
        productId: '',
        sellerId: '',
        eventId: '',
        title: '',
        imageUrl: '',
        unitPrice: 0,
        quantity: 1,
        currency: 'EUR',
        isDigital: false,
        requiresShipping: false,
      ),
    );
    if (item.id.isEmpty) return;
    unawaited(removeCartItem(item.id));
  }

  void setQuantity(String key, int quantity) {
    final item = merchUnifiedItems.firstWhere(
      (entry) => _legacyKeyForMerchItem(entry) == key,
      orElse: () => const CartItemModel(
        id: '',
        itemType: CartItemType.merch,
        productId: '',
        sellerId: '',
        eventId: '',
        title: '',
        imageUrl: '',
        unitPrice: 0,
        quantity: 1,
        currency: 'EUR',
        isDigital: false,
        requiresShipping: false,
      ),
    );
    if (item.id.isEmpty) return;
    unawaited(updateCartItemQuantity(item.id, quantity));
  }

  void clear() {
    unawaited(clearItemsByType(CartItemType.merch));
  }

  CollectionReference<Map<String, dynamic>> _cartCollection(String uid) {
    return _firestore
        .collection(CartConstants.userCollection)
        .doc(uid)
        .collection(CartConstants.unifiedCartCollection);
  }

  Future<void> _handleAuthStateChanged(User? user) async {
    await _cartSub?.cancel();
    _cartSub = null;

    if (user == null) {
      _uid = null;
      error = null;
      loading = false;
      _items
        ..clear()
        ..addAll(_anonymousItems);
      notifyListeners();
      return;
    }

    _uid = user.uid;
    error = null;
    loading = true;
    notifyListeners();

    await migrateLegacyCartsToUnifiedCart(user.uid);

    if (_anonymousItems.isNotEmpty) {
      final pending = List<CartItemModel>.from(_anonymousItems);
      _anonymousItems.clear();
      for (final item in pending) {
        await addItem(user.uid, item);
      }
    }

    _cartSub = watchCartItems(user.uid).listen(
      (items) {
        _items
          ..clear()
          ..addAll(items);
        loading = false;
        error = null;
        notifyListeners();
      },
      onError: (Object err, StackTrace stackTrace) {
        debugPrint('Cart watch error: $err');
        debugPrintStack(stackTrace: stackTrace);
        loading = false;
        error = err;
        notifyListeners();
      },
    );
  }

  void _upsertLocalAnonymousItem(CartItemModel item) {
    final normalized = _normalizeCartItem(item);
    final cartItemId = _resolveCartItemId(normalized);
    final index = _anonymousItems.indexWhere((entry) => entry.id == cartItemId);
    if (index >= 0) {
      _anonymousItems[index] = _mergeExistingItem(
        _anonymousItems[index],
        normalized.copyWith(id: cartItemId),
      );
    } else {
      _anonymousItems.add(normalized.copyWith(id: cartItemId));
    }
    _items
      ..clear()
      ..addAll(_anonymousItems);
    notifyListeners();
  }

  void _updateLocalAnonymousQuantity(String cartItemId, int quantity) {
    final index = _anonymousItems.indexWhere((item) => item.id == cartItemId);
    if (index < 0) return;
    if (quantity <= 0) {
      _anonymousItems.removeAt(index);
    } else {
      final current = _anonymousItems[index];
      _anonymousItems[index] = current.copyWith(
        quantity: current.canAdjustQuantity ? quantity.clamp(1, 999) : 1,
        updatedAt: DateTime.now(),
      );
    }
    _items
      ..clear()
      ..addAll(_anonymousItems);
    notifyListeners();
  }

  CartItemModel _normalizeCartItem(CartItemModel item) {
    final normalizedQuantity = item.canAdjustQuantity ? item.safeQuantity : 1;
    return item.copyWith(
      title: item.title.trim().isEmpty ? 'Article' : item.title.trim(),
      subtitle: item.subtitle?.trim(),
      imageUrl: item.imageUrl.trim(),
      unitPrice: item.unitPrice < 0 ? 0 : item.unitPrice,
      quantity: normalizedQuantity,
      currency: item.currency.trim().isEmpty ? 'EUR' : item.currency.trim().toUpperCase(),
      eventId: item.eventId.trim(),
      sellerId: item.sellerId.trim(),
      productId: item.productId.trim(),
      sourceType: item.sourceType?.trim(),
      metadata: item.metadata == null ? null : Map<String, dynamic>.from(item.metadata!),
      createdAt: item.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  CartItemModel _mergeExistingItem(CartItemModel existing, CartItemModel incoming) {
    final mergedQuantity = existing.canAdjustQuantity
        ? (existing.safeQuantity + incoming.safeQuantity).clamp(1, 999)
        : 1;
    return existing.copyWith(
      title: incoming.title,
      subtitle: incoming.subtitle,
      imageUrl: incoming.imageUrl.isEmpty ? existing.imageUrl : incoming.imageUrl,
      unitPrice: incoming.unitPrice,
      quantity: mergedQuantity,
      currency: incoming.currency,
      isDigital: incoming.isDigital,
      requiresShipping: incoming.requiresShipping,
      sourceType: incoming.sourceType,
      metadata: incoming.metadata ?? existing.metadata,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> _buildFirestorePayload(
    CartItemModel item, {
    bool preserveCreatedAt = false,
  }) {
    final data = item.toMap();
    data['id'] = item.id;
    data['createdAt'] = preserveCreatedAt && item.createdAt != null
        ? Timestamp.fromDate(item.createdAt!)
        : FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    return data;
  }

  Future<void> _migrateLegacyMerchCollection(String uid, String collectionName) async {
    final snapshot = await _firestore
        .collection(CartConstants.userCollection)
        .doc(uid)
        .collection(collectionName)
        .get();
    for (final doc in snapshot.docs) {
      final item = _legacyMerchItemFromMap(doc.id, doc.data());
      if (item == null) continue;
      await _writeMigratedItemIfMissing(uid, item);
    }
  }

  Future<void> _migrateLegacyMediaCollection(String uid, String collectionName) async {
    final snapshot = await _firestore
        .collection(CartConstants.userCollection)
        .doc(uid)
        .collection(collectionName)
        .get();
    for (final doc in snapshot.docs) {
      final item = _legacyMediaItemFromMap(doc.id, doc.data());
      if (item == null) continue;
      await _writeMigratedItemIfMissing(uid, item);
    }
  }

  Future<void> _migrateLegacyMediaDocument(String uid) async {
    final snapshot = await _firestore
        .collection(CartConstants.legacyMediaDocumentCollection)
        .doc(uid)
        .get();
    final data = snapshot.data();
    if (data == null) return;
    final rawItems = data['items'];
    if (rawItems is! Iterable) return;
    for (final rawItem in rawItems) {
      if (rawItem is! Map) continue;
      final item = _legacyMediaItemFromMap('', Map<String, dynamic>.from(rawItem));
      if (item == null) continue;
      await _writeMigratedItemIfMissing(uid, item);
    }
  }

  Future<void> _writeMigratedItemIfMissing(String uid, CartItemModel item) async {
    final normalized = _normalizeCartItem(item);
    final cartItemId = _resolveCartItemId(normalized);
    final ref = _cartCollection(uid).doc(cartItemId);
    final existing = await ref.get();
    if (existing.exists) return;
    await ref.set(_buildFirestorePayload(normalized.copyWith(id: cartItemId)));
  }

  CartItemModel? _legacyMerchItemFromMap(String docId, Map<String, dynamic> data) {
    final productId = (data['productId'] ?? '').toString().trim();
    if (productId.isEmpty) return null;
    final groupId = (data['groupId'] ?? '').toString().trim();
    final size = (data['size'] ?? 'M').toString().trim();
    final color = (data['color'] ?? 'Noir').toString().trim();
    final imagePath = (data['imagePath'] ?? '').toString().trim();
    final imageUrl = imagePath.isNotEmpty
        ? imagePath
        : (data['imageUrl'] ?? '').toString().trim();
    final priceCents = data['priceCents'] is num ? (data['priceCents'] as num).round() : 0;

    return CartItemModel(
      id: docId,
      itemType: CartItemType.merch,
      productId: productId,
      sellerId: '',
      eventId: '',
      title: (data['title'] ?? 'Article').toString().trim(),
      subtitle: '$size - $color',
      imageUrl: imageUrl,
      unitPrice: priceCents / 100,
      quantity: data['quantity'] is num ? (data['quantity'] as num).toInt() : 1,
      currency: 'EUR',
      isDigital: false,
      requiresShipping: true,
      sourceType: CartConstants.merchSourceType,
      metadata: <String, dynamic>{
        if (groupId.isNotEmpty) 'groupId': groupId,
        'size': size,
        'color': color,
        if (imagePath.isNotEmpty) 'imagePath': imagePath,
      },
    );
  }

  CartItemModel? _legacyMediaItemFromMap(String docId, Map<String, dynamic> data) {
    final productId = (data['productId'] ?? data['assetId'] ?? '').toString().trim();
    if (productId.isEmpty) return null;

    final metadata = <String, dynamic>{
      if ((data['assetType'] ?? '').toString().trim().isNotEmpty)
        'assetType': (data['assetType'] ?? '').toString().trim(),
      if ((data['galleryId'] ?? '').toString().trim().isNotEmpty)
        'galleryId': (data['galleryId'] ?? '').toString().trim(),
      if (data['metadata'] is Map)
        ...Map<String, dynamic>.from(data['metadata'] as Map),
    };

    return CartItemModel(
      id: docId,
      itemType: CartItemType.media,
      productId: productId,
      sellerId: (data['sellerId'] ?? data['photographerId'] ?? '').toString().trim(),
      eventId: (data['eventId'] ?? '').toString().trim(),
      title: (data['title'] ?? 'Media').toString().trim(),
      subtitle: (data['subtitle'] ?? '').toString().trim().isEmpty
          ? null
          : (data['subtitle'] ?? '').toString().trim(),
      imageUrl: (data['imageUrl'] ?? data['thumbnailUrl'] ?? '').toString().trim(),
      unitPrice: data['unitPrice'] is num ? (data['unitPrice'] as num).toDouble() : 0,
      quantity: 1,
      currency: (data['currency'] ?? 'EUR').toString().trim(),
      isDigital: true,
      requiresShipping: false,
      sourceType: (data['sourceType'] ?? CartConstants.mediaSourceType).toString().trim(),
      metadata: metadata,
    );
  }

  CartItem _toLegacyMerchItem(CartItemModel item) {
    final metadata = item.metadata ?? const <String, dynamic>{};
    final groupId = (metadata['groupId'] ?? '').toString();
    final size = (metadata['size'] ?? 'M').toString();
    final color = (metadata['color'] ?? 'Noir').toString();
    final imagePath = (metadata['imagePath'] ?? '').toString().trim();

    return CartItem(
      groupId: groupId,
      productId: item.productId,
      title: item.title,
      priceCents: (item.unitPrice * 100).round(),
      imageUrl: imagePath.isNotEmpty ? '' : item.imageUrl,
      imagePath: imagePath.isEmpty ? null : imagePath,
      size: size,
      color: color,
      quantity: item.safeQuantity,
    );
  }

  String _legacyKeyForMerchItem(CartItemModel item) {
    final metadata = item.metadata ?? const <String, dynamic>{};
    final groupId = (metadata['groupId'] ?? '').toString();
    final size = (metadata['size'] ?? 'M').toString();
    final color = (metadata['color'] ?? 'Noir').toString();
    return '$groupId::${item.productId}::$size::$color';
  }

  String _resolveCartItemId(CartItemModel item) {
    final mergeKey = _buildLogicalMergeKey(item);
    return 'ci_${sha1.convert(utf8.encode(mergeKey)).toString()}';
  }

  String _buildLogicalMergeKey(CartItemModel item) {
    final normalizedMetadata = _stableEncode(item.metadata ?? const <String, dynamic>{});
    return <String>[
      item.itemType.name,
      item.productId,
      item.sellerId,
      item.eventId,
      item.sourceType ?? '',
      normalizedMetadata,
    ].join('||');
  }

  String _stableEncode(dynamic value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      final map = <String, dynamic>{};
      for (final key in keys) {
        map[key] = _stableEncode(value[key]);
      }
      return jsonEncode(map);
    }
    if (value is Iterable) {
      return jsonEncode(value.map(_stableEncode).toList(growable: false));
    }
    return value?.toString() ?? '';
  }

  int _sortCartItems(CartItemModel a, CartItemModel b) {
    final aDate = a.updatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bDate = b.updatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bDate.compareTo(aDate);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _cartSub?.cancel();
    super.dispose();
  }
}
