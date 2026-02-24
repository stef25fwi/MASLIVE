import 'dart:math' as math;

import '../models/market_circuit_models.dart';

typedef LngLat = ({double lng, double lat});

class CheckItem {
  const CheckItem({
    required this.id,
    required this.label,
    required this.ok,
    required this.weight,
    this.required = true,
    this.hint,
  });

  final String id;
  final String label;
  final bool ok;
  final int weight;
  final bool required;
  final String? hint;
}

class PublishQualityReport {
  const PublishQualityReport({required this.score, required this.items});

  final int score;
  final List<CheckItem> items;

  bool get canPublish =>
      items.where((i) => i.required).every((item) => item.ok);
}

class PublishQualityService {
  static const double perimeterClosureToleranceMeters = 30.0;
  static const double maxMeanSegmentMeters = 800.0;

  PublishQualityReport evaluate({
    required List<LngLat> perimeter,
    required List<LngLat> route,
    required String routeColorHex,
    required double routeWidth,
    required List<MarketMapLayer> layers,
    required List<MarketMapPOI> pois,
  }) {
    final perimeterClosed = _isPerimeterClosed(perimeter);
    final perimeterVertexCount = _perimeterVertexCount(perimeter);
    final routeMinPoints = route.length >= 2;
    final routeDensity = _meanSegmentMeters(route) <= maxMeanSegmentMeters;
    final styleValid = routeWidth > 0 && _isValidHexColor(routeColorHex);
    final hasPoi = pois.isNotEmpty;
    final hasLayers = layers.isNotEmpty;
    final boundsSane = _allPointsSane([...perimeter, ...route]);

    final items = <CheckItem>[
      CheckItem(
        id: 'perimeterClosed',
        label: 'Périmètre fermé (>=3 points + boucle)',
        ok: perimeterVertexCount >= 3 && perimeterClosed,
        weight: 20,
        required: true,
        hint: 'Ajoute au moins 3 points puis active “Boucle fermée” (ou ferme le polygone).',
      ),
      CheckItem(
        id: 'routeMinPoints',
        label: 'Tracé avec au moins 2 points',
        ok: routeMinPoints,
        weight: 15,
        required: true,
        hint: 'Ajoute au moins un segment au tracé.',
      ),
      CheckItem(
        id: 'routeDensity',
        label: 'Densité du tracé (espacement raisonnable)',
        ok: routeDensity,
        weight: 10,
        required: true,
        hint: 'Ajoute des points intermédiaires sur les longs segments.',
      ),
      CheckItem(
        id: 'styleValid',
        label: 'Style valide (couleur + largeur)',
        ok: styleValid,
        weight: 10,
        required: true,
        hint: 'Vérifie la couleur hex et la largeur > 0.',
      ),
      CheckItem(
        id: 'atLeastOnePoi',
        label: 'Au moins un POI',
        ok: hasPoi,
        weight: 15,
        required: true,
        hint: 'Ajoute au moins un point d’intérêt.',
      ),
      CheckItem(
        id: 'layersExist',
        label: 'Au moins une couche',
        ok: hasLayers,
        weight: 10,
        required: true,
        hint: 'Crée/active au moins une couche.',
      ),
      CheckItem(
        id: 'boundsSane',
        label: 'Coordonnées cohérentes (bornes géographiques)',
        ok: boundsSane,
        weight: 20,
        required: true,
        hint: 'Corrige les points hors bornes lat/lng.',
      ),
    ];

    final totalWeight = items.fold<int>(0, (sum, i) => sum + i.weight);
    final successWeight =
        items.where((i) => i.ok).fold<int>(0, (sum, i) => sum + i.weight);
    final score = totalWeight == 0
        ? 0
        : ((successWeight / totalWeight) * 100).round().clamp(0, 100);

    return PublishQualityReport(score: score, items: items);
  }

  bool _isPerimeterClosed(List<LngLat> points) {
    if (points.length < 3) return false;
    final first = points.first;
    final last = points.last;
    return _distanceMeters(first, last) <= perimeterClosureToleranceMeters;
  }

  int _perimeterVertexCount(List<LngLat> points) {
    if (points.isEmpty) return 0;
    if (points.length == 1) return 1;

    // Si le polygone est déjà fermé (dernier proche du premier), on ignore
    // le point de fermeture pour compter les sommets réels.
    if (_isPerimeterClosed(points)) {
      return math.max(0, points.length - 1);
    }
    return points.length;
  }

  bool _isValidHexColor(String value) {
    final v = value.trim();
    return RegExp(r'^#?[0-9a-fA-F]{6}$').hasMatch(v);
  }

  bool _allPointsSane(List<LngLat> points) {
    for (final p in points) {
      if (p.lat < -90 || p.lat > 90) return false;
      if (p.lng < -180 || p.lng > 180) return false;
      if (p.lat.isNaN || p.lng.isNaN) return false;
    }
    return true;
  }

  double _meanSegmentMeters(List<LngLat> points) {
    if (points.length < 2) return 0;
    double sum = 0;
    var count = 0;
    for (var i = 0; i < points.length - 1; i++) {
      sum += _distanceMeters(points[i], points[i + 1]);
      count++;
    }
    return count == 0 ? 0 : (sum / count);
  }

  double _distanceMeters(LngLat a, LngLat b) {
    const earthRadius = 6371000.0;
    final lat1 = _toRad(a.lat);
    final lat2 = _toRad(b.lat);
    final dLat = _toRad(b.lat - a.lat);
    final dLng = _toRad(b.lng - a.lng);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * earthRadius * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  double _toRad(double deg) => deg * math.pi / 180.0;
}
