import 'package:shared_preferences/shared_preferences.dart';
import '../utils/mapbox_token_web_stub.dart'
  if (dart.library.html) '../utils/mapbox_token_web_web.dart';

class MapboxTokenInfo {
  final String token;
  final String source;

  const MapboxTokenInfo({required this.token, required this.source});
}

/// Gestion centralisée du token Mapbox.
///
/// Ordre de résolution:
/// 1) `--dart-define=MAPBOX_ACCESS_TOKEN=...`
/// 2) `--dart-define=MAPBOX_TOKEN=...` (legacy)
/// 3) Token stocké dans SharedPreferences (fonctionne aussi sur Web)
class MapboxTokenService {
  static const String _prefsKey = 'maslive.mapboxAccessToken';
  static const String _prefsLegacyKey = 'maslive.mapboxToken';

  static String _cachedToken = '';
  static String _cachedSource = '...';

  static String get cachedToken => _cachedToken;
  static String get cachedSource => _cachedSource;

  static const String _compileTimeToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
  );
  static const String _compileTimeLegacyToken = String.fromEnvironment(
    'MAPBOX_TOKEN',
  );

  // Pas de fallback hardcodé : le token doit venir de --dart-define ou de SharedPreferences.

  static Future<MapboxTokenInfo> getTokenInfo() async {
    if (_compileTimeToken.isNotEmpty) {
      final info = const MapboxTokenInfo(
        token: _compileTimeToken,
        source: 'dart-define MAPBOX_ACCESS_TOKEN',
      );
      _cachedToken = info.token;
      _cachedSource = info.source;
      return info;
    }

    if (_compileTimeLegacyToken.isNotEmpty) {
      final info = const MapboxTokenInfo(
        token: _compileTimeLegacyToken,
        source: 'dart-define MAPBOX_TOKEN (legacy)',
      );
      _cachedToken = info.token;
      _cachedSource = info.source;
      return info;
    }

    final webToken = readWebMapboxToken();
    if (webToken.isNotEmpty) {
      final info = MapboxTokenInfo(
        token: webToken,
        source: 'window.__MAPBOX_TOKEN__',
      );
      _cachedToken = info.token;
      _cachedSource = info.source;
      return info;
    }

    final prefs = await SharedPreferences.getInstance();

    final stored = (prefs.getString(_prefsKey) ?? '').trim();
    if (stored.isNotEmpty) {
      final info = MapboxTokenInfo(
        token: stored,
        source: 'SharedPreferences $_prefsKey',
      );
      _cachedToken = info.token;
      _cachedSource = info.source;
      return info;
    }

    final storedLegacy = (prefs.getString(_prefsLegacyKey) ?? '').trim();
    if (storedLegacy.isNotEmpty) {
      final info = MapboxTokenInfo(
        token: storedLegacy,
        source: 'SharedPreferences $_prefsLegacyKey (legacy)',
      );
      _cachedToken = info.token;
      _cachedSource = info.source;
      return info;
    }

    const info = MapboxTokenInfo(token: '', source: 'aucun');
    _cachedToken = info.token;
    _cachedSource = info.source;
    return info;
  }

  static Future<void> warmUp() async {
    await getTokenInfo();
  }

  static Future<String> getToken() async => (await getTokenInfo()).token;

  /// Résolution synchrone du token (utile pour des widgets/services qui ne
  /// veulent pas d'await).
  ///
  /// Ordre:
  /// 1) `override`
  /// 2) `--dart-define=MAPBOX_ACCESS_TOKEN=...`
  /// 3) `--dart-define=MAPBOX_TOKEN=...` (legacy)
  /// 4) cache (renseigné après [warmUp]/[getTokenInfo])
  static String getTokenSync({String? override}) {
    final overridden = (override ?? '').trim();
    if (overridden.isNotEmpty) return overridden;
    if (_compileTimeToken.isNotEmpty) return _compileTimeToken;
    if (_compileTimeLegacyToken.isNotEmpty) return _compileTimeLegacyToken;
    final webToken = readWebMapboxToken();
    if (webToken.isNotEmpty) return webToken;
    if (_cachedToken.isNotEmpty) return _cachedToken;
    return '';
  }

  /// Source sync correspondant à [getTokenSync].
  static String getTokenSourceSync({String? override}) {
    final overridden = (override ?? '').trim();
    if (overridden.isNotEmpty) return 'override param';
    if (_compileTimeToken.isNotEmpty) return 'dart-define MAPBOX_ACCESS_TOKEN';
    if (_compileTimeLegacyToken.isNotEmpty) {
      return 'dart-define MAPBOX_TOKEN (legacy)';
    }
    final webToken = readWebMapboxToken();
    if (webToken.isNotEmpty) return 'window.__MAPBOX_TOKEN__';
    return _cachedSource;
  }

  static Future<void> setToken(String token) async {
    final trimmed = token.trim();
    final prefs = await SharedPreferences.getInstance();
    if (trimmed.isEmpty) {
      await prefs.remove(_prefsKey);
      await prefs.remove(_prefsLegacyKey);

      _cachedToken = '';
      _cachedSource = 'aucun';
      return;
    }

    await prefs.setString(_prefsKey, trimmed);

    _cachedToken = trimmed;
    _cachedSource = 'SharedPreferences $_prefsKey';
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    await prefs.remove(_prefsLegacyKey);

    _cachedToken = '';
    _cachedSource = 'aucun';
  }
}
