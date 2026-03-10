// Stub export CSV/JSON.
// NOTE: brancher sur share_plus / écriture fichier si nécessaire.

import 'dart:convert';

import '../models/group_admin_live_stats.dart';
import '../models/tracking_live_summary.dart';

class TrackingExportService {
  const TrackingExportService();

  Future<String> exportAsJson({
    required TrackingLiveSummary summary,
    required List<GroupAdminLiveStats> groups,
  }) async {
    final payload = {
      'summary': {
        'groupAdminsOnline': summary.groupAdminsOnline,
        'trackersOnline': summary.trackersOnline,
        'activeSessions': summary.activeSessions,
        'totalConnectionsToday': summary.totalConnectionsToday,
        'avgSessionDurationTodaySec': summary.avgSessionDurationTodaySec,
        'gpsPingsToday': summary.gpsPingsToday,
        'groupsCount': summary.groupsCount,
        'lastActivityAt': summary.lastActivityAt?.toIso8601String(),
      },
      'groups': groups
          .map(
            (g) => {
              'groupAdminId': g.groupAdminId,
              'groupAdminCodeId': g.groupAdminCodeId,
              'displayName': g.displayName,
              'countryId': g.countryId,
              'eventId': g.eventId,
              'circuitId': g.circuitId,
              'isOnline': g.isOnline,
              'trackersCount': g.trackersCount ?? g.trackers.length,
              'trackersOnlineCount':
                  g.trackersOnlineCount ?? g.trackers.where((t) => t.isOnline).length,
              'gpsPingCountToday': g.gpsPingCountToday,
              'totalConnectionsToday': g.totalConnectionsToday,
              'lastSeenAt': g.lastSeenAt?.toIso8601String(),
              'updatedAt': g.updatedAt?.toIso8601String(),
            },
          )
          .toList(),
    };

    return jsonEncode(payload);
  }

  Future<String> exportAsCsv({
    required List<GroupAdminLiveStats> groups,
  }) async {
    // NOTE: implémenter un vrai export CSV.
    return 'groupAdminId,code,displayName,online,trackersCount\n'
        '${groups.map((g) {
          final safeName = (g.displayName ?? '').replaceAll('"', '""');
          return '${g.groupAdminId},${g.groupAdminCodeId},"$safeName",${g.isOnline},${g.trackersCount ?? g.trackers.length}';
        }).join('\n')}';
  }
}
