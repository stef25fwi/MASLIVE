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
    final clamped = value.clamp(min, max);
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
        Slider(
          value: clamped,
          min: min,
          max: max,
          divisions: divisions,
          label: '${clamped.toStringAsFixed(decimals)}$unit',
          onChanged: onChanged,
        ),
      ],
    );
  }
}
