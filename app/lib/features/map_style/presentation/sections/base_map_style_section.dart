import 'package:flutter/material.dart';

import '../../domain/entities/map_style_enums.dart';
import '../../domain/entities/map_style_preset.dart';
import '../../utils/map_style_defaults.dart';

class BaseMapStyleSection extends StatelessWidget {
  const BaseMapStyleSection({
    super.key,
    required this.preset,
    required this.onChanged,
  });

  final MapStylePreset preset;
  final ValueChanged<MapStylePreset> onChanged;

  @override
  Widget build(BuildContext context) {
    final global = preset.theme.global;

    return Column(
      children: <Widget>[
        DropdownButtonFormField<String>(
          initialValue: global.mapboxBaseStyle,
          decoration: const InputDecoration(labelText: 'mapboxBaseStyle'),
          items: MapStyleDefaults.mapboxBaseStyles
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(growable: false),
          onChanged: (value) {
            if (value == null) return;
            onChanged(
              preset.copyWith(
                theme: preset.theme.copyWith(
                  global: global.copyWith(mapboxBaseStyle: value),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        _slider(
          label: 'brightness',
          value: global.brightness,
          min: 0,
          max: 2,
          onChanged: (value) => onChanged(
            preset.copyWith(
              theme: preset.theme.copyWith(global: global.copyWith(brightness: value)),
            ),
          ),
        ),
        _slider(
          label: 'contrast',
          value: global.contrast,
          min: 0,
          max: 2,
          onChanged: (value) => onChanged(
            preset.copyWith(
              theme: preset.theme.copyWith(global: global.copyWith(contrast: value)),
            ),
          ),
        ),
        _slider(
          label: 'saturation',
          value: global.saturation,
          min: 0,
          max: 2,
          onChanged: (value) => onChanged(
            preset.copyWith(
              theme: preset.theme.copyWith(global: global.copyWith(saturation: value)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<MapStyleMode>(
          initialValue: global.mode,
          decoration: const InputDecoration(labelText: 'mode'),
          items: MapStyleMode.values
              .map((item) => DropdownMenuItem(value: item, child: Text(item.name)))
              .toList(growable: false),
          onChanged: (value) {
            if (value == null) return;
            onChanged(
              preset.copyWith(
                theme: preset.theme.copyWith(global: global.copyWith(mode: value)),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('$label: ${value.toStringAsFixed(2)}'),
        Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
      ],
    );
  }
}
