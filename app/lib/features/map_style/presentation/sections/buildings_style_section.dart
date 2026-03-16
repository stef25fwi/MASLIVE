import 'package:flutter/material.dart';

import '../../domain/entities/map_style_preset.dart';

class BuildingsStyleSection extends StatelessWidget {
  const BuildingsStyleSection({
    super.key,
    required this.preset,
    required this.onChanged,
  });

  final MapStylePreset preset;
  final ValueChanged<MapStylePreset> onChanged;

  @override
  Widget build(BuildContext context) {
    final buildings = preset.theme.buildings;
    return Column(
      children: <Widget>[
        SwitchListTile.adaptive(
          title: const Text('enabled'),
          value: buildings.enabled,
          onChanged: (value) => _patch(buildings.copyWith(enabled: value)),
        ),
        _text('color', buildings.color, (v) => _patch(buildings.copyWith(color: v))),
        _text('secondaryColor', buildings.secondaryColor, (v) => _patch(buildings.copyWith(secondaryColor: v))),
        _text('roofTint', buildings.roofTint, (v) => _patch(buildings.copyWith(roofTint: v))),
        _slider('opacity', buildings.opacity, 0, 1, (v) => _patch(buildings.copyWith(opacity: v))),
        _slider('extrusion', buildings.extrusion, 0, 1, (v) => _patch(buildings.copyWith(extrusion: v))),
        _slider('shadow', buildings.shadow, 0, 1, (v) => _patch(buildings.copyWith(shadow: v))),
        _slider('lightIntensity', buildings.lightIntensity, 0, 1, (v) => _patch(buildings.copyWith(lightIntensity: v))),
      ],
    );
  }

  void _patch(dynamic next) {
    onChanged(preset.copyWith(theme: preset.theme.copyWith(buildings: next)));
  }

  Widget _text(String label, String initial, ValueChanged<String> onValue) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        initialValue: initial,
        decoration: InputDecoration(labelText: label),
        onChanged: onValue,
      ),
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
