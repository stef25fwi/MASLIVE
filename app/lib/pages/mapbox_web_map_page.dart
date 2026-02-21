import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import '../services/mapbox_token_service.dart';
import '../ui/map/maslive_map.dart';
import 'splash_wrapper_page.dart' show mapReadyNotifier;

/// Page affichant Mapbox GL JS sur Web uniquement
class MapboxWebMapPage extends StatefulWidget {
  const MapboxWebMapPage({super.key});

  @override
  State<MapboxWebMapPage> createState() => _MapboxWebMapPageState();
}

class _MapboxWebMapPageState extends State<MapboxWebMapPage> {
  // Constante: délai historique avant notification splash
  static const Duration _mapReadyDelay = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final token = MapboxTokenService.getTokenSync();

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
              'Token Mapbox manquant.\n'
              'Configure MAPBOX_ACCESS_TOKEN (ou MAPBOX_TOKEN legacy)\n'
              'ou renseigne-le via la UI (SharedPreferences).',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    // Mode plein écran - Carte passe sous les barres système
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: Container(
                  color: Colors.black,
                  child: MasLiveMap(
                    initialLat: 16.2410, // Pointe-à-Pitre
                    initialLng: -61.5340,
                    initialZoom: 15.0,
                    initialPitch: 45.0,
                    initialBearing: 0.0,
                    styleUrl: 'mapbox://styles/mapbox/streets-v12',
                    onMapReady: (_) {
                      Future.delayed(_mapReadyDelay, () {
                        if (!mounted) return;
                        if (!mapReadyNotifier.value) {
                          mapReadyNotifier.value = true;
                          debugPrint('✅ MapboxWebMapPage: Carte prête, notification splash');
                        }
                      });
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
