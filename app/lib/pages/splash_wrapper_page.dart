import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'splash_screen.dart';
import 'home_map_page_v3.dart';

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
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white, // Fond blanc permanent pour éviter les flashs
      child: Stack(
        children: [
          // La page home est chargée en arrière-plan pour que la carte commence à se charger
          if (_showHome)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 400),
              opacity: _mapReady ? 1.0 : 0.0,
              child: const HomeMapPageV3(), // 🎯 Home par défaut
            ),

          // Le splashscreen reste visible tant que la carte n'est pas prête
          if (!_mapReady)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 400),
              opacity: _mapReady ? 0.0 : 1.0,
              child: const SplashScreen(),
            ),
        ],
      ),
    );
  }
}
