/// Utilitaires géodésiques pour calculs de positions GPS précis
import 'dart:math';

class GeoUtils {
  /// Rayon terrestre en km (WGS84)
  static const double earthRadiusKm = 6371.0;

  /// Calcule le centroïde géodésique (plus précis que moyenne arithmétique)
  /// 
  /// Pour positions locales (< 100km): arithmétique suffit
  /// Pour positions distantes (> 100km): géodésique recommandée
  /// 
  /// Utilise la méthode 3D (convertit lat/lng en coordonnées cartésiennes)
  static ({double latitude, double longitude, double altitude})
      calculateGeodeticCenter(
    List<({double latitude, double longitude, double altitude})> positions, {
    bool useWeights = false,
    List<double>? weights,
  }) {
    if (positions.isEmpty) {
      throw ArgumentError('positions cannot be empty');
    }

    double sumX = 0.0;
    double sumY = 0.0;
    double sumZ = 0.0;
    double sumAltitude = 0.0;
    double sumWeights = 0.0;

    for (int i = 0; i < positions.length; i++) {
      final pos = positions[i];
      final weight = useWeights && weights != null && i < weights.length
          ? weights[i]
          : 1.0;

      // Conversion lat/lng en radians
      final latRad = pos.latitude * pi / 180.0;
      final lngRad = pos.longitude * pi / 180.0;

      // Projection en coordonnées cartésiennes 3D
      final cosLat = cos(latRad);
      final x = cosLat * cos(lngRad);
      final y = cosLat * sin(lngRad);
      final z = sin(latRad);

      // Accumulation pondérée
      sumX += x * weight;
      sumY += y * weight;
      sumZ += z * weight;
      sumAltitude += pos.altitude * weight;
      sumWeights += weight;
    }

    // Normalisation
    final avgX = sumX / sumWeights;
    final avgY = sumY / sumWeights;
    final avgZ = sumZ / sumWeights;
    final avgAltitude = sumAltitude / sumWeights;

    // Conversion inverse en lat/lng
    final latitude = atan2(avgZ, sqrt(avgX * avgX + avgY * avgY)) * 180.0 / pi;
    final longitude = atan2(avgY, avgX) * 180.0 / pi;

    return (
      latitude: latitude,
      longitude: longitude,
      altitude: avgAltitude,
    );
  }

  /// Calcule la distance Haversine entre deux points GPS
  static double calculateDistanceKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final dLat = (lat2 - lat1) * pi / 180.0;
    final dLng = (lng2 - lng1) * pi / 180.0;

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180.0) *
            cos(lat2 * pi / 180.0) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  /// Calcule la distance Haversine en mètres
  static double calculateDistanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    return calculateDistanceKm(lat1, lng1, lat2, lng2) * 1000.0;
  }

  /// Calcule le bearing (angle) entre deux points
  static double calculateBearing(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final dLng = (lng2 - lng1) * pi / 180.0;
    final lat1Rad = lat1 * pi / 180.0;
    final lat2Rad = lat2 * pi / 180.0;

    final y = sin(dLng) * cos(lat2Rad);
    final x = cos(lat1Rad) * sin(lat2Rad) -
        sin(lat1Rad) * cos(lat2Rad) * cos(dLng);

    final bearing = atan2(y, x) * 180.0 / pi;
    return (bearing + 360) % 360; // Normaliser 0-360°
  }

  /// Calcule une position à une distance et direction donnée
  static ({double latitude, double longitude}) calculateDestination(
    double lat,
    double lng,
    double distanceKm,
    double bearing,
  ) {
    final latRad = lat * pi / 180.0;
    final lngRad = lng * pi / 180.0;
    final bearingRad = bearing * pi / 180.0;

    final distRatio = distanceKm / earthRadiusKm;

    final lat2Rad = asin(sin(latRad) * cos(distRatio) +
        cos(latRad) * sin(distRatio) * cos(bearingRad));

    final lng2Rad = lngRad +
        atan2(sin(bearingRad) * sin(distRatio) * cos(latRad),
            cos(distRatio) - sin(latRad) * sin(lat2Rad));

    return (
      latitude: lat2Rad * 180.0 / pi,
      longitude: lng2Rad * 180.0 / pi,
    );
  }

  /// Crée un polygone convex hull autour des positions (Graham scan)
  static List<({double latitude, double longitude})> calculateConvexHull(
    List<({double latitude, double longitude})> positions,
  ) {
    if (positions.length <= 3) return positions;

    // Tri par latitude/longitude
    final sorted = [...positions]..sort((a, b) {
      if (a.latitude != b.latitude) return a.latitude.compareTo(b.latitude);
      return a.longitude.compareTo(b.longitude);
    });

    // Calcul du hull
    final hull = <({double latitude, double longitude})>[];

    // Lower hull
    for (final p in sorted) {
      while (hull.length >= 2 &&
          _crossProduct(hull[hull.length - 2], hull[hull.length - 1], p) <= 0) {
        hull.removeLast();
      }
      hull.add(p);
    }

    // Upper hull
    final upperStart = hull.length + 1;
    for (int i = sorted.length - 2; i >= 0; i--) {
      final p = sorted[i];
      while (hull.length >= upperStart &&
          _crossProduct(hull[hull.length - 2], hull[hull.length - 1], p) <= 0) {
        hull.removeLast();
      }
      hull.add(p);
    }

    hull.removeLast(); // Enlever le point dupliqué
    return hull;
  }

  static double _crossProduct(
    ({double latitude, double longitude}) o,
    ({double latitude, double longitude}) a,
    ({double latitude, double longitude}) b,
  ) {
    return (a.longitude - o.longitude) * (b.latitude - o.latitude) -
        (a.latitude - o.latitude) * (b.longitude - o.longitude);
  }

  /// Vérifie si un point est dans un polygone (ray casting algorithm)
  static bool isPointInPolygon(
    double lat,
    double lng,
    List<({double latitude, double longitude})> polygon,
  ) {
    if (polygon.length < 3) return false;

    bool inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      // x = longitude, y = latitude
      final xi = polygon[i].longitude;
      final yi = polygon[i].latitude;
      final xj = polygon[j].longitude;
      final yj = polygon[j].latitude;

      final intersects = (yi > lat) != (yj > lat);
      if (intersects) {
        final xOnEdge = (xj - xi) * (lat - yi) / (yj - yi) + xi;
        if (lng < xOnEdge) {
          inside = !inside;
        }
      }
    }

    return inside;
  }
}
