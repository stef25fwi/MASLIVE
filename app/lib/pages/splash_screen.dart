import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.onComplete});
  
  final VoidCallback? onComplete;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    
    debugPrint('🚀 SplashScreen: initState - waiting for map to load');
    
    // ✅ Masquer la status bar et navigation bar
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    
    // ✅ Statusbar noir
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    
    // ✅ Navigation déclenchée par la page home quand la carte est prête
    // Le callback onComplete sera appelé par main.dart après le chargement de la carte
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
        'assets/splash/wom1.png',
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
