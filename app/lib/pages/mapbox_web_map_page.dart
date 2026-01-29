import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../ui/widgets/mapbox_web_view_platform.dart';

/// Page affichant Mapbox GL JS sur Web uniquement
class MapboxWebMapPage extends StatelessWidget {
  const MapboxWebMapPage({super.key});

  @override
  Widget build(BuildContext context) {
    const token = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

    if (!kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mapbox Web'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Cette page est uniquement disponible sur Web.\n'
              'Sur mobile, utilisez la version native Mapbox.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (token.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mapbox Web'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'MAPBOX_ACCESS_TOKEN manquant.\n'
              'Lance avec --dart-define=MAPBOX_ACCESS_TOKEN=...',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapbox Web (GL JS)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Mapbox GL JS'),
                  content: const Text(
                    'Cette carte utilise Mapbox GL JS via HtmlElementView.\n\n'
                    'Mobile: mapbox_maps_flutter (natif)\n'
                    'Web: Mapbox GL JS\n\n'
                    'Moteur officiel Mapbox pour un look & feel identique.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fermer'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: MapboxWebView(
        accessToken: token,
        initialLat: 16.2410, // Pointe-à-Pitre
        initialLng: -61.5340,
        initialZoom: 15.0,
        initialPitch: 45.0,
        initialBearing: 0.0,
        styleUrl: 'mapbox://styles/mapbox/streets-v12',
      ),
    );
  }
}
