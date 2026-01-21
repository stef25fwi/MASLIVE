import 'package:latlong2/latlong.dart';

class RouteValidator {
  const RouteValidator();

  /// Calcule la distance entre deux points en km (Haversine)
  static double distance(LatLng p1, LatLng p2) {
    const Distance d = Distance();
    return d(p1, p2) / 1000; // Distance retourne en mètres, convertir en km
  }

  /// Distance totale de la route
  static double totalDistance(List<LatLng> points) {
    if (points.length < 2) return 0;
    double total = 0;
    for (int i = 0; i < points.length - 1; i++) {
      total += distance(points[i], points[i + 1]);
    }
    return total;
  }

  /// Valide les règles basiques
  static String? validate({
    required String name,
    required List<LatLng> points,
    double minPoints = 2,
    double minDistanceKm = 0.1,
  }) {
    if (name.trim().isEmpty) return "Nom obligatoire";
    if (points.isEmpty) return "Aucun point";
    if (points.length < minPoints) return "Au moins $minPoints points requis";
    
    final totalDist = totalDistance(points);
    if (totalDist < minDistanceKm) {
      return "Distance minimale: ${minDistanceKm.toStringAsFixed(2)} km (actuellement: ${totalDist.toStringAsFixed(2)} km)";
    }
    return null;
  }

  /// Détecte si deux points sont proches (< metersThreshold)
  static bool isNearby(LatLng p1, LatLng p2, {double metersThreshold = 50}) {
    final d = distance(p1, p2) * 1000; // km to meters
    return d < metersThreshold;
  }

  /// Trouve les doublons ou points très proches
  static List<int> findDuplicates(List<LatLng> points, {double metersThreshold = 50}) {
    final indices = <int>[];
    for (int i = 0; i < points.length - 1; i++) {
      if (isNearby(points[i], points[i + 1], metersThreshold: metersThreshold)) {
        indices.add(i + 1);
      }
    }
    return indices;
  }

  /// Estime le temps (simple: 5 km/h en moyenne)
  static Duration estimatedTime(List<LatLng> points, {double speedKmh = 5.0}) {
    final dist = totalDistance(points);
    final hours = dist / speedKmh;
    return Duration(minutes: (hours * 60).toInt());
  }
}
