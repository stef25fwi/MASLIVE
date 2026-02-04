// Modèles Session de tracking + Points GPS
// Collection: group_tracks/{adminGroupId}/sessions/{sessionId}
// Sub-collection: .../sessions/{sessionId}/points/{pointId}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'group_admin.dart';

class TrackSession {
  final String id;
  final String adminGroupId;
  final String uid; // qui a tracké (admin ou tracker)
  final String role; // "admin" ou "tracker"
  final DateTime startedAt;
  final DateTime? endedAt;
  final TrackSummary? summary;
  final DateTime updatedAt;

  TrackSession({
    required this.id,
    required this.adminGroupId,
    required this.uid,
    required this.role,
    required this.startedAt,
    this.endedAt,
    this.summary,
    required this.updatedAt,
  });

  bool get isActive => endedAt == null;

  factory TrackSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TrackSession(
      id: doc.id,
      adminGroupId: data['adminGroupId'] ?? '',
      uid: data['uid'] ?? '',
      role: data['role'] ?? 'tracker',
      startedAt: (data['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endedAt: (data['endedAt'] as Timestamp?)?.toDate(),
      summary: data['summary'] != null
          ? TrackSummary.fromMap(data['summary'])
          : null,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'adminGroupId': adminGroupId,
      'uid': uid,
      'role': role,
      'startedAt': Timestamp.fromDate(startedAt),
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'summary': summary?.toMap(),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

// Résumé calculé d'une session
class TrackSummary {
  final int durationSec;
  final double distanceM;
  final double ascentM; // dénivelé positif
  final double descentM; // dénivelé négatif
  final double avgSpeedMps; // vitesse moyenne m/s
  final int pointsCount;

  TrackSummary({
    required this.durationSec,
    required this.distanceM,
    required this.ascentM,
    required this.descentM,
    required this.avgSpeedMps,
    required this.pointsCount,
  });

  factory TrackSummary.fromMap(Map<String, dynamic> map) {
    return TrackSummary(
      durationSec: map['durationSec'] ?? 0,
      distanceM: (map['distanceM'] ?? 0.0).toDouble(),
      ascentM: (map['ascentM'] ?? 0.0).toDouble(),
      descentM: (map['descentM'] ?? 0.0).toDouble(),
      avgSpeedMps: (map['avgSpeedMps'] ?? 0.0).toDouble(),
      pointsCount: map['pointsCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'durationSec': durationSec,
      'distanceM': distanceM,
      'ascentM': ascentM,
      'descentM': descentM,
      'avgSpeedMps': avgSpeedMps,
      'pointsCount': pointsCount,
    };
  }

  // Getters formatés
  String get durationFormatted {
    final hours = durationSec ~/ 3600;
    final minutes = (durationSec % 3600) ~/ 60;
    final seconds = durationSec % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  String get distanceKm => (distanceM / 1000).toStringAsFixed(2);
  String get avgSpeedKmh => (avgSpeedMps * 3.6).toStringAsFixed(1);
}

// Point GPS individuel
// Sub-collection: group_tracks/{adminGroupId}/sessions/{sessionId}/points/{pointId}
class TrackPoint {
  final String id;
  final double lat;
  final double lng;
  final double? altitude;
  final double? accuracy;
  final DateTime timestamp;

  TrackPoint({
    required this.id,
    required this.lat,
    required this.lng,
    this.altitude,
    this.accuracy,
    required this.timestamp,
  });

  factory TrackPoint.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TrackPoint(
      id: doc.id,
      lat: (data['lat'] ?? 0.0).toDouble(),
      lng: (data['lng'] ?? 0.0).toDouble(),
      altitude: data['alt']?.toDouble(),
      accuracy: data['accuracy']?.toDouble(),
      timestamp: (data['ts'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'lat': lat,
      'lng': lng,
      'alt': altitude,
      'accuracy': accuracy,
      'ts': Timestamp.fromDate(timestamp),
    };
  }

  GeoPosition toGeoPosition() {
    return GeoPosition(
      lat: lat,
      lng: lng,
      altitude: altitude,
      accuracy: accuracy,
      timestamp: timestamp,
    );
  }

  // Validation point
  bool isValid() {
    if (lat == 0.0 && lng == 0.0) return false;
    if (accuracy != null && accuracy! > 100) return false;
    return true;
  }
}
