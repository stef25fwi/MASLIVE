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
