import 'package:cloud_firestore/cloud_firestore.dart';

/// Modèle pour les articles gérés par le superadmin (casquette, tshirt, porteclé, bandana)
class SuperadminArticle {
  final String id;
  final String name;
  final String description;
  final String category; // casquette, tshirt, porteclé, bandana
  final double price;
  final String imageUrl; // Image couverture/principale
  final int stock;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? sku; // Stock Keeping Unit
  final List<String> tags;
  final Map<String, dynamic>? metadata; // Données additionnelles (tailles, couleurs, etc.)
  
  // NEW: Support galerie et métadonnées images
  final List<String> galleryImages; // Images supplémentaires
  final String? thumbnailUrl; // URL miniature pour liste
  final Map<String, dynamic>? imageMetadata; // uploadedBy, uploadedAt, fileSize, etc.

  SuperadminArticle({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.imageUrl,
    required this.stock,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.sku,
    this.tags = const [],
    this.metadata,
    this.galleryImages = const [],
    this.thumbnailUrl,
    this.imageMetadata,
  });

  factory SuperadminArticle.fromMap(Map<String, dynamic> data, String docId) {
    return SuperadminArticle(
      id: docId,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      imageUrl: data['imageUrl'] ?? '',
      stock: data['stock'] ?? 0,
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sku: data['sku'],
      tags: List<String>.from(data['tags'] ?? []),
      metadata: data['metadata'],
      galleryImages: List<String>.from(data['galleryImages'] ?? []),
      thumbnailUrl: data['thumbnailUrl'],
      imageMetadata: data['imageMetadata'],
    );
  }

  factory SuperadminArticle.fromJson(Map<String, dynamic> json) {
    return SuperadminArticle(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      price: (json['price'] ?? 0.0).toDouble(),
      imageUrl: json['imageUrl'] ?? '',
      stock: json['stock'] ?? 0,
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null 
        ? DateTime.parse(json['createdAt']) 
        : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
        ? DateTime.parse(json['updatedAt']) 
        : DateTime.now(),
      sku: json['sku'],
      tags: List<String>.from(json['tags'] ?? []),
      metadata: json['metadata'],
      galleryImages: List<String>.from(json['galleryImages'] ?? []),
      thumbnailUrl: json['thumbnailUrl'],
      imageMetadata: json['imageMetadata'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'category': category,
      'price': price,
      'imageUrl': imageUrl,
      'stock': stock,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'sku': sku,
      'tags': tags,
      'metadata': metadata,
      'galleryImages': galleryImages,
      'thumbnailUrl': thumbnailUrl,
      'imageMetadata': imageMetadata,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'price': price,
      'imageUrl': imageUrl,
      'stock': stock,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'sku': sku,
      'tags': tags,
      'metadata': metadata,
      'galleryImages': galleryImages,
      'thumbnailUrl': thumbnailUrl,
      'imageMetadata': imageMetadata,
    };
  }

  SuperadminArticle copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    double? price,
    String? imageUrl,
    int? stock,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? sku,
    List<String>? tags,
    Map<String, dynamic>? metadata,
    List<String>? galleryImages,
    String? thumbnailUrl,
    Map<String, dynamic>? imageMetadata,
  }) {
    return SuperadminArticle(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      stock: stock ?? this.stock,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sku: sku ?? this.sku,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
      galleryImages: galleryImages ?? this.galleryImages,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      imageMetadata: imageMetadata ?? this.imageMetadata,
    );
  }
}
