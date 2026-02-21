import 'dart:math';

import 'latlng.dart';

/// Projection d’un point sur une polyline (approx equirectangular, très rapide).
/// Retourne le point le plus proche SUR la polyline.
LatLng snapToPolyline({
  required LatLng p,
  required List<LatLng> polyline,
}) {
  if (polyline.length < 2) return p;

  final refLat = p.lat * pi / 180.0;
  double bestDist2 = double.infinity;
  LatLng best = p;

  for (int i = 0; i < polyline.length - 1; i++) {
    final a = polyline[i];
    final b = polyline[i + 1];

    final proj = _projectPointToSegment(p, a, b, refLat);
    final d2 = _dist2(p, proj, refLat);
    if (d2 < bestDist2) {
      bestDist2 = d2;
      best = proj;
    }
  }
  return best;
}

/// Convertit lat/lng en "mètres" approx autour de refLat
double _mx(double lng, double refLat) =>
    (lng * pi / 180.0) * 6371000.0 * cos(refLat);

double _my(double lat) => (lat * pi / 180.0) * 6371000.0;

LatLng _projectPointToSegment(LatLng p, LatLng a, LatLng b, double refLat) {
  final px = _mx(p.lng, refLat);
  final py = _my(p.lat);

  final ax = _mx(a.lng, refLat);
  final ay = _my(a.lat);

  final bx = _mx(b.lng, refLat);
  final by = _my(b.lat);

  final abx = bx - ax;
  final aby = by - ay;

  final apx = px - ax;
  final apy = py - ay;

  final abLen2 = abx * abx + aby * aby;
  if (abLen2 == 0) return a;

  var t = (apx * abx + apy * aby) / abLen2;
  t = t.clamp(0.0, 1.0);

  final cx = ax + t * abx;
  final cy = ay + t * aby;

  // back to lat/lng
  final lat = (cy / 6371000.0) * 180.0 / pi;
  final lng = (cx / (6371000.0 * cos(refLat))) * 180.0 / pi;
  return LatLng(lat, lng);
}

double _dist2(LatLng p1, LatLng p2, double refLat) {
  final dx = _mx(p1.lng, refLat) - _mx(p2.lng, refLat);
  final dy = _my(p1.lat) - _my(p2.lat);
  return dx * dx + dy * dy;
}
