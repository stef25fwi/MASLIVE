import 'package:flutter/material.dart';
import 'pages/splash_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(
        assetPath: 'assets/splash/maslive.png',
        starCount: 160,
        luminanceThreshold: 0.62,
      ),
    );
  }
}
