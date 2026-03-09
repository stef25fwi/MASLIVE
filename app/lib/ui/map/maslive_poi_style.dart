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
const String kMasLivePoiAppearanceIconPointId = 'icon_point';

const Set<String> kMasLivePoiAppearanceIconPointAliases = {
  'icon_point',
  'icon-point.webp',
  'icon-point.wbp',
  'point.webp',
  'point.wbp',
  'point_webp',
  'point_wbp',
  'point',
};

String normalizeMasLivePoiAppearanceId(String? rawId) {
  final id = (rawId ?? '').trim();
  if (id.isEmpty) return '';
  if (kMasLivePoiAppearanceIconPointAliases.contains(id)) {
    return kMasLivePoiAppearanceIconPointId;
  }
  return id;
}

bool isMasLivePoiIconPointAppearance(String? rawId) {
  final id = (rawId ?? '').trim();
  if (id.isEmpty) return false;
  return kMasLivePoiAppearanceIconPointAliases.contains(id);
}

@immutable
class MasLivePoiAppearancePreset {
  final String id;
  final String label;
  final MasLivePoiStyle style;
  final String? assetPath;
  final String? mapIconId;
  final double iconSize;

  const MasLivePoiAppearancePreset({
    required this.id,
    required this.label,
    required this.style,
    this.assetPath,
    this.mapIconId,
    this.iconSize = 1.0,
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
  MasLivePoiAppearancePreset(
    id: 'icon_point',
    label: 'Icône point',
    style: MasLivePoiStyle(
      circleRadius: 7.0,
      circleColor: Color(0xFF0A84FF),
      circleStrokeWidth: 2.0,
      circleStrokeColor: Color(0xFFFFFFFF),
    ),
    assetPath: 'assets/images/icon-point.webp',
    mapIconId: 'maslive_poi_icon_point',
    iconSize: 0.55,
  ),
];

Widget buildMasLivePoiAppearanceMenuItem(
  MasLivePoiAppearancePreset preset, {
  double previewSize = 22,
}) {
  final preview = preset.assetPath != null
      ? ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.asset(
            preset.assetPath!,
            width: previewSize,
            height: previewSize,
            fit: BoxFit.contain,
          ),
        )
      : Container(
          width: previewSize,
          height: previewSize,
          decoration: BoxDecoration(
            color: preset.style.circleColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: preset.style.circleStrokeColor,
              width: preset.style.circleStrokeWidth,
            ),
          ),
        );

  return Row(
    children: [
      preview,
      const SizedBox(width: 10),
      Expanded(child: Text(preset.label)),
    ],
  );
}

String masLiveColorToCssHex(Color color) {
  int to8(double v) => (v * 255.0).round().clamp(0, 255);

  final r = to8(color.r).toRadixString(16).padLeft(2, '0');
  final g = to8(color.g).toRadixString(16).padLeft(2, '0');
  final b = to8(color.b).toRadixString(16).padLeft(2, '0');
  return '#$r$g$b';
}
