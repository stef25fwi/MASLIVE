import 'package:flutter/material.dart';
import '../../services/circuit_preset_service.dart';

/// Widget pour afficher un log des modifications avant publication
class CircuitChangelogViewer extends StatelessWidget {
  final Map<String, dynamic> oldData;
  final Map<String, dynamic> newData;
  final String title;

  const CircuitChangelogViewer({
    super.key,
    required this.oldData,
    required this.newData,
    this.title = 'Modifications détectées',
  });

  @override
  Widget build(BuildContext context) {
    final presetService = CircuitPresetService();
    final changelog = presetService.generateChangelog(
      oldData: oldData,
      newData: newData,
    );

    if (changelog.isEmpty) {
      return Card(
        color: Colors.grey[100],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.grey[600]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Aucune modification depuis la dernière sauvegarde',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: ExpansionTile(
        leading: const Icon(Icons.timeline, color: Colors.blue),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          '${changelog.length} ${changelog.length == 1 ? 'modification' : 'modifications'}',
          style: const TextStyle(fontSize: 12),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: changelog.entries.map((entry) {
                return _ChangeItem(
                  fieldKey: entry.key,
                  change: entry.value as Map<String, dynamic>,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangeItem extends StatelessWidget {
  final String fieldKey;
  final Map<String, dynamic> change;

  const _ChangeItem({
    required this.fieldKey,
    required this.change,
  });

  String _getFieldName(String key) {
    const fieldNames = {
      'name': 'Nom du circuit',
      'description': 'Description',
      'countryId': 'Pays',
      'eventId': 'Événement',
      'styleUrl': 'Style de carte',
      'perimeterPoints': 'Points du périmètre',
      'routePoints': 'Points du tracé',
      'routeColor': 'Couleur du tracé',
      'routeWidth': 'Largeur du tracé',
      'layers': 'Nombre de layers',
      'pois': 'Nombre de POIs',
      'routeStylePro': 'Style Pro',
    };
    return fieldNames[key] ?? key;
  }

  IconData _getFieldIcon(String key) {
    const icons = {
      'name': Icons.label,
      'description': Icons.description,
      'countryId': Icons.flag,
      'eventId': Icons.event,
      'styleUrl': Icons.map,
      'perimeterPoints': Icons.pentagon,
      'routePoints': Icons.polyline,
      'routeColor': Icons.palette,
      'routeWidth': Icons.line_weight,
      'layers': Icons.layers,
      'pois': Icons.location_on,
      'routeStylePro': Icons.style,
    };
    return icons[key] ?? Icons.edit;
  }

  String _formatValue(dynamic value) {
    if (value == null) return 'non défini';
    if (value is List) return '${value.length} éléments';
    if (value is String && value.isEmpty) return 'vide';
    if (value is String && value.length > 50) {
      return '${value.substring(0, 47)}...';
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final oldValue = change['old'];
    final newValue = change['new'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _getFieldIcon(fieldKey),
            size: 20,
            color: Colors.blue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getFieldName(fieldKey),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Avant',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.red[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatValue(oldValue),
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Après',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatValue(newValue),
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
