import 'package:flutter/material.dart';

import '../models/tracker_live_stats.dart';
import '../provider/tracking_live_provider.dart';
import '../widgets/tracker_status_chip.dart';

class TrackerListPanel extends StatelessWidget {
  const TrackerListPanel({
    super.key,
    required this.trackers,
    required this.provider,
  });

  final List<TrackerLiveStats> trackers;
  final TrackingLiveProvider provider;

  @override
  Widget build(BuildContext context) {
    if (trackers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'Aucun tracker rattaché.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.grey[600]),
        ),
      );
    }

    final sorted = [...trackers]
      ..sort((a, b) {
        if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
        final at = a.updatedAt ?? a.lastSeenAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.updatedAt ?? b.lastSeenAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });

    return Column(
      children: sorted
          .map(
            (t) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_pin_circle),
              title: Text(t.displayName),
              subtitle: Text(
                'Dernière activité: ${provider.presence.formatLastSeen(t.lastSeenAt)}'
                '${t.gpsPingCountToday != null ? ' • Pings aujourd\'hui: ${t.gpsPingCountToday}' : ''}',
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TrackerStatusChip(
                    isOnline: t.isOnline,
                    lastSeenAt: t.lastSeenAt,
                    presence: provider.presence,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Session: ${_formatSessionDuration(t)}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  String _formatSessionDuration(TrackerLiveStats t) {
    final d = provider.presence.liveSessionDuration(
      t.currentSessionStartAt,
      t.isOnline,
    );
    if (d == null) return '—';
    return provider.presence.formatDuration(d);
  }
}
