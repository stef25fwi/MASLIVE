import 'package:flutter/material.dart';
import 'pages/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Laisse l'app démarrer même si Firebase n'est pas encore configuré.
  }
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
