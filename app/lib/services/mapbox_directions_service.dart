import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapboxDirectionsService {
  final String accessToken;
  const MapboxDirectionsService(this.accessToken);

  String _pos(Point p) => '${p.coordinates.lng},${p.coordinates.lat}';

  /// Auto (driving): un seul appel Directions avec waypoints.
  ///
  /// Retourne une liste de [Point] représentant la geometry de la route.
  /// En cas d'échec (HTTP != 200, réponse vide, parsing), retourne une liste vide.
  Future<List<Point>> getDrivingRouteGeometry(List<Point> waypoints) async {
    if (waypoints.length < 2) return const [];

    final coords = waypoints.map(_pos).join(';');

    // geometries=geojson => réponse facile à parser
    final uri = Uri.parse(
      'https://api.mapbox.com/directions/v5/mapbox/driving/$coords'
      '?geometries=geojson&overview=full&steps=false&access_token=$accessToken',
    );

    final res = await http.get(uri);
    if (res.statusCode != 200) return const [];

    final jsonBody = jsonDecode(res.body) as Map<String, dynamic>;
    final routes = (jsonBody['routes'] as List?) ?? const [];
    if (routes.isEmpty) return const [];

    final geometry = (routes.first as Map<String, dynamic>)['geometry']
        as Map<String, dynamic>;
    final coordsList = (geometry['coordinates'] as List).cast<List>();

    return coordsList
        .map(
          (c) => Point(
            coordinates: Position(
              (c[0] as num).toDouble(),
              (c[1] as num).toDouble(),
            ),
          ),
        )
        .toList();
  }

  Future<List<Point>> getDrivingSegment(Point a, Point b) async {
    return getDrivingRouteGeometry([a, b]);
  }

  /// Hybrid: essaie de snap chaque segment sur la route automobile.
  /// Si une requête échoue => fallback ligne droite (manuel).
  ///
  /// Avantage: contourne mieux les limites de waypoints en découpant segment-by-segment.
  Future<List<Point>> getHybridGeometry(List<Point> routePoints) async {
    if (routePoints.length < 2) return const [];
    final out = <Point>[];

    for (int i = 0; i < routePoints.length - 1; i++) {
      final a = routePoints[i];
      final b = routePoints[i + 1];
      final seg = await getDrivingSegment(a, b);

      if (seg.isNotEmpty) {
        // éviter duplicat du point de jonction
        if (out.isNotEmpty) {
          out.addAll(seg.skip(1));
        } else {
          out.addAll(seg);
        }
      } else {
        // fallback manuel: segment droit
        if (out.isEmpty) out.add(a);
        out.add(b);
      }
    }
    return out;
  }
}
