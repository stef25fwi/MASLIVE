class MapStyleLabelsConfig {
  const MapStyleLabelsConfig({
    required this.textColor,
    required this.opacity,
    required this.fontSize,
    required this.poiDensity,
    required this.showBusinesses,
    required this.showTransport,
    required this.showParking,
    required this.showTourism,
  });

  final String textColor;
  final double opacity;
  final double fontSize;
  final double poiDensity;
  final bool showBusinesses;
  final bool showTransport;
  final bool showParking;
  final bool showTourism;

  MapStyleLabelsConfig copyWith({
    String? textColor,
    double? opacity,
    double? fontSize,
    double? poiDensity,
    bool? showBusinesses,
    bool? showTransport,
    bool? showParking,
    bool? showTourism,
  }) {
    return MapStyleLabelsConfig(
      textColor: textColor ?? this.textColor,
      opacity: opacity ?? this.opacity,
      fontSize: fontSize ?? this.fontSize,
      poiDensity: poiDensity ?? this.poiDensity,
      showBusinesses: showBusinesses ?? this.showBusinesses,
      showTransport: showTransport ?? this.showTransport,
      showParking: showParking ?? this.showParking,
      showTourism: showTourism ?? this.showTourism,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MapStyleLabelsConfig &&
        other.textColor == textColor &&
        other.opacity == opacity &&
        other.fontSize == fontSize &&
        other.poiDensity == poiDensity &&
        other.showBusinesses == showBusinesses &&
        other.showTransport == showTransport &&
        other.showParking == showParking &&
        other.showTourism == showTourism;
  }

  @override
  int get hashCode {
    return Object.hash(
      textColor,
      opacity,
      fontSize,
      poiDensity,
      showBusinesses,
      showTransport,
      showParking,
      showTourism,
    );
  }
}
