class MapStyleWaterConfig {
  const MapStyleWaterConfig({
    required this.color,
    required this.opacity,
    required this.shoreHighlight,
    required this.brightness,
    required this.reflection,
  });

  final String color;
  final double opacity;
  final String shoreHighlight;
  final double brightness;
  final double reflection;

  MapStyleWaterConfig copyWith({
    String? color,
    double? opacity,
    String? shoreHighlight,
    double? brightness,
    double? reflection,
  }) {
    return MapStyleWaterConfig(
      color: color ?? this.color,
      opacity: opacity ?? this.opacity,
      shoreHighlight: shoreHighlight ?? this.shoreHighlight,
      brightness: brightness ?? this.brightness,
      reflection: reflection ?? this.reflection,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MapStyleWaterConfig &&
        other.color == color &&
        other.opacity == opacity &&
        other.shoreHighlight == shoreHighlight &&
        other.brightness == brightness &&
        other.reflection == reflection;
  }

  @override
  int get hashCode => Object.hash(color, opacity, shoreHighlight, brightness, reflection);
}
