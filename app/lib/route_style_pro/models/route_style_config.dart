import 'dart:ui' show Color;

/// Version du schéma JSON stocké.
const int kRouteStyleSchemaVersion = 2;

/// Représentation simple (lat, lng) pour les services.
typedef LatLng = ({double lat, double lng});

enum RouteLineCap { round, butt, square }

enum RouteLineJoin { round, bevel, miter }

/// Configuration “Pro” de style d’un tracé automobile.
///
/// Objectifs:
/// - Sérialisation stable (toJson/fromJson)
/// - Validation/clamp des valeurs
/// - Compatible UI (sliders / toggles)
class RouteStyleConfig {
  final int schemaVersion;

  // A) Géométrie / comportement
  final bool carMode;
  final double snapToleranceMeters;
  final RouteLineCap lineCap;
  final RouteLineJoin lineJoin;
  /// 0..100 (0 = pas de simplification)
  final double simplifyPercent;

  // B) Waze-like (double couche)
  final double mainWidth;
  final double casingWidth;
  final Color mainColor;
  final Color casingColor;
  /// 0..1
  final double opacity;

    // B2) 3D (visuel)
    /// Multiplicateur appliqué aux largeurs (main/casing/glow) pour donner un rendu plus "épais".
    /// 0.5..3.0
    final double widthScale3d;

    /// Hauteur simulée au-dessus du "sol" (Mapbox): appliquée via line-translate (px).
    /// 0..40
    final double elevationPx;

  // C) Ombre / Glow
  final bool shadowEnabled;
  /// 0..1
  final double shadowOpacity;
  /// en pixels style (effet simple)
  final double shadowBlur;

  final bool glowEnabled;
  /// 0..1
  final double glowOpacity;
  /// blur style
  final double glowBlur;
  /// largeur additionnelle (px)
  final double glowWidth;

  // D) Dash / motifs / effets
  final bool dashEnabled;
  final double dashLength;
  final double dashGap;

  final bool pulseEnabled;
  /// 0..100 (UI)
  final double pulseSpeed;

  // E) Gradient + Rainbow animé
  final bool gradientEnabled;
  final bool rainbowEnabled;
  /// 0..1
  final double rainbowSaturation;
  /// 0..100
  final double rainbowSpeed;
  final bool rainbowReverse;

  // F) Traffic / segments (démo)
  final bool trafficDemoEnabled;

  // G) Route avancée
  final bool vanishingEnabled;
  /// 0..1
  final double vanishingProgress;

  final bool alternativesEnabled;

  const RouteStyleConfig({
    this.schemaVersion = kRouteStyleSchemaVersion,
    // A
    this.carMode = true,
    this.snapToleranceMeters = 35.0,
    this.lineCap = RouteLineCap.round,
    this.lineJoin = RouteLineJoin.round,
    this.simplifyPercent = 15.0,
    // B
    this.mainWidth = 7.0,
    this.casingWidth = 11.0,
    this.mainColor = const Color(0xFF1A73E8),
    this.casingColor = const Color(0xFF0B1B2B),
    this.opacity = 1.0,
    this.widthScale3d = 1.0,
    this.elevationPx = 0.0,
    // C
    this.shadowEnabled = true,
    this.shadowOpacity = 0.40,
    this.shadowBlur = 2.0,
    this.glowEnabled = true,
    this.glowOpacity = 0.55,
    this.glowBlur = 6.0,
    this.glowWidth = 6.0,
    // D
    this.dashEnabled = false,
    this.dashLength = 2.0,
    this.dashGap = 1.0,
    this.pulseEnabled = false,
    this.pulseSpeed = 35.0,
    // E
    this.gradientEnabled = false,
    this.rainbowEnabled = false,
    this.rainbowSaturation = 1.0,
    this.rainbowSpeed = 35.0,
    this.rainbowReverse = false,
    // F
    this.trafficDemoEnabled = false,
    // G
    this.vanishingEnabled = false,
    this.vanishingProgress = 0.0,
    this.alternativesEnabled = false,
  });

  RouteStyleConfig copyWith({
    int? schemaVersion,
    bool? carMode,
    double? snapToleranceMeters,
    RouteLineCap? lineCap,
    RouteLineJoin? lineJoin,
    double? simplifyPercent,
    double? mainWidth,
    double? casingWidth,
    Color? mainColor,
    Color? casingColor,
    double? opacity,
    double? widthScale3d,
    double? elevationPx,
    bool? shadowEnabled,
    double? shadowOpacity,
    double? shadowBlur,
    bool? glowEnabled,
    double? glowOpacity,
    double? glowBlur,
    double? glowWidth,
    bool? dashEnabled,
    double? dashLength,
    double? dashGap,
    bool? pulseEnabled,
    double? pulseSpeed,
    bool? gradientEnabled,
    bool? rainbowEnabled,
    double? rainbowSaturation,
    double? rainbowSpeed,
    bool? rainbowReverse,
    bool? trafficDemoEnabled,
    bool? vanishingEnabled,
    double? vanishingProgress,
    bool? alternativesEnabled,
  }) {
    return RouteStyleConfig(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      carMode: carMode ?? this.carMode,
      snapToleranceMeters: snapToleranceMeters ?? this.snapToleranceMeters,
      lineCap: lineCap ?? this.lineCap,
      lineJoin: lineJoin ?? this.lineJoin,
      simplifyPercent: simplifyPercent ?? this.simplifyPercent,
      mainWidth: mainWidth ?? this.mainWidth,
      casingWidth: casingWidth ?? this.casingWidth,
      mainColor: mainColor ?? this.mainColor,
      casingColor: casingColor ?? this.casingColor,
      opacity: opacity ?? this.opacity,
    widthScale3d: widthScale3d ?? this.widthScale3d,
    elevationPx: elevationPx ?? this.elevationPx,
      shadowEnabled: shadowEnabled ?? this.shadowEnabled,
      shadowOpacity: shadowOpacity ?? this.shadowOpacity,
      shadowBlur: shadowBlur ?? this.shadowBlur,
      glowEnabled: glowEnabled ?? this.glowEnabled,
      glowOpacity: glowOpacity ?? this.glowOpacity,
      glowBlur: glowBlur ?? this.glowBlur,
      glowWidth: glowWidth ?? this.glowWidth,
      dashEnabled: dashEnabled ?? this.dashEnabled,
      dashLength: dashLength ?? this.dashLength,
      dashGap: dashGap ?? this.dashGap,
      pulseEnabled: pulseEnabled ?? this.pulseEnabled,
      pulseSpeed: pulseSpeed ?? this.pulseSpeed,
      gradientEnabled: gradientEnabled ?? this.gradientEnabled,
      rainbowEnabled: rainbowEnabled ?? this.rainbowEnabled,
      rainbowSaturation: rainbowSaturation ?? this.rainbowSaturation,
      rainbowSpeed: rainbowSpeed ?? this.rainbowSpeed,
      rainbowReverse: rainbowReverse ?? this.rainbowReverse,
      trafficDemoEnabled: trafficDemoEnabled ?? this.trafficDemoEnabled,
      vanishingEnabled: vanishingEnabled ?? this.vanishingEnabled,
      vanishingProgress: vanishingProgress ?? this.vanishingProgress,
      alternativesEnabled: alternativesEnabled ?? this.alternativesEnabled,
    ).validated();
  }

  RouteStyleConfig validated() {
    double clamp(double v, double min, double max) =>
        v.isNaN ? min : (v < min ? min : (v > max ? max : v));

    return RouteStyleConfig(
      schemaVersion: schemaVersion,
      carMode: carMode,
      snapToleranceMeters: clamp(snapToleranceMeters, 5, 150),
      lineCap: lineCap,
      lineJoin: lineJoin,
      simplifyPercent: clamp(simplifyPercent, 0, 100),
      mainWidth: clamp(mainWidth, 2, 20),
            casingWidth: clamp(casingWidth, 0, 30),
      mainColor: mainColor,
      casingColor: casingColor,
      opacity: clamp(opacity, 0, 1),
            widthScale3d: clamp(widthScale3d, 0.5, 3.0),
            elevationPx: clamp(elevationPx, 0, 40),
      shadowEnabled: shadowEnabled,
      shadowOpacity: clamp(shadowOpacity, 0, 1),
      shadowBlur: clamp(shadowBlur, 0, 20),
      glowEnabled: glowEnabled,
      glowOpacity: clamp(glowOpacity, 0, 1),
      glowBlur: clamp(glowBlur, 0, 40),
      glowWidth: clamp(glowWidth, 0, 30),
      dashEnabled: dashEnabled,
      dashLength: clamp(dashLength, 0.5, 10),
      dashGap: clamp(dashGap, 0.5, 10),
      pulseEnabled: pulseEnabled,
      pulseSpeed: clamp(pulseSpeed, 0, 100),
      gradientEnabled: gradientEnabled,
      rainbowEnabled: rainbowEnabled,
      rainbowSaturation: clamp(rainbowSaturation, 0, 1),
      rainbowSpeed: clamp(rainbowSpeed, 0, 100),
      rainbowReverse: rainbowReverse,
      trafficDemoEnabled: trafficDemoEnabled,
      vanishingEnabled: vanishingEnabled,
      vanishingProgress: clamp(vanishingProgress, 0, 1),
      alternativesEnabled: alternativesEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'carMode': carMode,
      'snapToleranceMeters': snapToleranceMeters,
      'lineCap': lineCap.name,
      'lineJoin': lineJoin.name,
      'simplifyPercent': simplifyPercent,
      'mainWidth': mainWidth,
      'casingWidth': casingWidth,
      'mainColor': _colorToHexArgb(mainColor),
      'casingColor': _colorToHexArgb(casingColor),
      'opacity': opacity,
    'widthScale3d': widthScale3d,
    'elevationPx': elevationPx,
      'shadowEnabled': shadowEnabled,
      'shadowOpacity': shadowOpacity,
      'shadowBlur': shadowBlur,
      'glowEnabled': glowEnabled,
      'glowOpacity': glowOpacity,
      'glowBlur': glowBlur,
      'glowWidth': glowWidth,
      'dashEnabled': dashEnabled,
      'dashLength': dashLength,
      'dashGap': dashGap,
      'pulseEnabled': pulseEnabled,
      'pulseSpeed': pulseSpeed,
      'gradientEnabled': gradientEnabled,
      'rainbowEnabled': rainbowEnabled,
      'rainbowSaturation': rainbowSaturation,
      'rainbowSpeed': rainbowSpeed,
      'rainbowReverse': rainbowReverse,
      'trafficDemoEnabled': trafficDemoEnabled,
      'vanishingEnabled': vanishingEnabled,
      'vanishingProgress': vanishingProgress,
      'alternativesEnabled': alternativesEnabled,
    };
  }

  static RouteStyleConfig fromJson(Map<String, dynamic> json) {
    RouteLineCap parseCap(String? v) {
      return RouteLineCap.values
          .where((e) => e.name == v)
          .cast<RouteLineCap?>()
          .firstWhere((e) => e != null, orElse: () => RouteLineCap.round)!;
    }

    RouteLineJoin parseJoin(String? v) {
      return RouteLineJoin.values
          .where((e) => e.name == v)
          .cast<RouteLineJoin?>()
          .firstWhere((e) => e != null, orElse: () => RouteLineJoin.round)!;
    }

    final cfg = RouteStyleConfig(
      schemaVersion: (json['schemaVersion'] is num)
          ? (json['schemaVersion'] as num).toInt()
          : kRouteStyleSchemaVersion,
      carMode: json['carMode'] is bool ? json['carMode'] as bool : true,
      snapToleranceMeters: (json['snapToleranceMeters'] is num)
          ? (json['snapToleranceMeters'] as num).toDouble()
          : 35.0,
      lineCap: parseCap(json['lineCap'] as String?),
      lineJoin: parseJoin(json['lineJoin'] as String?),
      simplifyPercent: (json['simplifyPercent'] is num)
          ? (json['simplifyPercent'] as num).toDouble()
          : 15.0,
      mainWidth:
          (json['mainWidth'] is num) ? (json['mainWidth'] as num).toDouble() : 7.0,
      casingWidth: (json['casingWidth'] is num)
          ? (json['casingWidth'] as num).toDouble()
          : 11.0,
      mainColor: _colorFromHexArgb(json['mainColor'] as String?) ??
          const Color(0xFF1A73E8),
      casingColor: _colorFromHexArgb(json['casingColor'] as String?) ??
          const Color(0xFF0B1B2B),
      opacity:
          (json['opacity'] is num) ? (json['opacity'] as num).toDouble() : 1.0,
      widthScale3d: (json['widthScale3d'] is num)
          ? (json['widthScale3d'] as num).toDouble()
          : 1.0,
      elevationPx: (json['elevationPx'] is num)
          ? (json['elevationPx'] as num).toDouble()
          : 0.0,
      shadowEnabled:
          json['shadowEnabled'] is bool ? json['shadowEnabled'] as bool : true,
      shadowOpacity: (json['shadowOpacity'] is num)
          ? (json['shadowOpacity'] as num).toDouble()
          : 0.40,
      shadowBlur: (json['shadowBlur'] is num)
          ? (json['shadowBlur'] as num).toDouble()
          : 2.0,
      glowEnabled:
          json['glowEnabled'] is bool ? json['glowEnabled'] as bool : true,
      glowOpacity: (json['glowOpacity'] is num)
          ? (json['glowOpacity'] as num).toDouble()
          : 0.55,
      glowBlur:
          (json['glowBlur'] is num) ? (json['glowBlur'] as num).toDouble() : 6.0,
      glowWidth: (json['glowWidth'] is num)
          ? (json['glowWidth'] as num).toDouble()
          : 6.0,
      dashEnabled:
          json['dashEnabled'] is bool ? json['dashEnabled'] as bool : false,
      dashLength: (json['dashLength'] is num)
          ? (json['dashLength'] as num).toDouble()
          : 2.0,
      dashGap:
          (json['dashGap'] is num) ? (json['dashGap'] as num).toDouble() : 1.0,
      pulseEnabled:
          json['pulseEnabled'] is bool ? json['pulseEnabled'] as bool : false,
      pulseSpeed: (json['pulseSpeed'] is num)
          ? (json['pulseSpeed'] as num).toDouble()
          : 35.0,
      gradientEnabled: json['gradientEnabled'] is bool
          ? json['gradientEnabled'] as bool
          : false,
      rainbowEnabled:
          json['rainbowEnabled'] is bool ? json['rainbowEnabled'] as bool : false,
      rainbowSaturation: (json['rainbowSaturation'] is num)
          ? (json['rainbowSaturation'] as num).toDouble()
          : 1.0,
      rainbowSpeed: (json['rainbowSpeed'] is num)
          ? (json['rainbowSpeed'] as num).toDouble()
          : 35.0,
      rainbowReverse: json['rainbowReverse'] is bool
          ? json['rainbowReverse'] as bool
          : false,
      trafficDemoEnabled: json['trafficDemoEnabled'] is bool
          ? json['trafficDemoEnabled'] as bool
          : false,
      vanishingEnabled: json['vanishingEnabled'] is bool
          ? json['vanishingEnabled'] as bool
          : false,
      vanishingProgress: (json['vanishingProgress'] is num)
          ? (json['vanishingProgress'] as num).toDouble()
          : 0.0,
      alternativesEnabled: json['alternativesEnabled'] is bool
          ? json['alternativesEnabled'] as bool
          : false,
    );

    return cfg.validated();
  }

  static String _colorToHexArgb(Color c) {
    final a = ((c.a * 255).round()).clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final r = ((c.r * 255).round()).clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final g = ((c.g * 255).round()).clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final b = ((c.b * 255).round()).clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#${a.toUpperCase()}${r.toUpperCase()}${g.toUpperCase()}${b.toUpperCase()}';
  }

  static Color? _colorFromHexArgb(String? v) {
    if (v == null) return null;
    final m = RegExp(r'^#?([0-9a-fA-F]{8})$').firstMatch(v.trim());
    if (m == null) return null;
    final argb = int.parse(m.group(1)!, radix: 16);
    return Color(argb);
  }
}
