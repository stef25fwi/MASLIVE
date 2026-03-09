import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/enums/media_asset_type.dart';
import '../mappers/timestamp_mapper.dart';

int _entitlementInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}

List<String> _entitlementStringList(dynamic value) {
  if (value is! Iterable) return const <String>[];
  return value.map((item) => item.toString()).toList(growable: false);
}

/// Droit d'accès HD ou téléchargement après achat validé.
class MediaEntitlementModel {
  final String entitlementId;
  final String buyerUid;
  final String orderId;
  final String assetId;
  final MediaAssetType assetType;
  final String photographerId;
  final List<String> photoIds;
  final int downloadCount;
  final int? downloadLimit;
  final DateTime? expiresAt;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MediaEntitlementModel({
    required this.entitlementId,
    required this.buyerUid,
    required this.orderId,
    required this.assetId,
    required this.assetType,
    required this.photographerId,
    this.photoIds = const <String>[],
    this.downloadCount = 0,
    this.downloadLimit,
    this.expiresAt,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MediaEntitlementModel.fromMap(
    Map<String, dynamic> map, {
    String? entitlementId,
  }) {
    return MediaEntitlementModel(
      entitlementId: entitlementId ?? (map['entitlementId']?.toString() ?? ''),
      buyerUid: map['buyerUid']?.toString() ?? '',
      orderId: map['orderId']?.toString() ?? '',
      assetId: map['assetId']?.toString() ?? '',
      assetType: mediaAssetTypeFromString(map['assetType']?.toString()),
      photographerId: map['photographerId']?.toString() ?? '',
      photoIds: _entitlementStringList(map['photoIds']),
      downloadCount: _entitlementInt(map['downloadCount']),
      downloadLimit: map['downloadLimit'] is num
          ? (map['downloadLimit'] as num).toInt()
          : null,
      expiresAt: TimestampMapper.fromFirestore(map['expiresAt']),
      isActive: map['isActive'] as bool? ?? true,
      createdAt: TimestampMapper.fromFirestoreOrNow(map['createdAt']),
      updatedAt: TimestampMapper.fromFirestoreOrNow(map['updatedAt']),
    );
  }

  factory MediaEntitlementModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return MediaEntitlementModel.fromMap(doc.data() ?? const <String, dynamic>{}, entitlementId: doc.id);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'entitlementId': entitlementId,
      'buyerUid': buyerUid,
      'orderId': orderId,
      'assetId': assetId,
      'assetType': assetType.firestoreValue,
      'photographerId': photographerId,
      'photoIds': photoIds,
      'downloadCount': downloadCount,
      if (downloadLimit != null) 'downloadLimit': downloadLimit,
      if (expiresAt != null) 'expiresAt': TimestampMapper.toFirestore(expiresAt),
      'isActive': isActive,
      'createdAt': TimestampMapper.toFirestore(createdAt),
      'updatedAt': TimestampMapper.toFirestore(updatedAt),
    };
  }

  MediaEntitlementModel copyWith({
    String? entitlementId,
    String? buyerUid,
    String? orderId,
    String? assetId,
    MediaAssetType? assetType,
    String? photographerId,
    List<String>? photoIds,
    int? downloadCount,
    int? downloadLimit,
    DateTime? expiresAt,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MediaEntitlementModel(
      entitlementId: entitlementId ?? this.entitlementId,
      buyerUid: buyerUid ?? this.buyerUid,
      orderId: orderId ?? this.orderId,
      assetId: assetId ?? this.assetId,
      assetType: assetType ?? this.assetType,
      photographerId: photographerId ?? this.photographerId,
      photoIds: photoIds ?? this.photoIds,
      downloadCount: downloadCount ?? this.downloadCount,
      downloadLimit: downloadLimit ?? this.downloadLimit,
      expiresAt: expiresAt ?? this.expiresAt,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}