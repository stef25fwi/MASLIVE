import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';

class OrderService {
  static final OrderService _instance = OrderService._();
  factory OrderService() => _instance;
  OrderService._();

  final _db = FirebaseFirestore.instance;

  /// Créer une nouvelle commande
  Future<String> createOrder({
    required String userId,
    required String groupId,
    required List<OrderLineItem> items,
    required int totalPrice,
    String? notes,
  }) async {
    final docRef = await _db.collection('orders').add({
      'userId': userId,
      'groupId': groupId,
      'items': items.map((i) => i.toMap()).toList(),
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
