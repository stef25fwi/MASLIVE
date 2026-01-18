import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RouteStep {
  final List<LatLng> points;
  final int durationSeconds;
  final int distanceMeters;
  final String instruction;

  RouteStep({
    required this.points,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.instruction,
  });
}

class RoutingService {
  static final RoutingService _instance = RoutingService._();
  factory RoutingService() => _instance;
  RoutingService._();

  // OSRM public server (gratuit, pas besoin de clé)
  static const String osrmUrl = 'https://router.project-osrm.org/route/v1';

  /// Calculer une route entre deux points
  Future<RouteStep?> getRoute(LatLng start, LatLng end) async {
    try {
      final coords = '${start.longitude},${start.latitude};${end.longitude},${end.latitude}';
      final url = '$osrmUrl/driving/$coords?steps=true&geometries=geojson';

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Timeout'),
      );

      if (response.statusCode != 200) {
        throw Exception('Erreur OSRM: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      if (data['routes'] == null || (data['routes'] as List).isEmpty) {
        return null;
      }

      final route = data['routes'][0] as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>;
      final coordinates = geometry['coordinates'] as List<dynamic>;

      // Convertir les coordonnées [lng, lat] en LatLng
      final points = coordinates
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();

      final duration = (route['duration'] as num).toInt();
      final distance = (route['distance'] as num).toInt();

      // Construire l'instruction à partir des étapes si disponibles
      String instruction = 'Route';
      if (route['legs'] != null && (route['legs'] as List).isNotEmpty) {
        instruction = '${distance ~/ 1000} km - ${duration ~/ 60} min';
      }

      return RouteStep(
        points: points,
        durationSeconds: duration,
        distanceMeters: distance,
        instruction: instruction,
      );
    } catch (e) {
      print('Erreur getRoute: $e');
      return null;
    }
  }

  /// Calculer une route multi-points (via plusieurs waypoints)
  Future<RouteStep?> getMultiRoute(List<LatLng> waypoints) async {
    if (waypoints.length < 2) return null;

    try {
      final coords = waypoints
          .map((p) => '${p.longitude},${p.latitude}')
          .join(';');
      
      final url = '$osrmUrl/driving/$coords?steps=true&geometries=geojson';

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Timeout'),
      );

      if (response.statusCode != 200) {
        throw Exception('Erreur OSRM: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      if (data['routes'] == null || (data['routes'] as List).isEmpty) {
        return null;
      }

      final route = data['routes'][0] as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>;
      final coordinates = geometry['coordinates'] as List<dynamic>;

      final points = coordinates
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();

      final duration = (route['duration'] as num).toInt();
      final distance = (route['distance'] as num).toInt();

      return RouteStep(
        points: points,
        durationSeconds: duration,
        distanceMeters: distance,
        instruction: '${distance ~/ 1000} km - ${duration ~/ 60} min',
      );
    } catch (e) {
      print('Erreur getMultiRoute: $e');
      return null;
    }
  }

  /// Format pour affichage (distance en km, durée en heures:minutes)
  String formatRoute(RouteStep route) {
    final km = route.distanceMeters / 1000;
    final hours = route.durationSeconds ~/ 3600;
    final minutes = (route.durationSeconds % 3600) ~/ 60;
    
    if (hours > 0) {
      return '${km.toStringAsFixed(1)} km - ${hours}h ${minutes}min';
    }
    return '${km.toStringAsFixed(1)} km - ${minutes}min';
  }
}
