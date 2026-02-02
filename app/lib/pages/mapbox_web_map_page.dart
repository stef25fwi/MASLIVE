import 'dart:async';
import 'dart:ui' as ui;

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
  // Constantes pour la gestion du resize
  static const Duration _resizeDebounceDelay = Duration(milliseconds: 80);
  static const Duration _mapReadyDelay = Duration(milliseconds: 500);
  
  ui.Size? _lastWebMapSize;
  int _webMapRebuildTick = 0;
  Timer? _resizeDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Notifier que la carte est prête après un court délai
    Future.delayed(_mapReadyDelay, () {
      if (!mounted) return;
      
      // Notifier le splash wrapper que la carte est chargée
      if (!mapReadyNotifier.value) {
        mapReadyNotifier.value = true;
        debugPrint('✅ MapboxWebMapPage: Carte prête, notification splash');
      }
    });
  }

  @override
  void dispose() {
    _resizeDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Détecte : rotation, split-view, resize fenêtre, clavier virtuel
    if (mounted) {
      try {
        setState(() => _webMapRebuildTick++);
      } catch (e) {
        debugPrint('⚠️ Erreur didChangeMetrics: $e');
      }
    }
  }
  
  /// Planifie un resize de la carte avec debounce pour éviter les rebuilds excessifs.
  /// 
  /// Cette méthode est appelée par LayoutBuilder à chaque changement de contraintes.
  /// Le debounce évite de rebuilder la carte 10+ fois pendant une animation de resize.
  void _scheduleResize(ui.Size size) {
    // Ignorer si la taille n'a pas changé (optimisation)
    if (_lastWebMapSize == size) return;
    _lastWebMapSize = size;

    // Annuler le timer précédent (debounce)
    _resizeDebounce?.cancel();
    
    // Attendre que le resize soit stabilisé avant de rebuilder
    _resizeDebounce = Timer(_resizeDebounceDelay, () {
      if (!mounted) return; // Sécurité supplémentaire
      
      try {
        // Incrémenter le tick force Flutter à recréer la carte avec une nouvelle Key
        setState(() => _webMapRebuildTick++);
        debugPrint(
          '✅ Mapbox Web resize: ${size.width.toInt()}x${size.height.toInt()} '
          '(tick: $_webMapRebuildTick)',
        );
      } catch (e) {
        debugPrint('⚠️ Erreur _scheduleResize: $e');
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
            final size = ui.Size(constraints.maxWidth, constraints.maxHeight);
            
            // PostFrameCallback garantit que le resize est appelé APRÈS
            // que le layout soit terminé, évitant les conflits avec setState
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scheduleResize(size);
            });
            
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
                            'mapbox-web-${size.width.toInt()}x${size.height.toInt()}_$_webMapRebuildTick',
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
