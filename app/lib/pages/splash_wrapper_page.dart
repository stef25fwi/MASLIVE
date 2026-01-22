import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'splash_screen.dart';
import 'home_map_page.dart';

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

  @override
  void initState() {
    super.initState();
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
      debugPrint('✅ SplashWrapperPage: Carte prête, masquage du splashscreen');
      setState(() => _mapReady = true);
      
      // Restaurer les barres système
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // La page home est chargée en arrière-plan pour que la carte commence à se charger
        if (_showHome)
          Opacity(
            opacity: _mapReady ? 1.0 : 0.0,
            child: const HomeMapPage(),
          ),
        
        // Le splashscreen reste visible tant que la carte n'est pas prête
        if (!_mapReady)
          const SplashScreen(),
      ],
    );
  }
}
