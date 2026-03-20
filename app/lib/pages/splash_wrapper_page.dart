import 'dart:async' show unawaited;

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

  final Stopwatch _splashSw = Stopwatch();
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
    _splashSw.start();
    _splashStartTime = DateTime.now();
    debugPrint('🚀 SplashWrapperPage: initState - preparing home page');

    // Écouter quand la carte est prête
    mapReadyNotifier.addListener(_onMapReady);

    // Précharger les assets visuels pendant le splash.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAssetPreload();
    });

    // Timeout de secours : ✅ réduit (12→10s web, 10→8s natif) car Firebase timeout est 8s.
    final timeout = kIsWeb
        ? const Duration(seconds: 10)
        : const Duration(seconds: 8);
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
    debugPrint('⏱ Splash: map signal ready at ${_splashSw.elapsedMilliseconds}ms');
    _tryHideSplash();
  }

  /// Tier 1 : charge les 4 images critiques pendant le splash (~50ms).
  /// Tier 2 : toutes les autres images → background après masquage du splash.
  Future<void> _startAssetPreload() async {
    // Tier 1 — rapide, seulement les images affichées immédiatement.
    for (final path in StartupPreloadService.tier1Images) {
      if (!mounted) return;
      try {
        await precacheImage(AssetImage(path), context);
      } catch (_) {}
    }
    // Style carte JSON (lecture mémoire, < 5ms).
    await StartupPreloadService.warmupMapStyleAsset();

    if (!mounted) return;
    _assetsReady = true;
    debugPrint('⏱ Splash: tier1 assets ready at ${_splashSw.elapsedMilliseconds}ms');
    _tryHideSplash();

    // Tier 2 — lancé en arrière-plan, n'attend PAS le splash.
    unawaited(_preloadTier2Async());
  }

  /// Précharge les images secondaires en arrière-plan (non bloquant).
  Future<void> _preloadTier2Async() async {
    final tier2 = await StartupPreloadService.collectTier2Assets();
    for (final path in tier2) {
      if (!mounted) return;
      try {
        await precacheImage(AssetImage(path), context);
      } catch (_) {}
    }
    debugPrint('⏱ Splash: tier2 assets ready (${tier2.length} images)');
  }

  void _tryHideSplash() {
    if (_didHideSplash) return;
    if (!_mapSignalReady || !_assetsReady) return;

    final elapsedMs = DateTime.now().difference(_splashStartTime).inMilliseconds;
    // ✅ Délai minimum réduit 2500ms → 1800ms = gain ~700ms visible.
    final remainingMs = 1800 - elapsedMs;

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
    debugPrint('🏁 Splash: hide at ${_splashSw.elapsedMilliseconds}ms (force=$force)');
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
