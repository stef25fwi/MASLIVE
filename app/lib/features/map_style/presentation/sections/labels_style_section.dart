import 'package:flutter/material.dart';

import '../../domain/entities/map_style_preset.dart';

class LabelsStyleSection extends StatelessWidget {
  const LabelsStyleSection({
    super.key,
    required this.preset,
    required this.onChanged,
  });

  final MapStylePreset preset;
  final ValueChanged<MapStylePreset> onChanged;

  @override
  Widget build(BuildContext context) {
    final labels = preset.theme.labels;
    return Column(
      children: <Widget>[
        _text('textColor', labels.textColor, (v) => _patch(labels.copyWith(textColor: v))),
        _slider('opacity', labels.opacity, 0, 1, (v) => _patch(labels.copyWith(opacity: v))),
        _slider('fontSize', labels.fontSize, 8, 24, (v) => _patch(labels.copyWith(fontSize: v))),
        _slider('poiDensity', labels.poiDensity, 0, 2, (v) => _patch(labels.copyWith(poiDensity: v))),
        SwitchListTile.adaptive(
          title: const Text('showBusinesses'),
          value: labels.showBusinesses,
          onChanged: (value) => _patch(labels.copyWith(showBusinesses: value)),
        ),
        SwitchListTile.adaptive(
          title: const Text('showTransport'),
          value: labels.showTransport,
          onChanged: (value) => _patch(labels.copyWith(showTransport: value)),
        ),
        SwitchListTile.adaptive(
          title: const Text('showParking'),
          value: labels.showParking,
          onChanged: (value) => _patch(labels.copyWith(showParking: value)),
        ),
        SwitchListTile.adaptive(
          title: const Text('showTourism'),
          value: labels.showTourism,
          onChanged: (value) => _patch(labels.copyWith(showTourism: value)),
        ),
      ],
    );
  }

  void _patch(dynamic next) {
    onChanged(preset.copyWith(theme: preset.theme.copyWith(labels: next)));
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
