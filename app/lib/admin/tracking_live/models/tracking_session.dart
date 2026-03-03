import 'package:cloud_firestore/cloud_firestore.dart';

class TrackingSession {
  const TrackingSession({
    required this.sessionId,
    required this.userId,
    required this.role,
    this.groupAdminId,
    this.trackerId,
    required this.startedAt,
    this.endedAt,
    this.durationSec,
    required this.isActive,
    this.countryId,
    this.eventRefId,
    this.circuitId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String sessionId;
  final String userId;
  final String role;
  final String? groupAdminId;
  final String? trackerId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationSec;
  final bool isActive;
  final String? countryId;
  final String? eventRefId;
  final String? circuitId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory TrackingSession.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return TrackingSession(
      sessionId: (data['sessionId'] as String?) ?? doc.id,
      userId: (data['userId'] as String?) ?? '',
      role: (data['role'] as String?) ?? '',
      groupAdminId: data['groupAdminId'] as String?,
      trackerId: data['trackerId'] as String?,
      startedAt: _tsToDate(data['startedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      endedAt: _tsToDate(data['endedAt']),
      durationSec: _numToInt(data['durationSec']),
      isActive: (data['isActive'] as bool?) ?? false,
      countryId: data['countryId'] as String?,
      eventRefId: data['eventRefId'] as String?,
      circuitId: data['circuitId'] as String?,
      createdAt: _tsToDate(data['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: _tsToDate(data['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  factory TrackingSession.fromMap(Map<String, dynamic> data) {
    return TrackingSession(
      sessionId: (data['sessionId'] as String?) ?? '',
      userId: (data['userId'] as String?) ?? '',
      role: (data['role'] as String?) ?? '',
      groupAdminId: data['groupAdminId'] as String?,
      trackerId: data['trackerId'] as String?,
      startedAt: _tsToDate(data['startedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      endedAt: _tsToDate(data['endedAt']),
      durationSec: _numToInt(data['durationSec']),
      isActive: (data['isActive'] as bool?) ?? false,
      countryId: data['countryId'] as String?,
      eventRefId: data['eventRefId'] as String?,
      circuitId: data['circuitId'] as String?,
      createdAt: _tsToDate(data['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: _tsToDate(data['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'userId': userId,
      'role': role,
      'groupAdminId': groupAdminId,
      'trackerId': trackerId,
      'startedAt': Timestamp.fromDate(startedAt),
      'endedAt': endedAt == null ? null : Timestamp.fromDate(endedAt!),
      'durationSec': durationSec,
      'isActive': isActive,
      'countryId': countryId,
      'eventRefId': eventRefId,
      'circuitId': circuitId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  TrackingSession copyWith({
    DateTime? endedAt,
    int? durationSec,
    bool? isActive,
    DateTime? updatedAt,
  }) {
    return TrackingSession(
      sessionId: sessionId,
      userId: userId,
      role: role,
      groupAdminId: groupAdminId,
      trackerId: trackerId,
      startedAt: startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSec: durationSec ?? this.durationSec,
      isActive: isActive ?? this.isActive,
      countryId: countryId,
      eventRefId: eventRefId,
      circuitId: circuitId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Duration get duration {
    if (durationSec != null) return Duration(seconds: durationSec!);
    final end = endedAt ?? DateTime.now();
    return end.difference(startedAt);
  }

  static int? _numToInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static DateTime? _tsToDate(Object? v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }
}
