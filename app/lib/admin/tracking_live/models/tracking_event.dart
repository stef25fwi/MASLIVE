import 'package:cloud_firestore/cloud_firestore.dart';

class TrackingEvent {
  const TrackingEvent({
    required this.eventId,
    required this.type,
    required this.userId,
    required this.role,
    this.groupAdminId,
    this.trackerId,
    this.sessionId,
    this.countryId,
    this.eventRefId,
    this.circuitId,
    required this.timestamp,
    this.metadata,
  });

  final String eventId;
  final String type; // login | logout | heartbeat | gps_ping | tracker_linked | tracker_unlinked
  final String userId;
  final String role; // group_admin | tracker_group
  final String? groupAdminId;
  final String? trackerId;
  final String? sessionId;
  final String? countryId;
  final String? eventRefId;
  final String? circuitId;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  factory TrackingEvent.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return TrackingEvent(
      eventId: (data['eventId'] as String?) ?? doc.id,
      type: (data['type'] as String?) ?? 'unknown',
      userId: (data['userId'] as String?) ?? '',
      role: (data['role'] as String?) ?? '',
      groupAdminId: data['groupAdminId'] as String?,
      trackerId: data['trackerId'] as String?,
      sessionId: data['sessionId'] as String?,
      countryId: data['countryId'] as String?,
      eventRefId: data['eventRefId'] as String?,
      circuitId: data['circuitId'] as String?,
      timestamp: _tsToDate(data['timestamp']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      metadata: data['metadata'] is Map
          ? Map<String, dynamic>.from(data['metadata'] as Map)
          : null,
    );
  }

  factory TrackingEvent.fromMap(Map<String, dynamic> data) {
    return TrackingEvent(
      eventId: (data['eventId'] as String?) ?? '',
      type: (data['type'] as String?) ?? 'unknown',
      userId: (data['userId'] as String?) ?? '',
      role: (data['role'] as String?) ?? '',
      groupAdminId: data['groupAdminId'] as String?,
      trackerId: data['trackerId'] as String?,
      sessionId: data['sessionId'] as String?,
      countryId: data['countryId'] as String?,
      eventRefId: data['eventRefId'] as String?,
      circuitId: data['circuitId'] as String?,
      timestamp: _tsToDate(data['timestamp']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      metadata: data['metadata'] is Map
          ? Map<String, dynamic>.from(data['metadata'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'type': type,
      'userId': userId,
      'role': role,
      'groupAdminId': groupAdminId,
      'trackerId': trackerId,
      'sessionId': sessionId,
      'countryId': countryId,
      'eventRefId': eventRefId,
      'circuitId': circuitId,
      'timestamp': Timestamp.fromDate(timestamp),
      'metadata': metadata,
    };
  }

  TrackingEvent copyWith({
    String? type,
    String? userId,
    String? role,
    String? groupAdminId,
    String? trackerId,
    String? sessionId,
    String? countryId,
    String? eventRefId,
    String? circuitId,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return TrackingEvent(
      eventId: eventId,
      type: type ?? this.type,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      groupAdminId: groupAdminId ?? this.groupAdminId,
      trackerId: trackerId ?? this.trackerId,
      sessionId: sessionId ?? this.sessionId,
      countryId: countryId ?? this.countryId,
      eventRefId: eventRefId ?? this.eventRefId,
      circuitId: circuitId ?? this.circuitId,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }

  static DateTime? _tsToDate(Object? v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }
}
