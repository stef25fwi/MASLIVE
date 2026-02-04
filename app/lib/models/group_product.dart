// Modèle Produit Boutique Groupe
// Collection: group_shops/{adminGroupId}/products/{productId}

export 'product_model.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

class GroupShopProduct {
  final String id;
  final String adminGroupId;
  final String title;
  final String description;
  final double price;
  final String currency;
  final int stock;
  final List<String> photoUrls;
  final bool isVisible;
  final DateTime createdAt;
  final DateTime updatedAt;

  GroupShopProduct({
    required this.id,
    required this.adminGroupId,
    required this.title,
    required this.description,
    required this.price,
    this.currency = 'EUR',
    required this.stock,
    required this.photoUrls,
    this.isVisible = true,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get inStock => stock > 0;

  factory GroupShopProduct.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupShopProduct(
      id: doc.id,
      adminGroupId: data['adminGroupId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      currency: data['currency'] ?? 'EUR',
      stock: data['stock'] ?? 0,
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
      isVisible: data['isVisible'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'adminGroupId': adminGroupId,
      'title': title,
      'description': description,
      'price': price,
      'currency': currency,
      'stock': stock,
      'photoUrls': photoUrls,
      'isVisible': isVisible,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  GroupShopProduct copyWith({
    String? title,
    String? description,
    double? price,
    String? currency,
    int? stock,
    List<String>? photoUrls,
    bool? isVisible,
    DateTime? updatedAt,
  }) {
    return GroupShopProduct(
      id: id,
      adminGroupId: adminGroupId,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      stock: stock ?? this.stock,
      photoUrls: photoUrls ?? this.photoUrls,
      isVisible: isVisible ?? this.isVisible,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

