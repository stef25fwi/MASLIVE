import 'dart:convert';

import 'package:flutter/services.dart';

class StartupPreloadService {
  const StartupPreloadService._();

  static const List<String> _splashImages = <String>['assets/splash/wom1.png'];

  static Future<Set<String>> collectSplashImageAssets() async {
    return <String>{..._splashImages};
  }

  static Future<Set<String>> collectDeferredImageAssets() async {
    final assets = <String>{};

    try {
      final manifestJson = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifest =
          jsonDecode(manifestJson) as Map<String, dynamic>;

      for (final assetPath in manifest.keys) {
        if (!_isImageAsset(assetPath)) continue;
        if (assetPath.startsWith('assets/images/') ||
            assetPath.startsWith('assets/shop/')) {
          if (_splashImages.contains(assetPath)) continue;
          assets.add(assetPath);
        }
      }
    } catch (_) {
      // Le préchargement différé reste optionnel.
    }

    return assets;
  }

  static Future<void> warmupMapStyleAsset() async {
    try {
      await rootBundle.loadString('assets/map_styles/google_light.json');
    } catch (_) {
      // Optionnel.
    }
  }

  static bool _isImageAsset(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp');
  }
}
