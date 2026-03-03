import '../models/group_admin_live_stats.dart';
import '../models/tracker_live_stats.dart';
import '../models/tracking_event.dart';
import '../models/tracking_live_summary.dart';

// Service de calculs et transformations UI.
// La page Admin lit surtout; l'écriture d'événements/sessions est préparée en stubs.
class TrackingStatsService {
  const TrackingStatsService();

  TrackingLiveSummary computeGlobalSummary({
    required List<GroupAdminLiveStats> groups,
    required List<TrackerLiveStats> trackers,
    required List<TrackingEvent> recentEvents,
  }) {
    final now = DateTime.now();
    final groupAdminsOnline = groups.where((g) => g.isOnline).length;
    final trackersOnline = trackers.where((t) => t.isOnline).length;

    final activeSessions =
        groups.where((g) => (g.currentSessionId ?? '').isNotEmpty).length +
        trackers.where((t) => (t.currentSessionId ?? '').isNotEmpty).length;

    final totalConnectionsToday = groups.fold<int>(
      0,
      (sum, g) => sum + (g.totalConnectionsToday ?? 0),
    );

    // Moyenne des durées des sessions actives (best-effort) à partir des timestamps live.
    // Note: ce KPI devient exact si les clients écrivent correctement currentSessionStartAt.
    final activeDurationsSec = <int>[];
    for (final g in groups) {
      if (!g.isOnline) continue;
      final start = g.currentSessionStartAt;
      if (start == null) continue;
      final d = now.difference(start);
      if (!d.isNegative) activeDurationsSec.add(d.inSeconds);
    }
    for (final t in trackers) {
      if (!t.isOnline) continue;
      final start = t.currentSessionStartAt;
      if (start == null) continue;
      final d = now.difference(start);
      if (!d.isNegative) activeDurationsSec.add(d.inSeconds);
    }

    final avgSessionDurationTodaySec = activeDurationsSec.isEmpty
        ? 0.0
        : activeDurationsSec.reduce((a, b) => a + b) /
              activeDurationsSec.length;

    final gpsPingsToday =
        groups.fold<int>(0, (sum, g) => sum + (g.gpsPingCountToday ?? 0)) +
        trackers.fold<int>(0, (sum, t) => sum + (t.gpsPingCountToday ?? 0));

    DateTime? lastActivityAt;
    for (final e in recentEvents) {
      if (lastActivityAt == null || e.timestamp.isAfter(lastActivityAt)) {
        lastActivityAt = e.timestamp;
      }
    }

    return TrackingLiveSummary(
      groupAdminsOnline: groupAdminsOnline,
      trackersOnline: trackersOnline,
      activeSessions: activeSessions,
      totalConnectionsToday: totalConnectionsToday,
      avgSessionDurationTodaySec: avgSessionDurationTodaySec,
      gpsPingsToday: gpsPingsToday,
      lastActivityAt: lastActivityAt,
      groupsCount: groups.length,
    );
  }

  // ---- Stubs d'enregistrement (à appeler depuis app tracker / group admin) ----

  Future<void> recordLoginEvent({
    required String userId,
    required String role,
    String? groupAdminId,
    String? trackerId,
    String? sessionId,
    Map<String, dynamic>? metadata,
  }) async {
    // NOTE: écrire dans tracking_events + (optionnel) mise à jour tracking_live_*.
  }

  Future<void> recordLogoutEvent({
    required String userId,
    required String role,
    String? groupAdminId,
    String? trackerId,
    String? sessionId,
    Map<String, dynamic>? metadata,
  }) async {
    // NOTE: écrire dans tracking_events.
  }

  Future<void> recordHeartbeatEvent({
    required String userId,
    required String role,
    String? groupAdminId,
    String? trackerId,
    String? sessionId,
    Map<String, dynamic>? metadata,
  }) async {
    // NOTE: écrire dans tracking_events.
  }

  Future<void> recordGpsPingEvent({
    required String userId,
    required String role,
    String? groupAdminId,
    String? trackerId,
    String? sessionId,
    Map<String, dynamic>? metadata,
  }) async {
    // NOTE: écrire dans tracking_events.
  }

  Future<void> openSession({
    required String userId,
    required String role,
    String? groupAdminId,
    String? trackerId,
    String? countryId,
    String? eventRefId,
    String? circuitId,
  }) async {
    // NOTE: créer un document tracking_sessions avec isActive=true.
  }

  Future<void> closeSession({
    required String sessionId,
    DateTime? endedAt,
  }) async {
    // NOTE: fermer la session + calcul durationSec.
  }

  // ---- Cloud Functions (pseudo-code / NOTE) ----
  // NOTE(functions): agrégation journalière automatique -> tracking_stats_daily
  // NOTE(functions): fermeture de sessions abandonnées (timeout)
  // NOTE(functions): recalcul isOnline si heartbeat expiré
  // NOTE(functions): snapshots horaires optionnels
}
