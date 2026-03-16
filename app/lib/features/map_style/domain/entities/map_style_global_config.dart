import 'map_style_enums.dart';

class MapStyleGlobalConfig {
  const MapStyleGlobalConfig({
    required this.mapboxBaseStyle,
    required this.brightness,
    required this.contrast,
    required this.saturation,
    required this.mode,
  });

  final String mapboxBaseStyle;
  final double brightness;
  final double contrast;
  final double saturation;
  final MapStyleMode mode;

  MapStyleGlobalConfig copyWith({
    String? mapboxBaseStyle,
    double? brightness,
    double? contrast,
    double? saturation,
    MapStyleMode? mode,
  }) {
    return MapStyleGlobalConfig(
      mapboxBaseStyle: mapboxBaseStyle ?? this.mapboxBaseStyle,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      mode: mode ?? this.mode,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MapStyleGlobalConfig &&
        other.mapboxBaseStyle == mapboxBaseStyle &&
        other.brightness == brightness &&
        other.contrast == contrast &&
        other.saturation == saturation &&
        other.mode == mode;
  }

  @override
  int get hashCode {
    return Object.hash(mapboxBaseStyle, brightness, contrast, saturation, mode);
  }
}
