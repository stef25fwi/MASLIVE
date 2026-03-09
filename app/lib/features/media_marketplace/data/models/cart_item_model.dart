import 'package:flutter/foundation.dart';

import '../../core/enums/media_asset_type.dart';

double _cartItemDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return fallback;
}

int _cartItemInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}

/// Ligne de panier représentant une photo ou un pack.
class CartItemModel {
  final String assetId;
  final MediaAssetType assetType;
  final String photographerId;
  final String? galleryId;
  final String? eventId;
  final String title;
  final String? thumbnailUrl;
  final double unitPrice;
  final String currency;
  final int quantity;
  final Map<String, dynamic> metadata;

  const CartItemModel({
    required this.assetId,
    required this.assetType,
    required this.photographerId,
    this.galleryId,
    this.eventId,
    required this.title,
    this.thumbnailUrl,
    this.unitPrice = 0,
    this.currency = 'EUR',
    this.quantity = 1,
    this.metadata = const <String, dynamic>{},
  });

  double get totalPrice => unitPrice * quantity;

  factory CartItemModel.fromMap(Map<String, dynamic> map) {
    return CartItemModel(
      assetId: map['assetId']?.toString() ?? '',
      assetType: mediaAssetTypeFromString(map['assetType']?.toString()),
      photographerId: map['photographerId']?.toString() ?? '',
      galleryId: map['galleryId']?.toString(),
      eventId: map['eventId']?.toString(),
      title: map['title']?.toString() ?? '',
      thumbnailUrl: map['thumbnailUrl']?.toString(),
      unitPrice: _cartItemDouble(map['unitPrice']),
      currency: map['currency']?.toString() ?? 'EUR',
      quantity: _cartItemInt(map['quantity'], fallback: 1),
      metadata: map['metadata'] is Map
          ? Map<String, dynamic>.from(map['metadata'] as Map)
          : const <String, dynamic>{},
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'assetId': assetId,
      'assetType': assetType.firestoreValue,
      'photographerId': photographerId,
      if (galleryId != null) 'galleryId': galleryId,
      if (eventId != null) 'eventId': eventId,
      'title': title,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      'unitPrice': unitPrice,
      'currency': currency,
      'quantity': quantity,
      'metadata': metadata,
    };
  }

  CartItemModel copyWith({
    String? assetId,
    MediaAssetType? assetType,
    String? photographerId,
    String? galleryId,
    String? eventId,
    String? title,
    String? thumbnailUrl,
    double? unitPrice,
    String? currency,
    int? quantity,
    Map<String, dynamic>? metadata,
  }) {
    return CartItemModel(
      assetId: assetId ?? this.assetId,
      assetType: assetType ?? this.assetType,
      photographerId: photographerId ?? this.photographerId,
      galleryId: galleryId ?? this.galleryId,
      eventId: eventId ?? this.eventId,
      title: title ?? this.title,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      unitPrice: unitPrice ?? this.unitPrice,
      currency: currency ?? this.currency,
      quantity: quantity ?? this.quantity,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CartItemModel &&
        other.assetId == assetId &&
        other.assetType == assetType &&
        other.photographerId == photographerId &&
        other.galleryId == galleryId &&
        other.eventId == eventId &&
        other.title == title &&
        other.thumbnailUrl == thumbnailUrl &&
        other.unitPrice == unitPrice &&
        other.currency == currency &&
        other.quantity == quantity &&
        mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(
        assetId,
        assetType,
        photographerId,
        galleryId,
        eventId,
        title,
        thumbnailUrl,
        unitPrice,
        currency,
        quantity,
        Object.hashAll(metadata.entries),
      );
}