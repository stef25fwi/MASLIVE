import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

enum PerimeterMode { polygon, circle }

enum RouteMode { manual, autoDriving, hybrid }

class DraftRoute {
  /// Points posés par l’utilisateur (numérotés)
  final List<Point> routePoints;

  /// Géométrie finale à dessiner (manual ou calculée)
  final List<Point> routeGeometry;

  /// "Relier les points" activé ?
  final bool connected;

  /// manual/auto/hybrid
  final RouteMode mode;

  const DraftRoute({
    this.routePoints = const [],
    this.routeGeometry = const [],
    this.connected = false,
    this.mode = RouteMode.manual,
  });

  DraftRoute copyWith({
    List<Point>? routePoints,
    List<Point>? routeGeometry,
    bool? connected,
    RouteMode? mode,
  }) {
    return DraftRoute(
      routePoints: routePoints ?? this.routePoints,
      routeGeometry: routeGeometry ?? this.routeGeometry,
      connected: connected ?? this.connected,
      mode: mode ?? this.mode,
    );
  }

  bool get hasEnoughPoints => routePoints.length >= 2;
}

class DraftPerimeter {
  final PerimeterMode mode;

  final List<Point> polygonPoints;

  final Point? circleCenter;
  final double? circleRadiusMeters;

  const DraftPerimeter._({
    required this.mode,
    this.polygonPoints = const <Point>[],
    this.circleCenter,
    this.circleRadiusMeters,
  });

  const DraftPerimeter.polygon(List<Point> pts)
      : this._(mode: PerimeterMode.polygon, polygonPoints: pts);

  const DraftPerimeter.circle({required Point center, required double radiusMeters})
      : this._(
          mode: PerimeterMode.circle,
          circleCenter: center,
          circleRadiusMeters: radiusMeters,
        );

  bool get isValid {
    if (mode == PerimeterMode.polygon) return polygonPoints.length >= 3;
    return circleCenter != null && (circleRadiusMeters ?? 0) >= 10;
  }

  DraftPerimeter copyWith({
    PerimeterMode? mode,
    List<Point>? polygonPoints,
    Point? circleCenter,
    double? circleRadiusMeters,
  }) {
    return DraftPerimeter._(
      mode: mode ?? this.mode,
      polygonPoints: polygonPoints ?? this.polygonPoints,
      circleCenter: circleCenter ?? this.circleCenter,
      circleRadiusMeters: circleRadiusMeters ?? this.circleRadiusMeters,
    );
  }
}

class DraftCircuit {
  final String countryId;
  final String countryName;
  final String eventName;
  final String circuitName;
  final DateTime? date;
  final String? countryIso2;
  final DraftPerimeter? perimeter;
  final DraftRoute route;

  const DraftCircuit({
    required this.countryId,
    required this.countryName,
    required this.eventName,
    required this.circuitName,
    required this.date,
    required this.countryIso2,
    required this.perimeter,
    this.route = const DraftRoute(),
  });

  factory DraftCircuit.empty() {
    return const DraftCircuit(
      countryId: '',
      countryName: '',
      eventName: '',
      circuitName: '',
      date: null,
      countryIso2: null,
      perimeter: null,
      route: DraftRoute(),
    );
  }

  DraftCircuit copyWith({
    String? countryId,
    String? countryName,
    String? eventName,
    String? circuitName,
    DateTime? date,
    String? countryIso2,
    DraftPerimeter? perimeter,
    DraftRoute? route,
  }) {
    return DraftCircuit(
      countryId: countryId ?? this.countryId,
      countryName: countryName ?? this.countryName,
      eventName: eventName ?? this.eventName,
      circuitName: circuitName ?? this.circuitName,
      date: date ?? this.date,
      countryIso2: countryIso2 ?? this.countryIso2,
      perimeter: perimeter ?? this.perimeter,
      route: route ?? this.route,
    );
  }
}
