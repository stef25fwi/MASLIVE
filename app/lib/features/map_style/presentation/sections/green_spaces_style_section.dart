import 'package:flutter/material.dart';

import '../../domain/entities/map_style_preset.dart';

class GreenSpacesStyleSection extends StatelessWidget {
  const GreenSpacesStyleSection({
    super.key,
    required this.preset,
    required this.onChanged,
  });

  final MapStylePreset preset;
  final ValueChanged<MapStylePreset> onChanged;

  @override
  Widget build(BuildContext context) {
    final green = preset.theme.greenSpaces;
    return Column(
      children: <Widget>[
        _text('color', green.color, (v) => _patch(green.copyWith(color: v))),
        _text('secondaryColor', green.secondaryColor, (v) => _patch(green.copyWith(secondaryColor: v))),
        _slider('opacity', green.opacity, 0, 1, (v) => _patch(green.copyWith(opacity: v))),
        _slider('saturation', green.saturation, 0, 2, (v) => _patch(green.copyWith(saturation: v))),
        _slider('contrast', green.contrast, 0, 2, (v) => _patch(green.copyWith(contrast: v))),
        DropdownButtonFormField<String>(
          initialValue: green.mode,
          decoration: const InputDecoration(labelText: 'mode'),
          items: const <String>['naturel', 'pastel', 'tropical', 'urbain', 'nuit']
              .map((item) => DropdownMenuItem<String>(value: item, child: Text(item)))
              .toList(growable: false),
          onChanged: (value) {
            if (value == null) return;
            _patch(green.copyWith(mode: value));
          },
        ),
      ],
    );
  }

  void _patch(dynamic next) {
    onChanged(preset.copyWith(theme: preset.theme.copyWith(greenSpaces: next)));
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
