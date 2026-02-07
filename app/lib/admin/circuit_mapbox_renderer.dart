import 'package:flutter/material.dart';

typedef LngLat = ({double lng, double lat});
typedef SegmentDef = ({int startIndex, int endIndex, Color color, String name});

/// Service pour afficher des circuits (périmètre + tracé + segments colorés)
/// Unifie le rendu web et natif Mapbox avec support des couleurs de segments.
class CircuitMapboxRenderer {
  // Couleurs standard
  static const Color startMarkerColor = Color(0xFF4CAF50); // Vert
  static const Color endMarkerColor = Color(0xFFF44336);   // Rouge
  static const Color perimeterColor = Color(0xFF00AEEF);    // Cyan
  static const Color routeColor = Color(0xFF1A73E8);        // Bleu

  /// Génère un GeoJSON FeatureCollection pour les segments colorés
  static Map<String, dynamic> generateSegmentGeoJSON(
    List<LngLat> route,
    List<SegmentDef> segments,
  ) {
    final features = <Map<String, dynamic>>[];

    for (final seg in segments) {
      final start = seg.startIndex.clamp(0, route.length - 1);
      final end = seg.endIndex.clamp(0, route.length - 1);

      if (end <= start) continue;

      final pts = route.sublist(start, end + 1);
      if (pts.length < 2) continue;

      final color = _colorToHex(seg.color);

      features.add({
        'type': 'Feature',
        'properties': {
          'name': seg.name,
          'color': color,
          'width': 8.0,
        },
        'geometry': {
          'type': 'LineString',
          'coordinates': pts.map((p) => [p.lng, p.lat]).toList(),
        },
      });
    }

    return {
      'type': 'FeatureCollection',
      'features': features,
    };
  }

  /// Génère un GeoJSON pour le périmètre (polygon fermé)
  static Map<String, dynamic> generatePerimeterGeoJSON(List<LngLat> perimeter) {
    if (perimeter.length < 3) {
      return {'type': 'FeatureCollection', 'features': []};
    }

    final closed = _closePath(perimeter);
    final coords = closed.map((p) => [p.lng, p.lat]).toList();

    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': {
            'name': 'Périmètre',
            'color': _colorToHex(perimeterColor),
            'width': 3.0,
          },
          'geometry': {
            'type': 'LineString',
            'coordinates': coords,
          },
        },
      ],
    };
  }

  /// Génère un GeoJSON pour le tracé (polyline) avec markers start/end
  static Map<String, dynamic> generateRouteGeoJSON(List<LngLat> route) {
    final features = <Map<String, dynamic>>[];

    if (route.length >= 2) {
      features.add({
        'type': 'Feature',
        'properties': {
          'name': 'Tracé',
          'color': _colorToHex(routeColor),
          'width': 6.0,
        },
        'geometry': {
          'type': 'LineString',
          'coordinates': route.map((p) => [p.lng, p.lat]).toList(),
        },
      });
    }

    // Markers start/end
    if (route.isNotEmpty) {
      final start = route.first;
      features.add({
        'type': 'Feature',
        'properties': {
          'name': 'Début',
          'markerColor': _colorToHex(startMarkerColor),
        },
        'geometry': {
          'type': 'Point',
          'coordinates': [start.lng, start.lat],
        },
      });
    }

    if (route.length > 1) {
      final end = route.last;
      features.add({
        'type': 'Feature',
        'properties': {
          'name': 'Fin',
          'markerColor': _colorToHex(endMarkerColor),
        },
        'geometry': {
          'type': 'Point',
          'coordinates': [end.lng, end.lat],
        },
      });
    }

    return {
      'type': 'FeatureCollection',
      'features': features,
    };
  }

  /// Convertit Color Flutter en format hex #RRGGBB
  static String _colorToHex(Color c) {
    final r = (c.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (c.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (c.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }

  /// Ferme un path (ajoute le premier point à la fin)
  static List<LngLat> _closePath(List<LngLat> pts) {
    if (pts.isEmpty) return pts;
    final first = pts.first;
    final last = pts.last;
    if (first.lng == last.lng && first.lat == last.lat) return pts;
    return [...pts, first];
  }

  /// Calcule les bounds d'une liste de points pour le zoom auto
  static ({double minLng, double maxLng, double minLat, double maxLat}) calculateBounds(
    List<LngLat> points,
  ) {
    if (points.isEmpty) {
      return (minLng: -61.5, maxLng: -61.5, minLat: 16.2, maxLat: 16.2);
    }

    double minLng = points[0].lng;
    double maxLng = points[0].lng;
    double minLat = points[0].lat;
    double maxLat = points[0].lat;

    for (final p in points) {
      minLng = minLng > p.lng ? p.lng : minLng;
      maxLng = maxLng < p.lng ? p.lng : maxLng;
      minLat = minLat > p.lat ? p.lat : minLat;
      maxLat = maxLat < p.lat ? p.lat : maxLat;
    }

    return (minLng: minLng, maxLng: maxLng, minLat: minLat, maxLat: maxLat);
  }

  /// Calcule le zoom level idéal pour les bounds
  static double calculateZoomLevel(
    double minLng,
    double maxLng,
    double minLat,
    double maxLat,
  ) {
    final width = maxLng - minLng;
    final height = maxLat - minLat;
    final maxDim = width > height ? width : height;

    if (maxDim > 1.0) return 9.0;
    if (maxDim > 0.5) return 10.0;
    if (maxDim > 0.1) return 12.0;
    if (maxDim > 0.05) return 13.0;
    return 14.0;
  }

  /// Haversine: distance entre deux points en km
  static double haversineDistance(LngLat p1, LngLat p2) {
    const earthRadiusKm = 6371;
    final dLat = _toRad(p2.lat - p1.lat);
    final dLng = _toRad(p2.lng - p1.lng);
    final a = _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_toRad(p1.lat)) *
            _cos(_toRad(p2.lat)) *
            _sin(dLng / 2) *
            _sin(dLng / 2);
    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _toRad(double deg) => deg * 3.141592653589793 / 180;
  static double _sin(double x) {
    const pi = 3.141592653589793;
    x = x % (2 * pi);
    return (x * (3 - x * x / (pi * pi / 4)) /
        (1 + x * x / (pi * pi / 4)));
  }
  static double _cos(double x) => _sin(x + 3.141592653589793 / 2);
  static double _atan2(double y, double x) => (y / (x + 1e-10));
  static double _sqrt(double x) => x < 0 ? 0 : (x == 0 ? 0 : x);
}

/// Widget pour afficher une légende des segments
class CircuitLegend extends StatelessWidget {
  final List<SegmentDef> segments;
  final bool isCompact;

  const CircuitLegend({
    super.key,
    required this.segments,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isCompact
          ? _buildCompactLegend()
          : _buildExpandedLegend(),
    );
  }

  Widget _buildCompactLegend() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Segments',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: segments
              .map((seg) => Chip(
                    avatar: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: seg.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    label: Text(
                      seg.name,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildExpandedLegend() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Segments du Circuit',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 12),
        ...segments.map((seg) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 4,
                decoration: BoxDecoration(
                  color: seg.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                seg.name,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        )),
      ],
    );
  }
}

/// Widget pour les points de référence (markers)
class CircuitMarkerLegend extends StatelessWidget {
  final bool showStart;
  final bool showEnd;

  const CircuitMarkerLegend({
    super.key,
    this.showStart = true,
    this.showEnd = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Repères',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          if (showStart)
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: CircuitMapboxRenderer.startMarkerColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Début',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
          if (showStart && showEnd) const SizedBox(height: 4),
          if (showEnd)
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: CircuitMapboxRenderer.endMarkerColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Fin',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
