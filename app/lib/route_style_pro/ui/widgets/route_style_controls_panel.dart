import 'package:flutter/material.dart';

import '../../models/route_style_config.dart';
import '../../models/route_style_preset.dart';
import 'color_picker_tile.dart';
import 'route_style_slider.dart';
import 'toggle_tile.dart';

class RouteStyleControlsPanel extends StatelessWidget {
  final RouteStyleConfig config;
  final ValueChanged<RouteStyleConfig> onChanged;

  final VoidCallback onTestAutoRoute;
  final VoidCallback onUseMyTrace;

  final VoidCallback onSave;
  final VoidCallback onReset;

  const RouteStyleControlsPanel({
    super.key,
    required this.config,
    required this.onChanged,
    required this.onTestAutoRoute,
    required this.onUseMyTrace,
    required this.onSave,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final cfg = config.validated();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onTestAutoRoute,
                  icon: const Icon(Icons.directions_car),
                  label: const Text('Tester sur un itinéraire auto'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onUseMyTrace,
                  icon: const Icon(Icons.timeline),
                  label: const Text('Utiliser mon tracé'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ExpansionTile(
            title: const Text('Base', style: TextStyle(fontWeight: FontWeight.bold)),
            initiallyExpanded: true,
            children: [
              ToggleTile(
                title: 'Mode voiture (snap + style route)',
                value: cfg.carMode,
                onChanged: (v) => onChanged(cfg.copyWith(carMode: v)),
              ),
              RouteStyleSlider(
                label: 'Opacité',
                value: cfg.opacity,
                min: 0.2,
                max: 1.0,
                divisions: 16,
                unit: '',
                decimals: 2,
                onChanged: (v) => onChanged(cfg.copyWith(opacity: v)),
              ),
              const SizedBox(height: 6),
              _EnumDropdown<RouteLineCap>(
                label: 'Arrondis (cap)',
                value: cfg.lineCap,
                values: RouteLineCap.values,
                labelFor: (v) => v.name,
                onChanged: (v) => onChanged(cfg.copyWith(lineCap: v)),
              ),
              _EnumDropdown<RouteLineJoin>(
                label: 'Jonctions (join)',
                value: cfg.lineJoin,
                values: RouteLineJoin.values,
                labelFor: (v) => v.name,
                onChanged: (v) => onChanged(cfg.copyWith(lineJoin: v)),
              ),
            ],
          ),

          ExpansionTile(
            title: const Text('Waze-like', style: TextStyle(fontWeight: FontWeight.bold)),
            children: [
              RouteStyleSlider(
                label: 'Largeur main',
                value: cfg.mainWidth,
                min: 2,
                max: 20,
                divisions: 18,
                unit: ' px',
                decimals: 0,
                onChanged: (v) => onChanged(cfg.copyWith(mainWidth: v)),
              ),
              RouteStyleSlider(
                label: 'Largeur casing',
                value: cfg.casingWidth,
                min: 0,
                max: 30,
                divisions: 30,
                unit: ' px',
                decimals: 0,
                onChanged: (v) => onChanged(cfg.copyWith(casingWidth: v)),
              ),
              ColorPickerTile(
                title: 'Couleur main',
                color: cfg.mainColor,
                onChanged: (c) => onChanged(cfg.copyWith(mainColor: c)),
              ),
              ColorPickerTile(
                title: 'Couleur casing',
                color: cfg.casingColor,
                onChanged: (c) => onChanged(cfg.copyWith(casingColor: c)),
              ),
            ],
          ),

          ExpansionTile(
            title: const Text('Glow / Ombre', style: TextStyle(fontWeight: FontWeight.bold)),
            children: [
              ToggleTile(
                title: 'Ombre',
                value: cfg.shadowEnabled,
                onChanged: (v) => onChanged(cfg.copyWith(shadowEnabled: v)),
              ),
              if (cfg.shadowEnabled) ...[
                RouteStyleSlider(
                  label: 'Opacité ombre',
                  value: cfg.shadowOpacity,
                  min: 0,
                  max: 1,
                  divisions: 20,
                  decimals: 2,
                  onChanged: (v) => onChanged(cfg.copyWith(shadowOpacity: v)),
                ),
                RouteStyleSlider(
                  label: 'Blur ombre',
                  value: cfg.shadowBlur,
                  min: 0,
                  max: 20,
                  divisions: 20,
                  unit: ' px',
                  decimals: 0,
                  onChanged: (v) => onChanged(cfg.copyWith(shadowBlur: v)),
                ),
              ],
              const Divider(),
              ToggleTile(
                title: 'Glow',
                value: cfg.glowEnabled,
                onChanged: (v) => onChanged(cfg.copyWith(glowEnabled: v)),
              ),
              if (cfg.glowEnabled) ...[
                RouteStyleSlider(
                  label: 'Opacité glow',
                  value: cfg.glowOpacity,
                  min: 0,
                  max: 1,
                  divisions: 20,
                  decimals: 2,
                  onChanged: (v) => onChanged(cfg.copyWith(glowOpacity: v)),
                ),
                RouteStyleSlider(
                  label: 'Blur glow',
                  value: cfg.glowBlur,
                  min: 0,
                  max: 40,
                  divisions: 40,
                  unit: ' px',
                  decimals: 0,
                  onChanged: (v) => onChanged(cfg.copyWith(glowBlur: v)),
                ),
                RouteStyleSlider(
                  label: 'Largeur glow',
                  value: cfg.glowWidth,
                  min: 0,
                  max: 30,
                  divisions: 30,
                  unit: ' px',
                  decimals: 0,
                  onChanged: (v) => onChanged(cfg.copyWith(glowWidth: v)),
                ),
              ],
            ],
          ),

          ExpansionTile(
            title: const Text('Gradient & Rainbow', style: TextStyle(fontWeight: FontWeight.bold)),
            children: [
              ToggleTile(
                title: 'Gradient',
                subtitle: 'Démo via segments (expression get(color))',
                value: cfg.gradientEnabled,
                onChanged: (v) => onChanged(cfg.copyWith(gradientEnabled: v)),
              ),
              ToggleTile(
                title: 'Rainbow animé',
                value: cfg.rainbowEnabled,
                onChanged: (v) => onChanged(cfg.copyWith(rainbowEnabled: v)),
              ),
              if (cfg.rainbowEnabled) ...[
                RouteStyleSlider(
                  label: 'Saturation',
                  value: cfg.rainbowSaturation,
                  min: 0,
                  max: 1,
                  divisions: 20,
                  decimals: 2,
                  onChanged: (v) => onChanged(cfg.copyWith(rainbowSaturation: v)),
                ),
                RouteStyleSlider(
                  label: 'Vitesse',
                  value: cfg.rainbowSpeed,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  unit: '',
                  decimals: 0,
                  onChanged: (v) => onChanged(cfg.copyWith(rainbowSpeed: v)),
                ),
                ToggleTile(
                  title: 'Direction arrière',
                  value: cfg.rainbowReverse,
                  onChanged: (v) => onChanged(cfg.copyWith(rainbowReverse: v)),
                ),
              ],
            ],
          ),

          ExpansionTile(
            title: const Text('Traffic / Segments', style: TextStyle(fontWeight: FontWeight.bold)),
            children: [
              ToggleTile(
                title: 'Traffic coloring (démo)',
                subtitle: 'Coloration segmentée vert/orange/rouge',
                value: cfg.trafficDemoEnabled,
                onChanged: (v) => onChanged(cfg.copyWith(trafficDemoEnabled: v)),
              ),
              const SizedBox(height: 8),
              ToggleTile(
                title: 'Vanishing route line',
                subtitle: 'Partie parcourue translucide (démo)',
                value: cfg.vanishingEnabled,
                onChanged: (v) => onChanged(cfg.copyWith(vanishingEnabled: v)),
              ),
              if (cfg.vanishingEnabled)
                RouteStyleSlider(
                  label: 'Progression',
                  value: cfg.vanishingProgress,
                  min: 0,
                  max: 1,
                  divisions: 20,
                  decimals: 2,
                  onChanged: (v) => onChanged(cfg.copyWith(vanishingProgress: v)),
                ),
              const SizedBox(height: 8),
              ToggleTile(
                title: 'Alternative routes (démo)',
                subtitle: 'Structure extensible (pas de routes alternatives réelles)',
                value: cfg.alternativesEnabled,
                onChanged: (v) => onChanged(cfg.copyWith(alternativesEnabled: v)),
              ),
            ],
          ),

          ExpansionTile(
            title: const Text('Presets', style: TextStyle(fontWeight: FontWeight.bold)),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in RouteStylePresets.all)
                    ChoiceChip(
                      label: Text(p.label),
                      selected: _looksLikePreset(cfg, p.config),
                      onSelected: (_) => onChanged(p.config),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Astuce: les presets remplacent la config courante.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),

          ExpansionTile(
            title: const Text('Snap & Qualité', style: TextStyle(fontWeight: FontWeight.bold)),
            children: [
              RouteStyleSlider(
                label: 'Tolérance snap',
                value: cfg.snapToleranceMeters,
                min: 5,
                max: 150,
                divisions: 29,
                unit: ' m',
                decimals: 0,
                onChanged: (v) => onChanged(cfg.copyWith(snapToleranceMeters: v)),
              ),
              RouteStyleSlider(
                label: 'Simplification',
                value: cfg.simplifyPercent,
                min: 0,
                max: 100,
                divisions: 20,
                unit: ' %',
                decimals: 0,
                onChanged: (v) => onChanged(cfg.copyWith(simplifyPercent: v)),
              ),
              ToggleTile(
                title: 'Dash',
                value: cfg.dashEnabled,
                onChanged: (v) => onChanged(cfg.copyWith(dashEnabled: v)),
              ),
              if (cfg.dashEnabled) ...[
                RouteStyleSlider(
                  label: 'Dash length',
                  value: cfg.dashLength,
                  min: 0.5,
                  max: 10,
                  divisions: 19,
                  decimals: 1,
                  onChanged: (v) => onChanged(cfg.copyWith(dashLength: v)),
                ),
                RouteStyleSlider(
                  label: 'Dash gap',
                  value: cfg.dashGap,
                  min: 0.5,
                  max: 10,
                  divisions: 19,
                  decimals: 1,
                  onChanged: (v) => onChanged(cfg.copyWith(dashGap: v)),
                ),
              ],
              ToggleTile(
                title: 'Pulse',
                subtitle: 'Animation opacité glow',
                value: cfg.pulseEnabled,
                onChanged: (v) => onChanged(cfg.copyWith(pulseEnabled: v)),
              ),
              if (cfg.pulseEnabled)
                RouteStyleSlider(
                  label: 'Vitesse pulse',
                  value: cfg.pulseSpeed,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  decimals: 0,
                  onChanged: (v) => onChanged(cfg.copyWith(pulseSpeed: v)),
                ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReset,
                  child: const Text('Réinitialiser'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onSave,
                  child: const Text('Appliquer / Enregistrer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _looksLikePreset(RouteStyleConfig a, RouteStyleConfig b) {
    // Heuristique simple (évite d'avoir un state presetId)
    final aa = a.validated();
    final bb = b.validated();
    return aa.mainWidth == bb.mainWidth &&
        aa.casingWidth == bb.casingWidth &&
        aa.mainColor.toARGB32() == bb.mainColor.toARGB32() &&
        aa.casingColor.toARGB32() == bb.casingColor.toARGB32() &&
        aa.glowEnabled == bb.glowEnabled &&
        aa.rainbowEnabled == bb.rainbowEnabled;
  }
}

class _EnumDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> values;
  final String Function(T) labelFor;
  final ValueChanged<T> onChanged;

  const _EnumDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          DropdownButton<T>(
            value: value,
            items: [
              for (final v in values)
                DropdownMenuItem<T>(
                  value: v,
                  child: Text(labelFor(v)),
                ),
            ],
            onChanged: (v) {
              if (v == null) return;
              onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}
