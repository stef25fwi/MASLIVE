import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';

class OrderService {
  static final OrderService _instance = OrderService._();
  factory OrderService() => _instance;
  OrderService._();

  final _db = FirebaseFirestore.instance;

  Future<String?> _sellerIdForProductId(String productId) async {
    if (productId.trim().isEmpty) return null;

    Map<String, dynamic>? data;

    // 1) Priorité Storex: shops/global/products/{productId}
    try {
      final storexSnap = await _db
          .collection('shops')
          .doc('global')
          .collection('products')
          .doc(productId)
          .get();
      if (storexSnap.exists) data = storexSnap.data();
    } catch (_) {}

    // 2) Fallback legacy: products/{productId}
    if (data == null) {
      try {
        final legacySnap = await _db.collection('products').doc(productId).get();
        if (legacySnap.exists) data = legacySnap.data();
      } catch (_) {}
    }

    if (data == null) return null;

    String pick(String key) {
      final v = data?[key];
      return (v is String) ? v.trim() : '';
    }

    final ownerId = pick('ownerId');
    if (ownerId.isNotEmpty) return ownerId;
    final ownerUid = pick('ownerUid');
    if (ownerUid.isNotEmpty) return ownerUid;
    final sellerId = pick('sellerId');
    if (sellerId.isNotEmpty) return sellerId;
    return null;
  }

  /// Créer une nouvelle commande
  Future<String> createOrder({
    required String userId,
    required String groupId,
    required List<OrderLineItem> items,
    required int totalPrice,
    String? notes,
  }) async {
    final itemMaps = items.map((i) => i.toMap()).toList();

    // IMPORTANT: sellerIds doit être un array unique pour isSellerOfOrder.
    // On tente de le dériver depuis les produits.
    final productIds = itemMaps
        .map((m) => (m['productId'] ?? '').toString().trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final sellerByProductId = <String, String>{};
    if (productIds.isNotEmpty) {
      final results = await Future.wait(
        productIds.map((pid) async => MapEntry(pid, await _sellerIdForProductId(pid))),
      );
      for (final e in results) {
        final sellerId = (e.value ?? '').trim();
        if (sellerId.isNotEmpty) sellerByProductId[e.key] = sellerId;
      }
    }

    for (final m in itemMaps) {
      final pid = (m['productId'] ?? '').toString().trim();
      final sellerId = sellerByProductId[pid];
      if (sellerId != null && sellerId.isNotEmpty) {
        m['sellerId'] = sellerId;
      }
    }

    final sellerIds = sellerByProductId.values.toSet().toList()..sort();

    final docRef = await _db.collection('orders').add({
      'userId': userId,
      'buyerId': userId,
      'groupId': groupId,
      'sellerIds': sellerIds,
      'items': itemMaps,
      'totalPrice': totalPrice,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'deliveredAt': null,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return docRef.id;
  }

  /// Récupérer une commande
  Future<ShopOrder?> getOrder(String orderId) async {
    try {
      final doc = await _db.collection('orders').doc(orderId).get();
      if (!doc.exists) return null;
      return ShopOrder.fromFirestore(doc);
    } catch (e) {
      // print('Erreur getOrder: $e');
      return null;
    }
  }

  /// Flux de commandes pour un utilisateur
  Stream<List<ShopOrder>> watchUserOrders(String userId) {
    return _db
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => ShopOrder.fromFirestore(doc)).toList());
  }

  /// Flux de commandes pour un groupe (admin)
  Stream<List<ShopOrder>> watchGroupOrders(String groupId) {
    return _db
        .collection('orders')
        .where('groupId', isEqualTo: groupId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => ShopOrder.fromFirestore(doc)).toList());
  }

  /// Mettre à jour le statut
  Future<void> updateStatus(String orderId, String newStatus) async {
    await _db.collection('orders').doc(orderId).update({
      'status': newStatus,
      if (newStatus == 'delivered')
        'deliveredAt': FieldValue.serverTimestamp(),
    });
  }

  /// Annuler une commande
  Future<void> cancelOrder(String orderId) async {
    await updateStatus(orderId, 'cancelled');
  }

  /// Ajouter des notes
  Future<void> addNotes(String orderId, String notes) async {
    await _db.collection('orders').doc(orderId).update({
      'notes': notes,
    });
  }

  /// Supprimer une commande (admin/modération)
  Future<void> deleteOrder(String orderId) async {
    await _db.collection('orders').doc(orderId).delete();
  }
}
