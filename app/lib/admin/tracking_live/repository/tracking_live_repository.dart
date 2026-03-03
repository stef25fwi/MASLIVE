import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/group_admin_live_stats.dart';
import '../models/tracker_live_stats.dart';
import '../models/tracking_daily_aggregate.dart';
import '../models/tracking_event.dart';
import '../models/tracking_session.dart';

class TrackingLiveRepository {
  TrackingLiveRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // Collections (proposition de schéma)
  static const String colLiveGroups = 'tracking_live_groups';
  static const String colLiveTrackers = 'tracking_live_trackers';
  static const String colEvents = 'tracking_events';
  static const String colSessions = 'tracking_sessions';
  static const String colDaily = 'tracking_stats_daily';

  Stream<List<GroupAdminLiveStats>> watchLiveGroups({int limit = 500}) {
    return _firestore
        .collection(colLiveGroups)
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(GroupAdminLiveStats.fromFirestore).toList());
  }

  Stream<List<TrackerLiveStats>> watchLiveTrackers({int limit = 3000}) {
    return _firestore
        .collection(colLiveTrackers)
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(TrackerLiveStats.fromFirestore).toList());
  }

  Stream<List<TrackingEvent>> watchRecentEvents({int limit = 200}) {
    return _firestore
        .collection(colEvents)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(TrackingEvent.fromFirestore).toList());
  }

  Future<List<TrackingSession>> fetchSessionsForPeriod({
    required DateTime start,
    required DateTime end,
    int limit = 1000,
  }) async {
    final q = await _firestore
        .collection(colSessions)
        .where('startedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startedAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('startedAt', descending: true)
        .limit(limit)
        .get();

    return q.docs.map(TrackingSession.fromFirestore).toList();
  }

  Future<List<TrackingDailyAggregate>> fetchDailyAggregates({
    required DateTime start,
    required DateTime end,
    String? groupAdminId,
    int limit = 90,
  }) async {
    // Forme possible: tracking_stats_daily/{yyyyMMdd}/global/{doc}
    // Ici: lecture simple sur tracking_stats_daily, en attente d'une structure finale.
    // TODO: adapter quand le schéma Firestore sera figé (global vs sous-collections).

    final startKey = _dateKey(start);
    final endKey = _dateKey(end);

    Query<Map<String, dynamic>> q = _firestore
        .collection(colDaily)
        .orderBy('dateKey', descending: true)
        .where('dateKey', isGreaterThanOrEqualTo: startKey)
        .where('dateKey', isLessThanOrEqualTo: endKey)
        .limit(limit);

    if (groupAdminId != null && groupAdminId.trim().isNotEmpty) {
      q = q.where('groupAdminId', isEqualTo: groupAdminId);
    }

    final snap = await q.get();
    return snap.docs.map(TrackingDailyAggregate.fromFirestore).toList();
  }

  Map<String, List<TrackerLiveStats>> mapTrackersByGroup(
    List<TrackerLiveStats> trackers,
  ) {
    final map = <String, List<TrackerLiveStats>>{};
    for (final t in trackers) {
      final key = t.parentGroupAdminId;
      if (key.trim().isEmpty) continue;
      (map[key] ??= <TrackerLiveStats>[]).add(t);
    }
    return map;
  }

  List<GroupAdminLiveStats> enrichGroupsWithTrackers({
    required List<GroupAdminLiveStats> groups,
    required List<TrackerLiveStats> trackers,
  }) {
    final byGroup = mapTrackersByGroup(trackers);

    return groups
        .map((g) => g.copyWith(trackers: byGroup[g.groupAdminId] ?? const []))
        .toList();
  }

  static String _dateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }
}
