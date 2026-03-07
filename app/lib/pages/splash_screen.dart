import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:math' as math;

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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final isLandscape = size.width > size.height;
          final imageMaxWidth = math.min(
            isLandscape ? size.width * 0.62 : size.width * 0.92,
            1080.0,
          );
          final imageMaxHeight = math.min(
            isLandscape ? size.height * 0.82 : size.height * 0.68,
            920.0,
          );
          final horizontalPadding = math.max(20.0, size.width * 0.04);
          final spinnerBottom = math.max(28.0, size.height * 0.06);

          return Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: imageMaxWidth,
                        maxHeight: imageMaxHeight,
                      ),
                      child: Image.asset(
                        'assets/splash/wom1.png',
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint('❌ SplashScreen: Image load error: $error');
                          return const ColoredBox(
                            color: Colors.white,
                            child: Center(
                              child: Icon(
                                Icons.festival,
                                size: 120,
                                color: Color(0xFFFF6FB1),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: spinnerBottom,
                child: SafeArea(
                  top: false,
                  child: Center(
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        strokeWidth: 4,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFFFF6FB1),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
