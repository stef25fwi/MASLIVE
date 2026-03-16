import '../domain/entities/map_style_enums.dart';
import '../domain/entities/map_style_preset.dart';

class MapStylePreviewConfig {
  const MapStylePreviewConfig({
    required this.styleUrl,
    required this.pitch,
    required this.bearing,
    required this.mode,
  });

  final String styleUrl;
  final double pitch;
  final double bearing;
  final MapStyleMode mode;
}

class MapStylePreviewService {
  const MapStylePreviewService();

  MapStylePreviewConfig buildPreviewConfig(
    MapStylePreset preset, {
    bool is3d = false,
    MapStyleMode? overrideMode,
  }) {
    final mode = overrideMode ?? preset.theme.global.mode;
    final pitch = is3d ? 45.0 : 0.0;
    final bearing = switch (mode) {
      MapStyleMode.day => 0.0,
      MapStyleMode.sunset => 20.0,
      MapStyleMode.night => 35.0,
      MapStyleMode.auto => 10.0,
    };

    return MapStylePreviewConfig(
      styleUrl: preset.theme.global.mapboxBaseStyle,
      pitch: pitch,
      bearing: bearing,
      mode: mode,
    );
  }
}
