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
  // --- Sélection recommandée (choix par défaut) ---
  MasLivePoiPicto(
    id: 'food',
    label: 'Food',
    icon: Icons.lunch_dining_outlined,
    color: Color(0xFFEF6C00),
  ),
  MasLivePoiPicto(
    id: 'wc',
    label: 'WC',
    icon: Icons.wc_outlined,
    color: Color(0xFF1565C0),
  ),
  MasLivePoiPicto(
    id: 'glace',
    label: 'Glace',
    icon: Icons.icecream_outlined,
    color: Color(0xFFEC407A),
  ),
  MasLivePoiPicto(
    id: 'restaurant',
    label: 'Restaurant',
    icon: Icons.restaurant_outlined,
    color: Color(0xFF6D4C41),
  ),
  MasLivePoiPicto(
    id: 'police',
    label: 'Police',
    icon: Icons.local_police_outlined,
    color: Color(0xFF283593),
  ),
  MasLivePoiPicto(
    id: 'sante',
    label: 'Santé',
    icon: Icons.local_hospital_outlined,
    color: Color(0xFFD32F2F),
  ),
  MasLivePoiPicto(
    id: 'info_tourisme',
    label: 'Office tourisme',
    icon: Icons.info_outlined,
    color: Color(0xFF00838F),
  ),
  MasLivePoiPicto(
    id: 'lieu_touristique',
    label: 'À visiter',
    icon: Icons.photo_camera_outlined,
    color: Color(0xFF2E7D32),
  ),
  MasLivePoiPicto(
    id: 'musee',
    label: 'Musée',
    icon: Icons.museum_outlined,
    color: Color(0xFF5D4037),
  ),

  // --- Série étendue (mêmes pictos outlined) ---
  MasLivePoiPicto(
    id: 'bar',
    label: 'Bar',
    icon: Icons.local_bar_outlined,
    color: Color(0xFFAD1457),
  ),
  MasLivePoiPicto(
    id: 'cafe',
    label: 'Café',
    icon: Icons.local_cafe_outlined,
    color: Color(0xFF6D4C41),
  ),
  MasLivePoiPicto(
    id: 'boisson',
    label: 'Boisson / eau',
    icon: Icons.local_drink_outlined,
    color: Color(0xFF0277BD),
  ),
  MasLivePoiPicto(
    id: 'hotel',
    label: 'Hôtel',
    icon: Icons.hotel_outlined,
    color: Color(0xFF4527A0),
  ),
  MasLivePoiPicto(
    id: 'parking',
    label: 'Parking',
    icon: Icons.local_parking_outlined,
    color: Color(0xFF1565C0),
  ),
  MasLivePoiPicto(
    id: 'plage',
    label: 'Plage',
    icon: Icons.beach_access_outlined,
    color: Color(0xFF00838F),
  ),
  MasLivePoiPicto(
    id: 'pharmacie',
    label: 'Pharmacie',
    icon: Icons.local_pharmacy_outlined,
    color: Color(0xFF2E7D32),
  ),
  MasLivePoiPicto(
    id: 'atm',
    label: 'Distributeur',
    icon: Icons.local_atm_outlined,
    color: Color(0xFF00695C),
  ),
  MasLivePoiPicto(
    id: 'essence',
    label: 'Carburant',
    icon: Icons.local_gas_station_outlined,
    color: Color(0xFF37474F),
  ),
  MasLivePoiPicto(
    id: 'boutique',
    label: 'Boutique',
    icon: Icons.storefront_outlined,
    color: Color(0xFF8B5CF6),
  ),
  MasLivePoiPicto(
    id: 'shopping',
    label: 'Shopping',
    icon: Icons.shopping_bag_outlined,
    color: Color(0xFF6A1B9A),
  ),
  MasLivePoiPicto(
    id: 'marche',
    label: 'Marché',
    icon: Icons.local_mall_outlined,
    color: Color(0xFFAD1457),
  ),
  MasLivePoiPicto(
    id: 'festival',
    label: 'Festival',
    icon: Icons.festival_outlined,
    color: Color(0xFFC2185B),
  ),
  MasLivePoiPicto(
    id: 'musique',
    label: 'Scène / musique',
    icon: Icons.music_note_outlined,
    color: Color(0xFF6200EA),
  ),
  MasLivePoiPicto(
    id: 'spectacle',
    label: 'Spectacle',
    icon: Icons.theater_comedy_outlined,
    color: Color(0xFF4A148C),
  ),
  MasLivePoiPicto(
    id: 'fete',
    label: 'Fête',
    icon: Icons.celebration_outlined,
    color: Color(0xFFD81B60),
  ),
  MasLivePoiPicto(
    id: 'monument',
    label: 'Monument',
    icon: Icons.account_balance_outlined,
    color: Color(0xFF5D4037),
  ),
  MasLivePoiPicto(
    id: 'eglise',
    label: 'Église',
    icon: Icons.church_outlined,
    color: Color(0xFF455A64),
  ),
  MasLivePoiPicto(
    id: 'taxi',
    label: 'Taxi',
    icon: Icons.local_taxi_outlined,
    color: Color(0xFFF57F17),
  ),
  MasLivePoiPicto(
    id: 'bus',
    label: 'Bus',
    icon: Icons.directions_bus_outlined,
    color: Color(0xFF1565C0),
  ),
  MasLivePoiPicto(
    id: 'bateau',
    label: 'Bateau',
    icon: Icons.directions_boat_outlined,
    color: Color(0xFF0277BD),
  ),
  MasLivePoiPicto(
    id: 'rencontre',
    label: 'Point rencontre',
    icon: Icons.groups_outlined,
    color: Color(0xFF00838F),
  ),
  MasLivePoiPicto(
    id: 'secours',
    label: 'Secours',
    icon: Icons.medical_services_outlined,
    color: Color(0xFFD32F2F),
  ),
  MasLivePoiPicto(
    id: 'parc',
    label: 'Parc',
    icon: Icons.park_outlined,
    color: Color(0xFF2E7D32),
  ),
  MasLivePoiPicto(
    id: 'sport',
    label: 'Sport',
    icon: Icons.sports_soccer_outlined,
    color: Color(0xFF33691E),
  ),
  MasLivePoiPicto(
    id: 'stade',
    label: 'Stade',
    icon: Icons.stadium_outlined,
    color: Color(0xFF283593),
  ),
  MasLivePoiPicto(
    id: 'nightlife',
    label: 'Vie nocturne',
    icon: Icons.nightlife_outlined,
    color: Color(0xFF6A1B9A),
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
