import 'package:flutter/material.dart';

typedef LngLat = ({double lng, double lat});

/// Stub non-web : permet de compiler sur mobile/desktop.
/// Sur web, l'implémentation réelle est dans `mapbox_web_circuit_map.dart`.
class MapboxWebCircuitMap extends StatelessWidget {
  final String? mapboxToken;
  final List<LngLat> perimeter;
  final List<LngLat> route;
  final List<({int startIndex, int endIndex, Color color, String name})> segments;
  final ValueChanged<LngLat> onTapLngLat;

  const MapboxWebCircuitMap({
    super.key,
    required this.mapboxToken,
    required this.perimeter,
    required this.route,
    required this.segments,
    required this.onTapLngLat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.04),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Text(
        'MapboxWebCircuitMap est disponible uniquement sur Web.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
