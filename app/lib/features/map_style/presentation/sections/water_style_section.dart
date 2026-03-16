import 'package:flutter/material.dart';

import '../../domain/entities/map_style_preset.dart';

class WaterStyleSection extends StatelessWidget {
  const WaterStyleSection({
    super.key,
    required this.preset,
    required this.onChanged,
  });

  final MapStylePreset preset;
  final ValueChanged<MapStylePreset> onChanged;

  @override
  Widget build(BuildContext context) {
    final water = preset.theme.water;
    return Column(
      children: <Widget>[
        _text('color', water.color, (v) => _patch(water.copyWith(color: v))),
        _text('shoreHighlight', water.shoreHighlight, (v) => _patch(water.copyWith(shoreHighlight: v))),
        _slider('opacity', water.opacity, 0, 1, (v) => _patch(water.copyWith(opacity: v))),
        _slider('brightness', water.brightness, 0, 2, (v) => _patch(water.copyWith(brightness: v))),
        _slider('reflection', water.reflection, 0, 1, (v) => _patch(water.copyWith(reflection: v))),
      ],
    );
  }

  void _patch(dynamic next) {
    onChanged(preset.copyWith(theme: preset.theme.copyWith(water: next)));
  }

  Widget _text(String label, String initial, ValueChanged<String> onValue) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(initialValue: initial, decoration: InputDecoration(labelText: label), onChanged: onValue),
    );
  }

  Widget _slider(String label, double value, double min, double max, ValueChanged<double> onValue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('$label: ${value.toStringAsFixed(2)}'),
        Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onValue),
      ],
    );
  }
}
