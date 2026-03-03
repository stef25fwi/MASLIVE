import 'package:flutter/material.dart';

import '../provider/tracking_live_provider.dart';

class TrackingFiltersBar extends StatelessWidget {
  const TrackingFiltersBar({
    super.key,
    required this.provider,
  });

  final TrackingLiveProvider provider;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 260,
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Recherche (nom / code / uid)',
                ),
                onChanged: provider.setSearchQuery,
              ),
            ),
            _StatusDropdown(
              value: provider.statusFilter,
              onChanged: provider.setStatusFilter,
            ),
            _StringDropdown(
              label: 'Pays',
              value: provider.countryFilter,
              values: provider.availableCountries,
              onChanged: provider.setCountryFilter,
            ),
            _StringDropdown(
              label: 'Événement',
              value: provider.eventFilter,
              values: provider.availableEvents,
              onChanged: provider.setEventFilter,
            ),
            _StringDropdown(
              label: 'Circuit',
              value: provider.circuitFilter,
              values: provider.availableCircuits,
              onChanged: provider.setCircuitFilter,
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: provider.onlyWithActiveTrackers,
                  onChanged: (v) => provider.toggleOnlyWithActiveTrackers(v ?? false),
                ),
                const SizedBox(width: 4),
                const Text('Trackers actifs'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDropdown extends StatelessWidget {
  const _StatusDropdown({
    required this.value,
    required this.onChanged,
  });

  final TrackingStatusFilter value;
  final ValueChanged<TrackingStatusFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<TrackingStatusFilter>(
        value: value,
        items: const [
          DropdownMenuItem(
            value: TrackingStatusFilter.all,
            child: Text('Statut: Tous'),
          ),
          DropdownMenuItem(
            value: TrackingStatusFilter.online,
            child: Text('Statut: Online'),
          ),
          DropdownMenuItem(
            value: TrackingStatusFilter.offline,
            child: Text('Statut: Offline'),
          ),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

class _StringDropdown extends StatelessWidget {
  const _StringDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> values;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String?>(
        value: value,
        hint: Text(label),
        items: <DropdownMenuItem<String?>>[
          DropdownMenuItem<String?>(
            value: null,
            child: Text('$label: Tous'),
          ),
          ...values.map(
            (v) => DropdownMenuItem<String?>(
              value: v,
              child: Text('$label: $v'),
            ),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
