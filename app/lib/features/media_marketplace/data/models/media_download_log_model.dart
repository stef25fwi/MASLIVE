import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/enums/media_asset_type.dart';
import '../mappers/timestamp_mapper.dart';

Map<String, dynamic> _downloadLogMap(dynamic value) {
  if (value is! Map) return const <String, dynamic>{};
  return Map<String, dynamic>.from(value);
}

/// Trace d'un téléchargement autorisé/refusé pour audit et sécurité.
class MediaDownloadLogModel {
  final String logId;
  final String buyerUid;
  final String entitlementId;
  final String assetId;
  final MediaAssetType assetType;
  final String? photoId;
  final String outcome;
  final String? signedUrlPath;
  final String? ipAddress;
  final String? userAgent;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const MediaDownloadLogModel({
    required this.logId,
    required this.buyerUid,
    required this.entitlementId,
    required this.assetId,
    required this.assetType,
    this.photoId,
    required this.outcome,
    this.signedUrlPath,
    this.ipAddress,
    this.userAgent,
    this.metadata = const <String, dynamic>{},
    required this.createdAt,
  });

  factory MediaDownloadLogModel.fromMap(Map<String, dynamic> map, {String? logId}) {
    return MediaDownloadLogModel(
      logId: logId ?? (map['logId']?.toString() ?? ''),
      buyerUid: map['buyerUid']?.toString() ?? '',
      entitlementId: map['entitlementId']?.toString() ?? '',
      assetId: map['assetId']?.toString() ?? '',
      assetType: mediaAssetTypeFromString(map['assetType']?.toString()),
      photoId: map['photoId']?.toString(),
      outcome: map['outcome']?.toString() ?? '',
      signedUrlPath: map['signedUrlPath']?.toString(),
      ipAddress: map['ipAddress']?.toString(),
      userAgent: map['userAgent']?.toString(),
      metadata: _downloadLogMap(map['metadata']),
      createdAt: TimestampMapper.fromFirestoreOrNow(map['createdAt']),
    );
  }

  factory MediaDownloadLogModel.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    return MediaDownloadLogModel.fromMap(doc.data() ?? const <String, dynamic>{}, logId: doc.id);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'logId': logId,
      'buyerUid': buyerUid,
      'entitlementId': entitlementId,
      'assetId': assetId,
      'assetType': assetType.firestoreValue,
      if (photoId != null) 'photoId': photoId,
      'outcome': outcome,
      if (signedUrlPath != null) 'signedUrlPath': signedUrlPath,
      if (ipAddress != null) 'ipAddress': ipAddress,
      if (userAgent != null) 'userAgent': userAgent,
      'metadata': metadata,
      'createdAt': TimestampMapper.toFirestore(createdAt),
    };
  }
}