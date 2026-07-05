// Préchauffe (web only) les chunks JS différés des pages les plus probables
// à être ouvertes juste après la home, pendant le temps mort post-splash.
//
// Sur Flutter web, chaque route enregistrée avec un `deferred as` (main.dart)
// télécharge son propre chunk JS au premier `loadLibrary()`. Sans préchauffe,
// le premier tap sur une icône de la bottom bar (Boutique/Profil → user-shell,
// panier → cart, favoris → favorites) affiche un écran vide le temps du
// téléchargement réseau — perçu comme un délai d'ouverture de page.
//
// `loadLibrary()` est idempotent et son état est partagé par le runtime
// dart2js/DDC pour la bibliothèque cible, quel que soit le préfixe qui
// déclenche le chargement: appeler loadLibrary() ICI (tôt, en tâche de fond)
// fait que l'appel équivalent dans `onGenerateRoute` (main.dart), déclenché
// plus tard par la navigation réelle, retombe sur un chunk déjà en cache —
// résolution quasi instantanée, sans retélécharger.
//
// Sur natif, les imports différés sont compilés dans le binaire: l'appel est
// un no-op quasi gratuit. On le fait quand même pour garder un seul chemin de
// code, mais l'essentiel du gain est sur le web.

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;

// ignore_for_file: unused_import
// Ces imports différés ne sont utilisés que via `.loadLibrary()` (aucun
// symbole de la bibliothèque n'est référencé) — l'analyzer ne reconnaît pas
// cet usage comme un "use" de l'import, d'où le faux positif `unused_import`.
import '../pages/user_facing_shell_page.dart' deferred as prefetch_user_shell;
import '../pages/cart/unified_cart_page.dart' deferred as prefetch_cart;
import '../pages/favorites_page.dart' deferred as prefetch_favorites;

/// Lance le préchargement en tâche de fond (best-effort, jamais bloquant).
/// À appeler une fois, après que la home a rendu sa première frame.
void prefetchLikelyDeferredRoutes() {
  if (!kIsWeb) return;

  unawaited(_safeLoad(prefetch_user_shell.loadLibrary));
  unawaited(_safeLoad(prefetch_cart.loadLibrary));
  unawaited(_safeLoad(prefetch_favorites.loadLibrary));
}

Future<void> _safeLoad(Future<void> Function() loadLibrary) async {
  try {
    await loadLibrary();
  } catch (_) {
    // Best-effort: un échec réseau ici ne doit jamais impacter l'app.
    // La navigation réelle retentera le chargement normalement.
  }
}
