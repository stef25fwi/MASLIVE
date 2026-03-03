class TrackingPresenceService {
  const TrackingPresenceService({
    this.heartbeatTimeout = const Duration(seconds: 90),
    this.recentInactiveWindow = const Duration(minutes: 10),
  });

  final Duration heartbeatTimeout;
  final Duration recentInactiveWindow;

  bool isOnlineFromLastSeen(
    DateTime? lastSeenAt, {
    Duration? timeout,
  }) {
    if (lastSeenAt == null) return false;
    final t = timeout ?? heartbeatTimeout;
    return DateTime.now().difference(lastSeenAt) <= t;
  }

  bool isRecentlyInactive(DateTime? lastSeenAt) {
    if (lastSeenAt == null) return false;
    final diff = DateTime.now().difference(lastSeenAt);
    return diff > heartbeatTimeout && diff <= recentInactiveWindow;
  }

  Duration? liveSessionDuration(DateTime? sessionStartAt, bool isOnline) {
    if (!isOnline) return null;
    if (sessionStartAt == null) return null;
    final d = DateTime.now().difference(sessionStartAt);
    if (d.isNegative) return Duration.zero;
    return d;
  }

  String formatDuration(Duration d) {
    final total = d.inSeconds;
    final h = (total ~/ 3600).toString().padLeft(2, '0');
    final m = ((total % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String formatLastSeen(DateTime? dt) {
    if (dt == null) return '—';
    final diff = DateTime.now().difference(dt);
    if (diff.isNegative) return 'à l\'instant';

    if (diff.inSeconds < 60) return 'il y a ${diff.inSeconds}s';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
    return 'il y a ${diff.inDays}j';
  }
}
