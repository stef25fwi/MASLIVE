/// Widget pour gérer la visibilité du groupe sur les cartes
import 'package:flutter/material.dart';
import '../../models/map_preset_model.dart';
import '../../services/group/group_map_visibility_service.dart';
import '../../services/map_presets_service.dart';

class GroupMapVisibilityWidget extends StatefulWidget {
  final String adminUid;
  final String groupId;

  const GroupMapVisibilityWidget({
    super.key,
    required this.adminUid,
    required this.groupId,
  });

  @override
  State<GroupMapVisibilityWidget> createState() =>
      _GroupMapVisibilityWidgetState();
}

class _GroupMapVisibilityWidgetState extends State<GroupMapVisibilityWidget> {
  final _visibilityService = GroupMapVisibilityService.instance;
  final _presetService = MapPresetsService();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.map, size: 28, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Visibilité sur les cartes',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline, size: 20),
                  tooltip: 'Sélectionnez les cartes où le groupe est visible',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Cochez les cartes pour rendre votre groupe visible à tous les utilisateurs visualisant ces cartes',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<String>>(
              stream: _visibilityService.streamVisibleMaps(widget.adminUid),
              builder: (context, visibilitySnapshot) {
                final visibleMapIds = visibilitySnapshot.data ?? [];

                return StreamBuilder<List<MapPresetModel>>(
                  stream: _presetService.getGroupPresetsStream(widget.groupId),
                  builder: (context, presetsSnapshot) {
                    if (presetsSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final presets = presetsSnapshot.data ?? [];

                    if (presets.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Aucune carte disponible pour ce groupe',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return Column(
                      children: presets.map((preset) {
                        final isVisible = visibleMapIds.contains(preset.id);

                        return CheckboxListTile(
                          value: isVisible,
                          onChanged: (value) async {
                            await _visibilityService.toggleMapVisibility(
                              adminUid: widget.adminUid,
                              mapId: preset.id,
                              isVisible: value ?? false,
                            );
                          },
                          title: Text(preset.title),
                          subtitle: Text(
                            preset.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          secondary: Icon(
                            isVisible ? Icons.visibility : Icons.visibility_off,
                            color: isVisible ? Colors.green : Colors.grey,
                          ),
                          dense: true,
                        );
                      }).toList(),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
