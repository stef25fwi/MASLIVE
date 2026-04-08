import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum CartItemType {
  merch,
  media,
}

CartItemType cartItemTypeFromString(
  String? value, {
  CartItemType fallback = CartItemType.merch,
}) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'merch':
      return CartItemType.merch;
    case 'media':
      return CartItemType.media;
    default:
      return fallback;
  }
}

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value.trim().replaceAll(',', '.')) ?? fallback;
  }
  return fallback;
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    switch (value.trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
      case 'oui':
        return true;
      case 'false':
      case '0':
      case 'no':
      case 'non':
        return false;
      default:
        return fallback;
    }
  }
  return fallback;
}

DateTime? _asDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value)?.toLocal();
  return null;
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is! Map) return null;
  return Map<String, dynamic>.from(value);
}

String _normalizedString(dynamic value, {String fallback = ''}) {
  final normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? fallback : normalized;
}

@immutable
class CartItemModel {
  const CartItemModel({
    required this.id,
    required this.itemType,
    required this.productId,
    required this.sellerId,
    required this.eventId,
    required this.title,
    this.subtitle,
    required this.imageUrl,
    required this.unitPrice,
    required this.quantity,
    required this.currency,
    required this.isDigital,
    required this.requiresShipping,
    this.sourceType,
    this.metadata,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final CartItemType itemType;
  final String productId;
  final String sellerId;
  final String eventId;
  final String title;
  final String? subtitle;
  final String imageUrl;
  final double unitPrice;
  final int quantity;
  final String currency;
  final bool isDigital;
  final bool requiresShipping;
  final String? sourceType;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  double get totalPrice => unitPrice * safeQuantity;

  int get safeQuantity => quantity < 1 ? 1 : quantity;

  /// Can adjust quantity for this item.
  /// Media items are digital and indivisible: quantity is always 1.
  bool get canAdjustQuantity => itemType == CartItemType.merch;

  factory CartItemModel.fromMap(
    Map<String, dynamic> map, {
    String? id,
  }) {
    final itemType = cartItemTypeFromString(map['itemType']?.toString());
    final parsedQuantity = _asInt(map['quantity'], fallback: 1).clamp(1, 999);

    return CartItemModel(
      id: _normalizedString(id ?? map['id']),
      itemType: itemType,
      productId: _normalizedString(map['productId']),
      sellerId: _normalizedString(map['sellerId']),
      eventId: _normalizedString(map['eventId']),
      title: _normalizedString(map['title'], fallback: 'Article'),
      subtitle: _normalizedString(map['subtitle']).isEmpty
          ? null
          : _normalizedString(map['subtitle']),
      imageUrl: _normalizedString(map['imageUrl']),
      unitPrice: _asDouble(map['unitPrice']),
        quantity: itemType == CartItemType.media ? 1 : parsedQuantity,
      currency: _normalizedString(map['currency'], fallback: 'EUR'),
      isDigital: _asBool(map['isDigital']),
      requiresShipping: _asBool(map['requiresShipping']),
      sourceType: _normalizedString(map['sourceType']).isEmpty
          ? null
          : _normalizedString(map['sourceType']),
      metadata: _asMap(map['metadata']),
      createdAt: _asDateTime(map['createdAt']),
      updatedAt: _asDateTime(map['updatedAt']),
    );
  }

  factory CartItemModel.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    return CartItemModel.fromMap(doc.data() ?? const <String, dynamic>{}, id: doc.id);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'itemType': itemType.name,
      'productId': productId,
      'sellerId': sellerId,
      'eventId': eventId,
      'title': title,
      if (subtitle != null && subtitle!.trim().isNotEmpty) 'subtitle': subtitle,
      'imageUrl': imageUrl,
      'unitPrice': unitPrice,
      'quantity': safeQuantity,
      'currency': currency,
      'isDigital': isDigital,
      'requiresShipping': requiresShipping,
      if (sourceType != null && sourceType!.trim().isNotEmpty) 'sourceType': sourceType,
      if (metadata != null) 'metadata': metadata,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  CartItemModel copyWith({
    String? id,
    CartItemType? itemType,
    String? productId,
    String? sellerId,
    String? eventId,
    String? title,
    String? subtitle,
    bool clearSubtitle = false,
    String? imageUrl,
    double? unitPrice,
    int? quantity,
    String? currency,
    bool? isDigital,
    bool? requiresShipping,
    String? sourceType,
    bool clearSourceType = false,
    Map<String, dynamic>? metadata,
    bool clearMetadata = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CartItemModel(
      id: id ?? this.id,
      itemType: itemType ?? this.itemType,
      productId: productId ?? this.productId,
      sellerId: sellerId ?? this.sellerId,
      eventId: eventId ?? this.eventId,
      title: title ?? this.title,
      subtitle: clearSubtitle ? null : (subtitle ?? this.subtitle),
      imageUrl: imageUrl ?? this.imageUrl,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      currency: currency ?? this.currency,
      isDigital: isDigital ?? this.isDigital,
      requiresShipping: requiresShipping ?? this.requiresShipping,
      sourceType: clearSourceType ? null : (sourceType ?? this.sourceType),
      metadata: clearMetadata ? null : (metadata ?? this.metadata),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CartItemModel &&
        other.id == id &&
        other.itemType == itemType &&
        other.productId == productId &&
        other.sellerId == sellerId &&
        other.eventId == eventId &&
        other.title == title &&
        other.subtitle == subtitle &&
        other.imageUrl == imageUrl &&
        other.unitPrice == unitPrice &&
        other.quantity == quantity &&
        other.currency == currency &&
        other.isDigital == isDigital &&
        other.requiresShipping == requiresShipping &&
        other.sourceType == sourceType &&
        mapEquals(other.metadata, metadata) &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        itemType,
        productId,
        sellerId,
        eventId,
        title,
        subtitle,
        imageUrl,
        unitPrice,
        quantity,
        currency,
        isDigital,
        requiresShipping,
        sourceType,
        metadata == null ? null : Object.hashAll(metadata!.entries),
        createdAt,
        updatedAt,
      );
}