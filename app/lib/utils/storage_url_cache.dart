import 'package:firebase_storage/firebase_storage.dart';

/// Cache mémoire des résolutions `gs://` -> `downloadURL`.
///
/// Objectif: éviter de refaire un aller-retour réseau Firebase Storage à
/// chaque ouverture d'une même fiche (polaroid POI, cartes produits, etc.).
/// Les download URLs Firebase sont stables tant que le token n'est pas
/// régénéré, donc un cache process-lifetime est sûr et améliore nettement
/// la fluidité d'affichage des cartes.
class StorageUrlCache {
  StorageUrlCache._();

  static final Map<String, String> _resolved = <String, String>{};
  static final Map<String, Future<String>> _inFlight = <String, Future<String>>{};

  /// Résout une URL `gs://` en download URL, avec cache et déduplication
  /// des requêtes concurrentes. Renvoie l'URL d'origine en cas d'échec.
  static Future<String> resolve(String gsUrl) {
    final key = gsUrl.trim();
    final cached = _resolved[key];
    if (cached != null) return Future<String>.value(cached);

    final pending = _inFlight[key];
    if (pending != null) return pending;

    final future = _fetch(key);
    _inFlight[key] = future;
    return future;
  }

  static Future<String> _fetch(String key) async {
    try {
      final ref = FirebaseStorage.instance.refFromURL(key);
      final url = await ref.getDownloadURL();
      _resolved[key] = url;
      return url;
    } catch (_) {
      // On ne met pas l'échec en cache: une nouvelle tentative pourra réussir.
      return key;
    } finally {
      _inFlight.remove(key);
    }
  }

  /// Renvoie l'URL déjà résolue sans déclencher de requête (ou null).
  static String? peek(String gsUrl) => _resolved[gsUrl.trim()];

  static void clear() {
    _resolved.clear();
    _inFlight.clear();
  }
}
