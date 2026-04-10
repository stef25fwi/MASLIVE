import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'splash_screen.dart';
import 'default_map_page.dart';
import 'home_map_page_3d.dart';
import '../services/startup_preload_service.dart';
import '../utils/startup_trace.dart';
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
  static const Duration _fadeDuration = Duration(milliseconds: 220);
  static const Duration _minimumSplashDuration = Duration(milliseconds: 280);
  static const Duration _deferredAssetPreloadDelay = Duration(
    milliseconds: 120,
  );
  static const Duration _mapPlaceholderFadeDuration = Duration(
    milliseconds: 180,
  );

  final bool _showHome = true;
  bool _mapReady = false;
  bool _mapSignalReady = false;
  bool _assetsReady = false;
  bool _homeFrameReady = false;
  bool _didHideSplash = false;
  bool _showSplashOverlay = true;
  bool _didStartDeferredAssetPreload = false;
  late DateTime _splashStartTime;

  Widget get _homeAfterSplash {
    if (kIsWeb) return const DefaultMapPage();
    return const HomeMapPage3D();
  }

  @override
  void initState() {
    super.initState();
    _splashStartTime = DateTime.now();
    StartupTrace.mark('splash_init');
    StartupTrace.log('SPLASH', 'initState');
    debugPrint('🚀 SplashWrapperPage: initState - preparing home page');

    // Repartir d'un état propre à chaque entrée sur le splash.
    // Sinon un ancien `true` peut empêcher toute nouvelle transition car
    // l'écouteur ne reçoit pas de changement de valeur.
    if (mapReadyNotifier.value) {
      mapReadyNotifier.value = false;
      StartupTrace.log('SPLASH', 'mapReadyNotifier reset to false');
    }

    // Écouter quand la carte est prête
    mapReadyNotifier.addListener(_onMapReady);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _homeFrameReady = true;
      StartupTrace.mark('splash_first_frame');
      StartupTrace.log('SPLASH', 'first frame rendered');
      _startAssetPreload();
      _tryHideSplash();
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
    final totalMs = StartupTrace.elapsedSince('splash_init');
    final afterHideMs = StartupTrace.elapsedSince('splash_hidden');
    StartupTrace.mark('map_ready_signal');
    StartupTrace.log(
      'SPLASH',
      'mapReadyNotifier observed true total=${totalMs ?? -1}ms afterHide=${afterHideMs ?? -1}ms',
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _startAssetPreload() async {
    StartupTrace.log('SPLASH', 'asset preload start');
    try {
      final assets = await StartupPreloadService.collectSplashImageAssets();
      StartupTrace.log(
        'SPLASH',
        'asset manifest collected count=${assets.length}',
      );
      if (!mounted) return;

      await Future.wait(
        assets.map((path) => precacheImage(AssetImage(path), context).catchError((_) {})),
      );

      try {
        await StartupPreloadService.warmupMapStyleAsset();
        StartupTrace.log('SPLASH', 'warmupMapStyleAsset success');
      } catch (e) {
        StartupTrace.log('SPLASH', 'warmupMapStyleAsset failed: $e');
        debugPrint('⚠️ SplashWrapper: warmupMapStyleAsset échoué: $e');
      }
    } catch (e) {
      StartupTrace.log('SPLASH', 'asset preload failed: $e');
      debugPrint('⚠️ SplashWrapper: preload inattendu échoué: $e');
    }

    if (!mounted) return;
    _assetsReady = true;
    StartupTrace.log('SPLASH', 'asset preload complete');
    _tryHideSplash();
  }

  void _tryHideSplash() {
    if (_didHideSplash) return;
    if (!_homeFrameReady || !_assetsReady) {
      StartupTrace.log(
        'SPLASH',
        'gate blocked homeFrameReady=$_homeFrameReady assetsReady=$_assetsReady mapSignalReady=$_mapSignalReady',
      );
      return;
    }

    final elapsedMs = DateTime.now()
        .difference(_splashStartTime)
        .inMilliseconds;
    final remainingMs = _minimumSplashDuration.inMilliseconds - elapsedMs;

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
    final totalMs = StartupTrace.elapsedSince('splash_init');
    StartupTrace.log(
      'SPLASH',
      'hideSplash force=$force mapSignalReady=$_mapSignalReady assetsReady=$_assetsReady total=${totalMs ?? -1}ms',
    );
    StartupTrace.mark('splash_hide_start');
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
      StartupTrace.mark('splash_hidden');
      StartupTrace.log('SPLASH', 'splash overlay removed');
      unawaited(_startDeferredAssetPreload());
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

  Future<void> _startDeferredAssetPreload() async {
    if (_didStartDeferredAssetPreload) return;
    _didStartDeferredAssetPreload = true;

    await Future<void>.delayed(_deferredAssetPreloadDelay);
    if (!mounted) return;

    StartupTrace.log('SPLASH', 'deferred asset preload start');
    try {
      final assets = await StartupPreloadService.collectDeferredImageAssets();
      if (!mounted) return;

      for (final path in assets) {
        if (!mounted) return;
        try {
          await precacheImage(AssetImage(path), context);
        } catch (_) {
          // Optionnel: ne jamais bloquer l'affichage de la home.
        }
      }
      StartupTrace.log(
        'SPLASH',
        'deferred asset preload complete count=${assets.length}',
      );
    } catch (e) {
      StartupTrace.log('SPLASH', 'deferred asset preload failed: $e');
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
                  child: _homeAfterSplash,
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

            Positioned.fill(
              child: IgnorePointer(
                ignoring: true,
                child: AnimatedOpacity(
                  duration: _mapPlaceholderFadeDuration,
                  opacity: (!_showSplashOverlay && !_mapSignalReady) ? 1.0 : 0.0,
                  child: const _MapWarmupOverlay(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapWarmupOverlay extends StatelessWidget {
  const _MapWarmupOverlay();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
      ),
      child: const Align(
        alignment: Alignment.bottomCenter,
        child: SafeArea(
          top: false,
          minimum: EdgeInsets.only(bottom: 28),
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0x66FF6FB1)),
            ),
          ),
        ),
      ),
    );
  }
}
