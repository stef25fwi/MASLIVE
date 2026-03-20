import 'dart:convert';

import 'package:flutter/services.dart';

/// Service de préchargement d'assets au démarrage.
///
/// Stratégie à deux niveaux :
/// - **Tier 1** (4 images critiques) : chargées PENDANT le splash (~50ms).
/// - **Tier 2** (toutes les autres) : chargées en arrière-plan APRÈS masquage
///   du splash, sans jamais bloquer l'affichage de la carte.
class StartupPreloadService {
  const StartupPreloadService._();

  /// Images Tier 1 : affichées en premier à l'écran (splash + navbar principale).
  /// ✅ Volontairement courte : chargée de façon synchrone pendant le splash.
  static const List<String> tier1Images = <String>[
    'assets/splash/wom1.png',
    'assets/images/maslivelogo.png',
    'assets/images/maslivesmall.png',
    'assets/images/icon wc parking.png',
  ];

  /// Retourne les images Tier 2 : [assets/images/] + [assets/shop/] hors Tier 1.
  /// Destiné à être appelé en arrière-plan après masquage du splash.
  static Future<List<String>> collectTier2Assets() async {
    final tier2 = <String>[];
    try {
      final manifestJson = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifest =
          jsonDecode(manifestJson) as Map<String, dynamic>;
      for (final assetPath in manifest.keys) {
        if (!_isImageAsset(assetPath)) continue;
        if ((assetPath.startsWith('assets/images/') ||
                assetPath.startsWith('assets/shop/')) &&
            !tier1Images.contains(assetPath)) {
          tier2.add(assetPath);
        }
      }
    } catch (_) {
      // Non bloquant.
    }
    return tier2;
  }

  /// Précharge le JSON du style carte en mémoire (non bloquant pour le splash).
  static Future<void> warmupMapStyleAsset() async {
    try {
      await rootBundle.loadString('assets/map_styles/google_light.json');
    } catch (_) {}
  }

  static bool _isImageAsset(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp');
  }
}
