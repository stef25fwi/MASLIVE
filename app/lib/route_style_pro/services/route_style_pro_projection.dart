import 'dart:convert';
import 'dart:ui' show Color;

import '../models/route_style_config.dart';

RouteStyleConfig? tryParseRouteStylePro(dynamic raw) {
  if (raw is Map) {
    try {
      return RouteStyleConfig.fromJson(
        Map<String, dynamic>.from(raw),
      ).validated();
    } catch (_) {
      return null;
    }
  }
  if (raw is String) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    try {
      final decoded = jsonDecode(s);
      if (decoded is Map) {
        return RouteStyleConfig.fromJson(
          Map<String, dynamic>.from(decoded),
        ).validated();
      }
    } catch (_) {
      return null;
    }
  }
  return null;
}

String colorToHexRgb(Color c) {
  final r = ((c.r * 255).round())
      .clamp(0, 255)
      .toRadixString(16)
      .padLeft(2, '0');
  final g = ((c.g * 255).round())
      .clamp(0, 255)
      .toRadixString(16)
      .padLeft(2, '0');
  final b = ((c.b * 255).round())
      .clamp(0, 255)
      .toRadixString(16)
      .padLeft(2, '0');
  return '#${r.toUpperCase()}${g.toUpperCase()}${b.toUpperCase()}';
}

/// Projection Style Pro -> style "legacy" consommé par l'app (polyline simple).
///
/// Si [base] est fourni, on préserve les clés existantes non gérées ici
/// (ex: showDirection/roadLike) et on ne surchage que ce qui est nécessaire.
Map<String, dynamic> projectProToLegacyStyle(
  RouteStyleConfig cfg, {
  Map<String, dynamic>? base,
}) {
  final out = <String, dynamic>{};
  if (base != null) out.addAll(base);

  // Compat minimale (utilisée par DefaultMap/Home, etc.)
  out['color'] = colorToHexRgb(cfg.mainColor);
  out['width'] = cfg.mainWidth * cfg.widthScale3d;

  // Heuristiques: si la config Pro a une "casing" significative, on active un rendu roadLike
  // (les consommateurs legacy n'ont pas de double-stroke explicite).
  final preservedRoadLike = (out['roadLike'] is bool)
      ? out['roadLike'] as bool
      : null;
  out['roadLike'] = preservedRoadLike ?? (cfg.casingWidth > cfg.mainWidth);

  out['shadow3d'] = cfg.shadowEnabled;

  // Animation direction (legacy) ~ pulse
  out['animateDirection'] = cfg.pulseEnabled;
  out['animationSpeed'] = (cfg.pulseSpeed / 25.0).clamp(0.5, 5.0);

  // showDirection: non défini en Style Pro -> on préserve le legacy si présent.
  return out;
}
