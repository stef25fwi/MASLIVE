import 'package:cloud_firestore/cloud_firestore.dart';

class GroupProduct {
  final String id;
  final String title;
  final int priceCents;
  final String imageUrl;
  final String? imageUrl2;
  final String? imagePath; // Pour assets locaux
  final String category;
  final bool isActive;
  final String moderationStatus; // 'pending' | 'approved' | 'rejected'
  final String? moderationReason;
  final Map<String, int>? stockByVariant; // 'taille|couleur' -> stock
  final List<String>? availableSizes;
  final List<String>? availableColors;
  final int? stockQty; // stock total normalisé
  final List<String>? tags; // tags normalisés (catégorie, taille, couleur...)

  const GroupProduct({
    required this.id,
    required this.title,
    required this.priceCents,
    required this.imageUrl,
    this.imageUrl2,
    this.imagePath,
    required this.category,
    required this.isActive,
    this.moderationStatus = 'approved',
    this.moderationReason,
    this.stockByVariant,
    this.availableSizes,
    this.availableColors,
    this.stockQty,
    this.tags,
  });

  String get priceLabel {
    final euros = priceCents / 100;
    if (euros == euros.truncate()) {
      return '${euros.toStringAsFixed(0)},00 €';
    }
    return '${euros.toStringAsFixed(2).replaceAll('.', ',')} €';
  }
  
  // Récupère le stock pour une variante donnée
  int stockFor(String size, String color) {
    if (stockByVariant == null) return 999; // Stock illimité si non géré
    return stockByVariant!['$size|$color'] ?? 0;
  }
  
  // Liste des tailles disponibles
  List<String> get sizes => availableSizes ?? const ['XS', 'S', 'M', 'L', 'XL'];
  
  // Liste des couleurs disponibles
  List<String> get colors => availableColors ?? const ['Noir', 'Blanc', 'Gris'];

  // Stock total dérivé : stockQty si présent, sinon somme des variantes
  int get totalStock {
    if (stockQty != null) return stockQty!;
    if (stockByVariant == null) return 999; // stock virtuellement illimité
    return stockByVariant!.values.fold<int>(0, (total, v) => total + v);
  }

  bool get isOutOfStock => totalStock <= 0;

  factory GroupProduct.fromMap(String id, Map<String, dynamic> data) {
    final status = (data['moderationStatus'] ?? '').toString().trim();

    // Compat ancien schéma (commerce_module_single_file Product)
    final legacyName = (data['name'] ?? '').toString();
    final legacyPrice = data['price'];
    final legacyMainImageUrl = (data['mainImageUrl'] ?? '').toString();
    final legacyCategoryId = (data['categoryId'] ?? '').toString();
    final legacyImages = data['images'];
    
    // Parser le stock par variante
    Map<String, int>? stockByVariant;
    if (data['stockByVariant'] != null) {
      stockByVariant = Map<String, int>.from(data['stockByVariant'] as Map);
    }
    
    // Parser les tailles et couleurs disponibles
    List<String>? availableSizes;
    if (data['availableSizes'] != null) {
      availableSizes = List<String>.from(data['availableSizes'] as List);
    }
    
    List<String>? availableColors;
    if (data['availableColors'] != null) {
      availableColors = List<String>.from(data['availableColors'] as List);
    }

    final int? stockQty = data['stockQty'] is int ? data['stockQty'] as int : null;
    List<String>? tags;
    if (data['tags'] != null) {
      tags = List<String>.from(data['tags'] as List);
    }

    int priceCents;
    final pc = data['priceCents'];
    if (pc is int) {
      priceCents = pc;
    } else if (pc is num) {
      priceCents = pc.round();
    } else if (legacyPrice is num) {
      priceCents = (legacyPrice * 100).round();
    } else {
      priceCents = 0;
    }

    String imageUrl = (data['imageUrl'] ?? '').toString();
    if (imageUrl.trim().isEmpty) {
      imageUrl = legacyMainImageUrl;
    }

    String? imageUrl2;
    final rawImageUrl2 = (data['imageUrl2'] as String?);
    if (rawImageUrl2 != null && rawImageUrl2.trim().isNotEmpty) {
      imageUrl2 = rawImageUrl2;
    } else if (legacyImages is List && legacyImages.length > 1) {
      final second = legacyImages[1];
      if (second is Map) {
        final url = (second['url'] ?? '').toString();
        if (url.trim().isNotEmpty) imageUrl2 = url;
      }
    }
    
    return GroupProduct(
      id: id,
      title: ((data['title'] ?? '').toString().trim().isNotEmpty
        ? (data['title'] ?? '').toString()
        : legacyName),
      priceCents: priceCents,
      imageUrl: imageUrl,
      imageUrl2: imageUrl2,
      imagePath: (data['imagePath'] as String?)?.trim().isEmpty == true
          ? null
          : data['imagePath'] as String?,
      category: ((data['category'] ?? '').toString().trim().isNotEmpty
        ? (data['category'] ?? '').toString()
        : (legacyCategoryId.trim().isNotEmpty ? legacyCategoryId : 'T-shirts')),
      isActive: (data['isActive'] ?? true) as bool,
      moderationStatus: status.isEmpty
          ? ((data['isActive'] ?? true) == true ? 'approved' : 'pending')
          : status,
        moderationReason: (data['moderationReason'] as String?)?.trim().isEmpty == true
          ? null
          : (data['moderationReason'] as String?),
      stockByVariant: stockByVariant,
      availableSizes: availableSizes,
      availableColors: availableColors,
      stockQty: stockQty,
      tags: tags,
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
      if (imagePath != null && imagePath!.isNotEmpty) 'imagePath': imagePath,
      'category': category,
      'isActive': isActive,
      'moderationStatus': moderationStatus,
      if (moderationReason != null && moderationReason!.isNotEmpty)
        'moderationReason': moderationReason,
      if (stockByVariant != null) 'stockByVariant': stockByVariant,
      if (availableSizes != null) 'availableSizes': availableSizes,
      if (availableColors != null) 'availableColors': availableColors,
      if (stockQty != null) 'stockQty': stockQty,
      if (tags != null) 'tags': tags,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  bool get isApproved => moderationStatus == 'approved' && isActive;
  bool get isRejected => moderationStatus == 'rejected' && !isActive;
  bool get isPending => moderationStatus == 'pending' && !isActive;
}
