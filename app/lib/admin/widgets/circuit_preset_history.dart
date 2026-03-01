import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../services/circuit_preset_service.dart';

/// Widget pour afficher l'historique des presets avec possibilité de restauration
class CircuitPresetHistory extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> currentData;
  final Function(Map<String, dynamic> data, String presetName) onRestore;

  const CircuitPresetHistory({
    super.key,
    required this.projectId,
    required this.currentData,
    required this.onRestore,
  });

  @override
  State<CircuitPresetHistory> createState() => _CircuitPresetHistoryState();
}

class _CircuitPresetHistoryState extends State<CircuitPresetHistory> {
  final CircuitPresetService _presetService = CircuitPresetService();
  List<CircuitPresetVersion>? _presets;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    _loadPresets();
  }

  Future<void> _loadPresets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final presets = await _presetService.listPresets(
        projectId: widget.projectId,
        limit: 50,
      );
      
      if (mounted) {
        setState(() {
          _presets = presets;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _restorePreset(CircuitPresetVersion preset) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurer cette version ?'),
        content: Text(
          'Êtes-vous sûr de vouloir restaurer la version "${preset.name}" ?\n\n'
          'Les modifications actuelles non sauvegardées seront perdues.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Restaurer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      widget.onRestore(preset.data, preset.name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Version "${preset.name}" restaurée'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _deletePreset(CircuitPresetVersion preset) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette version ?'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer la version "${preset.name}" ?\n\n'
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _presetService.deletePreset(
          projectId: widget.projectId,
          presetId: preset.id,
        );
        await _loadPresets();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Version supprimée'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Erreur: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _viewChangelog(CircuitPresetVersion preset) async {
    final changelog = _presetService.generateChangelog(
      oldData: preset.data,
      newData: widget.currentData,
    );

    final changelogText = _presetService.formatChangelog(changelog);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Différences avec "${preset.name}"'),
        content: SingleChildScrollView(
          child: Text(
            changelogText.isEmpty
                ? 'Aucune différence détectée'
                : changelogText,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text('Erreur: $_error'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                onPressed: _loadPresets,
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (_presets == null || _presets!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Aucune version sauvegardée',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Créez des presets pour sauvegarder\nl\'état actuel de votre circuit',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _presets!.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final preset = _presets![index];
        return _PresetCard(
          preset: preset,
          onRestore: () => _restorePreset(preset),
          onDelete: () => _deletePreset(preset),
          onViewChangelog: () => _viewChangelog(preset),
        );
      },
    );
  }
}

class _PresetCard extends StatelessWidget {
  final CircuitPresetVersion preset;
  final VoidCallback onRestore;
  final VoidCallback onDelete;
  final VoidCallback onViewChangelog;

  const _PresetCard({
    required this.preset,
    required this.onRestore,
    required this.onDelete,
    required this.onViewChangelog,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onViewChangelog,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'v${preset.version}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          preset.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timeago.format(preset.createdAt, locale: 'fr'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      switch (value) {
                        case 'restore':
                          onRestore();
                          break;
                        case 'compare':
                          onViewChangelog();
                          break;
                        case 'delete':
                          onDelete();
                          break;
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'restore',
                        child: Row(
                          children: [
                            Icon(Icons.restore, size: 20),
                            SizedBox(width: 8),
                            Text('Restaurer'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'compare',
                        child: Row(
                          children: [
                            Icon(Icons.compare_arrows, size: 20),
                            SizedBox(width: 8),
                            Text('Voir différences'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Supprimer', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (preset.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  preset.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.polyline,
                    label: '${(preset.data['routePoints'] as List?)?.length ?? 0} pts tracé',
                  ),
                  _InfoChip(
                    icon: Icons.location_on,
                    label: '${(preset.data['pois'] as List?)?.length ?? 0} POIs',
                  ),
                  _InfoChip(
                    icon: Icons.layers,
                    label: '${(preset.data['layers'] as List?)?.length ?? 0} layers',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
