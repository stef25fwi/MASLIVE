import 'package:cloud_firestore/cloud_firestore.dart';

class TrackingDailyAggregate {
  const TrackingDailyAggregate({
    required this.dateKey,
    this.scope,
    this.groupAdminId,
    this.groupAdminConnections,
    this.trackerConnections,
    this.activeSessionsPeak,
    this.gpsPingCount,
    this.avgSessionDurationSec,
    this.uniqueGroupAdmins,
    this.uniqueTrackers,
    required this.updatedAt,
  });

  final String dateKey; // yyyyMMdd
  final String? scope; // global | group
  final String? groupAdminId;
  final int? groupAdminConnections;
  final int? trackerConnections;
  final int? activeSessionsPeak;
  final int? gpsPingCount;
  final double? avgSessionDurationSec;
  final int? uniqueGroupAdmins;
  final int? uniqueTrackers;
  final DateTime updatedAt;

  factory TrackingDailyAggregate.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return TrackingDailyAggregate(
      dateKey: (data['dateKey'] as String?) ?? doc.id,
      scope: data['scope'] as String?,
      groupAdminId: data['groupAdminId'] as String?,
      groupAdminConnections: _numToInt(data['groupAdminConnections']),
      trackerConnections: _numToInt(data['trackerConnections']),
      activeSessionsPeak: _numToInt(data['activeSessionsPeak']),
      gpsPingCount: _numToInt(data['gpsPingCount']),
      avgSessionDurationSec: _numToDouble(data['avgSessionDurationSec']),
      uniqueGroupAdmins: _numToInt(data['uniqueGroupAdmins']),
      uniqueTrackers: _numToInt(data['uniqueTrackers']),
      updatedAt: _tsToDate(data['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  factory TrackingDailyAggregate.fromMap(Map<String, dynamic> data) {
    return TrackingDailyAggregate(
      dateKey: (data['dateKey'] as String?) ?? '',
      scope: data['scope'] as String?,
      groupAdminId: data['groupAdminId'] as String?,
      groupAdminConnections: _numToInt(data['groupAdminConnections']),
      trackerConnections: _numToInt(data['trackerConnections']),
      activeSessionsPeak: _numToInt(data['activeSessionsPeak']),
      gpsPingCount: _numToInt(data['gpsPingCount']),
      avgSessionDurationSec: _numToDouble(data['avgSessionDurationSec']),
      uniqueGroupAdmins: _numToInt(data['uniqueGroupAdmins']),
      uniqueTrackers: _numToInt(data['uniqueTrackers']),
      updatedAt: _tsToDate(data['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dateKey': dateKey,
      'scope': scope,
      'groupAdminId': groupAdminId,
      'groupAdminConnections': groupAdminConnections,
      'trackerConnections': trackerConnections,
      'activeSessionsPeak': activeSessionsPeak,
      'gpsPingCount': gpsPingCount,
      'avgSessionDurationSec': avgSessionDurationSec,
      'uniqueGroupAdmins': uniqueGroupAdmins,
      'uniqueTrackers': uniqueTrackers,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  TrackingDailyAggregate copyWith({
    int? groupAdminConnections,
    int? trackerConnections,
    int? activeSessionsPeak,
    int? gpsPingCount,
    double? avgSessionDurationSec,
    int? uniqueGroupAdmins,
    int? uniqueTrackers,
    DateTime? updatedAt,
  }) {
    return TrackingDailyAggregate(
      dateKey: dateKey,
      scope: scope,
      groupAdminId: groupAdminId,
      groupAdminConnections: groupAdminConnections ?? this.groupAdminConnections,
      trackerConnections: trackerConnections ?? this.trackerConnections,
      activeSessionsPeak: activeSessionsPeak ?? this.activeSessionsPeak,
      gpsPingCount: gpsPingCount ?? this.gpsPingCount,
      avgSessionDurationSec: avgSessionDurationSec ?? this.avgSessionDurationSec,
      uniqueGroupAdmins: uniqueGroupAdmins ?? this.uniqueGroupAdmins,
      uniqueTrackers: uniqueTrackers ?? this.uniqueTrackers,
      updatedAt: updatedAt ?? this.updatedAt,
    );
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
