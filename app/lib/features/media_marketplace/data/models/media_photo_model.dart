import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/enums/media_visibility.dart';
import '../../core/enums/moderation_status.dart';
import '../../core/enums/photo_lifecycle_status.dart';
import '../mappers/timestamp_mapper.dart';

List<String> _photoStringList(dynamic value) {
  if (value is! Iterable) return const <String>[];
  return value.map((item) => item.toString()).toList(growable: false);
}

Map<String, dynamic> _photoMap(dynamic value) {
  if (value is! Map) return const <String, dynamic>{};
  return Map<String, dynamic>.from(value);
}

int? _photoNullableInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

double _photoDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return fallback;
}

/// Photo vendable ou consultable dans la marketplace.
class MediaPhotoModel {
  final String photoId;
  final String photographerId;
  final String ownerUid;
  final String galleryId;
  final String eventId;
  final String countryId;
  final String? countryName;
  final String circuitId;
  final String? circuitName;
  final String? eventName;
  final String originalPath;
  final String previewPath;
  final String thumbnailPath;
  final String watermarkedPath;
  final String downloadFileName;
  final int? width;
  final int? height;
  final int? sizeBytes;
  final String? mimeType;
  final String? hash;
  final Map<String, dynamic> exif;
  final List<String> tags;
  final List<String> faceTags;
  final String? bibNumber;
  final int? sequenceNo;
  final DateTime? shotAt;
  final ModerationStatus moderationStatus;
  final PhotoLifecycleStatus lifecycleStatus;
  final MediaVisibility visibility;
  final bool isPublished;
  final bool isForSale;
  final double unitPrice;
  final String currency;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MediaPhotoModel({
    required this.photoId,
    required this.photographerId,
    required this.ownerUid,
    required this.galleryId,
    required this.eventId,
    required this.countryId,
    this.countryName,
    required this.circuitId,
    this.circuitName,
    this.eventName,
    required this.originalPath,
    required this.previewPath,
    required this.thumbnailPath,
    required this.watermarkedPath,
    required this.downloadFileName,
    this.width,
    this.height,
    this.sizeBytes,
    this.mimeType,
    this.hash,
    this.exif = const <String, dynamic>{},
    this.tags = const <String>[],
    this.faceTags = const <String>[],
    this.bibNumber,
    this.sequenceNo,
    this.shotAt,
    this.moderationStatus = ModerationStatus.pending,
    this.lifecycleStatus = PhotoLifecycleStatus.draft,
    this.visibility = MediaVisibility.private,
    this.isPublished = false,
    this.isForSale = false,
    this.unitPrice = 0,
    this.currency = 'EUR',
    required this.createdAt,
    required this.updatedAt,
  });

  factory MediaPhotoModel.fromMap(
    Map<String, dynamic> map, {
    String? photoId,
  }) {
    return MediaPhotoModel(
      photoId: photoId ?? (map['photoId']?.toString() ?? ''),
      photographerId: map['photographerId']?.toString() ?? '',
      ownerUid: map['ownerUid']?.toString() ?? '',
      galleryId: map['galleryId']?.toString() ?? '',
      eventId: map['eventId']?.toString() ?? '',
      countryId: map['countryId']?.toString() ?? '',
      countryName: map['countryName']?.toString(),
      circuitId: map['circuitId']?.toString() ?? '',
      circuitName: map['circuitName']?.toString(),
      eventName: map['eventName']?.toString(),
      originalPath: map['originalPath']?.toString() ?? '',
      previewPath: map['previewPath']?.toString() ?? '',
      thumbnailPath: map['thumbnailPath']?.toString() ?? '',
      watermarkedPath: map['watermarkedPath']?.toString() ?? '',
      downloadFileName: map['downloadFileName']?.toString() ?? '',
      width: _photoNullableInt(map['width']),
      height: _photoNullableInt(map['height']),
      sizeBytes: _photoNullableInt(map['sizeBytes']),
      mimeType: map['mimeType']?.toString(),
      hash: map['hash']?.toString(),
      exif: _photoMap(map['exif']),
      tags: _photoStringList(map['tags']),
      faceTags: _photoStringList(map['faceTags']),
      bibNumber: map['bibNumber']?.toString(),
      sequenceNo: _photoNullableInt(map['sequenceNo']),
      shotAt: TimestampMapper.fromFirestore(map['shotAt']),
      moderationStatus: moderationStatusFromString(map['moderationStatus']?.toString()),
      lifecycleStatus: photoLifecycleStatusFromString(map['lifecycleStatus']?.toString()),
      visibility: mediaVisibilityFromString(map['visibility']?.toString()),
      isPublished: map['isPublished'] as bool? ?? false,
      isForSale: map['isForSale'] as bool? ?? false,
      unitPrice: _photoDouble(map['unitPrice']),
      currency: map['currency']?.toString() ?? 'EUR',
      createdAt: TimestampMapper.fromFirestoreOrNow(map['createdAt']),
      updatedAt: TimestampMapper.fromFirestoreOrNow(map['updatedAt']),
    );
  }

  factory MediaPhotoModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return MediaPhotoModel.fromMap(doc.data() ?? const <String, dynamic>{}, photoId: doc.id);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'photoId': photoId,
      'photographerId': photographerId,
      'ownerUid': ownerUid,
      'galleryId': galleryId,
      'eventId': eventId,
      'countryId': countryId,
      if (countryName != null) 'countryName': countryName,
      'circuitId': circuitId,
      if (circuitName != null) 'circuitName': circuitName,
      if (eventName != null) 'eventName': eventName,
      'originalPath': originalPath,
      'previewPath': previewPath,
      'thumbnailPath': thumbnailPath,
      'watermarkedPath': watermarkedPath,
      'downloadFileName': downloadFileName,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (sizeBytes != null) 'sizeBytes': sizeBytes,
      if (mimeType != null) 'mimeType': mimeType,
      if (hash != null) 'hash': hash,
      'exif': exif,
      'tags': tags,
      'faceTags': faceTags,
      if (bibNumber != null) 'bibNumber': bibNumber,
      if (sequenceNo != null) 'sequenceNo': sequenceNo,
      if (shotAt != null) 'shotAt': TimestampMapper.toFirestore(shotAt),
      'moderationStatus': moderationStatus.firestoreValue,
      'lifecycleStatus': lifecycleStatus.firestoreValue,
      'visibility': visibility.firestoreValue,
      'isPublished': isPublished,
      'isForSale': isForSale,
      'unitPrice': unitPrice,
      'currency': currency,
      'createdAt': TimestampMapper.toFirestore(createdAt),
      'updatedAt': TimestampMapper.toFirestore(updatedAt),
    };
  }

  MediaPhotoModel copyWith({
    String? photoId,
    String? photographerId,
    String? ownerUid,
    String? galleryId,
    String? eventId,
    String? countryId,
    String? countryName,
    String? circuitId,
    String? circuitName,
    String? eventName,
    String? originalPath,
    String? previewPath,
    String? thumbnailPath,
    String? watermarkedPath,
    String? downloadFileName,
    int? width,
    int? height,
    int? sizeBytes,
    String? mimeType,
    String? hash,
    Map<String, dynamic>? exif,
    List<String>? tags,
    List<String>? faceTags,
    String? bibNumber,
    int? sequenceNo,
    DateTime? shotAt,
    ModerationStatus? moderationStatus,
    PhotoLifecycleStatus? lifecycleStatus,
    MediaVisibility? visibility,
    bool? isPublished,
    bool? isForSale,
    double? unitPrice,
    String? currency,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MediaPhotoModel(
      photoId: photoId ?? this.photoId,
      photographerId: photographerId ?? this.photographerId,
      ownerUid: ownerUid ?? this.ownerUid,
      galleryId: galleryId ?? this.galleryId,
      eventId: eventId ?? this.eventId,
      countryId: countryId ?? this.countryId,
      countryName: countryName ?? this.countryName,
      circuitId: circuitId ?? this.circuitId,
      circuitName: circuitName ?? this.circuitName,
      eventName: eventName ?? this.eventName,
      originalPath: originalPath ?? this.originalPath,
      previewPath: previewPath ?? this.previewPath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      watermarkedPath: watermarkedPath ?? this.watermarkedPath,
      downloadFileName: downloadFileName ?? this.downloadFileName,
      width: width ?? this.width,
      height: height ?? this.height,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      mimeType: mimeType ?? this.mimeType,
      hash: hash ?? this.hash,
      exif: exif ?? this.exif,
      tags: tags ?? this.tags,
      faceTags: faceTags ?? this.faceTags,
      bibNumber: bibNumber ?? this.bibNumber,
      sequenceNo: sequenceNo ?? this.sequenceNo,
      shotAt: shotAt ?? this.shotAt,
      moderationStatus: moderationStatus ?? this.moderationStatus,
      lifecycleStatus: lifecycleStatus ?? this.lifecycleStatus,
      visibility: visibility ?? this.visibility,
      isPublished: isPublished ?? this.isPublished,
      isForSale: isForSale ?? this.isForSale,
      unitPrice: unitPrice ?? this.unitPrice,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaPhotoModel &&
        other.photoId == photoId &&
        other.photographerId == photographerId &&
        other.ownerUid == ownerUid &&
        other.galleryId == galleryId &&
        other.eventId == eventId &&
        other.countryId == countryId &&
        other.countryName == countryName &&
        other.circuitId == circuitId &&
        other.circuitName == circuitName &&
        other.eventName == eventName &&
        other.originalPath == originalPath &&
        other.previewPath == previewPath &&
        other.thumbnailPath == thumbnailPath &&
        other.watermarkedPath == watermarkedPath &&
        other.downloadFileName == downloadFileName &&
        other.width == width &&
        other.height == height &&
        other.sizeBytes == sizeBytes &&
        other.mimeType == mimeType &&
        other.hash == hash &&
        mapEquals(other.exif, exif) &&
        listEquals(other.tags, tags) &&
        listEquals(other.faceTags, faceTags) &&
        other.bibNumber == bibNumber &&
        other.sequenceNo == sequenceNo &&
        other.shotAt == shotAt &&
        other.moderationStatus == moderationStatus &&
        other.lifecycleStatus == lifecycleStatus &&
        other.visibility == visibility &&
        other.isPublished == isPublished &&
        other.isForSale == isForSale &&
        other.unitPrice == unitPrice &&
        other.currency == currency &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
        photoId,
        photographerId,
        ownerUid,
        galleryId,
        eventId,
        countryId,
        countryName,
        circuitId,
        circuitName,
        eventName,
        originalPath,
        previewPath,
        thumbnailPath,
        watermarkedPath,
        downloadFileName,
        width,
        height,
        sizeBytes,
        mimeType,
        hash,
        Object.hashAll(exif.entries),
        Object.hashAll(tags),
        Object.hashAll(faceTags),
        bibNumber,
        sequenceNo,
        shotAt,
        moderationStatus,
        lifecycleStatus,
        visibility,
        isPublished,
        isForSale,
        unitPrice,
        currency,
        createdAt,
        updatedAt,
      ]);
}