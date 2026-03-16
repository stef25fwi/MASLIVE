class MapStyleBuildingsConfig {
  const MapStyleBuildingsConfig({
    required this.enabled,
    required this.color,
    required this.secondaryColor,
    required this.opacity,
    required this.extrusion,
    required this.roofTint,
    required this.shadow,
    required this.lightIntensity,
  });

  final bool enabled;
  final String color;
  final String secondaryColor;
  final double opacity;
  final double extrusion;
  final String roofTint;
  final double shadow;
  final double lightIntensity;

  MapStyleBuildingsConfig copyWith({
    bool? enabled,
    String? color,
    String? secondaryColor,
    double? opacity,
    double? extrusion,
    String? roofTint,
    double? shadow,
    double? lightIntensity,
  }) {
    return MapStyleBuildingsConfig(
      enabled: enabled ?? this.enabled,
      color: color ?? this.color,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      opacity: opacity ?? this.opacity,
      extrusion: extrusion ?? this.extrusion,
      roofTint: roofTint ?? this.roofTint,
      shadow: shadow ?? this.shadow,
      lightIntensity: lightIntensity ?? this.lightIntensity,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MapStyleBuildingsConfig &&
        other.enabled == enabled &&
        other.color == color &&
        other.secondaryColor == secondaryColor &&
        other.opacity == opacity &&
        other.extrusion == extrusion &&
        other.roofTint == roofTint &&
        other.shadow == shadow &&
        other.lightIntensity == lightIntensity;
  }

  @override
  int get hashCode {
    return Object.hash(
      enabled,
      color,
      secondaryColor,
      opacity,
      extrusion,
      roofTint,
      shadow,
      lightIntensity,
    );
  }
}
