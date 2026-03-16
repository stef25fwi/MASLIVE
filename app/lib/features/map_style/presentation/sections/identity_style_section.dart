import 'package:flutter/material.dart';

import '../../domain/entities/map_style_enums.dart';
import '../../domain/entities/map_style_preset.dart';

class IdentityStyleSection extends StatelessWidget {
  const IdentityStyleSection({
    super.key,
    required this.preset,
    required this.onChanged,
  });

  final MapStylePreset preset;
  final ValueChanged<MapStylePreset> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        TextFormField(
          initialValue: preset.name,
          decoration: const InputDecoration(labelText: 'name'),
          onChanged: (value) => onChanged(preset.copyWith(name: value)),
        ),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: preset.description,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'description'),
          onChanged: (value) => onChanged(preset.copyWith(description: value)),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<MapStyleCategory>(
          initialValue: preset.category,
          decoration: const InputDecoration(labelText: 'category'),
          items: MapStyleCategory.values
              .map((item) => DropdownMenuItem(value: item, child: Text(item.name)))
              .toList(growable: false),
          onChanged: (value) {
            if (value == null) return;
            onChanged(preset.copyWith(category: value));
          },
        ),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: preset.thumbnailUrl,
          decoration: const InputDecoration(labelText: 'thumbnail'),
          onChanged: (value) => onChanged(preset.copyWith(thumbnailUrl: value)),
        ),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: preset.dominantColor,
          decoration: const InputDecoration(labelText: 'dominantColor (#RRGGBB)'),
          onChanged: (value) => onChanged(preset.copyWith(dominantColor: value)),
        ),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: preset.tags.join(', '),
          decoration: const InputDecoration(labelText: 'tags (comma separated)'),
          onChanged: (value) {
            final tags = value
                .split(',')
                .map((item) => item.trim())
                .where((item) => item.isNotEmpty)
                .toList(growable: false);
            onChanged(preset.copyWith(tags: tags));
          },
        ),
        const SizedBox(height: 10),
        SwitchListTile.adaptive(
          title: const Text('visibleInWizard'),
          value: preset.visibleInWizard,
          onChanged: (value) => onChanged(
            preset.copyWith(
              visibleInWizard: value,
              isQuickPreset: value ? preset.isQuickPreset : false,
            ),
          ),
        ),
        SwitchListTile.adaptive(
          title: const Text('isQuickPreset'),
          value: preset.isQuickPreset,
          onChanged: preset.visibleInWizard
              ? (value) => onChanged(preset.copyWith(isQuickPreset: value))
              : null,
        ),
        SwitchListTile.adaptive(
          title: const Text('isDefault'),
          value: preset.isDefault,
          onChanged: (value) => onChanged(preset.copyWith(isDefault: value)),
        ),
      ],
    );
  }
}
