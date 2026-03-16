import 'package:flutter/material.dart';

import '../../domain/entities/map_style_preset.dart';

class LightingStyleSection extends StatelessWidget {
  const LightingStyleSection({
    super.key,
    required this.preset,
    required this.onChanged,
  });

  final MapStylePreset preset;
  final ValueChanged<MapStylePreset> onChanged;

  @override
  Widget build(BuildContext context) {
    final lighting = preset.theme.lighting;
    return Column(
      children: <Widget>[
        _slider('intensity', lighting.intensity, 0, 1, (v) => _patch(lighting.copyWith(intensity: v))),
        _slider('shadowStrength', lighting.shadowStrength, 0, 1, (v) => _patch(lighting.copyWith(shadowStrength: v))),
        _slider('lightAngle', lighting.lightAngle, 0, 360, (v) => _patch(lighting.copyWith(lightAngle: v))),
        _slider('temperature', lighting.temperature, 1000, 10000, (v) => _patch(lighting.copyWith(temperature: v))),
        _slider('glow', lighting.glow, 0, 1, (v) => _patch(lighting.copyWith(glow: v))),
      ],
    );
  }

  void _patch(dynamic next) {
    onChanged(preset.copyWith(theme: preset.theme.copyWith(lighting: next)));
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
