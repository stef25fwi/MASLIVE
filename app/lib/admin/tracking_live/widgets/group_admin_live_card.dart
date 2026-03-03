import 'package:flutter/material.dart';

import '../models/group_admin_live_stats.dart';
import '../provider/tracking_live_provider.dart';
import '../widgets/tracker_list_panel.dart';
import '../widgets/tracker_status_chip.dart';

class GroupAdminLiveCard extends StatelessWidget {
  const GroupAdminLiveCard({
    super.key,
    required this.group,
    required this.provider,
    this.onViewDetails,
    this.onHistory,
    this.onRefresh,
    this.onExport,
  });

  final GroupAdminLiveStats group;
  final TrackingLiveProvider provider;

  final VoidCallback? onViewDetails;
  final VoidCallback? onHistory;
  final VoidCallback? onRefresh;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final presence = provider.presence;
    final sessionDur = presence.liveSessionDuration(group.currentSessionStartAt, group.isOnline);

    final trackersTotal = group.trackersCount ?? group.trackers.length;
    final trackersOnline = group.trackersOnlineCount ?? group.trackers.where((t) => t.isOnline).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.groups, color: Colors.purple),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.displayLabel,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Code: ${group.groupAdminCodeId} • Dernière activité: ${presence.formatLastSeen(group.lastSeenAt)}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey[700]),
                      ),
                      if ((group.countryId ?? '').isNotEmpty ||
                          (group.eventId ?? '').isNotEmpty ||
                          (group.circuitId ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${group.countryId ?? '—'} / ${group.eventId ?? '—'} / ${group.circuitId ?? '—'}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TrackerStatusChip(
                  isOnline: group.isOnline,
                  lastSeenAt: group.lastSeenAt,
                  presence: presence,
                  compact: false,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _StatPill(label: 'Session', value: sessionDur == null ? '—' : presence.formatDuration(sessionDur)),
                _StatPill(label: 'Trackers', value: '$trackersOnline / $trackersTotal'),
                _StatPill(label: 'Pings session', value: '${group.gpsPingCountSession ?? 0}'),
                _StatPill(label: 'Pings today', value: '${group.gpsPingCountToday ?? 0}'),
                _StatPill(label: 'Connexions today', value: '${group.totalConnectionsToday ?? 0}'),
                _StatPill(label: 'Week', value: '${group.totalConnectionsWeek ?? 0}'),
                _StatPill(label: 'Month', value: '${group.totalConnectionsMonth ?? 0}'),
              ],
            ),
            if (group.averageLat != null && group.averageLng != null) ...[
              const SizedBox(height: 10),
              Text(
                'Position moyenne: ${group.averageLat!.toStringAsFixed(5)}, ${group.averageLng!.toStringAsFixed(5)}'
                '${group.averageContributorsCount != null ? ' • Contributeurs: ${group.averageContributorsCount}' : ''}'
                '${group.averagePositionUpdatedAt != null ? ' • MAJ: ${presence.formatLastSeen(group.averagePositionUpdatedAt)}' : ''}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey[700]),
              ),
            ],
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text(
                'Trackers rattachés (${group.trackers.length})',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              children: [
                TrackerListPanel(trackers: group.trackers, provider: provider),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: onViewDetails,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Voir détails'),
                ),
                OutlinedButton.icon(
                  onPressed: onHistory,
                  icon: const Icon(Icons.history),
                  label: const Text('Historique'),
                ),
                OutlinedButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Rafraîchir'),
                ),
                OutlinedButton.icon(
                  onPressed: onExport,
                  icon: const Icon(Icons.file_download),
                  label: const Text('Exporter'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
