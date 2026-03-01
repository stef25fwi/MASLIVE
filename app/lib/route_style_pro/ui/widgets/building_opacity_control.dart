import 'package:flutter/material.dart';

import '../../models/route_style_config.dart';

/// Widget de contrôle de la transparence des immeubles 3D (premium).
///
/// Fournit:
/// - Un toggle pour activer/désactiver les bâtiments 3D
/// - Un slider pour régler l'opacité (0% = invisible, 100% = opaque)
/// - Des presets rapides cliquables
/// - Un bouton de réinitialisation
class BuildingOpacityControl extends StatelessWidget {
  final RouteStyleConfig config;
  final ValueChanged<RouteStyleConfig> onChanged;

  /// Presets d'opacité disponibles
  static const List<({String label, double value})> presets = [
    (label: 'Opaque', value: 1.0),
    (label: 'Confort', value: 0.70),
    (label: 'Équilibré', value: 0.55),
    (label: 'Léger', value: 0.35),
    (label: 'Ghost', value: 0.20),
  ];

  /// Valeur par défaut (60%)
  static const double defaultOpacity = 0.60;

  const BuildingOpacityControl({
    super.key,
    required this.config,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = config.buildings3dEnabled;
    final opacity = config.buildingOpacity;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête avec icône et toggle
          Row(
            children: [
              Icon(
                Icons.apartment_rounded,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transparence immeubles',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Règle l\'opacité des bâtiments 3D',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isEnabled,
                onChanged: (v) => onChanged(
                  config.copyWith(buildings3dEnabled: v),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Slider principal
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: opacity,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  onChanged: isEnabled
                      ? (v) => onChanged(
                            config.copyWith(buildingOpacity: v),
                          )
                      : null,
                  label: '${(opacity * 100).round()}%',
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 60,
                child: Text(
                  '${(opacity * 100).round()}%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isEnabled
                        ? theme.colorScheme.primary
                        : theme.disabledColor,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Presets rapides
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presets.map((preset) {
              final isActive = (opacity - preset.value).abs() < 0.05;
              return _PresetChip(
                label: preset.label,
                isActive: isActive,
                isEnabled: isEnabled,
                onTap: () => onChanged(
                  config.copyWith(buildingOpacity: preset.value),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),

          // Bouton réinitialiser
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: isEnabled
                  ? () => onChanged(
                        config.copyWith(buildingOpacity: defaultOpacity),
                      )
                  : null,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Réinitialiser'),
            ),
          ),

          // Tooltip explicatif
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '0% = invisible • 100% = opaque',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip de preset cliquable
class _PresetChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isEnabled;
  final VoidCallback onTap;

  const _PresetChip({
    required this.label,
    required this.isActive,
    required this.isEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: isEnabled ? onTap : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.3),
            width: isActive ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
            color: isActive
                ? theme.colorScheme.onPrimary
                : (isEnabled
                    ? theme.colorScheme.onSurface
                    : theme.disabledColor),
          ),
        ),
      ),
    );
  }
}
