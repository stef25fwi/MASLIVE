class MapStyleGreenSpacesConfig {
  const MapStyleGreenSpacesConfig({
    required this.color,
    required this.secondaryColor,
    required this.opacity,
    required this.saturation,
    required this.contrast,
    required this.mode,
  });

  final String color;
  final String secondaryColor;
  final double opacity;
  final double saturation;
  final double contrast;
  final String mode;

  MapStyleGreenSpacesConfig copyWith({
    String? color,
    String? secondaryColor,
    double? opacity,
    double? saturation,
    double? contrast,
    String? mode,
  }) {
    return MapStyleGreenSpacesConfig(
      color: color ?? this.color,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      opacity: opacity ?? this.opacity,
      saturation: saturation ?? this.saturation,
      contrast: contrast ?? this.contrast,
      mode: mode ?? this.mode,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MapStyleGreenSpacesConfig &&
        other.color == color &&
        other.secondaryColor == secondaryColor &&
        other.opacity == opacity &&
        other.saturation == saturation &&
        other.contrast == contrast &&
        other.mode == mode;
  }

  @override
  int get hashCode {
    return Object.hash(color, secondaryColor, opacity, saturation, contrast, mode);
  }
}
