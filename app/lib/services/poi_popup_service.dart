import '../utils/poi_normalizer.dart';

class PoiPopupService {
  const PoiPopupService();

  static bool? parseBool(dynamic raw) {
    if (raw == null) return null;
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final s = raw.trim().toLowerCase();
      if (s == 'true' || s == '1' || s == 'yes' || s == 'y') return true;
      if (s == 'false' || s == '0' || s == 'no' || s == 'n') return false;
    }
    return null;
  }

  static bool defaultPopupEnabledForType(PoiType type) {
    return switch (type) {
      PoiType.wc => false,
      _ => true,
    };
  }

  /// Résout si un POI est "cliquable" pour ouvrir la polaroid.
  ///
  /// Règles:
  /// - Lit `popupEnabled` d'abord dans `meta['popupEnabled']`, sinon `rootPopupEnabled`.
  /// - Supporte bool/num/string.
  /// - Fallback: WC=false, autres=true.
  /// - Optionnel: si `requireImage==true` et `hasImage==false` => false.
  static bool isPopupEnabled({
    required String? type,
    Map<String, dynamic>? meta,
    dynamic rootPopupEnabled,
    bool requireImage = false,
    bool hasImage = true,
  }) {
    final poiType = PoiNormalizer.normalizePoiType(type);
    final raw = (meta ?? const <String, dynamic>{})['popupEnabled'] ??
        rootPopupEnabled;

    final parsed = parseBool(raw);
    final resolved = parsed ?? defaultPopupEnabledForType(poiType);

    if (requireImage && !hasImage) return false;
    return resolved;
  }
}
