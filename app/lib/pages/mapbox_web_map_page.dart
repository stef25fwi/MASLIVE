import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import '../services/mapbox_token_service.dart';
import '../ui/widgets/mapbox_web_view_platform.dart';
import 'splash_wrapper_page.dart' show mapReadyNotifier;

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
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Notifier que la carte est prête après un court délai
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _isMapReady = true);
      
      // Notifier le splash wrapper que la carte est chargée
      if (!mapReadyNotifier.value) {
        mapReadyNotifier.value = true;
        debugPrint('✅ MapboxWebMapPage: Carte prête, notification splash');
      }
    });
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
        body: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            
            return Stack(
              children: [
                // Carte Mapbox en plein écran
                Positioned.fill(
                  child: RepaintBoundary(
                    child: SizedBox(
                      width: size.width,
                      height: size.height,
                      child: Container(
                        color: Colors.black,
                        child: MapboxWebView(
                          key: ValueKey(
                            'mapbox-web-fullscreen-${_webMapRebuildTick}-${size.width.toStringAsFixed(0)}x${size.height.toStringAsFixed(0)}',
                          ),
                          accessToken: token,
                          initialLat: 16.2410, // Pointe-à-Pitre
                          initialLng: -61.5340,
                          initialZoom: 15.0,
                          initialPitch: 45.0,
                          initialBearing: 0.0,
                          styleUrl: 'mapbox://styles/mapbox/streets-v12',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
