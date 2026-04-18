import 'package:cloud_firestore/cloud_firestore.dart';

class BloomArtItem {
  const BloomArtItem({
    required this.id,
    required this.sellerId,
    required this.sellerProfileType,
    required this.sellerDisplayName,
    required this.title,
    required this.description,
    required this.category,
    required this.condition,
    required this.materials,
    required this.dimensions,
    required this.images,
    required this.currency,
    required this.isPublished,
    required this.availabilityStatus,
    required this.deliveryMode,
    required this.deliveryNotes,
    this.referencePrice,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String sellerId;
  final String sellerProfileType;
  final String sellerDisplayName;
  final String title;
  final String description;
  final String category;
  final String condition;
  final List<String> materials;
  final String dimensions;
  final List<String> images;
  final double? referencePrice;
  final String currency;
  final bool isPublished;
  final String availabilityStatus;
  final String deliveryMode;
  final String deliveryNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isSold => availabilityStatus == 'sold';
  bool get isReserved => availabilityStatus == 'reserved';
  bool get isAvailableForOffers => isPublished && !isSold && !isReserved;

  BloomArtItem copyWith({
    String? id,
    String? sellerId,
    String? sellerProfileType,
    String? sellerDisplayName,
    String? title,
    String? description,
    String? category,
    String? condition,
    List<String>? materials,
    String? dimensions,
    List<String>? images,
    double? referencePrice,
    String? currency,
    bool? isPublished,
    String? availabilityStatus,
    String? deliveryMode,
    String? deliveryNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BloomArtItem(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      sellerProfileType: sellerProfileType ?? this.sellerProfileType,
      sellerDisplayName: sellerDisplayName ?? this.sellerDisplayName,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      condition: condition ?? this.condition,
      materials: materials ?? this.materials,
      dimensions: dimensions ?? this.dimensions,
      images: images ?? this.images,
      referencePrice: referencePrice ?? this.referencePrice,
      currency: currency ?? this.currency,
      isPublished: isPublished ?? this.isPublished,
      availabilityStatus: availabilityStatus ?? this.availabilityStatus,
      deliveryMode: deliveryMode ?? this.deliveryMode,
      deliveryNotes: deliveryNotes ?? this.deliveryNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap({bool includeReferencePrice = false}) {
    return <String, dynamic>{
      'sellerId': sellerId,
      'sellerProfileType': sellerProfileType,
      'sellerDisplayName': sellerDisplayName,
      'title': title,
      'description': description,
      'category': category,
      'condition': condition,
      'materials': materials,
      'dimensions': dimensions,
      'images': images,
      'currency': currency,
      'isPublished': isPublished,
      'availabilityStatus': availabilityStatus,
      'deliveryMode': deliveryMode,
      'deliveryNotes': deliveryNotes,
      if (includeReferencePrice) 'referencePrice': referencePrice,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  factory BloomArtItem.fromMap(String id, Map<String, dynamic> map) {
    return BloomArtItem(
      id: id,
      sellerId: (map['sellerId'] ?? '').toString(),
      sellerProfileType: (map['sellerProfileType'] ?? 'je_me_lance').toString(),
      sellerDisplayName: (map['sellerDisplayName'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      category: (map['category'] ?? '').toString(),
      condition: (map['condition'] ?? '').toString(),
      materials: _toStringList(map['materials']),
      dimensions: (map['dimensions'] ?? '').toString(),
      images: _toStringList(map['images']),
      referencePrice: _toDoubleOrNull(map['referencePrice']),
      currency: (map['currency'] ?? 'EUR').toString(),
      isPublished: map['isPublished'] == true,
      availabilityStatus: (map['availabilityStatus'] ?? 'draft').toString(),
      deliveryMode: (map['deliveryMode'] ?? '').toString(),
      deliveryNotes: (map['deliveryNotes'] ?? '').toString(),
      createdAt: _toDate(map['createdAt']),
      updatedAt: _toDate(map['updatedAt']),
    );
  }

  factory BloomArtItem.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    return BloomArtItem.fromMap(doc.id, doc.data() ?? <String, dynamic>{});
  }

  static List<String> _toStringList(Object? raw) {
    if (raw is List) {
      return raw.map((value) => value.toString().trim()).where((value) => value.isNotEmpty).toList(growable: false);
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return raw
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  static DateTime? _toDate(Object? raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }

  static double? _toDoubleOrNull(Object? raw) {
    if (raw == null) return null;
    final parsed = double.tryParse(raw.toString());
    return parsed;
  }
}