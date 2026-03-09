import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/enums/gallery_status.dart';
import '../../core/enums/media_visibility.dart';
import '../mappers/timestamp_mapper.dart';

List<String> _galleryStringList(dynamic value) {
  if (value is! Iterable) return const <String>[];
  return value.map((item) => item.toString()).toList(growable: false);
}

int _galleryInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}

/// Galerie marketplace rattachee a un evenement et a un photographe.
class MediaGalleryModel {
  final String galleryId;
  final String photographerId;
  final String ownerUid;
  final String eventId;
  final String title;
  final String? description;
  final String? coverPhotoId;
  final String? coverUrl;
  final MediaVisibility visibility;
  final GalleryStatus status;
  final List<String> tags;
  final String? linkedCountry;
  final String? linkedCircuitId;
  final List<String> linkedGroupIds;
  final int photoCount;
  final int publishedPhotoCount;
  final int packCount;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MediaGalleryModel({
    required this.galleryId,
    required this.photographerId,
    required this.ownerUid,
    required this.eventId,
    required this.title,
    this.description,
    this.coverPhotoId,
    this.coverUrl,
    this.visibility = MediaVisibility.private,
    this.status = GalleryStatus.draft,
    this.tags = const <String>[],
    this.linkedCountry,
    this.linkedCircuitId,
    this.linkedGroupIds = const <String>[],
    this.photoCount = 0,
    this.publishedPhotoCount = 0,
    this.packCount = 0,
    this.publishedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MediaGalleryModel.fromMap(
    Map<String, dynamic> map, {
    String? galleryId,
  }) {
    return MediaGalleryModel(
      galleryId: galleryId ?? (map['galleryId']?.toString() ?? ''),
      photographerId: map['photographerId']?.toString() ?? '',
      ownerUid: map['ownerUid']?.toString() ?? '',
      eventId: map['eventId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString(),
      coverPhotoId: map['coverPhotoId']?.toString(),
      coverUrl: map['coverUrl']?.toString(),
      visibility: mediaVisibilityFromString(map['visibility']?.toString()),
      status: galleryStatusFromString(map['status']?.toString()),
      tags: _galleryStringList(map['tags']),
      linkedCountry: map['linkedCountry']?.toString(),
      linkedCircuitId: map['linkedCircuitId']?.toString(),
      linkedGroupIds: _galleryStringList(map['linkedGroupIds']),
      photoCount: _galleryInt(map['photoCount']),
      publishedPhotoCount: _galleryInt(map['publishedPhotoCount']),
      packCount: _galleryInt(map['packCount']),
      publishedAt: TimestampMapper.fromFirestore(map['publishedAt']),
      createdAt: TimestampMapper.fromFirestoreOrNow(map['createdAt']),
      updatedAt: TimestampMapper.fromFirestoreOrNow(map['updatedAt']),
    );
  }

  factory MediaGalleryModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return MediaGalleryModel.fromMap(doc.data() ?? const <String, dynamic>{}, galleryId: doc.id);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'galleryId': galleryId,
      'photographerId': photographerId,
      'ownerUid': ownerUid,
      'eventId': eventId,
      'title': title,
      if (description != null) 'description': description,
      if (coverPhotoId != null) 'coverPhotoId': coverPhotoId,
      if (coverUrl != null) 'coverUrl': coverUrl,
      'visibility': visibility.firestoreValue,
      'status': status.firestoreValue,
      'tags': tags,
      if (linkedCountry != null) 'linkedCountry': linkedCountry,
      if (linkedCircuitId != null) 'linkedCircuitId': linkedCircuitId,
      'linkedGroupIds': linkedGroupIds,
      'photoCount': photoCount,
      'publishedPhotoCount': publishedPhotoCount,
      'packCount': packCount,
      if (publishedAt != null) 'publishedAt': TimestampMapper.toFirestore(publishedAt),
      'createdAt': TimestampMapper.toFirestore(createdAt),
      'updatedAt': TimestampMapper.toFirestore(updatedAt),
    };
  }

  MediaGalleryModel copyWith({
    String? galleryId,
    String? photographerId,
    String? ownerUid,
    String? eventId,
    String? title,
    String? description,
    String? coverPhotoId,
    String? coverUrl,
    MediaVisibility? visibility,
    GalleryStatus? status,
    List<String>? tags,
    String? linkedCountry,
    String? linkedCircuitId,
    List<String>? linkedGroupIds,
    int? photoCount,
    int? publishedPhotoCount,
    int? packCount,
    DateTime? publishedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MediaGalleryModel(
      galleryId: galleryId ?? this.galleryId,
      photographerId: photographerId ?? this.photographerId,
      ownerUid: ownerUid ?? this.ownerUid,
      eventId: eventId ?? this.eventId,
      title: title ?? this.title,
      description: description ?? this.description,
      coverPhotoId: coverPhotoId ?? this.coverPhotoId,
      coverUrl: coverUrl ?? this.coverUrl,
      visibility: visibility ?? this.visibility,
      status: status ?? this.status,
      tags: tags ?? this.tags,
      linkedCountry: linkedCountry ?? this.linkedCountry,
      linkedCircuitId: linkedCircuitId ?? this.linkedCircuitId,
      linkedGroupIds: linkedGroupIds ?? this.linkedGroupIds,
      photoCount: photoCount ?? this.photoCount,
      publishedPhotoCount: publishedPhotoCount ?? this.publishedPhotoCount,
      packCount: packCount ?? this.packCount,
      publishedAt: publishedAt ?? this.publishedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaGalleryModel &&
        other.galleryId == galleryId &&
        other.photographerId == photographerId &&
        other.ownerUid == ownerUid &&
        other.eventId == eventId &&
        other.title == title &&
        other.description == description &&
        other.coverPhotoId == coverPhotoId &&
        other.coverUrl == coverUrl &&
        other.visibility == visibility &&
        other.status == status &&
        listEquals(other.tags, tags) &&
        other.linkedCountry == linkedCountry &&
        other.linkedCircuitId == linkedCircuitId &&
        listEquals(other.linkedGroupIds, linkedGroupIds) &&
        other.photoCount == photoCount &&
        other.publishedPhotoCount == publishedPhotoCount &&
        other.packCount == packCount &&
        other.publishedAt == publishedAt &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
        galleryId,
        photographerId,
        ownerUid,
        eventId,
        title,
        description,
        coverPhotoId,
        coverUrl,
        visibility,
        status,
        Object.hashAll(tags),
        linkedCountry,
        linkedCircuitId,
        Object.hashAll(linkedGroupIds),
        photoCount,
        publishedPhotoCount,
        packCount,
        publishedAt,
        createdAt,
        updatedAt,
      );
}