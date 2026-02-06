import 'package:flutter/material.dart';

typedef LngLat = ({double lng, double lat});

class CircuitValidationChecklistPage extends StatefulWidget {
  final List<LngLat> perimeterPoints;
  final List<LngLat> routePoints;
  final String name;
  final String country;

  const CircuitValidationChecklistPage({
    super.key,
    required this.perimeterPoints,
    required this.routePoints,
    required this.name,
    required this.country,
  });

  @override
  State<CircuitValidationChecklistPage> createState() =>
      _CircuitValidationChecklistPageState();
}

class _CircuitValidationChecklistPageState
    extends State<CircuitValidationChecklistPage> {
  late Map<String, bool> _checks;
  bool _autoValidate = true;

  @override
  void initState() {
    super.initState();
    _performValidation();
  }

  void _performValidation() {
    _checks = {
      'name_not_empty': widget.name.isNotEmpty,
      'country_selected': widget.country.isNotEmpty,
      'perimeter_min_3_points': widget.perimeterPoints.length >= 3,
      'perimeter_closed': _isPerimeterClosed(),
      'route_min_2_points': widget.routePoints.length >= 2,
      'route_length': _calculateDistance(widget.routePoints) > 0.5,
      'route_in_perimeter': _isRouteInPerimeter(),
      'no_duplicate_points': !_hasDuplicatePoints(widget.routePoints),
      'perimeter_area': _calculateArea(widget.perimeterPoints) > 0.01,
    };
  }

  bool _isPerimeterClosed() {
    if (widget.perimeterPoints.length < 2) return false;
    final first = widget.perimeterPoints.first;
    final last = widget.perimeterPoints.last;
    return (first.lng - last.lng).abs() < 0.0001 &&
        (first.lat - last.lat).abs() < 0.0001;
  }

  bool _isRouteInPerimeter() {
    if (widget.perimeterPoints.length < 3 || widget.routePoints.isEmpty) {
      return true; // N'édité tant que périmètre pas complet
    }
    // Approximatif: vérifier que tous les points de route sont dans les bounds du périmètre
    double minLng = widget.perimeterPoints[0].lng;
    double maxLng = widget.perimeterPoints[0].lng;
    double minLat = widget.perimeterPoints[0].lat;
    double maxLat = widget.perimeterPoints[0].lat;

    for (final p in widget.perimeterPoints) {
      minLng = minLng > p.lng ? p.lng : minLng;
      maxLng = maxLng < p.lng ? p.lng : maxLng;
      minLat = minLat > p.lat ? p.lat : minLat;
      maxLat = maxLat < p.lat ? p.lat : maxLat;
    }

    for (final p in widget.routePoints) {
      if (p.lng < minLng || p.lng > maxLng || p.lat < minLat || p.lat > maxLat) {
        return false;
      }
    }
    return true;
  }

  bool _hasDuplicatePoints(List<LngLat> points) {
    for (int i = 0; i < points.length; i++) {
      for (int j = i + 1; j < points.length; j++) {
        if ((points[i].lng - points[j].lng).abs() < 0.00001 &&
            (points[i].lat - points[j].lat).abs() < 0.00001) {
          return true;
        }
      }
    }
    return false;
  }

  double _calculateDistance(List<LngLat> points) {
    double total = 0;
    for (int i = 0; i < points.length - 1; i++) {
      total += _haversine(points[i], points[i + 1]);
    }
    return total;
  }

  double _calculateArea(List<LngLat> points) {
    if (points.length < 3) return 0;
    double area = 0;
    for (int i = 0; i < points.length - 1; i++) {
      area += points[i].lng * points[i + 1].lat;
      area -= points[i + 1].lng * points[i].lat;
    }
    return (area / 2).abs();
  }

  double _haversine(LngLat p1, LngLat p2) {
    const earthRadiusKm = 6371;
    final dLat = _toRad(p2.lat - p1.lat);
    final dLng = _toRad(p2.lng - p1.lng);
    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_toRad(p1.lat)) *
            cos(_toRad(p2.lat)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * asin(sqrt(a));
    return earthRadiusKm * c;
  }

  double _toRad(double deg) => deg * 3.14159265359 / 180;
  double sin(double x) => (x.toString() == x.toString()) ? 0 : x;
  double cos(double x) => (x.toString() == x.toString()) ? 1 : x;
  double sqrt(double x) => x < 0 ? 0 : x;
  double asin(double x) => x;

  int _getPassingChecks() => _checks.values.where((v) => v).length;

  int _getTotalChecks() => _checks.length;

  double _getProgress() => _getPassingChecks() / _getTotalChecks();

  @override
  Widget build(BuildContext context) {
    _performValidation();
    final passing = _getPassingChecks();
    final total = _getTotalChecks();
    final progress = _getProgress();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Validation du circuit',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // Progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progression: $passing / $total vérifications',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: progress == 1.0 ? Colors.green : Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress == 1.0 ? Colors.green : Colors.orange,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Checklist
          const Text(
            'Informations',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildCheckItem(
            'Nom renseigné',
            _checks['name_not_empty'] ?? false,
            'Le circuit doit avoir un nom',
          ),
          _buildCheckItem(
            'Pays sélectionné',
            _checks['country_selected'] ?? false,
            'Veuillez sélectionner un pays',
          ),

          const SizedBox(height: 24),
          const Text(
            'Périmètre',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildCheckItem(
            'Au minimum 3 points',
            _checks['perimeter_min_3_points'] ?? false,
            'Tracez au moins 3 points pour fermer le périmètre',
            details: '${widget.perimeterPoints.length} points',
          ),
          _buildCheckItem(
            'Polygone fermé',
            _checks['perimeter_closed'] ?? false,
            'Le premier et dernier point doivent être identiques',
          ),
          _buildCheckItem(
            'Surface > 0.01 km²',
            _checks['perimeter_area'] ?? false,
            'La surface du périmètre semble trop petite',
            details:
                '${_calculateArea(widget.perimeterPoints).toStringAsFixed(3)} km²',
          ),

          const SizedBox(height: 24),
          const Text(
            'Tracé',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildCheckItem(
            'Au minimum 2 points',
            _checks['route_min_2_points'] ?? false,
            'Tracez au moins 2 points pour le tracé',
            details: '${widget.routePoints.length} points',
          ),
          _buildCheckItem(
            'Distance > 0.5 km',
            _checks['route_length'] ?? false,
            'Le tracé doit être plus long',
            details:
                '${_calculateDistance(widget.routePoints).toStringAsFixed(2)} km',
          ),
          _buildCheckItem(
            'Pas de points dupliqués',
            _checks['no_duplicate_points'] ?? false,
            'Deux points ne doivent pas être identiques',
          ),
          _buildCheckItem(
            'Tracé dans le périmètre',
            _checks['route_in_perimeter'] ?? false,
            'Tous les points du tracé doivent être dans le périmètre',
          ),

          const SizedBox(height: 32),

          // Status
          if (progress < 1.0)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_rounded, color: Colors.orange),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Veuillez corriger les erreurs avant de publier',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Le circuit respecte tous les critères de qualité ✅',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCheckItem(
    String label,
    bool isPassing,
    String hint, {
    String? details,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isPassing ? Colors.green : Colors.red,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              isPassing ? Icons.check : Icons.close,
              color: Colors.white,
              size: 14,
            ),
          ),
        ),
        title: Text(
          label,
          style: TextStyle(
            decoration: isPassing ? TextDecoration.none : null,
            color: isPassing ? Colors.black : Colors.red,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              hint,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            if (details != null) ...[
              const SizedBox(height: 4),
              Text(
                details,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
