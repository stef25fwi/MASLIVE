import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;

import 'mapbox_directions_service.dart';
import 'mapbox_token_service.dart';

typedef TrackCoord = ({double lat, double lng});

class MapboxPolylineSnapService {
  Future<List<TrackCoord>> snapPolyline(
    List<TrackCoord> rawPoints, {
    int maxWaypoints = 20,
  }) async {
    if (rawPoints.length < 2) return rawPoints;

    final token = MapboxTokenService.getTokenSync().trim();
    if (token.isEmpty) return rawPoints;

    final points = rawPoints.length > maxWaypoints
        ? rawPoints.sublist(rawPoints.length - maxWaypoints)
        : rawPoints;

    final service = MapboxDirectionsService(token);
    final geometry = await service.getDrivingRouteGeometry(
      points
          .map(
            (p) => mbx.Point(
              coordinates: mbx.Position(p.lng, p.lat),
            ),
          )
          .toList(),
    );

    if (geometry.isEmpty) return points;

    return geometry
        .map((p) => (lat: p.coordinates.lat.toDouble(), lng: p.coordinates.lng.toDouble()))
        .toList();
  }
}
