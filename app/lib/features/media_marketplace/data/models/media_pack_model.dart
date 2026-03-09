import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/enums/media_pack_pricing_mode.dart';
import '../mappers/timestamp_mapper.dart';

List<String> _packStringList(dynamic value) {
  if (value is! Iterable) return const <String>[];
  return value.map((item) => item.toString()).toList(growable: false);
}

int _packInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}

double _packDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return fallback;
}

/// Offre commerciale composee de plusieurs photos.
class MediaPackModel {
  final String packId;
  final String photographerId;
  final String ownerUid;
  final String galleryId;
  final String eventId;
  final String title;
  final String? description;
  final String? coverUrl;
  final MediaPackPricingMode pricingMode;
  final List<String> photoIds;
  final int? pickCount;
  final double price;
  final double? oldPrice;
  final String currency;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MediaPackModel({
    required this.packId,
    required this.photographerId,
    required this.ownerUid,
    required this.galleryId,
    required this.eventId,
    required this.title,
    this.description,
    this.coverUrl,
    this.pricingMode = MediaPackPricingMode.fixedPack,
    this.photoIds = const <String>[],
    this.pickCount,
    this.price = 0,
    this.oldPrice,
    this.currency = 'EUR',
    this.isActive = true,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MediaPackModel.fromMap(
    Map<String, dynamic> map, {
    String? packId,
  }) {
    return MediaPackModel(
      packId: packId ?? (map['packId']?.toString() ?? ''),
      photographerId: map['photographerId']?.toString() ?? '',
      ownerUid: map['ownerUid']?.toString() ?? '',
      galleryId: map['galleryId']?.toString() ?? '',
      eventId: map['eventId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString(),
      coverUrl: map['coverUrl']?.toString(),
      pricingMode: mediaPackPricingModeFromString(map['pricingMode']?.toString()),
      photoIds: _packStringList(map['photoIds']),
      pickCount: map['pickCount'] is num ? (map['pickCount'] as num).toInt() : null,
      price: _packDouble(map['price']),
      oldPrice: map['oldPrice'] is num ? (map['oldPrice'] as num).toDouble() : null,
      currency: map['currency']?.toString() ?? 'EUR',
      isActive: map['isActive'] as bool? ?? true,
      sortOrder: _packInt(map['sortOrder']),
      createdAt: TimestampMapper.fromFirestoreOrNow(map['createdAt']),
      updatedAt: TimestampMapper.fromFirestoreOrNow(map['updatedAt']),
    );
  }

  factory MediaPackModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return MediaPackModel.fromMap(doc.data() ?? const <String, dynamic>{}, packId: doc.id);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'packId': packId,
      'photographerId': photographerId,
      'ownerUid': ownerUid,
      'galleryId': galleryId,
      'eventId': eventId,
      'title': title,
      if (description != null) 'description': description,
      if (coverUrl != null) 'coverUrl': coverUrl,
      'pricingMode': pricingMode.firestoreValue,
      'photoIds': photoIds,
      if (pickCount != null) 'pickCount': pickCount,
      'price': price,
      if (oldPrice != null) 'oldPrice': oldPrice,
      'currency': currency,
      'isActive': isActive,
      'sortOrder': sortOrder,
      'createdAt': TimestampMapper.toFirestore(createdAt),
      'updatedAt': TimestampMapper.toFirestore(updatedAt),
    };
  }

  MediaPackModel copyWith({
    String? packId,
    String? photographerId,
    String? ownerUid,
    String? galleryId,
    String? eventId,
    String? title,
    String? description,
    String? coverUrl,
    MediaPackPricingMode? pricingMode,
    List<String>? photoIds,
    int? pickCount,
    double? price,
    double? oldPrice,
    String? currency,
    bool? isActive,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MediaPackModel(
      packId: packId ?? this.packId,
      photographerId: photographerId ?? this.photographerId,
      ownerUid: ownerUid ?? this.ownerUid,
      galleryId: galleryId ?? this.galleryId,
      eventId: eventId ?? this.eventId,
      title: title ?? this.title,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      pricingMode: pricingMode ?? this.pricingMode,
      photoIds: photoIds ?? this.photoIds,
      pickCount: pickCount ?? this.pickCount,
      price: price ?? this.price,
      oldPrice: oldPrice ?? this.oldPrice,
      currency: currency ?? this.currency,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaPackModel &&
        other.packId == packId &&
        other.photographerId == photographerId &&
        other.ownerUid == ownerUid &&
        other.galleryId == galleryId &&
        other.eventId == eventId &&
        other.title == title &&
        other.description == description &&
        other.coverUrl == coverUrl &&
        other.pricingMode == pricingMode &&
        listEquals(other.photoIds, photoIds) &&
        other.pickCount == pickCount &&
        other.price == price &&
        other.oldPrice == oldPrice &&
        other.currency == currency &&
        other.isActive == isActive &&
        other.sortOrder == sortOrder &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
        packId,
        photographerId,
        ownerUid,
        galleryId,
        eventId,
        title,
        description,
        coverUrl,
        pricingMode,
        Object.hashAll(photoIds),
        pickCount,
        price,
        oldPrice,
        currency,
        isActive,
        sortOrder,
        createdAt,
        updatedAt,
      );
}