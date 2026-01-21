import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    
    debugPrint('🚀 SplashScreen: initState - starting timer');
    
    // ✅ Masquer la status bar et navigation bar
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    
    // ✅ Statusbar noir
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    
    // ✅ Navigation après 3 secondes vers la page d'accueil avec carte
    Future.delayed(const Duration(seconds: 3), () {
      debugPrint('🚀 SplashScreen: Timer finished, mounted=$mounted');
      if (mounted) {
        debugPrint('🚀 SplashScreen: Navigating to /');
        // Restaurer les barres système avant de naviguer
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        Navigator.of(context).pushReplacementNamed('/');
        debugPrint('🚀 SplashScreen: Navigation called');
      }
    });
  }

  @override
  void dispose() {
    // S'assurer que les barres système sont restaurées
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🚀 SplashScreen: build called');
    return Scaffold(
      backgroundColor: Colors.black,
      body: Image.asset(
        'assets/splash/maslivepink.png',
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('❌ SplashScreen: Image load error: $error');
          return const Center(
            child: CircularProgressIndicator(color: Colors.pink),
          );
        },
      ),
    );
  }
}
