import 'package:flutter/material.dart';

class RouteStyleSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String unit;
  final int decimals;
  final ValueChanged<double> onChanged;

  const RouteStyleSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    this.unit = '',
    this.decimals = 0,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clamped = value.clamp(min, max);
    final step = divisions != null && divisions! > 0
        ? (max - min) / divisions!
        : (decimals > 0 ? 1 / (decimals * 10) : 1.0);

    void nudge(double delta) {
      final next = (clamped + delta).clamp(min, max);
      if ((next - clamped).abs() < 0.0000001) return;
      onChanged(next);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '${clamped.toStringAsFixed(decimals)}$unit',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
        Row(
          children: [
            IconButton.outlined(
              tooltip: 'Diminuer $label',
              visualDensity: VisualDensity.compact,
              onPressed: clamped <= min ? null : () => nudge(-step),
              icon: const Icon(Icons.remove_rounded, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Slider(
                value: clamped,
                min: min,
                max: max,
                divisions: divisions,
                label: '${clamped.toStringAsFixed(decimals)}$unit',
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              tooltip: 'Augmenter $label',
              visualDensity: VisualDensity.compact,
              onPressed: clamped >= max ? null : () => nudge(step),
              icon: Icon(
                Icons.add_rounded,
                size: 18,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
