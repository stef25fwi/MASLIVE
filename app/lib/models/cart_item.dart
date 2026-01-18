import 'package:flutter/foundation.dart';

@immutable
class CartItem {
  final String groupId;
  final String productId;
  final String title;
  final int priceCents;
  final String imageUrl;
  final String size;
  final String color;
  final int quantity;

  const CartItem({
    required this.groupId,
    required this.productId,
    required this.title,
    required this.priceCents,
    required this.imageUrl,
    required this.size,
    required this.color,
    required this.quantity,
  });

  String get key => '$groupId::$productId::$size::$color';

  CartItem copyWith({int? quantity}) {
    return CartItem(
      groupId: groupId,
      productId: productId,
      title: title,
      priceCents: priceCents,
      imageUrl: imageUrl,
      size: size,
      color: color,
      quantity: quantity ?? this.quantity,
    );
  }
}
