import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/group_admin_live_stats.dart';
import '../models/tracker_live_stats.dart';
import '../models/tracking_event.dart';
import '../models/tracking_live_summary.dart';
import '../repository/tracking_live_repository.dart';
import '../services/tracking_export_service.dart';
import '../services/tracking_presence_service.dart';
import '../services/tracking_stats_service.dart';

enum TrackingStatusFilter { all, online, offline }

enum TrackingPeriodPreset { today, days7, days30, custom }

class TrackingPeriodSelection {
  const TrackingPeriodSelection({
    required this.preset,
    required this.start,
    required this.end,
  });

  final TrackingPeriodPreset preset;
  final DateTime start;
  final DateTime end;

  factory TrackingPeriodSelection.today() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return TrackingPeriodSelection(
      preset: TrackingPeriodPreset.today,
      start: start,
      end: now,
    );
  }

  factory TrackingPeriodSelection.lastDays(int days) {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days));
    return TrackingPeriodSelection(
      preset: days == 7
          ? TrackingPeriodPreset.days7
          : days == 30
          ? TrackingPeriodPreset.days30
          : TrackingPeriodPreset.custom,
      start: start,
      end: now,
    );
  }
}

class TrackingLiveProvider extends ChangeNotifier {
  TrackingLiveProvider({
    TrackingLiveRepository? repository,
    TrackingStatsService? statsService,
    TrackingPresenceService? presenceService,
    TrackingExportService? exportService,
  }) : _repository = repository ?? TrackingLiveRepository(),
       _statsService = statsService ?? const TrackingStatsService(),
       presence = presenceService ?? const TrackingPresenceService(),
       _exportService = exportService ?? const TrackingExportService();

  final TrackingLiveRepository _repository;
  final TrackingStatsService _statsService;
  final TrackingExportService _exportService;
  final TrackingPresenceService presence;

  bool isLoading = true;
  String? errorMessage;

  TrackingPeriodSelection selectedPeriod = TrackingPeriodSelection.today();

  String searchQuery = '';
  TrackingStatusFilter statusFilter = TrackingStatusFilter.all;
  String? countryFilter;
  String? eventFilter;
  String? circuitFilter;
  bool onlyWithActiveTrackers = false;

  DateTime? lastUpdatedAt;

  TrackingLiveSummary globalSummary = TrackingLiveSummary.empty();
  List<GroupAdminLiveStats> filteredGroups = const [];

  List<TrackingEvent> get recentEvents => List.unmodifiable(_recentEvents);

  List<GroupAdminLiveStats> _groups = const [];
  List<TrackerLiveStats> _trackers = const [];
  List<TrackingEvent> _recentEvents = const [];

  StreamSubscription? _subGroups;
  StreamSubscription? _subTrackers;
  StreamSubscription? _subEvents;

  Timer? _tick;

  // Options de filtre (alimentées à partir des données live)
  List<String> availableCountries = const [];
  List<String> availableEvents = const [];
  List<String> availableCircuits = const [];

  void init() {
    if (!isLoading) {
      // déjà initialisé
      return;
    }

    _subGroups = _repository.watchLiveGroups().listen(
      (groups) {
        _groups = groups;
        _recompute();
      },
      onError: (e) {
        errorMessage = e.toString();
        isLoading = false;
        notifyListeners();
      },
    );

    _subTrackers = _repository.watchLiveTrackers().listen(
      (trackers) {
        _trackers = trackers;
        _recompute();
      },
      onError: (e) {
        errorMessage = e.toString();
        isLoading = false;
        notifyListeners();
      },
    );

    _subEvents = _repository.watchRecentEvents().listen(
      (events) {
        _recentEvents = events;
        _recompute();
      },
      onError: (e) {
        // Non bloquant
      },
    );

    // Tick léger pour durées live / formatages
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _subGroups?.cancel();
    _subTrackers?.cancel();
    _subEvents?.cancel();
    super.dispose();
  }

  void setPeriod(TrackingPeriodSelection period) {
    selectedPeriod = period;
    _recompute();
  }

  void setStatusFilter(TrackingStatusFilter filter) {
    statusFilter = filter;
    _recompute();
  }

  void setSearchQuery(String q) {
    searchQuery = q;
    _recompute();
  }

  void setCountryFilter(String? v) {
    countryFilter = _normalizeNullable(v);
    _recompute();
  }

  void setEventFilter(String? v) {
    eventFilter = _normalizeNullable(v);
    _recompute();
  }

  void setCircuitFilter(String? v) {
    circuitFilter = _normalizeNullable(v);
    _recompute();
  }

  void toggleOnlyWithActiveTrackers(bool v) {
    onlyWithActiveTrackers = v;
    _recompute();
  }

  Future<void> refresh() async {
    // Les streams se rafraîchissent automatiquement.
    lastUpdatedAt = DateTime.now();
    notifyListeners();
  }

  Future<String> exportCurrentView({String format = 'json'}) async {
    if (format == 'csv') {
      return _exportService.exportAsCsv(groups: filteredGroups);
    }
    return _exportService.exportAsJson(
      summary: globalSummary,
      groups: filteredGroups,
    );
  }

  void _recompute() {
    isLoading = false;
    errorMessage = null;

    final enrichedGroups = _repository.enrichGroupsWithTrackers(
      groups: _groups,
      trackers: _trackers,
    );

    // Options de filtres dynamiques
    availableCountries = _uniqueNonEmpty(
      enrichedGroups.map((g) => g.countryId),
    );
    availableEvents = _uniqueNonEmpty(enrichedGroups.map((g) => g.eventId));
    availableCircuits = _uniqueNonEmpty(enrichedGroups.map((g) => g.circuitId));

    // Summary global
    globalSummary = _statsService.computeGlobalSummary(
      groups: enrichedGroups,
      trackers: _trackers,
      recentEvents: _recentEvents,
    );

    // Filtrage UI
    final q = searchQuery.trim().toLowerCase();

    final filtered = enrichedGroups.where((g) {
      if (countryFilter != null && (g.countryId ?? '') != countryFilter) {
        return false;
      }
      if (eventFilter != null && (g.eventId ?? '') != eventFilter) {
        return false;
      }
      if (circuitFilter != null && (g.circuitId ?? '') != circuitFilter) {
        return false;
      }

      if (onlyWithActiveTrackers) {
        final onlineCount = g.trackers.where((t) => t.isOnline).length;
        if (onlineCount <= 0) return false;
      }

      if (statusFilter == TrackingStatusFilter.online && !g.isOnline) {
        return false;
      }
      if (statusFilter == TrackingStatusFilter.offline && g.isOnline) {
        return false;
      }

      if (q.isNotEmpty) {
        final hay = '${g.displayLabel} ${g.groupAdminCodeId} ${g.groupAdminId}'
            .toLowerCase();
        if (!hay.contains(q)) return false;
      }

      return true;
    }).toList();

    filtered.sort((a, b) {
      // Online d'abord, puis updatedAt desc
      if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
      final at =
          a.updatedAt ?? a.lastSeenAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt =
          b.updatedAt ?? b.lastSeenAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });

    filteredGroups = filtered;

    // Dernière update (best-effort)
    lastUpdatedAt = _maxDate([
      globalSummary.lastActivityAt,
      ...enrichedGroups.map((g) => g.updatedAt),
      ..._trackers.map((t) => t.updatedAt),
    ]);

    notifyListeners();
  }

  static String? _normalizeNullable(String? v) {
    final t = (v ?? '').trim();
    return t.isEmpty ? null : t;
  }

  static List<String> _uniqueNonEmpty(Iterable<String?> items) {
    final set = <String>{};
    for (final v in items) {
      final t = (v ?? '').trim();
      if (t.isEmpty) continue;
      set.add(t);
    }
    final list = set.toList();
    list.sort();
    return list;
  }

  static DateTime? _maxDate(Iterable<DateTime?> items) {
    DateTime? max;
    for (final d in items) {
      if (d == null) continue;
      if (max == null || d.isAfter(max)) max = d;
    }
    return max;
  }
}
