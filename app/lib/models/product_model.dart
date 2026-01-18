import 'package:cloud_firestore/cloud_firestore.dart';

class GroupProduct {
  final String id;
  final String title;
  final int priceCents;
  final String imageUrl;
  final String category;
  final bool isActive;

  const GroupProduct({
    required this.id,
    required this.title,
    required this.priceCents,
    required this.imageUrl,
    required this.category,
    required this.isActive,
  });

  String get priceLabel => '€${(priceCents / 100).toStringAsFixed(0)}';

  factory GroupProduct.fromMap(String id, Map<String, dynamic> data) {
    return GroupProduct(
      id: id,
      title: (data['title'] ?? '') as String,
      priceCents: (data['priceCents'] ?? 0) as int,
      imageUrl: (data['imageUrl'] ?? '') as String,
      category: (data['category'] ?? 'T-shirts') as String,
      isActive: (data['isActive'] ?? true) as bool,
    );
  }

  // Convertir depuis Firestore document
  factory GroupProduct.fromFirestore(DocumentSnapshot doc) {
    return GroupProduct.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  // Convertir en Map pour Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'priceCents': priceCents,
      'imageUrl': imageUrl,
      'category': category,
      'isActive': isActive,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
