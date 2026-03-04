import 'package:flutter/material.dart';

@immutable
class MasLivePoiStyle {
  final double circleRadius;
  final Color circleColor;
  final double circleStrokeWidth;
  final Color circleStrokeColor;

  const MasLivePoiStyle({
    this.circleRadius = 7.0,
    this.circleColor = const Color(0xFF0A84FF),
    this.circleStrokeWidth = 2.0,
    this.circleStrokeColor = const Color(0xFFFFFFFF),
  });
}

/// Clé `metadata` utilisée pour persister le preset d'apparence d'un POI.
///
/// Exemple: `{ "appearance": "blue_dot" }`
const String kMasLivePoiAppearanceKey = 'appearance';

@immutable
class MasLivePoiAppearancePreset {
  final String id;
  final String label;
  final MasLivePoiStyle style;

  const MasLivePoiAppearancePreset({
    required this.id,
    required this.label,
    required this.style,
  });
}

/// Liste de presets extensible (ajout progressif de styles).
///
/// Important: les `id` sont persistés dans Firestore via `MarketMapPOI.metadata`.
const List<MasLivePoiAppearancePreset> kMasLivePoiAppearancePresets = [
  MasLivePoiAppearancePreset(
    id: 'blue_dot',
    label: 'Rond bleu',
    style: MasLivePoiStyle(
      circleRadius: 7.0,
      circleColor: Color(0xFF0A84FF),
      circleStrokeWidth: 2.0,
      circleStrokeColor: Color(0xFFFFFFFF),
    ),
  ),
  MasLivePoiAppearancePreset(
    id: 'red_pin',
    label: 'Pin rouge',
    style: MasLivePoiStyle(
      circleRadius: 10.0,
      circleColor: Color(0xFFFF3B30),
      circleStrokeWidth: 3.0,
      circleStrokeColor: Color(0xFFFFFFFF),
    ),
  ),
];

String masLiveColorToCssHex(Color color) {
  int to8(double v) => (v * 255.0).round().clamp(0, 255);

  final r = to8(color.r).toRadixString(16).padLeft(2, '0');
  final g = to8(color.g).toRadixString(16).padLeft(2, '0');
  final b = to8(color.b).toRadixString(16).padLeft(2, '0');
  return '#$r$g$b';
}
