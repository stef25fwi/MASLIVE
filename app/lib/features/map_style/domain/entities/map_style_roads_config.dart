class MapStyleRoadsConfig {
  const MapStyleRoadsConfig({
    required this.primaryColor,
    required this.secondaryColor,
    required this.pedestrianColor,
    required this.trafficAccent,
    required this.closedRoadColor,
    required this.detourColor,
    required this.lineThickness,
  });

  final String primaryColor;
  final String secondaryColor;
  final String pedestrianColor;
  final String trafficAccent;
  final String closedRoadColor;
  final String detourColor;
  final double lineThickness;

  MapStyleRoadsConfig copyWith({
    String? primaryColor,
    String? secondaryColor,
    String? pedestrianColor,
    String? trafficAccent,
    String? closedRoadColor,
    String? detourColor,
    double? lineThickness,
  }) {
    return MapStyleRoadsConfig(
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      pedestrianColor: pedestrianColor ?? this.pedestrianColor,
      trafficAccent: trafficAccent ?? this.trafficAccent,
      closedRoadColor: closedRoadColor ?? this.closedRoadColor,
      detourColor: detourColor ?? this.detourColor,
      lineThickness: lineThickness ?? this.lineThickness,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MapStyleRoadsConfig &&
        other.primaryColor == primaryColor &&
        other.secondaryColor == secondaryColor &&
        other.pedestrianColor == pedestrianColor &&
        other.trafficAccent == trafficAccent &&
        other.closedRoadColor == closedRoadColor &&
        other.detourColor == detourColor &&
        other.lineThickness == lineThickness;
  }

  @override
  int get hashCode {
    return Object.hash(
      primaryColor,
      secondaryColor,
      pedestrianColor,
      trafficAccent,
      closedRoadColor,
      detourColor,
      lineThickness,
    );
  }
}
