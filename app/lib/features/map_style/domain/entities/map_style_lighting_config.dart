class MapStyleLightingConfig {
  const MapStyleLightingConfig({
    required this.intensity,
    required this.shadowStrength,
    required this.lightAngle,
    required this.temperature,
    required this.glow,
  });

  final double intensity;
  final double shadowStrength;
  final double lightAngle;
  final double temperature;
  final double glow;

  MapStyleLightingConfig copyWith({
    double? intensity,
    double? shadowStrength,
    double? lightAngle,
    double? temperature,
    double? glow,
  }) {
    return MapStyleLightingConfig(
      intensity: intensity ?? this.intensity,
      shadowStrength: shadowStrength ?? this.shadowStrength,
      lightAngle: lightAngle ?? this.lightAngle,
      temperature: temperature ?? this.temperature,
      glow: glow ?? this.glow,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MapStyleLightingConfig &&
        other.intensity == intensity &&
        other.shadowStrength == shadowStrength &&
        other.lightAngle == lightAngle &&
        other.temperature == temperature &&
        other.glow == glow;
  }

  @override
  int get hashCode => Object.hash(intensity, shadowStrength, lightAngle, temperature, glow);
}
