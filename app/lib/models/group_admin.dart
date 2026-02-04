// Modèle Administrateur Groupe
// Collection: group_admins/{adminUid}

import 'package:cloud_firestore/cloud_firestore.dart';

class GroupAdmin {
  final String uid;
  final String adminGroupId; // 6 digits unique
  final String displayName;
  final bool isVisible;
  final String? selectedMapId;
  final GeoPosition? lastPosition;
  final GeoPosition? averagePosition;
  final DateTime createdAt;
  final DateTime updatedAt;

  GroupAdmin({
    required this.uid,
    required this.adminGroupId,
    required this.displayName,
    this.isVisible = true,
    this.selectedMapId,
    this.lastPosition,
    this.averagePosition,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GroupAdmin.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupAdmin(
      uid: doc.id,
      adminGroupId: data['adminGroupId'] ?? '',
      displayName: data['displayName'] ?? '',
      isVisible: data['isVisible'] ?? true,
      selectedMapId: data['selectedMapId'],
      lastPosition: data['lastPosition'] != null
          ? GeoPosition.fromMap(data['lastPosition'])
          : null,
      averagePosition: data['averagePosition'] != null
          ? GeoPosition.fromMap(data['averagePosition'])
          : null,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'adminGroupId': adminGroupId,
      'displayName': displayName,
      'isVisible': isVisible,
      'selectedMapId': selectedMapId,
      'lastPosition': lastPosition?.toMap(),
      'averagePosition': averagePosition?.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  GroupAdmin copyWith({
    String? displayName,
    bool? isVisible,
    String? selectedMapId,
    GeoPosition? lastPosition,
    GeoPosition? averagePosition,
    DateTime? updatedAt,
  }) {
    return GroupAdmin(
      uid: uid,
      adminGroupId: adminGroupId,
      displayName: displayName ?? this.displayName,
      isVisible: isVisible ?? this.isVisible,
      selectedMapId: selectedMapId ?? this.selectedMapId,
      lastPosition: lastPosition ?? this.lastPosition,
      averagePosition: averagePosition ?? this.averagePosition,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Position géographique avec métadonnées
class GeoPosition {
  final double lat;
  final double lng;
  final double? altitude;
  final double? accuracy;
  final DateTime timestamp;

  GeoPosition({
    required this.lat,
    required this.lng,
    this.altitude,
    this.accuracy,
    required this.timestamp,
  });

  factory GeoPosition.fromMap(Map<String, dynamic> map) {
    return GeoPosition(
      lat: (map['lat'] ?? 0.0).toDouble(),
      lng: (map['lng'] ?? 0.0).toDouble(),
      altitude: map['alt']?.toDouble(),
      accuracy: map['accuracy']?.toDouble(),
      timestamp: (map['ts'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lat': lat,
      'lng': lng,
      'alt': altitude,
      'accuracy': accuracy,
      'ts': Timestamp.fromDate(timestamp),
    };
  }

  // Vérifie si la position est valide pour calcul moyenne
  bool isValidForAverage({int maxAgeSeconds = 20, double maxAccuracy = 50.0}) {
    final age = DateTime.now().difference(timestamp).inSeconds;
    if (age > maxAgeSeconds) return false;
    if (accuracy != null && accuracy! > maxAccuracy) return false;
    if (lat == 0.0 && lng == 0.0) return false;
    return true;
  }
}

// Répertoire des codes admin (lookup rapide)
// Collection: group_admin_codes/{adminGroupId}
class GroupAdminCode {
  final String adminGroupId;
  final String adminUid;
  final DateTime createdAt;
  final bool isActive;

  GroupAdminCode({
    required this.adminGroupId,
    required this.adminUid,
    required this.createdAt,
    this.isActive = true,
  });

  factory GroupAdminCode.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupAdminCode(
      adminGroupId: doc.id,
      adminUid: data['adminUid'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'adminUid': adminUid,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }
}
