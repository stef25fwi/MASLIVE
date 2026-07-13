import 'dart:async';
import 'dart:convert';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cache des résolutions `gs://` -> `downloadURL`, **persisté sur disque**.
///
/// Objectif: affichage instantané des images au démarrage à froid. Les download
/// URLs Firebase sont stables tant que le token n'est pas régénéré, donc on peut
/// mémoriser durablement la correspondance et **éviter l'aller-retour réseau
/// `getDownloadURL()`** qui, sinon, précède chaque téléchargement d'image.
///
/// - Cache mémoire (lecture synchrone via [peek] => affichage sans spinner).
/// - Persistance via `shared_preferences` (localStorage sur web) chargée au boot
///   par [init]; les écritures sont regroupées (debounce) pour rester bon marché.
/// - Déduplication des requêtes concurrentes.
class StorageUrlCache {
  StorageUrlCache._();

  static const String _prefsKey = 'storage_url_cache_v1';
  static const int _maxEntries = 800;

  static final Map<String, String> _resolved = <String, String>{};
  static final Map<String, Future<String>> _inFlight = <String, Future<String>>{};

  static bool _loaded = false;
  static Future<void>? _loading;
  static Timer? _persistTimer;
  static bool _dirty = false;

  /// Charge le cache disque en mémoire (idempotent). À appeler tôt au démarrage
  /// pour que [peek] renvoie immédiatement les URLs déjà connues.
  static Future<void> init() {
    if (_loaded) return Future<void>.value();
    return _loading ??= _load();
  }

  static Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            if (key is String && value is String && value.isNotEmpty) {
              _resolved.putIfAbsent(key, () => value);
            }
          });
        }
      }
    } catch (_) {
      // Cache best-effort: en cas d'échec on repart d'un cache mémoire vide.
    } finally {
      _loaded = true;
      _loading = null;
    }
  }

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
      _schedulePersist();
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

  static void _schedulePersist() {
    _dirty = true;
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 400), _persist);
  }

  static Future<void> _persist() async {
    if (!_dirty) return;
    _dirty = false;
    try {
      // Bornage: on ne conserve que les dernières entrées pour éviter une
      // croissance illimitée du cache disque.
      Map<String, String> toStore = _resolved;
      if (_resolved.length > _maxEntries) {
        final entries = _resolved.entries.toList();
        final trimmed = entries.sublist(entries.length - _maxEntries);
        toStore = <String, String>{for (final e in trimmed) e.key: e.value};
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(toStore));
    } catch (_) {
      // Persistance best-effort.
    }
  }

  static Future<void> clear() async {
    _resolved.clear();
    _inFlight.clear();
    _dirty = false;
    _persistTimer?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {}
  }
}
