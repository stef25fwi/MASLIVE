import 'package:flutter/material.dart';
import 'package:masslive/ui_kit/tokens/maslive_tokens.dart';

@immutable
class MasLivePoiStyle {
  final double circleRadius;
  final Color circleColor;
  final double circleStrokeWidth;
  final Color circleStrokeColor;

  const MasLivePoiStyle({
    this.circleRadius = 7.0,
    this.circleColor = MasliveTokens.primary,
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
      circleColor: MasliveTokens.primary,
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
      circleColor: MasliveTokens.primary,
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

/// Clé `metadata` utilisée pour persister le pictogramme choisi par
/// l'utilisateur dans la page d'édition d'un POI.
///
/// Exemple: `{ "picto": "food" }`
const String kMasLivePoiPictoKey = 'picto';

/// Un pictogramme sélectionnable dans la galerie de la page d'édition POI.
///
/// Basé sur les icônes Material (aucun asset requis), ce qui garantit un
/// rendu net et cohérent quelle que soit la plateforme.
@immutable
class MasLivePoiPicto {
  final String id;
  final String label;
  final IconData icon;
  final Color color;

  const MasLivePoiPicto({
    required this.id,
    required this.label,
    required this.icon,
    this.color = MasliveTokens.primary,
  });
}

/// Catalogue des pictogrammes proposés dans la galerie.
///
/// Important: les `id` sont persistés dans Firestore via
/// `MarketMapPOI.metadata['picto']`. Ne pas renommer un `id` existant.
const List<MasLivePoiPicto> kMasLivePoiPictos = [
  MasLivePoiPicto(
    id: 'food',
    label: 'Food',
    icon: Icons.fastfood_rounded,
    color: Color(0xFFEF6C00),
  ),
  MasLivePoiPicto(
    id: 'wc',
    label: 'WC',
    icon: Icons.wc_rounded,
    color: Color(0xFF1565C0),
  ),
  MasLivePoiPicto(
    id: 'glace',
    label: 'Glace',
    icon: Icons.icecream_rounded,
    color: Color(0xFFEC407A),
  ),
  MasLivePoiPicto(
    id: 'restaurant',
    label: 'Restaurant',
    icon: Icons.restaurant_rounded,
    color: Color(0xFF6D4C41),
  ),
  MasLivePoiPicto(
    id: 'police',
    label: 'Police',
    icon: Icons.local_police_rounded,
    color: Color(0xFF283593),
  ),
  MasLivePoiPicto(
    id: 'sante',
    label: 'Santé',
    icon: Icons.local_hospital_rounded,
    color: Color(0xFFD32F2F),
  ),
  MasLivePoiPicto(
    id: 'info_tourisme',
    label: 'Office tourisme',
    icon: Icons.info_rounded,
    color: Color(0xFF00838F),
  ),
  MasLivePoiPicto(
    id: 'lieu_touristique',
    label: 'À visiter',
    icon: Icons.attractions_rounded,
    color: Color(0xFF2E7D32),
  ),
  MasLivePoiPicto(
    id: 'musee',
    label: 'Musée',
    icon: Icons.museum_rounded,
    color: Color(0xFF5D4037),
  ),
];

/// Retourne le picto correspondant à [id], ou `null` si inconnu/vide.
MasLivePoiPicto? masLivePoiPictoById(String? id) {
  final value = (id ?? '').trim();
  if (value.isEmpty) return null;
  for (final picto in kMasLivePoiPictos) {
    if (picto.id == value) return picto;
  }
  return null;
}

String masLiveColorToCssHex(Color color) {
  int to8(double v) => (v * 255.0).round().clamp(0, 255);

  final r = to8(color.r).toRadixString(16).padLeft(2, '0');
  final g = to8(color.g).toRadixString(16).padLeft(2, '0');
  final b = to8(color.b).toRadixString(16).padLeft(2, '0');
  return '#$r$g$b';
}
