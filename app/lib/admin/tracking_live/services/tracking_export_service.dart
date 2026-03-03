// Stub export CSV/JSON.
// TODO: brancher sur share_plus / écriture fichier si nécessaire.

import '../models/group_admin_live_stats.dart';
import '../models/tracking_live_summary.dart';

class TrackingExportService {
  const TrackingExportService();

  Future<String> exportAsJson({
    required TrackingLiveSummary summary,
    required List<GroupAdminLiveStats> groups,
  }) async {
    // TODO: implémenter un vrai export JSON structuré.
    return '{"summary": "TODO", "groups": ${groups.length}}';
  }

  Future<String> exportAsCsv({
    required List<GroupAdminLiveStats> groups,
  }) async {
    // TODO: implémenter un vrai export CSV.
    return 'groupAdminId,code,displayName,online,trackersCount\n'
        '${groups.map((g) {
          final safeName = (g.displayName ?? '').replaceAll('"', '""');
          return '${g.groupAdminId},${g.groupAdminCodeId},"$safeName",${g.isOnline},${g.trackersCount ?? g.trackers.length}';
        }).join('\n')}';
  }
}
