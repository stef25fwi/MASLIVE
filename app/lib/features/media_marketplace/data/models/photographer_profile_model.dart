import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/enums/photographer_status.dart';
import '../mappers/timestamp_mapper.dart';

Map<String, String> _profileStringMap(dynamic value) {
  if (value is! Map) return const <String, String>{};
  return value.map(
    (key, mapValue) => MapEntry(key.toString(), mapValue?.toString() ?? ''),
  );
}

int _profileInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}

double _profileDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return fallback;
}

/// Profil public/metier d'un photographe marketplace.
class PhotographerProfileModel {
  final String photographerId;
  final String ownerUid;
  final String brandName;
  final String? bio;
  final String? avatarUrl;
  final String? coverUrl;
  final String? phone;
  final String? email;
  final String? country;
  final String? city;
  final Map<String, String> socialLinks;
  final PhotographerStatus status;
  final bool isVerified;
  final double averageRating;
  final int salesCount;
  final double totalRevenueGross;
  final double totalRevenueNet;
  final String? activeSubscriptionId;
  final String? activePlanId;
  final int publishedPhotoCount;
  final int activeGalleryCount;
  final int activePackCount;
  final int storageUsedBytes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PhotographerProfileModel({
    required this.photographerId,
    required this.ownerUid,
    required this.brandName,
    this.bio,
    this.avatarUrl,
    this.coverUrl,
    this.phone,
    this.email,
    this.country,
    this.city,
    this.socialLinks = const <String, String>{},
    this.status = PhotographerStatus.pending,
    this.isVerified = false,
    this.averageRating = 0,
    this.salesCount = 0,
    this.totalRevenueGross = 0,
    this.totalRevenueNet = 0,
    this.activeSubscriptionId,
    this.activePlanId,
    this.publishedPhotoCount = 0,
    this.activeGalleryCount = 0,
    this.activePackCount = 0,
    this.storageUsedBytes = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PhotographerProfileModel.fromMap(
    Map<String, dynamic> map, {
    String? photographerId,
  }) {
    return PhotographerProfileModel(
      photographerId: photographerId ?? (map['photographerId']?.toString() ?? ''),
      ownerUid: map['ownerUid']?.toString() ?? '',
      brandName: map['brandName']?.toString() ?? '',
      bio: map['bio']?.toString(),
      avatarUrl: map['avatarUrl']?.toString(),
      coverUrl: map['coverUrl']?.toString(),
      phone: map['phone']?.toString(),
      email: map['email']?.toString(),
      country: map['country']?.toString(),
      city: map['city']?.toString(),
      socialLinks: _profileStringMap(map['socialLinks']),
      status: photographerStatusFromString(map['status']?.toString()),
      isVerified: map['isVerified'] as bool? ?? false,
      averageRating: _profileDouble(map['averageRating']),
      salesCount: _profileInt(map['salesCount']),
      totalRevenueGross: _profileDouble(map['totalRevenueGross']),
      totalRevenueNet: _profileDouble(map['totalRevenueNet']),
      activeSubscriptionId: map['activeSubscriptionId']?.toString(),
      activePlanId: map['activePlanId']?.toString(),
      publishedPhotoCount: _profileInt(map['publishedPhotoCount']),
      activeGalleryCount: _profileInt(map['activeGalleryCount']),
      activePackCount: _profileInt(map['activePackCount']),
      storageUsedBytes: _profileInt(map['storageUsedBytes']),
      createdAt: TimestampMapper.fromFirestoreOrNow(map['createdAt']),
      updatedAt: TimestampMapper.fromFirestoreOrNow(map['updatedAt']),
    );
  }

  factory PhotographerProfileModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return PhotographerProfileModel.fromMap(doc.data() ?? const <String, dynamic>{}, photographerId: doc.id);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'photographerId': photographerId,
      'ownerUid': ownerUid,
      'brandName': brandName,
      if (bio != null) 'bio': bio,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (coverUrl != null) 'coverUrl': coverUrl,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (country != null) 'country': country,
      if (city != null) 'city': city,
      'socialLinks': socialLinks,
      'status': status.firestoreValue,
      'isVerified': isVerified,
      'averageRating': averageRating,
      'salesCount': salesCount,
      'totalRevenueGross': totalRevenueGross,
      'totalRevenueNet': totalRevenueNet,
      if (activeSubscriptionId != null) 'activeSubscriptionId': activeSubscriptionId,
      if (activePlanId != null) 'activePlanId': activePlanId,
      'publishedPhotoCount': publishedPhotoCount,
      'activeGalleryCount': activeGalleryCount,
      'activePackCount': activePackCount,
      'storageUsedBytes': storageUsedBytes,
      'createdAt': TimestampMapper.toFirestore(createdAt),
      'updatedAt': TimestampMapper.toFirestore(updatedAt),
    };
  }

  PhotographerProfileModel copyWith({
    String? photographerId,
    String? ownerUid,
    String? brandName,
    String? bio,
    String? avatarUrl,
    String? coverUrl,
    String? phone,
    String? email,
    String? country,
    String? city,
    Map<String, String>? socialLinks,
    PhotographerStatus? status,
    bool? isVerified,
    double? averageRating,
    int? salesCount,
    double? totalRevenueGross,
    double? totalRevenueNet,
    String? activeSubscriptionId,
    String? activePlanId,
    int? publishedPhotoCount,
    int? activeGalleryCount,
    int? activePackCount,
    int? storageUsedBytes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PhotographerProfileModel(
      photographerId: photographerId ?? this.photographerId,
      ownerUid: ownerUid ?? this.ownerUid,
      brandName: brandName ?? this.brandName,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      country: country ?? this.country,
      city: city ?? this.city,
      socialLinks: socialLinks ?? this.socialLinks,
      status: status ?? this.status,
      isVerified: isVerified ?? this.isVerified,
      averageRating: averageRating ?? this.averageRating,
      salesCount: salesCount ?? this.salesCount,
      totalRevenueGross: totalRevenueGross ?? this.totalRevenueGross,
      totalRevenueNet: totalRevenueNet ?? this.totalRevenueNet,
      activeSubscriptionId: activeSubscriptionId ?? this.activeSubscriptionId,
      activePlanId: activePlanId ?? this.activePlanId,
      publishedPhotoCount: publishedPhotoCount ?? this.publishedPhotoCount,
      activeGalleryCount: activeGalleryCount ?? this.activeGalleryCount,
      activePackCount: activePackCount ?? this.activePackCount,
      storageUsedBytes: storageUsedBytes ?? this.storageUsedBytes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PhotographerProfileModel &&
        other.photographerId == photographerId &&
        other.ownerUid == ownerUid &&
        other.brandName == brandName &&
        other.bio == bio &&
        other.avatarUrl == avatarUrl &&
        other.coverUrl == coverUrl &&
        other.phone == phone &&
        other.email == email &&
        other.country == country &&
        other.city == city &&
        mapEquals(other.socialLinks, socialLinks) &&
        other.status == status &&
        other.isVerified == isVerified &&
        other.averageRating == averageRating &&
        other.salesCount == salesCount &&
        other.totalRevenueGross == totalRevenueGross &&
        other.totalRevenueNet == totalRevenueNet &&
        other.activeSubscriptionId == activeSubscriptionId &&
        other.activePlanId == activePlanId &&
        other.publishedPhotoCount == publishedPhotoCount &&
        other.activeGalleryCount == activeGalleryCount &&
        other.activePackCount == activePackCount &&
        other.storageUsedBytes == storageUsedBytes &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
        photographerId,
        ownerUid,
        brandName,
        bio,
        avatarUrl,
        coverUrl,
        phone,
        email,
        country,
        city,
        Object.hashAll(socialLinks.entries),
        status,
        isVerified,
        averageRating,
        salesCount,
        totalRevenueGross,
        totalRevenueNet,
        activeSubscriptionId,
        activePlanId,
        publishedPhotoCount,
        activeGalleryCount,
        activePackCount,
        storageUsedBytes,
        createdAt,
        updatedAt,
      ]);
}