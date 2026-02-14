import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../../services/mapbox_token_service.dart';
import '../models/route_style_config.dart';

class SnapOptions {
  final double toleranceMeters;
  /// 0..100 (reçoit le simplifyPercent de la config)
  final double simplifyPercent;

  const SnapOptions({
    this.toleranceMeters = 35.0,
    this.simplifyPercent = 0.0,
  });

  SnapOptions validated() {
    double clamp(double v, double min, double max) =>
        v.isNaN ? min : (v < min ? min : (v > max ? max : v));
    return SnapOptions(
      toleranceMeters: clamp(toleranceMeters, 5, 150),
      simplifyPercent: clamp(simplifyPercent, 0, 100),
    );
  }
}

class RouteLineString {
  final List<LatLng> points;

  const RouteLineString(this.points);

  Map<String, dynamic> toGeoJsonFeature({Map<String, dynamic>? properties}) {
    return {
      'type': 'Feature',
      'properties': properties ?? <String, dynamic>{},
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          for (final p in points) [p.lng, p.lat],
        ],
      },
    };
  }
}

class RouteSnapException implements Exception {
  final String message;
  final int? status;

  const RouteSnapException(this.message, {this.status});

  @override
  String toString() => status == null ? message : '$message (HTTP $status)';
}

/// Snapping automatique sur la route via Mapbox Map Matching API,
/// avec fallback Directions API.
class RouteSnapService {
  final http.Client _client;

  RouteSnapService({http.Client? client}) : _client = client ?? http.Client();

  Future<RouteLineString> snapToRoad(
    List<LatLng> points, {
    SnapOptions options = const SnapOptions(),
  }) async {
    final opt = options.validated();
    if (points.length < 2) return RouteLineString(points);

    final token = await MapboxTokenService.getToken();
    if (token.trim().isEmpty) {
      // Sans token, on fait au moins la simplification.
      return RouteLineString(_simplifyIfNeeded(points, opt.simplifyPercent));
    }

    // 1) Map Matching (meilleur pour traces imprécises)
    try {
      final matched = await _mapMatching(points, token, opt.toleranceMeters);
      final simplified = _simplifyIfNeeded(matched, opt.simplifyPercent);
      return RouteLineString(simplified);
    } catch (_) {
      // 2) Fallback Directions (robuste si matching échoue)
      final routed = await _directions(points, token, opt.toleranceMeters);
      final simplified = _simplifyIfNeeded(routed, opt.simplifyPercent);
      return RouteLineString(simplified);
    }
  }

  Future<List<LatLng>> _mapMatching(
    List<LatLng> points,
    String token,
    double radiusMeters,
  ) async {
    final coords = points
        .map((p) => '${p.lng.toStringAsFixed(6)},${p.lat.toStringAsFixed(6)}')
        .join(';');

    final radiuses = List.filled(points.length, radiusMeters.round())
        .map((r) => r.toString())
        .join(';');

    final uri = Uri.https('api.mapbox.com', '/matching/v5/mapbox/driving/$coords', {
      'access_token': token,
      'geometries': 'geojson',
      'radiuses': radiuses,
      'steps': 'false',
      'tidy': 'true',
    });

    final resp = await _client.get(uri);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw RouteSnapException('Map Matching failed', status: resp.statusCode);
    }

    final json = jsonDecode(resp.body);
    if (json is! Map<String, dynamic>) {
      throw const RouteSnapException('Map Matching response invalid');
    }

    final code = json['code'];
    if (code != 'Ok') {
      final message = (json['message'] as String?) ?? 'Map Matching error';
      throw RouteSnapException(message);
    }

    final matchings = json['matchings'];
    if (matchings is! List || matchings.isEmpty) {
      throw const RouteSnapException('No matching geometry');
    }

    final first = matchings.first;
    if (first is! Map) throw const RouteSnapException('No matching geometry');
    final geom = first['geometry'];
    if (geom is! Map) throw const RouteSnapException('No geometry');
    final coordsList = geom['coordinates'];
    if (coordsList is! List || coordsList.length < 2) {
      throw const RouteSnapException('Geometry empty');
    }

    return _coordsToLatLng(coordsList);
  }

  Future<List<LatLng>> _directions(
    List<LatLng> points,
    String token,
    double radiusMeters,
  ) async {
    final coords = points
        .map((p) => '${p.lng.toStringAsFixed(6)},${p.lat.toStringAsFixed(6)}')
        .join(';');

    final radiuses = List.filled(points.length, radiusMeters.round())
        .map((r) => r.toString())
        .join(';');

    final uri = Uri.https('api.mapbox.com', '/directions/v5/mapbox/driving/$coords', {
      'access_token': token,
      'geometries': 'geojson',
      'overview': 'full',
      'steps': 'false',
      'radiuses': radiuses,
    });

    final resp = await _client.get(uri);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw RouteSnapException('Directions failed', status: resp.statusCode);
    }

    final json = jsonDecode(resp.body);
    if (json is! Map<String, dynamic>) {
      throw const RouteSnapException('Directions response invalid');
    }

    final code = json['code'];
    if (code != 'Ok') {
      final message = (json['message'] as String?) ?? 'Directions error';
      throw RouteSnapException(message);
    }

    final routes = json['routes'];
    if (routes is! List || routes.isEmpty) {
      throw const RouteSnapException('No route');
    }

    final first = routes.first;
    if (first is! Map) throw const RouteSnapException('No route');
    final geom = first['geometry'];
    if (geom is! Map) throw const RouteSnapException('No geometry');
    final coordsList = geom['coordinates'];
    if (coordsList is! List || coordsList.length < 2) {
      throw const RouteSnapException('Geometry empty');
    }

    return _coordsToLatLng(coordsList);
  }

  List<LatLng> _coordsToLatLng(List coordsList) {
    final out = <LatLng>[];
    for (final c in coordsList) {
      if (c is List && c.length >= 2) {
        final lng = (c[0] as num).toDouble();
        final lat = (c[1] as num).toDouble();
        out.add((lat: lat, lng: lng));
      }
    }
    if (out.length < 2) throw const RouteSnapException('Geometry empty');
    return out;
  }

  List<LatLng> _simplifyIfNeeded(List<LatLng> pts, double simplifyPercent) {
    if (pts.length < 3) return pts;
    if (simplifyPercent <= 0) return pts;

    // Epsilon en mètres (plutôt conservateur).
    final epsilonMeters = 2.0 + (simplifyPercent / 100.0) * 18.0; // 2..20m
    return _douglasPeucker(pts, epsilonMeters);
  }

  // --- Douglas-Peucker (approx en mètres, projection equirectangulaire) ---

  List<LatLng> _douglasPeucker(List<LatLng> points, double epsilonMeters) {
    final keep = List<bool>.filled(points.length, false);
    keep[0] = true;
    keep[points.length - 1] = true;

    void simplify(int first, int last) {
      if (last <= first + 1) return;
      double maxDist = 0;
      int index = first;
      for (int i = first + 1; i < last; i++) {
        final d = _perpDistanceMeters(points[i], points[first], points[last]);
        if (d > maxDist) {
          maxDist = d;
          index = i;
        }
      }
      if (maxDist > epsilonMeters) {
        keep[index] = true;
        simplify(first, index);
        simplify(index, last);
      }
    }

    simplify(0, points.length - 1);

    final out = <LatLng>[];
    for (int i = 0; i < points.length; i++) {
      if (keep[i]) out.add(points[i]);
    }
    return out.length >= 2 ? out : points;
  }

  double _perpDistanceMeters(LatLng p, LatLng a, LatLng b) {
    // Projection equirectangulaire locale.
    final lat0 = (a.lat + b.lat) * 0.5 * math.pi / 180.0;

    final ax = a.lng * math.cos(lat0);
    final ay = a.lat;
    final bx = b.lng * math.cos(lat0);
    final by = b.lat;
    final px = p.lng * math.cos(lat0);
    final py = p.lat;

    final dx = bx - ax;
    final dy = by - ay;
    if (dx == 0 && dy == 0) return _haversineMeters(p, a);

    final t = ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy);
    final tt = t.clamp(0.0, 1.0);

    final projx = ax + tt * dx;
    final projy = ay + tt * dy;

    // Convertit degrés -> mètres (approx)
    final dLat = (py - projy) * 111320.0;
    final dLng = (px - projx) * 111320.0;
    return math.sqrt(dLat * dLat + dLng * dLng);
  }

  double _haversineMeters(LatLng p1, LatLng p2) {
    const r = 6371000.0;
    final dLat = (p2.lat - p1.lat) * math.pi / 180.0;
    final dLng = (p2.lng - p1.lng) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(p1.lat * math.pi / 180.0) *
            math.cos(p2.lat * math.pi / 180.0) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }
}
