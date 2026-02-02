import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'splash_screen.dart';
import 'default_map_page.dart';
import 'home_map_page_3d.dart';
import '../utils/web_viewport_resize.dart';

/// Notificateur global pour savoir quand la carte est prête
final ValueNotifier<bool> mapReadyNotifier = ValueNotifier<bool>(false);

/// Page qui gère le splashscreen et attend que la carte soit prête avant de l'afficher
class SplashWrapperPage extends StatefulWidget {
  const SplashWrapperPage({super.key});

  @override
  State<SplashWrapperPage> createState() => _SplashWrapperPageState();
}

class _SplashWrapperPageState extends State<SplashWrapperPage> {
  bool _showHome = false;
  bool _mapReady = false;
  late DateTime _splashStartTime;

  Widget get _homeAfterSplash =>
      kIsWeb ? const DefaultMapPage() : const HomeMapPage3D();

  @override
  void initState() {
    super.initState();
    _splashStartTime = DateTime.now();
    debugPrint('🚀 SplashWrapperPage: initState - preparing home page');

    // Écouter quand la carte est prête
    mapReadyNotifier.addListener(_onMapReady);

    // Pré-charger la page home immédiatement pour que la carte commence à se charger
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _showHome = true);
      }
    });

    // Timeout de secours : si la carte ne notifie pas dans les 5 secondes, on affiche quand même
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && !_mapReady) {
        debugPrint('⚠️ SplashWrapperPage: Timeout - forçage du masquage du splash après 5 secondes');
        _hideSplash();
      }
    });
  }

  @override
  void dispose() {
    mapReadyNotifier.removeListener(_onMapReady);
    super.dispose();
  }

  void _onMapReady() {
    if (mapReadyNotifier.value && !_mapReady) {
      // Calcul du délai écoulé depuis le démarrage du splash
      final elapsedSeconds = DateTime.now()
          .difference(_splashStartTime)
          .inSeconds;

      // Minimum 2.5 secondes de splashscreen
      if (elapsedSeconds < 2.5) {
        debugPrint(
          '⏳ SplashWrapperPage: Carte prête mais délai minimum non atteint ($elapsedSeconds sec < 2.5 sec)',
        );
        final remainingMs = (2500 - (elapsedSeconds * 1000)).toInt();
        Future.delayed(Duration(milliseconds: remainingMs), () {
          if (mounted) {
            _hideSplash();
          }
        });
      } else {
        debugPrint(
          '✅ SplashWrapperPage: Carte prête et délai minimum atteint, masquage du splashscreen',
        );
        _hideSplash();
      }
    }
  }

  void _hideSplash() {
    setState(() => _mapReady = true);
    // Restaurer les barres système
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // Sur le web, Mapbox GL JS se recale correctement après un resize.
    // On le simule ici pour éviter l'écran "moitié noir" tant que
    // l'utilisateur n'a pas pivoté l'app.
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        triggerWebViewportResize();
        Future.delayed(
          const Duration(milliseconds: 60),
          triggerWebViewportResize,
        );
        Future.delayed(
          const Duration(milliseconds: 220),
          triggerWebViewportResize,
        );
        // Après la fin du fade (AnimatedOpacity ~400ms)
        Future.delayed(
          const Duration(milliseconds: 520),
          triggerWebViewportResize,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white, // Fond blanc permanent pour éviter les flashs
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // La page home est chargée en arrière-plan pour que la carte commence à se charger
            if (_showHome)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_mapReady,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 400),
                    opacity: _mapReady ? 1.0 : 0.0,
                    child: _homeAfterSplash,
                  ),
                ),
              ),

            // Le splashscreen reste visible tant que la carte n'est pas prête
            if (!_mapReady)
              Positioned.fill(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 400),
                  opacity: _mapReady ? 0.0 : 1.0,
                  child: const SplashScreen(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
