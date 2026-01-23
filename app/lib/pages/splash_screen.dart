import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    
    // ✅ Statusbar blanc
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
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
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Image wom1 en plein écran
          Image.asset(
            'assets/splash/wom1.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('❌ SplashScreen: Image load error: $error');
              return Container(
                color: Colors.white,
                child: const Center(
                  child: Icon(
                    Icons.festival,
                    size: 120,
                    color: Color(0xFFFF6FB1),
                  ),
                ),
              );
            },
          ),
          // Animation de chargement en bas
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6FB1)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
