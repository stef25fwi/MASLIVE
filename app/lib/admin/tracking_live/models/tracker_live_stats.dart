import 'package:cloud_firestore/cloud_firestore.dart';

class TrackerLiveStats {
  const TrackerLiveStats({
    required this.trackerId,
    required this.parentGroupAdminId,
    this.trackerDisplayName,
    required this.isOnline,
    this.lastSeenAt,
    this.currentSessionId,
    this.currentSessionStartAt,
    this.gpsPingCountSession,
    this.gpsPingCountToday,
    this.lastGpsAt,
    this.batteryLevel,
    this.gpsAccuracy,
    this.updatedAt,
  });

  final String trackerId;
  final String parentGroupAdminId;
  final String? trackerDisplayName;
  final bool isOnline;
  final DateTime? lastSeenAt;
  final String? currentSessionId;
  final DateTime? currentSessionStartAt;
  final int? gpsPingCountSession;
  final int? gpsPingCountToday;
  final DateTime? lastGpsAt;
  final double? batteryLevel;
  final double? gpsAccuracy;
  final DateTime? updatedAt;

  factory TrackerLiveStats.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return TrackerLiveStats(
      trackerId: (data['trackerId'] as String?) ?? doc.id,
      parentGroupAdminId: (data['parentGroupAdminId'] as String?) ?? '',
      trackerDisplayName: data['trackerDisplayName'] as String?,
      isOnline: (data['isOnline'] as bool?) ?? false,
      lastSeenAt: _tsToDate(data['lastSeenAt']),
      currentSessionId: data['currentSessionId'] as String?,
      currentSessionStartAt: _tsToDate(data['currentSessionStartAt']),
      gpsPingCountSession: _numToInt(data['gpsPingCountSession']),
      gpsPingCountToday: _numToInt(data['gpsPingCountToday']),
      lastGpsAt: _tsToDate(data['lastGpsAt']),
      batteryLevel: _numToDouble(data['batteryLevel']),
      gpsAccuracy: _numToDouble(data['gpsAccuracy']),
      updatedAt: _tsToDate(data['updatedAt']),
    );
  }

  factory TrackerLiveStats.fromMap(Map<String, dynamic> data) {
    return TrackerLiveStats(
      trackerId: (data['trackerId'] as String?) ?? '',
      parentGroupAdminId: (data['parentGroupAdminId'] as String?) ?? '',
      trackerDisplayName: data['trackerDisplayName'] as String?,
      isOnline: (data['isOnline'] as bool?) ?? false,
      lastSeenAt: _tsToDate(data['lastSeenAt']),
      currentSessionId: data['currentSessionId'] as String?,
      currentSessionStartAt: _tsToDate(data['currentSessionStartAt']),
      gpsPingCountSession: _numToInt(data['gpsPingCountSession']),
      gpsPingCountToday: _numToInt(data['gpsPingCountToday']),
      lastGpsAt: _tsToDate(data['lastGpsAt']),
      batteryLevel: _numToDouble(data['batteryLevel']),
      gpsAccuracy: _numToDouble(data['gpsAccuracy']),
      updatedAt: _tsToDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'trackerId': trackerId,
      'parentGroupAdminId': parentGroupAdminId,
      'trackerDisplayName': trackerDisplayName,
      'isOnline': isOnline,
      'lastSeenAt': lastSeenAt == null ? null : Timestamp.fromDate(lastSeenAt!),
      'currentSessionId': currentSessionId,
      'currentSessionStartAt': currentSessionStartAt == null
          ? null
          : Timestamp.fromDate(currentSessionStartAt!),
      'gpsPingCountSession': gpsPingCountSession,
      'gpsPingCountToday': gpsPingCountToday,
      'lastGpsAt': lastGpsAt == null ? null : Timestamp.fromDate(lastGpsAt!),
      'batteryLevel': batteryLevel,
      'gpsAccuracy': gpsAccuracy,
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }

  TrackerLiveStats copyWith({
    bool? isOnline,
    DateTime? lastSeenAt,
    DateTime? currentSessionStartAt,
    int? gpsPingCountSession,
    int? gpsPingCountToday,
    DateTime? lastGpsAt,
    double? batteryLevel,
    double? gpsAccuracy,
  }) {
    return TrackerLiveStats(
      trackerId: trackerId,
      parentGroupAdminId: parentGroupAdminId,
      trackerDisplayName: trackerDisplayName,
      isOnline: isOnline ?? this.isOnline,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      currentSessionId: currentSessionId,
      currentSessionStartAt: currentSessionStartAt ?? this.currentSessionStartAt,
      gpsPingCountSession: gpsPingCountSession ?? this.gpsPingCountSession,
      gpsPingCountToday: gpsPingCountToday ?? this.gpsPingCountToday,
      lastGpsAt: lastGpsAt ?? this.lastGpsAt,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      gpsAccuracy: gpsAccuracy ?? this.gpsAccuracy,
      updatedAt: updatedAt,
    );
  }

  String get displayName => (trackerDisplayName ?? '').trim().isEmpty
      ? trackerId
      : trackerDisplayName!.trim();

  static int? _numToInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static double? _numToDouble(Object? v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static DateTime? _tsToDate(Object? v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }
}
