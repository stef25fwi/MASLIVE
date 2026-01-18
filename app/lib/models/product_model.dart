import 'package:cloud_firestore/cloud_firestore.dart';

class GroupProduct {
  final String id;
  final String title;
  final int priceCents;
  final String imageUrl;
  final String? imageUrl2;
  final String category;
  final bool isActive;
  final String moderationStatus; // 'pending' | 'approved' | 'rejected'
  final String? moderationReason;

  const GroupProduct({
    required this.id,
    required this.title,
    required this.priceCents,
    required this.imageUrl,
    this.imageUrl2,
    required this.category,
    required this.isActive,
    this.moderationStatus = 'approved',
    this.moderationReason,
  });

  String get priceLabel => '€${(priceCents / 100).toStringAsFixed(0)}';

  factory GroupProduct.fromMap(String id, Map<String, dynamic> data) {
    final status = (data['moderationStatus'] ?? '').toString().trim();
    return GroupProduct(
      id: id,
      title: (data['title'] ?? '') as String,
      priceCents: (data['priceCents'] ?? 0) as int,
      imageUrl: (data['imageUrl'] ?? '') as String,
      imageUrl2: (data['imageUrl2'] as String?)?.trim().isEmpty == true
          ? null
          : data['imageUrl2'] as String?,
      category: (data['category'] ?? 'T-shirts') as String,
      isActive: (data['isActive'] ?? true) as bool,
      moderationStatus: status.isEmpty
          ? ((data['isActive'] ?? true) == true ? 'approved' : 'pending')
          : status,
        moderationReason: (data['moderationReason'] as String?)?.trim().isEmpty == true
          ? null
          : (data['moderationReason'] as String?),
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
      if (imageUrl2 != null && imageUrl2!.isNotEmpty) 'imageUrl2': imageUrl2,
      'category': category,
      'isActive': isActive,
      'moderationStatus': moderationStatus,
      if (moderationReason != null && moderationReason!.isNotEmpty)
        'moderationReason': moderationReason,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  bool get isApproved => moderationStatus == 'approved' && isActive;
  bool get isRejected => moderationStatus == 'rejected' && !isActive;
  bool get isPending => moderationStatus == 'pending' && !isActive;
}
