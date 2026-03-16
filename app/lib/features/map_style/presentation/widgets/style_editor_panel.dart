import 'package:flutter/material.dart';

import '../../domain/entities/map_style_preset.dart';
import '../sections/base_map_style_section.dart';
import '../sections/buildings_style_section.dart';
import '../sections/green_spaces_style_section.dart';
import '../sections/identity_style_section.dart';
import '../sections/labels_style_section.dart';
import '../sections/lighting_style_section.dart';
import '../sections/preview_style_section.dart';
import '../sections/roads_style_section.dart';
import '../sections/water_style_section.dart';

class StyleEditorPanel extends StatelessWidget {
  const StyleEditorPanel({
    super.key,
    required this.preset,
    required this.onChanged,
    required this.onCancel,
    required this.onSaveDraft,
    required this.onPublish,
    required this.onAddQuickPreset,
    required this.onSetDefault,
    required this.onGenerateThumbnail,
    required this.onTestInWizard,
  });

  final MapStylePreset preset;
  final ValueChanged<MapStylePreset> onChanged;
  final VoidCallback onCancel;
  final VoidCallback onSaveDraft;
  final VoidCallback onPublish;
  final VoidCallback onAddQuickPreset;
  final VoidCallback onSetDefault;
  final VoidCallback onGenerateThumbnail;
  final VoidCallback onTestInWizard;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 9,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const TabBar(
            isScrollable: true,
            tabs: <Tab>[
              Tab(text: 'Identite'),
              Tab(text: 'Base map'),
              Tab(text: 'Buildings'),
              Tab(text: 'Green spaces'),
              Tab(text: 'Water'),
              Tab(text: 'Roads'),
              Tab(text: 'Labels & POI'),
              Tab(text: 'Lighting'),
              Tab(text: 'Preview'),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                SingleChildScrollView(child: IdentityStyleSection(preset: preset, onChanged: onChanged)),
                SingleChildScrollView(child: BaseMapStyleSection(preset: preset, onChanged: onChanged)),
                SingleChildScrollView(child: BuildingsStyleSection(preset: preset, onChanged: onChanged)),
                SingleChildScrollView(child: GreenSpacesStyleSection(preset: preset, onChanged: onChanged)),
                SingleChildScrollView(child: WaterStyleSection(preset: preset, onChanged: onChanged)),
                SingleChildScrollView(child: RoadsStyleSection(preset: preset, onChanged: onChanged)),
                SingleChildScrollView(child: LabelsStyleSection(preset: preset, onChanged: onChanged)),
                SingleChildScrollView(child: LightingStyleSection(preset: preset, onChanged: onChanged)),
                SingleChildScrollView(
                  child: PreviewStyleSection(
                    preset: preset,
                    onGenerateThumbnail: onGenerateThumbnail,
                    onTestInWizard: onTestInWizard,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              OutlinedButton(onPressed: onCancel, child: const Text('Annuler')),
              OutlinedButton.icon(
                onPressed: onSaveDraft,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Enregistrer brouillon'),
              ),
              FilledButton.icon(
                onPressed: onPublish,
                icon: const Icon(Icons.publish_outlined),
                label: const Text('Publier'),
              ),
              OutlinedButton.icon(
                onPressed: onAddQuickPreset,
                icon: const Icon(Icons.flash_on_outlined),
                label: const Text('Ajouter aux presets rapides'),
              ),
              OutlinedButton.icon(
                onPressed: onSetDefault,
                icon: const Icon(Icons.star_outline),
                label: const Text('Definir comme preset par defaut'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
