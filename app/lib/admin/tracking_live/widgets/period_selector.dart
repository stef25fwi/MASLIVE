import 'package:flutter/material.dart';

import '../provider/tracking_live_provider.dart';

class PeriodSelector extends StatelessWidget {
  const PeriodSelector({
    super.key,
    required this.selection,
    required this.onChanged,
  });

  final TrackingPeriodSelection selection;
  final ValueChanged<TrackingPeriodSelection> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<TrackingPeriodPreset>(
      segments: const [
        ButtonSegment(value: TrackingPeriodPreset.today, label: Text('Today')),
        ButtonSegment(value: TrackingPeriodPreset.days7, label: Text('7d')),
        ButtonSegment(value: TrackingPeriodPreset.days30, label: Text('30d')),
      ],
      selected: {selection.preset},
      onSelectionChanged: (s) {
        final preset = s.first;
        if (preset == TrackingPeriodPreset.today) {
          onChanged(TrackingPeriodSelection.today());
        } else if (preset == TrackingPeriodPreset.days7) {
          onChanged(TrackingPeriodSelection.lastDays(7));
        } else if (preset == TrackingPeriodPreset.days30) {
          onChanged(TrackingPeriodSelection.lastDays(30));
        } else {
          onChanged(selection);
        }
      },
      showSelectedIcon: false,
    );
  }
}
