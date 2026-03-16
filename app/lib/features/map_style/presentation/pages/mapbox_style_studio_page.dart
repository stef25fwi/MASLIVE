import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/mocks/map_style_mock_presets.dart';
import '../../domain/entities/map_style_preset.dart';
import '../../presentation/controllers/map_style_editor_controller.dart';
import '../../presentation/controllers/map_style_studio_controller.dart';
import '../../services/map_style_thumbnail_service.dart';
import '../../utils/map_style_defaults.dart';
import '../widgets/style_editor_panel.dart';
import '../widgets/style_preset_card.dart';

class MapboxStyleStudioPage extends StatelessWidget {
  const MapboxStyleStudioPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<MapStyleStudioController>(
          create: (_) => MapStyleStudioController()..start(organizationId: _resolveOrgId()),
        ),
        ChangeNotifierProvider<MapStyleEditorController>(
          create: (_) => MapStyleEditorController(),
        ),
      ],
      child: const _MapboxStyleStudioView(),
    );
  }

  String _resolveOrgId() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return (uid == null || uid.trim().isEmpty) ? 'maslive' : uid;
  }
}

class _MapboxStyleStudioView extends StatelessWidget {
  const _MapboxStyleStudioView();

  @override
  Widget build(BuildContext context) {
    final studio = context.watch<MapStyleStudioController>();
    final editor = context.watch<MapStyleEditorController>();

    final selected = editor.draft ?? studio.selectedPreset;
    if (editor.draft == null && studio.selectedPreset != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.read<MapStyleEditorController>().load(studio.selectedPreset!);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapbox Style Studio'),
        actions: <Widget>[
          TextButton.icon(
            onPressed: () => _createPreset(context),
            icon: const Icon(Icons.add),
            label: const Text('Nouveau preset'),
          ),
          TextButton.icon(
            onPressed: () => _seedMocks(context),
            icon: const Icon(Icons.file_upload_outlined),
            label: const Text('Importer'),
          ),
          TextButton.icon(
            onPressed: () {
              final current = selected;
              if (current == null) return;
              context.read<MapStyleStudioController>().setDefaultPreset(current.id);
            },
            icon: const Icon(Icons.star_outline),
            label: const Text('Preset par defaut'),
          ),
          IconButton(
            tooltip: 'Apercu plein ecran',
            onPressed: () {
              final current = selected;
              if (current == null) return;
              _showPreviewFullscreen(context, current);
            },
            icon: const Icon(Icons.fullscreen),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Creez des themes cartographiques reutilisables pour vos cartes, circuits et evenements',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 12),
            _StatsBand(controller: studio),
            const SizedBox(height: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final splitVertical = constraints.maxWidth >= 1080;
                  if (splitVertical) {
                    return Row(
                      children: <Widget>[
                        SizedBox(
                          width: 380,
                          child: _PresetLibrary(studio: studio, editor: editor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _EditorSurface(studio: studio, editor: editor, selected: selected),
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: <Widget>[
                      SizedBox(height: 260, child: _PresetLibrary(studio: studio, editor: editor)),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _EditorSurface(studio: studio, editor: editor, selected: selected),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createPreset(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
    final orgId = uid;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final draft = MapStyleDefaults.newDraft(
      id: id,
      ownerUid: uid,
      orgId: orgId,
      name: 'Preset ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
    );
    final created = await context.read<MapStyleStudioController>().createPreset(draft);
    if (!context.mounted) return;
    context.read<MapStyleEditorController>().load(created);
  }

  Future<void> _seedMocks(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
    final mocks = MapStyleMockPresets.build(ownerUid: uid, orgId: uid);
    final studio = context.read<MapStyleStudioController>();
    for (final preset in mocks) {
      await studio.createPreset(preset.copyWith(id: ''));
    }
  }

  void _showPreviewFullscreen(BuildContext context, MapStylePreset preset) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          contentPadding: const EdgeInsets.all(0),
          content: SizedBox(
            width: 980,
            height: 620,
            child: StyleEditorPanel(
              preset: preset,
              onChanged: (_) {},
              onCancel: () => Navigator.of(context).pop(),
              onSaveDraft: () {},
              onPublish: () {},
              onAddQuickPreset: () {},
              onSetDefault: () {},
              onGenerateThumbnail: () {},
              onTestInWizard: () {},
            ),
          ),
        );
      },
    );
  }
}

class _StatsBand extends StatelessWidget {
  const _StatsBand({required this.controller});

  final MapStyleStudioController controller;

  @override
  Widget build(BuildContext context) {
    final stats = controller.stats;
    final last = stats.lastUpdate == null
        ? 'N/A'
        : '${stats.lastUpdate!.day.toString().padLeft(2, '0')}/${stats.lastUpdate!.month.toString().padLeft(2, '0')} ${stats.lastUpdate!.hour.toString().padLeft(2, '0')}:${stats.lastUpdate!.minute.toString().padLeft(2, '0')}';

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        _stat('Presets total', '${stats.total}'),
        _stat('Presets publies', '${stats.published}'),
        _stat('Visibles wizard', '${stats.wizardVisible}'),
        _stat('Derniere modification', last),
      ],
    );
  }

  Widget _stat(String label, String value) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _PresetLibrary extends StatelessWidget {
  const _PresetLibrary({required this.studio, required this.editor});

  final MapStyleStudioController studio;
  final MapStyleEditorController editor;

  @override
  Widget build(BuildContext context) {
    if (studio.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (studio.error != null) {
      return Center(child: Text('Erreur: ${studio.error}'));
    }
    if (studio.presets.isEmpty) {
      return const Center(child: Text('Aucun preset. Creez-en un.'));
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.86,
      ),
      itemCount: studio.presets.length,
      itemBuilder: (context, index) {
        final preset = studio.presets[index];
        return StylePresetCard(
          preset: preset,
          isSelected: studio.selectedPreset?.id == preset.id,
          onTap: () {
            studio.selectPreset(preset);
            editor.load(preset);
          },
          onAction: (action) => _onPresetAction(context, preset, action),
        );
      },
    );
  }

  Future<void> _onPresetAction(BuildContext context, MapStylePreset preset, StylePresetAction action) async {
    final studioController = context.read<MapStyleStudioController>();
    switch (action) {
      case StylePresetAction.open:
        studioController.selectPreset(preset);
        context.read<MapStyleEditorController>().load(preset);
      case StylePresetAction.duplicate:
        final duplicated = await studioController.duplicatePreset(preset.id);
        if (!context.mounted) return;
        context.read<MapStyleEditorController>().load(duplicated);
      case StylePresetAction.rename:
        final value = await _prompt(context, title: 'Renommer preset', initialValue: preset.name);
        if (value == null || value.trim().isEmpty) return;
        await studioController.savePreset(preset.copyWith(name: value.trim()));
      case StylePresetAction.publish:
        await studioController.publishPreset(preset.id);
      case StylePresetAction.toggleWizard:
        await studioController.toggleWizardVisibility(preset, !preset.visibleInWizard);
      case StylePresetAction.delete:
        await studioController.deletePreset(preset.id);
    }
  }

  Future<String?> _prompt(BuildContext context, {required String title, required String initialValue}) async {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(controller: controller),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Valider')),
          ],
        );
      },
    );
  }
}

class _EditorSurface extends StatelessWidget {
  const _EditorSurface({
    required this.studio,
    required this.editor,
    required this.selected,
  });

  final MapStyleStudioController studio;
  final MapStyleEditorController editor;
  final MapStylePreset? selected;

  @override
  Widget build(BuildContext context) {
    if (selected == null) {
      return const Card(
        child: Center(
          child: Text('Selectionnez un preset pour commencer l\'edition.'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: StyleEditorPanel(
          preset: selected!,
          onChanged: (preset) => editor.load(preset),
          onCancel: editor.resetChanges,
          onSaveDraft: () async {
            final validation = editor.validateForSave();
            if (validation != null) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(validation)));
              }
              return;
            }
            final draft = editor.draft;
            if (draft == null) return;
            await studio.savePreset(draft.copyWith(status: draft.status));
          },
          onPublish: () async {
            final draft = editor.draft;
            if (draft == null) return;
            await studio.savePreset(draft);
            await studio.publishPreset(draft.id);
          },
          onAddQuickPreset: () async {
            final draft = editor.draft;
            if (draft == null) return;
            await studio.savePreset(
              draft.copyWith(
                visibleInWizard: true,
                isQuickPreset: true,
              ),
            );
          },
          onSetDefault: () async {
            final draft = editor.draft;
            if (draft == null) return;
            await studio.setDefaultPreset(draft.id);
          },
          onGenerateThumbnail: () async {
            final draft = editor.draft;
            if (draft == null) return;
            final service = const MapStyleThumbnailService();
            final url = await service.generatePlaceholderThumbnail(draft);
            editor.load(draft.copyWith(thumbnailUrl: url));
          },
          onTestInWizard: () {
            final draft = editor.draft;
            if (draft == null) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Preset pret pour Wizard etape 2: ${draft.name}')),
            );
          },
        ),
      ),
    );
  }
}
