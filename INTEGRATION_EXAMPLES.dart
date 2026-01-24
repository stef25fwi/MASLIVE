/// EXEMPLE D'INTÉGRATION - MEDIA SHOP V2
///
/// IMPORTANT
/// - Ce fichier à la racine sert de **documentation / copié-collé**.
/// - La version **compilable** est dans le projet Flutter : [app/lib/INTEGRATION_EXAMPLES.dart](app/lib/INTEGRATION_EXAMPLES.dart)
///
/// Les imports ci-dessous sont à adapter selon votre contexte :
///
/// ```dart
/// import 'package:flutter/material.dart';
/// import 'package:get/get.dart';
///
/// // Import de la nouvelle structure (dans /app/lib)
/// import 'pages/media_shop_wrapper.dart';
/// import 'pages/media_galleries_page_v2.dart';
/// ```

/// ============================================================
/// OPTION 1: Navigation simple depuis un bouton/menu
/// ============================================================

/// (Voir la version compilable dans /app/lib/INTEGRATION_EXAMPLES.dart)

/// ============================================================
/// OPTION 2: Onglet dans un BottomNavigationBar
/// ============================================================

/// (Voir la version compilable dans /app/lib/INTEGRATION_EXAMPLES.dart)

/// ============================================================
/// OPTION 3: Route nommée dans GetX / Named Routes
/// ============================================================

/// (Voir la version compilable dans /app/lib/INTEGRATION_EXAMPLES.dart)

/// ============================================================
/// OPTION 4: Avec paramètre groupId dynamique
/// ============================================================

/// (Voir la version compilable dans /app/lib/INTEGRATION_EXAMPLES.dart)

/// ============================================================
/// OPTION 5: Badge panier global (AppBar)
/// ============================================================

// Pour afficher un badge panier dans l'AppBar de toute l'app,
// il faut wrapper toute l'app avec GalleryCartScope

/// (Voir la version compilable dans /app/lib/INTEGRATION_EXAMPLES.dart)

/// ============================================================
/// NOTES IMPORTANTES
/// ============================================================
///
/// 1. Si vous utilisez MediaShopWrapper isolément (Option 1-4),
///    le panier sera perdu lors de la navigation back.
///
/// 2. Pour un panier persistant dans toute l'app, utilisez
///    l'Option 5 (wrapper au niveau MaterialApp).
///
/// 3. Pour sauvegarder le panier (SharedPreferences, etc.),
///    modifiez GalleryCartProvider pour ajouter la persistance.
///
/// 4. Pour le checkout Stripe, modifiez la méthode
///    _openCartSheet() dans media_galleries_page_v2.dart
