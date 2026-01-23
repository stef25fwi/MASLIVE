import 'package:flutter/foundation.dart' show kIsWeb;

class MapAccessLabels {
  final String title;
  final String subtitle;

  const MapAccessLabels({required this.title, required this.subtitle});
}

MapAccessLabels mapAccessLabels() {
  if (kIsWeb) {
    return const MapAccessLabels(
      title: 'Carte (Web/OSM)',
      subtitle: 'Fallback Web: OpenStreetMap (flutter_map)',
    );
  }

  return const MapAccessLabels(
    title: 'Mapbox (Google Light)',
    subtitle: 'Ouvrir la carte Mapbox + style JSON',
  );
}
