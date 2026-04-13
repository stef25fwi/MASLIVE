import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/mapbox_token_web_stub.dart'
  if (dart.library.html) '../utils/mapbox_token_web_web.dart';

class MapboxTokenInfo {
  final String token;
  final String source;
  final bool isValidFormat;
  final bool isPublicPkToken;
  final bool isSecretSkToken;
  final bool isPlaceholder;
  final String debugLabel;
  final String? errorCode;
  final String? errorMessage;

  const MapboxTokenInfo({
    required this.token,
    required this.source,
    required this.isValidFormat,
    required this.isPublicPkToken,
    required this.isSecretSkToken,
    required this.isPlaceholder,
    required this.debugLabel,
    this.errorCode,
    this.errorMessage,
  });

  const MapboxTokenInfo.empty()
    : token = '',
      source = 'aucun',
      isValidFormat = false,
      isPublicPkToken = false,
      isSecretSkToken = false,
      isPlaceholder = false,
      debugLabel = 'len=0;pk=false;sk=false;placeholder=false',
      errorCode = 'TOKEN_MISSING',
      errorMessage = 'Token Mapbox manquant.';
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

  static MapboxTokenInfo _cachedInfo = const MapboxTokenInfo.empty();

  static String get cachedToken => _cachedInfo.token;
  static String get cachedSource => _cachedInfo.source;
  static MapboxTokenInfo get cachedInfo => _cachedInfo;

  static const String _compileTimeToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
  );
  static const String _compileTimePublicToken = String.fromEnvironment(
    'MAPBOX_PUBLIC_TOKEN',
  );
  static const String _compileTimeLegacyToken = String.fromEnvironment(
    'MAPBOX_TOKEN',
  );

  static bool _isPlaceholderToken(String token) {
    final t = token.trim();
    if (t.isEmpty) return false;
    return t == 'YOUR_MAPBOX_TOKEN' ||
        t == 'TON_NOUVEAU_TOKEN_MAPBOX' ||
        t == 'pk.VOTRE_VRAI_TOKEN_MAPBOX' ||
        t.contains('VOTRE_VRAI_TOKEN') ||
        t.contains('TON_TOKEN') ||
        t.contains('NOUVEAU_TOKEN');
  }

  static MapboxTokenInfo _buildInfo({
    required String rawToken,
    required String source,
  }) {
    final token = rawToken.trim();
    final isPk = token.startsWith('pk.') || token.startsWith('pk_');
    final isSk = token.startsWith('sk.') || token.startsWith('sk_');
    final isPlaceholder = _isPlaceholderToken(token);

    String? errorCode;
    String? errorMessage;
    var isValid = true;

    if (token.isEmpty) {
      isValid = false;
      errorCode = 'TOKEN_MISSING';
      errorMessage = 'Token Mapbox manquant.';
    } else if (isPlaceholder) {
      isValid = false;
      errorCode = 'TOKEN_PLACEHOLDER';
      errorMessage =
          'Token Mapbox placeholder détecté. Fournis un vrai token public pk.*.';
    } else if (kIsWeb && (isSk || !isPk)) {
      isValid = false;
      errorCode = 'TOKEN_NOT_PUBLIC';
      errorMessage =
          'Sur le web, un token public Mapbox pk.* est requis (sk.* refusé).';
    }

    final safeToken = isValid ? token : '';
    return MapboxTokenInfo(
      token: safeToken,
      source: source,
      isValidFormat: isValid,
      isPublicPkToken: isPk,
      isSecretSkToken: isSk,
      isPlaceholder: isPlaceholder,
      debugLabel:
          'len=${token.length};pk=$isPk;sk=$isSk;placeholder=$isPlaceholder',
      errorCode: errorCode,
      errorMessage: errorMessage,
    );
  }

  static MapboxTokenInfo _remember(MapboxTokenInfo info) {
    _cachedInfo = info;
    if (kIsWeb) {
      if (info.token.isNotEmpty) {
        // Compat JS legacy: expose seulement le token validé.
        writeWebMapboxToken(info.token);
      } else {
        clearWebMapboxToken();
      }
    }
    return info;
  }

  static Future<MapboxTokenInfo> getTokenInfo() async {
    if (_compileTimeToken.isNotEmpty) {
      return _remember(
        _buildInfo(
          rawToken: _compileTimeToken,
          source: 'dart-define MAPBOX_ACCESS_TOKEN',
        ),
      );
    }

    if (_compileTimePublicToken.isNotEmpty) {
      return _remember(
        _buildInfo(
          rawToken: _compileTimePublicToken,
          source: 'dart-define MAPBOX_PUBLIC_TOKEN',
        ),
      );
    }

    if (_compileTimeLegacyToken.isNotEmpty) {
      return _remember(
        _buildInfo(
          rawToken: _compileTimeLegacyToken,
          source: 'dart-define MAPBOX_TOKEN (legacy)',
        ),
      );
    }

    final prefs = await SharedPreferences.getInstance();

    final stored = (prefs.getString(_prefsKey) ?? '').trim();
    if (stored.isNotEmpty) {
      return _remember(
        _buildInfo(
          rawToken: stored,
          source: 'SharedPreferences $_prefsKey',
        ),
      );
    }

    final storedLegacy = (prefs.getString(_prefsLegacyKey) ?? '').trim();
    if (storedLegacy.isNotEmpty) {
      return _remember(
        _buildInfo(
          rawToken: storedLegacy,
          source: 'SharedPreferences $_prefsLegacyKey (legacy)',
        ),
      );
    }

    // Fallback legacy web.
    final webToken = readWebMapboxToken();
    if (webToken.isNotEmpty) {
      return _remember(
        _buildInfo(
          rawToken: webToken,
          source: 'window.__MAPBOX_TOKEN__ (fallback)',
        ),
      );
    }

    // Fallback Firestore: config/mapbox -> champ 'accessToken'.
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('mapbox')
          .get()
          .timeout(const Duration(seconds: 5));
      final firestoreToken =
          ((doc.data()?['accessToken'] ?? '') as String).trim();
      if (firestoreToken.isNotEmpty) {
        debugPrint('[MAPBOX][TOKEN] Firestore fallback len=${firestoreToken.length}');
        // Persist locally for next cold start.
        final p = await SharedPreferences.getInstance();
        await p.setString(_prefsKey, firestoreToken);
        return _remember(
          _buildInfo(
            rawToken: firestoreToken,
            source: 'Firestore config/mapbox',
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ MapboxTokenService: Firestore fallback failed: $e');
    }

    return _remember(const MapboxTokenInfo.empty());
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
  /// 3) `--dart-define=MAPBOX_PUBLIC_TOKEN=...`
  /// 4) `--dart-define=MAPBOX_TOKEN=...` (legacy)
  /// 5) cache (renseigné après [warmUp]/[getTokenInfo])
  /// 6) `window.__MAPBOX_TOKEN__` (fallback legacy web)
  ///
  /// Toute valeur invalide (placeholder, sk.* ou non-pk sur web) est refusée.
  static MapboxTokenInfo getTokenInfoSync({String? override}) {
    final overridden = (override ?? '').trim();
    if (overridden.isNotEmpty) {
      return _buildInfo(rawToken: overridden, source: 'override param');
    }
    if (_compileTimeToken.isNotEmpty) {
      return _buildInfo(
        rawToken: _compileTimeToken,
        source: 'dart-define MAPBOX_ACCESS_TOKEN',
      );
    }
    if (_compileTimePublicToken.isNotEmpty) {
      return _buildInfo(
        rawToken: _compileTimePublicToken,
        source: 'dart-define MAPBOX_PUBLIC_TOKEN',
      );
    }
    if (_compileTimeLegacyToken.isNotEmpty) {
      return _buildInfo(
        rawToken: _compileTimeLegacyToken,
        source: 'dart-define MAPBOX_TOKEN (legacy)',
      );
    }
    if (_cachedInfo.source != 'aucun' || _cachedInfo.token.isNotEmpty) {
      return _cachedInfo;
    }
    final webToken = readWebMapboxToken();
    if (webToken.isNotEmpty) {
      return _buildInfo(
        rawToken: webToken,
        source: 'window.__MAPBOX_TOKEN__ (fallback)',
      );
    }
    return const MapboxTokenInfo.empty();
  }

  static String getTokenSync({String? override}) {
    return getTokenInfoSync(override: override).token;
  }

  /// Source sync correspondant à [getTokenSync].
  static String getTokenSourceSync({String? override}) {
    return getTokenInfoSync(override: override).source;
  }

  static Future<void> setToken(String token) async {
    final trimmed = token.trim();
    final prefs = await SharedPreferences.getInstance();
    if (trimmed.isEmpty) {
      await prefs.remove(_prefsKey);
      await prefs.remove(_prefsLegacyKey);

      _cachedInfo = const MapboxTokenInfo.empty();

      clearWebMapboxToken();
      return;
    }

    await prefs.setString(_prefsKey, trimmed);

    _cachedInfo = _buildInfo(
      rawToken: trimmed,
      source: 'SharedPreferences $_prefsKey',
    );
    if (_cachedInfo.token.isNotEmpty) {
      writeWebMapboxToken(_cachedInfo.token);
    } else {
      clearWebMapboxToken();
    }
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    await prefs.remove(_prefsLegacyKey);

    _cachedInfo = const MapboxTokenInfo.empty();

    clearWebMapboxToken();
  }
}
