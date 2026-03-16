import 'package:flutter/material.dart';

import '../../domain/entities/map_style_enums.dart';
import '../../domain/entities/map_style_preset.dart';

enum StylePresetAction {
  open,
  duplicate,
  rename,
  publish,
  toggleWizard,
  delete,
}

class StylePresetCard extends StatelessWidget {
  const StylePresetCard({
    super.key,
    required this.preset,
    required this.onTap,
    required this.onAction,
    this.isSelected = false,
  });

  final MapStylePreset preset;
  final VoidCallback onTap;
  final ValueChanged<StylePresetAction> onAction;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (preset.status) {
      MapStyleStatus.draft => Colors.orange,
      MapStyleStatus.published => Colors.green,
      MapStyleStatus.archived => Colors.grey,
    };

    return Card(
      elevation: isSelected ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? const Color(0xFF111827) : const Color(0xFFE5E7EB),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        _hexToColor(preset.dominantColor),
                        _hexToColor(preset.theme.water.color),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        preset.category.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      preset.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  PopupMenuButton<StylePresetAction>(
                    onSelected: onAction,
                    itemBuilder: (context) {
                      return <PopupMenuEntry<StylePresetAction>>[
                        const PopupMenuItem(value: StylePresetAction.open, child: Text('Ouvrir')),
                        const PopupMenuItem(value: StylePresetAction.duplicate, child: Text('Dupliquer')),
                        const PopupMenuItem(value: StylePresetAction.rename, child: Text('Renommer')),
                        const PopupMenuItem(value: StylePresetAction.publish, child: Text('Publier')),
                        PopupMenuItem(
                          value: StylePresetAction.toggleWizard,
                          child: Text(preset.visibleInWizard ? 'Masquer wizard' : 'Afficher wizard'),
                        ),
                        const PopupMenuItem(value: StylePresetAction.delete, child: Text('Supprimer')),
                      ];
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _dateLabel(preset.updatedAt),
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: <Widget>[
                  _badge(preset.status.name, statusColor),
                  if (preset.visibleInWizard) _badge('wizard', Colors.deepPurple),
                  if (preset.isDefault) _badge('default', Colors.black87),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _dateLabel(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month ${value.year} - $hour:$minute';
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }

  Color _hexToColor(String hex) {
    final value = hex.trim().replaceAll('#', '');
    if (value.length != 6) return const Color(0xFF111827);
    return Color(int.parse('FF$value', radix: 16));
  }
}
