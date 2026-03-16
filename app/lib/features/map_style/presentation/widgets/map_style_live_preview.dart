import 'package:flutter/material.dart';

import '../../../../ui/map/maslive_map.dart';
import '../../domain/entities/map_style_enums.dart';
import '../../domain/entities/map_style_preset.dart';
import '../../services/map_style_preview_service.dart';

class MapStyleLivePreview extends StatefulWidget {
  const MapStyleLivePreview({
    super.key,
    required this.preset,
    required this.onGenerateThumbnail,
    required this.onTestInWizard,
  });

  final MapStylePreset preset;
  final VoidCallback onGenerateThumbnail;
  final VoidCallback onTestInWizard;

  @override
  State<MapStyleLivePreview> createState() => _MapStyleLivePreviewState();
}

class _MapStyleLivePreviewState extends State<MapStyleLivePreview> {
  final _previewService = const MapStylePreviewService();
  bool _is3d = true;
  bool _compareMode = false;
  MapStyleMode _mode = MapStyleMode.day;

  @override
  void initState() {
    super.initState();
    _mode = widget.preset.theme.global.mode;
  }

  @override
  void didUpdateWidget(covariant MapStyleLivePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preset.id != widget.preset.id) {
      _mode = widget.preset.theme.global.mode;
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _previewService.buildPreviewConfig(widget.preset, is3d: _is3d, overrideMode: _mode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            SegmentedButton<bool>(
              segments: const <ButtonSegment<bool>>[
                ButtonSegment<bool>(value: false, label: Text('2D')),
                ButtonSegment<bool>(value: true, label: Text('3D')),
              ],
              selected: <bool>{_is3d},
              onSelectionChanged: (selection) {
                setState(() => _is3d = selection.first);
              },
            ),
            SegmentedButton<MapStyleMode>(
              segments: const <ButtonSegment<MapStyleMode>>[
                ButtonSegment<MapStyleMode>(value: MapStyleMode.day, label: Text('Day')),
                ButtonSegment<MapStyleMode>(value: MapStyleMode.sunset, label: Text('Sunset')),
                ButtonSegment<MapStyleMode>(value: MapStyleMode.night, label: Text('Night')),
              ],
              selected: <MapStyleMode>{_mode},
              onSelectionChanged: (selection) {
                setState(() => _mode = selection.first);
              },
            ),
            FilterChip(
              selected: _compareMode,
              label: const Text('Compare before/after'),
              onSelected: (value) => setState(() => _compareMode = value),
            ),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _is3d = true;
                  _compareMode = false;
                  _mode = widget.preset.theme.global.mode;
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reset'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: <Widget>[
                MasLiveMap(
                  styleUrl: config.styleUrl,
                  initialPitch: config.pitch,
                  initialBearing: config.bearing,
                  initialZoom: 13,
                ),
                if (_compareMode)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: MediaQuery.sizeOf(context).width * 0.45,
                      color: Colors.black.withValues(alpha: 0.20),
                      child: const Center(
                        child: Text(
                          'Before',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: <Widget>[
            FilledButton.icon(
              onPressed: widget.onTestInWizard,
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('Tester dans wizard'),
            ),
            OutlinedButton.icon(
              onPressed: widget.onGenerateThumbnail,
              icon: const Icon(Icons.image_outlined),
              label: const Text('Generer miniature'),
            ),
          ],
        ),
      ],
    );
  }
}
