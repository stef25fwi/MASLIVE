import 'package:flutter/material.dart';

import '../../domain/entities/map_style_preset.dart';

class RoadsStyleSection extends StatelessWidget {
  const RoadsStyleSection({
    super.key,
    required this.preset,
    required this.onChanged,
  });

  final MapStylePreset preset;
  final ValueChanged<MapStylePreset> onChanged;

  @override
  Widget build(BuildContext context) {
    final roads = preset.theme.roads;
    return Column(
      children: <Widget>[
        _text('primaryColor', roads.primaryColor, (v) => _patch(roads.copyWith(primaryColor: v))),
        _text('secondaryColor', roads.secondaryColor, (v) => _patch(roads.copyWith(secondaryColor: v))),
        _text('pedestrianColor', roads.pedestrianColor, (v) => _patch(roads.copyWith(pedestrianColor: v))),
        _text('trafficAccent', roads.trafficAccent, (v) => _patch(roads.copyWith(trafficAccent: v))),
        _text('closedRoadColor', roads.closedRoadColor, (v) => _patch(roads.copyWith(closedRoadColor: v))),
        _text('detourColor', roads.detourColor, (v) => _patch(roads.copyWith(detourColor: v))),
        _slider('lineThickness', roads.lineThickness, 0.4, 4, (v) => _patch(roads.copyWith(lineThickness: v))),
      ],
    );
  }

  void _patch(dynamic next) {
    onChanged(preset.copyWith(theme: preset.theme.copyWith(roads: next)));
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
