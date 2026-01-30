import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../ui/widgets/mapbox_web_view_platform.dart';

/// Page affichant Mapbox GL JS sur Web uniquement
class MapboxWebMapPage extends StatefulWidget {
  const MapboxWebMapPage({super.key});

  @override
  State<MapboxWebMapPage> createState() => _MapboxWebMapPageState();
}

class _MapboxWebMapPageState extends State<MapboxWebMapPage>
    with WidgetsBindingObserver {
  Size? _lastWebMapSize;
  int _webMapRebuildTick = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Rotation ou changement de taille de l'écran
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = MediaQuery.sizeOf(context);

      _lastWebMapSize ??= size;
      if (size != _lastWebMapSize) {
        debugPrint(
          '🔄 MapboxWebMapPage: Changement de taille détecté: '
          '${_lastWebMapSize?.width}x${_lastWebMapSize?.height} → '
          '${size.width}x${size.height}',
        );
        _lastWebMapSize = size;
        setState(() {
          _webMapRebuildTick++; // Force rebuild du WebView map
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const token = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

    if (!kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mapbox Web')),
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
        appBar: AppBar(title: const Text('Mapbox Web')),
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = MediaQuery.sizeOf(context);
          return Container(
            width: size.width,
            height: size.height,
            color: Colors.grey[200],
            child: MapboxWebView(
              key: ValueKey(
                'mapbox-web-admin-${_webMapRebuildTick}-${size.width.toStringAsFixed(0)}x${size.height.toStringAsFixed(0)}',
              ),
              accessToken: token,
              initialLat: 16.2410, // Pointe-à-Pitre
              initialLng: -61.5340,
              initialZoom: 15.0,
              initialPitch: 45.0,
              initialBearing: 0.0,
              styleUrl: 'mapbox://styles/mapbox/streets-v12',
            ),
          );
        },
      ),
    );
  }
}
