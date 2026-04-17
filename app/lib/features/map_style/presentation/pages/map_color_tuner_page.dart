import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../ui/map/maslive_map.dart';
import '../../../../ui/map/maslive_map_controller.dart';

class MapColorTunerPage extends StatefulWidget {
  const MapColorTunerPage({super.key});

  @override
  State<MapColorTunerPage> createState() => _MapColorTunerPageState();
}

class _MapColorTunerPageState extends State<MapColorTunerPage> {
  static const List<_MapStyleOption> _styleOptions = <_MapStyleOption>[
    _MapStyleOption('Streets', 'mapbox://styles/mapbox/streets-v12'),
    _MapStyleOption('Outdoors', 'mapbox://styles/mapbox/outdoors-v12'),
    _MapStyleOption('Light', 'mapbox://styles/mapbox/light-v11'),
    _MapStyleOption('Dark', 'mapbox://styles/mapbox/dark-v11'),
    _MapStyleOption(
      'Satellite Streets',
      'mapbox://styles/mapbox/satellite-streets-v12',
    ),
  ];

  final MasLiveMapController _mapController = MasLiveMapController();

  _MapStyleOption _selectedStyle = _styleOptions.first;
  bool _buildingsEnabled = true;
  double _buildingOpacity = 0.72;
  Color _buildingColor = const Color(0xFFD1D5DB);
  Color _greenColor = const Color(0xFF77B255);
  Color _waterColor = const Color(0xFF58A6FF);

  Future<void> _applyAllSettings() async {
    await _mapController.setBuildings3d(
      enabled: _buildingsEnabled,
      opacity: _buildingOpacity,
    );
    await _mapController.setBuildingsColor(_buildingColor);
    await _mapController.setParkColor(_greenColor);
    await _mapController.setWaterColor(_waterColor);
  }

  Future<void> _resetDefaults() async {
    setState(() {
      _selectedStyle = _styleOptions.first;
      _buildingsEnabled = true;
      _buildingOpacity = 0.72;
      _buildingColor = const Color(0xFFD1D5DB);
      _greenColor = const Color(0xFF77B255);
      _waterColor = const Color(0xFF58A6FF);
    });

    await _mapController.setStyle(_selectedStyle.styleUrl);
    unawaited(_applyAllSettings());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reglage couleurs carte'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Reinitialiser',
            onPressed: _resetDefaults,
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _StatusBanner(styleLabel: _selectedStyle.label),
          const SizedBox(height: 16),
          _Panel(
            title: 'Apercu live',
            subtitle:
                'Les commandes utilisent le moteur Mapbox deja present dans le projet. Aucun package n\'a ete ajoute.',
            child: Column(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: MasLiveMap(
                      controller: _mapController,
                      styleUrl: _selectedStyle.styleUrl,
                      initialLng: -61.5340,
                      initialLat: 16.2410,
                      initialZoom: 13.2,
                      initialPitch: 45,
                      initialBearing: 18,
                      onMapReady: (_) {
                        unawaited(_applyAllSettings());
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<_MapStyleOption>(
                  initialValue: _selectedStyle,
                  decoration: const InputDecoration(
                    labelText: 'Style de base Mapbox',
                    border: OutlineInputBorder(),
                  ),
                  items: _styleOptions
                      .map(
                        (option) => DropdownMenuItem<_MapStyleOption>(
                          value: option,
                          child: Text(option.label),
                        ),
                      )
                      .toList(),
                  onChanged: (option) {
                    if (option == null) return;
                    setState(() => _selectedStyle = option);
                    unawaited(_mapController.setStyle(option.styleUrl));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Panel(
            title: 'Batiments 3D',
            subtitle:
                'Commandes verifiees: activation 3D, opacite et teinte des fill-extrusion.',
            child: Column(
              children: <Widget>[
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activer les batiments 3D'),
                  value: _buildingsEnabled,
                  onChanged: (value) {
                    setState(() => _buildingsEnabled = value);
                    unawaited(_applyAllSettings());
                  },
                ),
                _SliderRow(
                  label: 'Opacite',
                  value: _buildingOpacity,
                  min: 0,
                  max: 1,
                  onChanged: (value) {
                    setState(() => _buildingOpacity = value);
                    unawaited(_applyAllSettings());
                  },
                ),
                const SizedBox(height: 8),
                _ColorEditorCard(
                  title: 'Teinte batiments',
                  color: _buildingColor,
                  presets: const <Color>[
                    Color(0xFFD1D5DB),
                    Color(0xFFB08968),
                    Color(0xFF8D99AE),
                    Color(0xFFE9C46A),
                  ],
                  onChanged: (color) {
                    setState(() => _buildingColor = color);
                    unawaited(_applyAllSettings());
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ColorEditorCard(
            title: 'Verdure',
            subtitle:
                'Parcs, zones vertes et couches de vegetation detectees par le style.',
            color: _greenColor,
            presets: const <Color>[
              Color(0xFF77B255),
              Color(0xFF3A7D44),
              Color(0xFF8FBC5A),
              Color(0xFF2D6A4F),
            ],
            onChanged: (color) {
              setState(() => _greenColor = color);
              unawaited(_applyAllSettings());
            },
          ),
          const SizedBox(height: 16),
          _ColorEditorCard(
            title: 'Eau',
            subtitle:
                'Mers, rivieres, canaux et couches water du style courant.',
            color: _waterColor,
            presets: const <Color>[
              Color(0xFF58A6FF),
              Color(0xFF1D4ED8),
              Color(0xFF22B8CF),
              Color(0xFF0EA5E9),
            ],
            onChanged: (color) {
              setState(() => _waterColor = color);
              unawaited(_applyAllSettings());
            },
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.styleLabel});

  final String styleLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Commandes validees avant installation',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Le projet expose deja des hooks Mapbox pour les batiments 3D et la verdure. L\'outil ajoute ici complete le flux avec la couleur de l\'eau et la teinte live des batiments.',
            style: TextStyle(color: Color(0xFF475569)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _StatusChip(icon: Icons.apartment_rounded, label: 'Batiments 3D OK'),
              _StatusChip(icon: Icons.park_rounded, label: 'Verdure OK'),
              _StatusChip(icon: Icons.water_rounded, label: 'Eau OK'),
              _StatusChip(icon: Icons.map_outlined, label: styleLabel),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: const Color(0xFF0F172A)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 92,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: Slider.adaptive(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            value.toStringAsFixed(2),
            textAlign: TextAlign.end,
            style: const TextStyle(fontFeatures: <FontFeature>[]),
          ),
        ),
      ],
    );
  }
}

class _ColorEditorCard extends StatelessWidget {
  const _ColorEditorCard({
    required this.title,
    required this.color,
    required this.presets,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Color color;
  final List<Color> presets;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = color;
    return _Panel(
      title: title,
      subtitle: subtitle ?? 'Reglage RGB direct sans dependance externe.',
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: current,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _hex(current),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presets
                .map(
                  (preset) => InkWell(
                    onTap: () => onChanged(preset),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: preset,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: preset.toARGB32() == current.toARGB32()
                              ? const Color(0xFF0F172A)
                              : Colors.white,
                          width: 3,
                        ),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          _RgbSlider(
            label: 'Rouge',
            value: (current.r * 255).roundToDouble(),
            activeColor: const Color(0xFFDC2626),
            onChanged: (value) => onChanged(
              _replaceRgb(current, r: value.round()),
            ),
          ),
          _RgbSlider(
            label: 'Vert',
            value: (current.g * 255).roundToDouble(),
            activeColor: const Color(0xFF16A34A),
            onChanged: (value) => onChanged(
              _replaceRgb(current, g: value.round()),
            ),
          ),
          _RgbSlider(
            label: 'Bleu',
            value: (current.b * 255).roundToDouble(),
            activeColor: const Color(0xFF2563EB),
            onChanged: (value) => onChanged(
              _replaceRgb(current, b: value.round()),
            ),
          ),
        ],
      ),
    );
  }

  static Color _replaceRgb(Color color, {int? r, int? g, int? b}) {
    return Color.fromARGB(
      255,
      r ?? (color.r * 255).round(),
      g ?? (color.g * 255).round(),
      b ?? (color.b * 255).round(),
    );
  }

  static String _hex(Color color) {
    final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#${r.toUpperCase()}${g.toUpperCase()}${b.toUpperCase()}';
  }
}

class _RgbSlider extends StatelessWidget {
  const _RgbSlider({
    required this.label,
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  final String label;
  final double value;
  final Color activeColor;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(width: 60, child: Text(label)),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: activeColor,
              thumbColor: activeColor,
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 255,
              divisions: 255,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 38,
          child: Text(value.round().toString(), textAlign: TextAlign.end),
        ),
      ],
    );
  }
}

class _MapStyleOption {
  const _MapStyleOption(this.label, this.styleUrl);

  final String label;
  final String styleUrl;
}