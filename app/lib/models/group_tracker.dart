// Modèle Tracker Groupe
// Collection: group_trackers/{trackerUid}

import 'package:cloud_firestore/cloud_firestore.dart';

import 'group_admin.dart';

class GroupTracker {
  const GroupTracker({
    required this.uid,
    this.adminGroupId,
    this.linkedAdminUid,
    required this.displayName,
    this.lastPosition,
    this.trackingActive = false,
    this.trackingSessionId,
    this.trackingStoppedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String uid;
  final String? adminGroupId;
  final String? linkedAdminUid;
  final String displayName;
  final GeoPosition? lastPosition;
  final bool trackingActive;
  final String? trackingSessionId;
  final DateTime? trackingStoppedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isLinked => adminGroupId != null && linkedAdminUid != null;

  factory GroupTracker.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupTracker(
      uid: doc.id,
      adminGroupId: data['adminGroupId'] as String?,
      linkedAdminUid: data['linkedAdminUid'] as String?,
      displayName: (data['displayName'] as String?) ?? '',
      lastPosition: data['lastPosition'] is Map
          ? GeoPosition.fromMap(
              Map<String, dynamic>.from(data['lastPosition'] as Map),
            )
          : null,
      trackingActive: data['trackingActive'] == true,
      trackingSessionId: data['trackingSessionId'] as String?,
      trackingStoppedAt: (data['trackingStoppedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'uid': uid,
      'adminGroupId': adminGroupId,
      'linkedAdminUid': linkedAdminUid,
      'displayName': displayName,
      'lastPosition': lastPosition?.toMap(),
      'trackingActive': trackingActive,
      'trackingSessionId': trackingSessionId,
      'trackingStoppedAt': trackingStoppedAt == null
          ? null
          : Timestamp.fromDate(trackingStoppedAt!),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  GroupTracker copyWith({
    String? adminGroupId,
    String? linkedAdminUid,
    String? displayName,
    GeoPosition? lastPosition,
    bool? trackingActive,
    String? trackingSessionId,
    DateTime? trackingStoppedAt,
    DateTime? updatedAt,
  }) {
    return GroupTracker(
      uid: uid,
      adminGroupId: adminGroupId ?? this.adminGroupId,
      linkedAdminUid: linkedAdminUid ?? this.linkedAdminUid,
      displayName: displayName ?? this.displayName,
      lastPosition: lastPosition ?? this.lastPosition,
      trackingActive: trackingActive ?? this.trackingActive,
      trackingSessionId: trackingSessionId ?? this.trackingSessionId,
      trackingStoppedAt: trackingStoppedAt ?? this.trackingStoppedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
