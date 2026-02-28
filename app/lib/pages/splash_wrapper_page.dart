import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'splash_screen.dart';
import 'default_map_page.dart';
import 'home_map_page_3d.dart';
import '../services/startup_preload_service.dart';
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
  static const Duration _fadeDuration = Duration(milliseconds: 450);

  final bool _showHome = true;
  bool _mapReady = false;
  bool _mapSignalReady = false;
  bool _assetsReady = false;
  bool _didHideSplash = false;
  bool _showSplashOverlay = true;
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

    // Précharger les assets visuels pendant le splash.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAssetPreload();
    });

    // Timeout de secours : si la carte ne notifie pas dans les 5 secondes, on affiche quand même
    final timeout = kIsWeb
        ? const Duration(seconds: 12)
        : const Duration(seconds: 10);
    Future.delayed(timeout, () {
      if (mounted && !_didHideSplash) {
        debugPrint(
          '⚠️ SplashWrapperPage: Timeout - forçage du masquage du splash après ${timeout.inSeconds} secondes',
        );
        _hideSplash(force: true);
      }
    });
  }

  @override
  void dispose() {
    mapReadyNotifier.removeListener(_onMapReady);
    super.dispose();
  }

  void _onMapReady() {
    if (!mapReadyNotifier.value || _mapSignalReady) return;
    _mapSignalReady = true;
    _tryHideSplash();
  }

  Future<void> _startAssetPreload() async {
    final assets = await StartupPreloadService.collectSplashImageAssets();
    if (!mounted) return;

    try {
      for (final path in assets) {
        await precacheImage(AssetImage(path), context);
      }
      await StartupPreloadService.warmupMapStyleAsset();
    } catch (_) {
      // Ne bloque jamais le démarrage.
    }

    if (!mounted) return;
    _assetsReady = true;
    _tryHideSplash();
  }

  void _tryHideSplash() {
    if (_didHideSplash) return;
    if (!_mapSignalReady || !_assetsReady) return;

    final elapsedMs = DateTime.now().difference(_splashStartTime).inMilliseconds;
    final remainingMs = 2500 - elapsedMs;

    if (remainingMs > 0) {
      debugPrint(
        '⏳ SplashWrapperPage: attente délai minimum splash (${remainingMs}ms restantes)',
      );
      Future.delayed(Duration(milliseconds: remainingMs), () {
        if (mounted) _hideSplash();
      });
      return;
    }

    _hideSplash();
  }

  void _hideSplash({bool force = false}) {
    if (_didHideSplash) return;
    _didHideSplash = true;
    setState(() {
      _mapReady = true;
      if (force) {
        _mapSignalReady = true;
        _assetsReady = true;
      }
    });

    // Laisser le temps au fade de se terminer avant de retirer le widget splash.
    Future.delayed(_fadeDuration, () {
      if (!mounted) return;
      setState(() {
        _showSplashOverlay = false;
      });
    });

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
        // Après la fin du fade
        Future.delayed(
          _fadeDuration + const Duration(milliseconds: 80),
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
                    duration: _fadeDuration,
                    opacity: _mapReady ? 1.0 : 0.0,
                    child: _homeAfterSplash,
                  ),
                ),
              ),

            // Le splashscreen reste visible tant que la carte n'est pas prête
            if (_showSplashOverlay)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: _mapReady,
                  child: AnimatedOpacity(
                    duration: _fadeDuration,
                    opacity: _mapReady ? 0.0 : 1.0,
                    child: const SplashScreen(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
