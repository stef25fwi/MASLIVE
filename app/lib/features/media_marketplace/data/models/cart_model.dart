import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../mappers/timestamp_mapper.dart';
import 'cart_item_model.dart';

List<CartItemModel> _cartItems(dynamic value) {
  if (value is! Iterable) return const <CartItemModel>[];
  return value
      .whereType<Map>()
      .map((item) => CartItemModel.fromMap(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

/// Panier utilisateur stocké dans Firestore sous carts/{uid}.
class CartModel {
  final String uid;
  final List<CartItemModel> items;
  final String currency;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CartModel({
    required this.uid,
    this.items = const <CartItemModel>[],
    this.currency = 'EUR',
    required this.createdAt,
    required this.updatedAt,
  });

  int get itemCount => items.fold<int>(0, (sum, item) => sum + item.quantity);

  double get subtotal => items.fold<double>(0, (sum, item) => sum + item.totalPrice);

  factory CartModel.fromMap(Map<String, dynamic> map, {String? uid}) {
    return CartModel(
      uid: uid ?? (map['uid']?.toString() ?? ''),
      items: _cartItems(map['items']),
      currency: map['currency']?.toString() ?? 'EUR',
      createdAt: TimestampMapper.fromFirestoreOrNow(map['createdAt']),
      updatedAt: TimestampMapper.fromFirestoreOrNow(map['updatedAt']),
    );
  }

  factory CartModel.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    return CartModel.fromMap(doc.data() ?? const <String, dynamic>{}, uid: doc.id);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'uid': uid,
      'items': items.map((item) => item.toMap()).toList(growable: false),
      'currency': currency,
      'createdAt': TimestampMapper.toFirestore(createdAt),
      'updatedAt': TimestampMapper.toFirestore(updatedAt),
    };
  }

  CartModel copyWith({
    String? uid,
    List<CartItemModel>? items,
    String? currency,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CartModel(
      uid: uid ?? this.uid,
      items: items ?? this.items,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CartModel &&
        other.uid == uid &&
        listEquals(other.items, items) &&
        other.currency == currency &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
        uid,
        Object.hashAll(items),
        currency,
        createdAt,
        updatedAt,
      );
}