import 'package:flutter/material.dart';

import '../services/tracking_presence_service.dart';

class TrackerStatusChip extends StatelessWidget {
  const TrackerStatusChip({
    super.key,
    required this.isOnline,
    required this.lastSeenAt,
    required this.presence,
    this.compact = true,
  });

  final bool isOnline;
  final DateTime? lastSeenAt;
  final TrackingPresenceService presence;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final recentlyInactive = !isOnline && presence.isRecentlyInactive(lastSeenAt);

    final bg = isOnline
        ? Colors.green.withValues(alpha: 0.14)
        : recentlyInactive
            ? Colors.orange.withValues(alpha: 0.14)
            : Colors.red.withValues(alpha: 0.12);

    final fg = isOnline
        ? Colors.green[800]!
        : recentlyInactive
            ? Colors.orange[800]!
            : Colors.red[800]!;

    final label = isOnline
        ? 'Online'
        : recentlyInactive
            ? 'Inactif récent'
            : 'Offline';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: fg,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w800,
              fontSize: compact ? 12 : 13,
            ),
          ),
        ],
      ),
    );
  }
}
