import 'package:flutter/material.dart';

import '../../../map_style/domain/entities/map_style_preset.dart';
import 'package:masslive/ui_kit/tokens/maslive_tokens.dart';

class WizardQuickPresetCarousel extends StatelessWidget {
  const WizardQuickPresetCarousel({
    super.key,
    required this.presets,
    required this.onApply,
    required this.onPreview,
    required this.onDuplicate,
    this.selectedPresetId,
  });

  final List<MapStylePreset> presets;
  final ValueChanged<MapStylePreset> onApply;
  final ValueChanged<MapStylePreset> onPreview;
  final ValueChanged<MapStylePreset> onDuplicate;
  final String? selectedPresetId;

  @override
  Widget build(BuildContext context) {
    if (presets.isEmpty) {
      return const Text(
        'Aucun preset rapide publie.',
        style: TextStyle(color: MasliveTokens.textMuted),
      );
    }

    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final preset = presets[index];
          final selected = selectedPresetId == preset.id;
          return SizedBox(
            width: 260,
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: selected ? MasliveTokens.text : MasliveTokens.line,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      preset.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      preset.description.isEmpty ? 'Sans description' : preset.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: MasliveTokens.textMuted, fontSize: 12),
                    ),
                    const Spacer(),
                    Wrap(
                      spacing: 8,
                      children: <Widget>[
                        FilledButton(
                          onPressed: () => onApply(preset),
                          child: const Text('Appliquer'),
                        ),
                        OutlinedButton(
                          onPressed: () => onPreview(preset),
                          child: const Text('Preview'),
                        ),
                        TextButton(
                          onPressed: () => onDuplicate(preset),
                          child: const Text('Dupliquer'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemCount: presets.length,
      ),
    );
  }
}
