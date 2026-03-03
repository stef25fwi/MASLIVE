import 'package:flutter/material.dart';

import '../models/tracking_live_summary.dart';

class LiveStatsChartPlaceholder extends StatelessWidget {
  const LiveStatsChartPlaceholder({
    super.key,
    required this.summary,
  });

  final TrackingLiveSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.show_chart),
                const SizedBox(width: 8),
                Text(
                  'Statistiques live',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Placeholder graphique (valeurs + mini barres) — prêt à brancher sur un vrai chart.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            _MiniBar(
              label: 'Sessions actives',
              value: summary.activeSessions.toDouble(),
              max: (summary.activeSessions + 10).toDouble(),
              color: Colors.blue,
            ),
            const SizedBox(height: 10),
            _MiniBar(
              label: 'Pings GPS (today)',
              value: summary.gpsPingsToday.toDouble(),
              max: (summary.gpsPingsToday + 50).toDouble(),
              color: Colors.teal,
            ),
            const SizedBox(height: 10),
            _MiniBar(
              label: 'Trackers online',
              value: summary.trackersOnline.toDouble(),
              max: (summary.groupsCount * 10 + 10).toDouble(),
              color: Colors.green,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
  });

  final String label;
  final double value;
  final double max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              value.toStringAsFixed(0),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
