import 'package:cloud_firestore/cloud_firestore.dart';

class OrderLineItem {
  final String productId;
  final String title;
  final int quantity;
  final int pricePerUnit; // en centimes

  OrderLineItem({
    required this.productId,
    required this.title,
    required this.quantity,
    required this.pricePerUnit,
  });

  int get totalPrice => quantity * pricePerUnit;

  factory OrderLineItem.fromMap(Map<String, dynamic> data) {
    return OrderLineItem(
      productId: data['productId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      quantity: data['quantity'] as int? ?? 1,
      pricePerUnit: data['pricePerUnit'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'title': title,
      'quantity': quantity,
      'pricePerUnit': pricePerUnit,
    };
  }
}

class ShopOrder {
  final String orderId;
  final String userId;
  final String groupId;
  final List<OrderLineItem> items;
  final int totalPrice; // en centimes
  final String status; // pending, confirmed, shipped, delivered, cancelled
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final String? notes;

  ShopOrder({
    required this.orderId,
    required this.userId,
    required this.groupId,
    required this.items,
    required this.totalPrice,
    this.status = 'pending',
    required this.createdAt,
    this.deliveredAt,
    this.notes,
  });

  factory ShopOrder.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final created = data['createdAt'] as Timestamp?;
    final delivered = data['deliveredAt'] as Timestamp?;
    final itemsData = data['items'] as List<dynamic>? ?? [];

    return ShopOrder(
      orderId: doc.id,
      userId: data['userId'] as String? ?? '',
      groupId: data['groupId'] as String? ?? '',
      items: itemsData
          .map((item) => OrderLineItem.fromMap(item as Map<String, dynamic>))
          .toList(),
      totalPrice: data['totalPrice'] as int? ?? 0,
      status: data['status'] as String? ?? 'pending',
      createdAt: created != null ? created.toDate() : DateTime.now(),
      deliveredAt: delivered?.toDate(),
      notes: data['notes'] as String?,
    );
  }

  factory ShopOrder.fromMap(String orderId, Map<String, dynamic> data) {
    final created = data['createdAt'] as Timestamp?;
    final delivered = data['deliveredAt'] as Timestamp?;
    final itemsData = data['items'] as List<dynamic>? ?? [];

    return ShopOrder(
      orderId: orderId,
      userId: data['userId'] as String? ?? '',
      groupId: data['groupId'] as String? ?? '',
      items: itemsData
          .map((item) => OrderLineItem.fromMap(item as Map<String, dynamic>))
          .toList(),
      totalPrice: data['totalPrice'] as int? ?? 0,
      status: data['status'] as String? ?? 'pending',
      createdAt: created != null ? created.toDate() : DateTime.now(),
      deliveredAt: delivered?.toDate(),
      notes: data['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'groupId': groupId,
      'items': items.map((i) => i.toMap()).toList(),
      'totalPrice': totalPrice,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
      'deliveredAt': deliveredAt,
      if (notes != null) 'notes': notes,
    };
  }

  ShopOrder copyWith({
    String? status,
    DateTime? deliveredAt,
    String? notes,
  }) {
    return ShopOrder(
      orderId: orderId,
      userId: userId,
      groupId: groupId,
      items: items,
      totalPrice: totalPrice,
      status: status ?? this.status,
      createdAt: createdAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      notes: notes ?? this.notes,
    );
  }

  String get formattedTotal {
    return '${(totalPrice / 100).toStringAsFixed(2)}€';
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'confirmed':
        return 'Confirmée';
      case 'shipped':
        return 'Expédiée';
      case 'delivered':
        return 'Livrée';
      case 'cancelled':
        return 'Annulée';
      default:
        return status;
    }
  }
}
