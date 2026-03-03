class TrackingLiveSummary {
  const TrackingLiveSummary({
    required this.groupAdminsOnline,
    required this.trackersOnline,
    required this.activeSessions,
    required this.totalConnectionsToday,
    required this.avgSessionDurationTodaySec,
    required this.gpsPingsToday,
    this.lastActivityAt,
    required this.groupsCount,
  });

  final int groupAdminsOnline;
  final int trackersOnline;
  final int activeSessions;
  final int totalConnectionsToday;
  final double avgSessionDurationTodaySec;
  final int gpsPingsToday;
  final DateTime? lastActivityAt;
  final int groupsCount;

  factory TrackingLiveSummary.empty() {
    return const TrackingLiveSummary(
      groupAdminsOnline: 0,
      trackersOnline: 0,
      activeSessions: 0,
      totalConnectionsToday: 0,
      avgSessionDurationTodaySec: 0,
      gpsPingsToday: 0,
      lastActivityAt: null,
      groupsCount: 0,
    );
  }

  TrackingLiveSummary copyWith({
    int? groupAdminsOnline,
    int? trackersOnline,
    int? activeSessions,
    int? totalConnectionsToday,
    double? avgSessionDurationTodaySec,
    int? gpsPingsToday,
    DateTime? lastActivityAt,
    int? groupsCount,
  }) {
    return TrackingLiveSummary(
      groupAdminsOnline: groupAdminsOnline ?? this.groupAdminsOnline,
      trackersOnline: trackersOnline ?? this.trackersOnline,
      activeSessions: activeSessions ?? this.activeSessions,
      totalConnectionsToday: totalConnectionsToday ?? this.totalConnectionsToday,
      avgSessionDurationTodaySec:
          avgSessionDurationTodaySec ?? this.avgSessionDurationTodaySec,
      gpsPingsToday: gpsPingsToday ?? this.gpsPingsToday,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      groupsCount: groupsCount ?? this.groupsCount,
    );
  }
}
