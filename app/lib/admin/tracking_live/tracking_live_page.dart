import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../ui/snack/top_snack_bar.dart';
import 'models/tracking_event.dart';
import 'provider/tracking_live_provider.dart';
import 'widgets/group_admin_live_card.dart';
import 'widgets/live_stats_chart_placeholder.dart';
import 'widgets/period_selector.dart';
import 'widgets/tracking_filters_bar.dart';
import 'widgets/tracking_kpi_tile.dart';

class TrackingLivePage extends StatelessWidget {
  const TrackingLivePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final p = TrackingLiveProvider();
        p.init();
        return p;
      },
      child: const _TrackingLiveView(),
    );
  }
}

class _TrackingLiveView extends StatelessWidget {
  const _TrackingLiveView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TrackingLiveProvider>();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Tracking Live'),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            icon: const Icon(Icons.refresh),
            onPressed: provider.refresh,
          ),
          IconButton(
            tooltip: 'Exporter (stub)',
            icon: const Icon(Icons.file_download),
            onPressed: () async {
              try {
                await provider.exportCurrentView();
                if (!context.mounted) return;
                TopSnackBar.show(
                  context,
                  const SnackBar(
                    content: Text('Export prêt (stub).'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                TopSnackBar.show(
                  context,
                  SnackBar(
                    content: Text('Erreur export: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Header(provider: provider),
          const SizedBox(height: 12),
          TrackingFiltersBar(provider: provider),
          const SizedBox(height: 12),
          _KpiGrid(provider: provider),
          const SizedBox(height: 12),
          LiveStatsChartPlaceholder(summary: provider.globalSummary),
          const SizedBox(height: 12),
          _RecentEventsSection(provider: provider),
          const SizedBox(height: 12),
          _GroupsSection(provider: provider),
        ],
      ),
    );
  }
}

class _RecentEventsSection extends StatelessWidget {
  const _RecentEventsSection({required this.provider});

  final TrackingLiveProvider provider;

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Chargement des événements…'),
            ],
          ),
        ),
      );
    }

    final events = provider.recentEvents;
    if (events.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.bolt, color: Colors.grey[700]),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Aucun événement récent.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final shown = events.length > 20 ? events.take(20).toList() : events;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt),
                const SizedBox(width: 8),
                Text(
                  'Événements récents',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  'Derniers ${shown.length}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 6),
            Column(
              children: [
                for (var i = 0; i < shown.length; i++) ...[
                  _EventTile(
                    provider: provider,
                    index: i,
                    total: shown.length,
                    event: shown[i],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.provider,
    required this.index,
    required this.total,
    required this.event,
  });

  final TrackingLiveProvider provider;
  final int index;
  final int total;
  final TrackingEvent event;

  @override
  Widget build(BuildContext context) {
    final type = event.type;
    final role = event.role;
    final ts = event.timestamp;

    final title = _formatType(type);
    final who = _formatWho(event);
    final when = provider.presence.formatLastSeen(ts);

    return Column(
      children: [
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(_iconForType(type), color: Colors.indigo[700]),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            '${role.isEmpty ? '—' : role}${who.isEmpty ? '' : ' • $who'}',
          ),
          trailing: Text(
            when,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (index != total - 1) const Divider(height: 1),
      ],
    );
  }

  String _formatType(String type) {
    switch (type) {
      case 'login':
        return 'Connexion';
      case 'logout':
        return 'Déconnexion';
      case 'heartbeat':
        return 'Heartbeat';
      case 'gps_ping':
        return 'Ping GPS';
      case 'tracker_linked':
        return 'Tracker rattaché';
      case 'tracker_unlinked':
        return 'Tracker détaché';
      default:
        return type;
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'login':
        return Icons.login;
      case 'logout':
        return Icons.logout;
      case 'heartbeat':
        return Icons.favorite;
      case 'gps_ping':
        return Icons.gps_fixed;
      case 'tracker_linked':
        return Icons.link;
      case 'tracker_unlinked':
        return Icons.link_off;
      default:
        return Icons.bolt;
    }
  }

  String _formatWho(TrackingEvent e) {
    final groupAdminId = e.groupAdminId ?? '';
    final trackerId = e.trackerId ?? '';
    if (trackerId.trim().isNotEmpty) return 'Tracker: $trackerId';
    if (groupAdminId.trim().isNotEmpty) return 'Groupe: $groupAdminId';
    final userId = e.userId;
    return userId.trim().isEmpty ? '' : 'User: $userId';
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.provider});

  final TrackingLiveProvider provider;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.radar, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tracking Live',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Monitoring des groupes et trackers en temps réel',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                  ),
                  if (provider.lastUpdatedAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Dernière mise à jour: ${provider.presence.formatLastSeen(provider.lastUpdatedAt)}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
            PeriodSelector(
              selection: provider.selectedPeriod,
              onChanged: provider.setPeriod,
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.provider});

  final TrackingLiveProvider provider;

  @override
  Widget build(BuildContext context) {
    final s = provider.globalSummary;

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final crossAxisCount = w >= 1100
            ? 4
            : w >= 800
            ? 3
            : 2;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.7,
          children: [
            TrackingKpiTile(
              title: 'Group Admin connectés',
              value: '${s.groupAdminsOnline}',
              subtitle: 'Live',
              icon: Icons.groups,
              color: Colors.green,
            ),
            TrackingKpiTile(
              title: 'Tracker Group connectés',
              value: '${s.trackersOnline}',
              subtitle: 'Live',
              icon: Icons.person_pin_circle,
              color: Colors.green,
            ),
            TrackingKpiTile(
              title: 'Sessions actives',
              value: '${s.activeSessions}',
              subtitle: 'Live',
              icon: Icons.timer,
              color: Colors.blue,
            ),
            TrackingKpiTile(
              title: 'Connexions aujourd\'hui',
              value: '${s.totalConnectionsToday}',
              subtitle: 'Group admins',
              icon: Icons.login,
              color: Colors.deepPurple,
            ),
            TrackingKpiTile(
              title: 'Durée moyenne session',
              value: s.avgSessionDurationTodaySec <= 0
                  ? '—'
                  : provider.presence.formatDuration(
                      Duration(seconds: s.avgSessionDurationTodaySec.round()),
                    ),
              subtitle: 'Sessions actives (live)',
              icon: Icons.av_timer,
              color: Colors.orange,
            ),
            TrackingKpiTile(
              title: 'Pings GPS aujourd\'hui',
              value: '${s.gpsPingsToday}',
              icon: Icons.gps_fixed,
              color: Colors.teal,
            ),
            TrackingKpiTile(
              title: 'Dernière activité',
              value: provider.presence.formatLastSeen(s.lastActivityAt),
              subtitle: 'Events',
              icon: Icons.bolt,
              color: Colors.indigo,
            ),
            TrackingKpiTile(
              title: 'Groupes suivis',
              value: '${s.groupsCount}',
              icon: Icons.visibility,
              color: Colors.purple,
            ),
          ],
        );
      },
    );
  }
}

class _GroupsSection extends StatelessWidget {
  const _GroupsSection({required this.provider});

  final TrackingLiveProvider provider;

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (provider.errorMessage != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Erreur: ${provider.errorMessage}'),
        ),
      );
    }

    final groups = provider.filteredGroups;
    if (groups.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.inbox, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 10),
              Text(
                'Aucun group admin à afficher.',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Vérifiez vos filtres ou les collections Firestore tracking_live_*.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final useGrid = w >= 1100;

        if (!useGrid) {
          return Column(
            children: [
              for (final g in groups) ...[
                GroupAdminLiveCard(
                  group: g,
                  provider: provider,
                  onViewDetails: null,
                  onHistory: null,
                  onRefresh: provider.refresh,
                  onExport: () async {
                    await provider.exportCurrentView(format: 'csv');
                    if (!context.mounted) return;
                    TopSnackBar.show(
                      context,
                      SnackBar(
                        content: Text(
                          'Export CSV prêt (stub) — ${g.groupAdminCodeId}',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
          ),
          itemCount: groups.length,
          itemBuilder: (context, i) {
            final g = groups[i];
            return GroupAdminLiveCard(
              group: g,
              provider: provider,
              onRefresh: provider.refresh,
              onExport: null,
            );
          },
        );
      },
    );
  }
}
