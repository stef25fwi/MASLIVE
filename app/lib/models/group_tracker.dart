// Modèle Tracker Groupe
// Collection: group_trackers/{trackerUid}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'group_admin.dart';

class GroupTracker {
  final String uid;
  final String? adminGroupId;
  final String? linkedAdminUid;
  final String displayName;
  final GeoPosition? lastPosition;
  final DateTime createdAt;
  final DateTime updatedAt;

  GroupTracker({
    required this.uid,
    this.adminGroupId,
    this.linkedAdminUid,
    required this.displayName,
    this.lastPosition,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isLinked => adminGroupId != null && linkedAdminUid != null;

  factory GroupTracker.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupTracker(
      uid: doc.id,
      adminGroupId: data['adminGroupId'],
      linkedAdminUid: data['linkedAdminUid'],
      displayName: data['displayName'] ?? '',
      lastPosition: data['lastPosition'] != null
          ? GeoPosition.fromMap(data['lastPosition'])
          : null,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'adminGroupId': adminGroupId,
      'linkedAdminUid': linkedAdminUid,
      'displayName': displayName,
      'lastPosition': lastPosition?.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  GroupTracker copyWith({
    String? adminGroupId,
    String? linkedAdminUid,
    String? displayName,
    GeoPosition? lastPosition,
    DateTime? updatedAt,
  }) {
    return GroupTracker(
      uid: uid,
      adminGroupId: adminGroupId ?? this.adminGroupId,
      linkedAdminUid: linkedAdminUid ?? this.linkedAdminUid,
      displayName: displayName ?? this.displayName,
      lastPosition: lastPosition ?? this.lastPosition,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
