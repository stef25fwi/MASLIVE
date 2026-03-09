import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/enums/moderation_status.dart';
import '../mappers/timestamp_mapper.dart';

Map<String, dynamic> _moderationQueueMap(dynamic value) {
  if (value is! Map) return const <String, dynamic>{};
  return Map<String, dynamic>.from(value);
}

/// File d'attente de modération admin pour photographes, galeries, photos ou packs.
class AdminModerationQueueModel {
  final String queueId;
  final String entityType;
  final String entityId;
  final String? photographerId;
  final String? ownerUid;
  final ModerationStatus status;
  final String? reason;
  final String? assignedAdminUid;
  final Map<String, dynamic> snapshot;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? reviewedAt;

  const AdminModerationQueueModel({
    required this.queueId,
    required this.entityType,
    required this.entityId,
    this.photographerId,
    this.ownerUid,
    this.status = ModerationStatus.pending,
    this.reason,
    this.assignedAdminUid,
    this.snapshot = const <String, dynamic>{},
    required this.createdAt,
    required this.updatedAt,
    this.reviewedAt,
  });

  factory AdminModerationQueueModel.fromMap(Map<String, dynamic> map, {String? queueId}) {
    return AdminModerationQueueModel(
      queueId: queueId ?? (map['queueId']?.toString() ?? ''),
      entityType: map['entityType']?.toString() ?? '',
      entityId: map['entityId']?.toString() ?? '',
      photographerId: map['photographerId']?.toString(),
      ownerUid: map['ownerUid']?.toString(),
      status: moderationStatusFromString(map['status']?.toString()),
      reason: map['reason']?.toString(),
      assignedAdminUid: map['assignedAdminUid']?.toString(),
      snapshot: _moderationQueueMap(map['snapshot']),
      createdAt: TimestampMapper.fromFirestoreOrNow(map['createdAt']),
      updatedAt: TimestampMapper.fromFirestoreOrNow(map['updatedAt']),
      reviewedAt: TimestampMapper.fromFirestore(map['reviewedAt']),
    );
  }

  factory AdminModerationQueueModel.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    return AdminModerationQueueModel.fromMap(doc.data() ?? const <String, dynamic>{}, queueId: doc.id);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'queueId': queueId,
      'entityType': entityType,
      'entityId': entityId,
      if (photographerId != null) 'photographerId': photographerId,
      if (ownerUid != null) 'ownerUid': ownerUid,
      'status': status.firestoreValue,
      if (reason != null) 'reason': reason,
      if (assignedAdminUid != null) 'assignedAdminUid': assignedAdminUid,
      'snapshot': snapshot,
      'createdAt': TimestampMapper.toFirestore(createdAt),
      'updatedAt': TimestampMapper.toFirestore(updatedAt),
      if (reviewedAt != null) 'reviewedAt': TimestampMapper.toFirestore(reviewedAt),
    };
  }

  AdminModerationQueueModel copyWith({
    String? queueId,
    String? entityType,
    String? entityId,
    String? photographerId,
    String? ownerUid,
    ModerationStatus? status,
    String? reason,
    String? assignedAdminUid,
    Map<String, dynamic>? snapshot,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? reviewedAt,
  }) {
    return AdminModerationQueueModel(
      queueId: queueId ?? this.queueId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      photographerId: photographerId ?? this.photographerId,
      ownerUid: ownerUid ?? this.ownerUid,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      assignedAdminUid: assignedAdminUid ?? this.assignedAdminUid,
      snapshot: snapshot ?? this.snapshot,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }
}