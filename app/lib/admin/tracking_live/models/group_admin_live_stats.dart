import 'package:cloud_firestore/cloud_firestore.dart';

import 'tracker_live_stats.dart';

class GroupAdminLiveStats {
  const GroupAdminLiveStats({
    required this.groupAdminId,
    required this.groupAdminCodeId,
    this.displayName,
    this.countryId,
    this.eventId,
    this.circuitId,
    required this.isOnline,
    this.lastSeenAt,
    this.currentSessionId,
    this.currentSessionStartAt,
    this.trackersCount,
    this.trackersOnlineCount,
    this.gpsPingCountSession,
    this.gpsPingCountToday,
    this.totalConnectionsToday,
    this.totalConnectionsWeek,
    this.totalConnectionsMonth,
    this.updatedAt,
    this.trackers = const <TrackerLiveStats>[],
    this.averageLat,
    this.averageLng,
    this.averagePositionUpdatedAt,
    this.averageContributorsCount,
  });

  final String groupAdminId; // uid (ou id technique)
  final String groupAdminCodeId; // code 6 chiffres
  final String? displayName;
  final String? countryId;
  final String? eventId;
  final String? circuitId;
  final bool isOnline;
  final DateTime? lastSeenAt;
  final String? currentSessionId;
  final DateTime? currentSessionStartAt;
  final int? trackersCount;
  final int? trackersOnlineCount;
  final int? gpsPingCountSession;
  final int? gpsPingCountToday;
  final int? totalConnectionsToday;
  final int? totalConnectionsWeek;
  final int? totalConnectionsMonth;
  final DateTime? updatedAt;

  // Enrichi côté client (relation)
  final List<TrackerLiveStats> trackers;

  // Bonus MASLIVE: position moyenne (optionnelle plus tard)
  final double? averageLat;
  final double? averageLng;
  final DateTime? averagePositionUpdatedAt;
  final int? averageContributorsCount;

  factory GroupAdminLiveStats.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};

    final avg = data['averagePosition'];
    final avgMap = avg is Map ? Map<String, dynamic>.from(avg) : null;

    return GroupAdminLiveStats(
      groupAdminId: (data['groupAdminId'] as String?) ?? doc.id,
      groupAdminCodeId: (data['groupAdminCodeId'] as String?) ?? '',
      displayName: data['displayName'] as String?,
      countryId: data['countryId'] as String?,
      eventId: data['eventId'] as String?,
      circuitId: data['circuitId'] as String?,
      isOnline: (data['isOnline'] as bool?) ?? false,
      lastSeenAt: _tsToDate(data['lastSeenAt']),
      currentSessionId: data['currentSessionId'] as String?,
      currentSessionStartAt: _tsToDate(data['currentSessionStartAt']),
      trackersCount: _numToInt(data['trackersCount']),
      trackersOnlineCount: _numToInt(data['trackersOnlineCount']),
      gpsPingCountSession: _numToInt(data['gpsPingCountSession']),
      gpsPingCountToday: _numToInt(data['gpsPingCountToday']),
      totalConnectionsToday: _numToInt(data['totalConnectionsToday']),
      totalConnectionsWeek: _numToInt(data['totalConnectionsWeek']),
      totalConnectionsMonth: _numToInt(data['totalConnectionsMonth']),
      updatedAt: _tsToDate(data['updatedAt']),
      averageLat: _numToDouble(avgMap?['lat']),
      averageLng: _numToDouble(avgMap?['lng']),
      averagePositionUpdatedAt: _tsToDate(avgMap?['updatedAt']),
      averageContributorsCount: _numToInt(avgMap?['contributorsCount']),
    );
  }

  factory GroupAdminLiveStats.fromMap(Map<String, dynamic> data) {
    return GroupAdminLiveStats(
      groupAdminId: (data['groupAdminId'] as String?) ?? '',
      groupAdminCodeId: (data['groupAdminCodeId'] as String?) ?? '',
      displayName: data['displayName'] as String?,
      countryId: data['countryId'] as String?,
      eventId: data['eventId'] as String?,
      circuitId: data['circuitId'] as String?,
      isOnline: (data['isOnline'] as bool?) ?? false,
      lastSeenAt: _tsToDate(data['lastSeenAt']),
      currentSessionId: data['currentSessionId'] as String?,
      currentSessionStartAt: _tsToDate(data['currentSessionStartAt']),
      trackersCount: _numToInt(data['trackersCount']),
      trackersOnlineCount: _numToInt(data['trackersOnlineCount']),
      gpsPingCountSession: _numToInt(data['gpsPingCountSession']),
      gpsPingCountToday: _numToInt(data['gpsPingCountToday']),
      totalConnectionsToday: _numToInt(data['totalConnectionsToday']),
      totalConnectionsWeek: _numToInt(data['totalConnectionsWeek']),
      totalConnectionsMonth: _numToInt(data['totalConnectionsMonth']),
      updatedAt: _tsToDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupAdminId': groupAdminId,
      'groupAdminCodeId': groupAdminCodeId,
      'displayName': displayName,
      'countryId': countryId,
      'eventId': eventId,
      'circuitId': circuitId,
      'isOnline': isOnline,
      'lastSeenAt': lastSeenAt == null ? null : Timestamp.fromDate(lastSeenAt!),
      'currentSessionId': currentSessionId,
      'currentSessionStartAt': currentSessionStartAt == null
          ? null
          : Timestamp.fromDate(currentSessionStartAt!),
      'trackersCount': trackersCount,
      'trackersOnlineCount': trackersOnlineCount,
      'gpsPingCountSession': gpsPingCountSession,
      'gpsPingCountToday': gpsPingCountToday,
      'totalConnectionsToday': totalConnectionsToday,
      'totalConnectionsWeek': totalConnectionsWeek,
      'totalConnectionsMonth': totalConnectionsMonth,
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }

  GroupAdminLiveStats copyWith({
    bool? isOnline,
    DateTime? lastSeenAt,
    DateTime? currentSessionStartAt,
    int? trackersCount,
    int? trackersOnlineCount,
    int? gpsPingCountSession,
    int? gpsPingCountToday,
    int? totalConnectionsToday,
    int? totalConnectionsWeek,
    int? totalConnectionsMonth,
    DateTime? updatedAt,
    List<TrackerLiveStats>? trackers,
  }) {
    return GroupAdminLiveStats(
      groupAdminId: groupAdminId,
      groupAdminCodeId: groupAdminCodeId,
      displayName: displayName,
      countryId: countryId,
      eventId: eventId,
      circuitId: circuitId,
      isOnline: isOnline ?? this.isOnline,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      currentSessionId: currentSessionId,
      currentSessionStartAt: currentSessionStartAt ?? this.currentSessionStartAt,
      trackersCount: trackersCount ?? this.trackersCount,
      trackersOnlineCount: trackersOnlineCount ?? this.trackersOnlineCount,
      gpsPingCountSession: gpsPingCountSession ?? this.gpsPingCountSession,
      gpsPingCountToday: gpsPingCountToday ?? this.gpsPingCountToday,
      totalConnectionsToday: totalConnectionsToday ?? this.totalConnectionsToday,
      totalConnectionsWeek: totalConnectionsWeek ?? this.totalConnectionsWeek,
      totalConnectionsMonth: totalConnectionsMonth ?? this.totalConnectionsMonth,
      updatedAt: updatedAt ?? this.updatedAt,
      trackers: trackers ?? this.trackers,
      averageLat: averageLat,
      averageLng: averageLng,
      averagePositionUpdatedAt: averagePositionUpdatedAt,
      averageContributorsCount: averageContributorsCount,
    );
  }

  String get displayLabel {
    final name = (displayName ?? '').trim();
    if (name.isNotEmpty) return name;
    return groupAdminCodeId.trim().isNotEmpty ? groupAdminCodeId : groupAdminId;
  }

  double get trackersOnlineRatio {
    final total = trackersCount ?? trackers.length;
    if (total <= 0) return 0;
    final online = trackersOnlineCount ?? trackers.where((t) => t.isOnline).length;
    return online / total;
  }

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
