import 'package:flutter/foundation.dart';

@immutable
class CartItem {
  final String groupId;
  final String productId;
  final String title;
  final int priceCents;
  final String imageUrl;
  final String? imagePath; // Pour les assets locaux (ex: assets/shop/image.png)
  final String size;
  final String color;
  final int quantity;

  const CartItem({
    required this.groupId,
    required this.productId,
    required this.title,
    required this.priceCents,
    this.imageUrl = '',
    this.imagePath, // Optionnel
    required this.size,
    required this.color,
    required this.quantity,
  });

  String get key => '$groupId::$productId::$size::$color';

  /// Retourne la clé de variante pour le stock (format: "taille|couleur")
  String get variantKey => '$size|$color';

  // Retourne l'image à utiliser (priorité à imagePath si défini)
  String get displayImage => imagePath ?? imageUrl;
  
  // Vérifie si c'est un asset local
  bool get isLocalAsset => imagePath != null && imagePath!.startsWith('assets/');

  CartItem copyWith({int? quantity, String? imagePath, String? imageUrl}) {
    return CartItem(
      groupId: groupId,
      productId: productId,
      title: title,
      priceCents: priceCents,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePath: imagePath ?? this.imagePath,
      size: size,
      color: color,
      quantity: quantity ?? this.quantity,
    );
  }
}
