import 'dart:ui' show Color;

import 'route_style_config.dart';

class RouteStylePreset {
  final String id;
  final String label;
  final RouteStyleConfig config;

  const RouteStylePreset({
    required this.id,
    required this.label,
    required this.config,
  });
}

class RouteStylePresets {
  // Presets demandés (Wizard circuit / étape Style Pro)
  static const RouteStylePreset premium3d = RouteStylePreset(
    id: 'premium',
    label: 'Premium 3D',
    config: RouteStyleConfig(
      carMode: true,
      // Ruban premium épais, lisible, avec vrai relief 3D.
      mainWidth: 13.0,
      casingWidth: 20.0,
      mainColor: Color(0xFF12E3A7),
      casingColor: Color(0xFF041E18),
      opacity: 1.0,
      widthScale3d: 1.34,
      thickness3d: 1.34,
      casingThickness3d: 1.26,
      elevationPx: 10.0,
      sidesEnabled: true,
      sidesIntensity: 0.64,

      shadowEnabled: true,
      shadowOpacity: 0.46,
      shadowBlur: 4.0,

      glowEnabled: true,
      glowOpacity: 0.44,
      glowBlur: 12.0,
      glowWidth: 7.0,

      buildings3dEnabled: true,
      buildingOpacity: 0.88,
      routeAlwaysOnTop: true,
      parkColor: Color(0xFF3F8F52),

      dashEnabled: false,
      pulseEnabled: false,

      rainbowEnabled: false,
      trafficDemoEnabled: false,
      vanishingEnabled: false,
    ),
  );

  static const RouteStylePreset carnivalMaslive = RouteStylePreset(
    id: 'carnival',
    label: 'Carnaval MASLIVE',
    config: RouteStyleConfig(
      carMode: true,
      // Néon festif très assumé, plus animé que Premium.
      mainWidth: 15.0,
      casingWidth: 12.0,
      mainColor: Color(0xFFFF4FD8),
      casingColor: Color(0xFF240033),
      opacity: 1.0,
      widthScale3d: 1.22,
      thickness3d: 1.18,
      casingThickness3d: 1.14,
      elevationPx: 6.0,
      sidesEnabled: true,
      sidesIntensity: 0.48,

      shadowEnabled: true,
      shadowOpacity: 0.34,
      shadowBlur: 4.0,

      glowEnabled: true,
      glowOpacity: 0.82,
      glowBlur: 18.0,
      glowWidth: 14.0,

      gradientEnabled: true,
      rainbowEnabled: true,
      rainbowSaturation: 1.0,
      rainbowSpeed: 82.0,
      rainbowReverse: false,
      pulseEnabled: true,
      pulseSpeed: 64.0,
      buildingOpacity: 0.74,
      parkColor: Color(0xFF00B894),

      dashEnabled: false,
      routeAlwaysOnTop: true,
    ),
  );

  static const RouteStylePreset collectivite = RouteStylePreset(
    id: 'collectivite',
    label: 'Collectivité',
    config: RouteStyleConfig(
      carMode: true,
      // Tracé institutionnel sobre, discipliné et très lisible.
      fitToRoadWidth: true,
      mainWidth: 9.0,
      casingWidth: 4.0,
      mainColor: Color(0xFF1E5BFF),
      casingColor: Color(0xFF0A275C),
      opacity: 0.96,
      widthScale3d: 0.92,
      thickness3d: 0.96,
      elevationPx: 1.0,

      shadowEnabled: true,
      shadowOpacity: 0.14,
      shadowBlur: 1.0,

      glowEnabled: true,
      glowOpacity: 0.12,
      glowBlur: 3.0,
      glowWidth: 2.0,

      buildings3dEnabled: true,
      buildingOpacity: 0.48,
      routeAlwaysOnTop: true,
      parkColor: Color(0xFF739E68),

      dashEnabled: false,
      pulseEnabled: false,
      rainbowEnabled: false,
      trafficDemoEnabled: false,
    ),
  );

  static const RouteStylePreset wazeLike = RouteStylePreset(
    id: 'waze',
    label: 'Waze-like',
    config: RouteStyleConfig(
      carMode: true,
      mainWidth: 7.0,
      casingWidth: 11.0,
      mainColor: Color(0xFF1A73E8),
      casingColor: Color(0xFF0B1B2B),
      glowEnabled: true,
      glowOpacity: 0.55,
      glowBlur: 6.0,
      glowWidth: 6.0,
      shadowEnabled: true,
      shadowOpacity: 0.40,
      shadowBlur: 2.0,
      dashEnabled: false,
      gradientEnabled: false,
      rainbowEnabled: false,
    ),
  );

  static const RouteStylePreset night = RouteStylePreset(
    id: 'night',
    label: 'Night',
    config: RouteStyleConfig(
      carMode: true,
      mainWidth: 7.0,
      casingWidth: 12.0,
      mainColor: Color(0xFF66D1FF),
      casingColor: Color(0xFF061018),
      glowEnabled: true,
      glowOpacity: 0.70,
      glowBlur: 10.0,
      glowWidth: 8.0,
      shadowEnabled: false,
    ),
  );

  static const RouteStylePreset minimal = RouteStylePreset(
    id: 'minimal',
    label: 'Minimal',
    config: RouteStyleConfig(
      carMode: false,
      mainWidth: 5.0,
      casingWidth: 0.0,
      mainColor: Color(0xFF1A73E8),
      casingColor: Color(0x00000000),
      glowEnabled: false,
      shadowEnabled: false,
      dashEnabled: false,
      opacity: 0.95,
    ),
  );

  static const RouteStylePreset neon = RouteStylePreset(
    id: 'neon',
    label: 'Neon',
    config: RouteStyleConfig(
      carMode: true,
      mainWidth: 7.0,
      casingWidth: 12.0,
      mainColor: Color(0xFF00FFB3),
      casingColor: Color(0xFF0A0F14),
      glowEnabled: true,
      glowOpacity: 0.85,
      glowBlur: 14.0,
      glowWidth: 12.0,
      shadowEnabled: false,
    ),
  );

  static const RouteStylePreset rainbow = RouteStylePreset(
    id: 'rainbow',
    label: 'Rainbow',
    config: RouteStyleConfig(
      carMode: true,
      mainWidth: 7.0,
      casingWidth: 12.0,
      mainColor: Color(0xFF1A73E8),
      casingColor: Color(0xFF0B1B2B),
      glowEnabled: true,
      glowOpacity: 0.45,
      glowBlur: 10.0,
      glowWidth: 8.0,
      gradientEnabled: true,
      rainbowEnabled: true,
      rainbowSpeed: 55.0,
    ),
  );

  static const List<RouteStylePreset> all = [
    premium3d,
    carnivalMaslive,
    collectivite,
    wazeLike,
    night,
    rainbow,
    neon,
    minimal,
  ];

  static RouteStylePreset? byId(String? id) {
    if (id == null || id.trim().isEmpty) return null;
    final needle = id.trim();
    for (final p in all) {
      if (p.id == needle) return p;
    }
    return null;
  }
}
