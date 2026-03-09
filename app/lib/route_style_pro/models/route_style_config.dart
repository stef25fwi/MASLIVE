import 'dart:ui' show Color;

/// Version du schéma JSON stocké.
const int kRouteStyleSchemaVersion = 8;

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
  static const double kRoadWidthModeMaxMainWidth = 5.0;
  static const double kRoadWidthModeMaxWidthScale3d = 0.85;
  static const double kRoadWidthModeMaxCasingExtra = 0.9;

  final int schemaVersion;

  // A) Géométrie / comportement
  final bool carMode;
    final bool freeDrawEnabled;
  final bool fitToRoadWidth;
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

  /// Si true, la couleur du casing est un dégradé "rainbow" par segments
  /// (au lieu d'une couleur fixe).
  final bool casingRainbowEnabled;

  /// 0..1
  final double opacity;

  // B2) 3D (visuel)
  /// Multiplicateur appliqué aux largeurs (main/casing/glow) pour donner un rendu plus "épais".
  /// 0.5..3.0
  final double widthScale3d;

  /// Facteur de relief (ruban 3D): accentue surtout l'ombre (largeur/blur/offset)
  /// sans remplacer le réglage de "Largeur".
  /// 0.6..1.8
  final double thickness3d;

  /// Multiplicateur spécifique au casing dans le rendu 3D.
  /// Permet d'épaissir ou d'affiner le contour indépendamment de la largeur 3D globale.
  /// 0.5..2.5
  final double casingThickness3d;

  /// Hauteur simulée au-dessus du "sol" (Mapbox): appliquée via line-translate (px).
  /// 0..40
  final double elevationPx;

  // B3) Faces latérales (côtés)
  /// Active/désactive l'affichage des faces latérales (côtés) du ruban 3D.
  final bool sidesEnabled;

  /// Intensité des côtés (principalement opacité).
  /// 0..1
  final double sidesIntensity;

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

  // H) Immeubles 3D (environnement)
  /// Active/désactive les bâtiments 3D sur la carte
  final bool buildings3dEnabled;

  /// Transparence des immeubles 3D (0=invisible, 1=opaque)
  /// 0..1
  final double buildingOpacity;

  // I) Lisibilité du tracé
  /// Si activé, force le tracé à rester au-dessus des immeubles (ordre des layers).
  /// (Utile sur certains styles/pitches où les bâtiments masquent le tracé.)
  final bool routeAlwaysOnTop;

  // J) Couleur des espaces verts (parcs, forêts, etc.)
  /// Couleur personnalisée pour les zones de verdure sur la carte (null = défaut du style)
  final Color? parkColor;

  const RouteStyleConfig({
    this.schemaVersion = kRouteStyleSchemaVersion,
    // A
    this.carMode = true,
    this.freeDrawEnabled = false,
    this.fitToRoadWidth = false,
    this.snapToleranceMeters = 35.0,
    this.lineCap = RouteLineCap.round,
    this.lineJoin = RouteLineJoin.round,
    this.simplifyPercent = 15.0,
    // B
    this.mainWidth = 7.0,
    this.casingWidth = 11.0,
    this.mainColor = const Color(0xFF1A73E8),
    this.casingColor = const Color(0xFF0B1B2B),
    this.casingRainbowEnabled = false,
    this.opacity = 1.0,
    this.widthScale3d = 1.0,
    this.thickness3d = 1.0,
    this.casingThickness3d = 1.0,
    this.elevationPx = 0.0,
    this.sidesEnabled = false,
    this.sidesIntensity = 0.70,
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
    // H
    this.buildings3dEnabled = true,
    this.buildingOpacity = 0.60,
    // I
    this.routeAlwaysOnTop = false,
    // J
    this.parkColor,
  });

  bool get roadEffectsEnabled => carMode;

  bool get roadWidthModeEnabled => roadEffectsEnabled && fitToRoadWidth;

  double get effectiveWidthScale3d => roadWidthModeEnabled
      ? widthScale3d.clamp(0.5, kRoadWidthModeMaxWidthScale3d)
      : widthScale3d;

  double get effectiveMainWidth => roadWidthModeEnabled
      ? mainWidth.clamp(2.0, kRoadWidthModeMaxMainWidth)
      : mainWidth;

  double get effectiveRenderedMainWidth =>
      effectiveMainWidth * effectiveWidthScale3d;

  bool get shouldRenderRoadLike =>
      roadEffectsEnabled &&
      (effectiveCasingWidth > 0 ||
          effectiveShadowEnabled ||
          effectiveGlowEnabled ||
          effectiveSidesEnabled ||
          effectiveElevationPx > 0);

  bool get effectiveShadowEnabled =>
      roadEffectsEnabled && shadowEnabled && !roadWidthModeEnabled;

  bool get effectiveGlowEnabled =>
      roadEffectsEnabled && glowEnabled && !roadWidthModeEnabled;

  bool get effectiveSidesEnabled =>
      roadEffectsEnabled && sidesEnabled && !roadWidthModeEnabled;

  bool get effectiveCasingRainbowEnabled =>
      roadEffectsEnabled && casingRainbowEnabled;

  double get effectiveCasingWidth {
    if (!roadEffectsEnabled) return 0.0;
    if (!roadWidthModeEnabled) return casingWidth;

    final maxAllowed = effectiveMainWidth + kRoadWidthModeMaxCasingExtra;
    return casingWidth.clamp(0.0, maxAllowed);
  }

  double get effectiveRenderedCasingWidth =>
      effectiveCasingWidth * effectiveWidthScale3d;

  double get effectiveElevationPx =>
      roadEffectsEnabled && !roadWidthModeEnabled ? elevationPx : 0.0;

  RouteStyleConfig copyWith({
    int? schemaVersion,
    bool? carMode,
    bool? freeDrawEnabled,
    bool? fitToRoadWidth,
    double? snapToleranceMeters,
    RouteLineCap? lineCap,
    RouteLineJoin? lineJoin,
    double? simplifyPercent,
    double? mainWidth,
    double? casingWidth,
    Color? mainColor,
    Color? casingColor,
    bool? casingRainbowEnabled,
    double? opacity,
    double? widthScale3d,
    double? thickness3d,
    double? casingThickness3d,
    double? elevationPx,
    bool? sidesEnabled,
    double? sidesIntensity,
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
    bool? buildings3dEnabled,
    double? buildingOpacity,
    bool? routeAlwaysOnTop,    Color? parkColor,  }) {
    return RouteStyleConfig(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      carMode: carMode ?? this.carMode,
    freeDrawEnabled: freeDrawEnabled ?? this.freeDrawEnabled,
      fitToRoadWidth: fitToRoadWidth ?? this.fitToRoadWidth,
      snapToleranceMeters: snapToleranceMeters ?? this.snapToleranceMeters,
      lineCap: lineCap ?? this.lineCap,
      lineJoin: lineJoin ?? this.lineJoin,
      simplifyPercent: simplifyPercent ?? this.simplifyPercent,
      mainWidth: mainWidth ?? this.mainWidth,
      casingWidth: casingWidth ?? this.casingWidth,
      mainColor: mainColor ?? this.mainColor,
      casingColor: casingColor ?? this.casingColor,
      casingRainbowEnabled: casingRainbowEnabled ?? this.casingRainbowEnabled,
      opacity: opacity ?? this.opacity,
      widthScale3d: widthScale3d ?? this.widthScale3d,
      thickness3d: thickness3d ?? this.thickness3d,
      casingThickness3d: casingThickness3d ?? this.casingThickness3d,
      elevationPx: elevationPx ?? this.elevationPx,
      sidesEnabled: sidesEnabled ?? this.sidesEnabled,
      sidesIntensity: sidesIntensity ?? this.sidesIntensity,
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
      buildings3dEnabled: buildings3dEnabled ?? this.buildings3dEnabled,
      buildingOpacity: buildingOpacity ?? this.buildingOpacity,
      routeAlwaysOnTop: routeAlwaysOnTop ?? this.routeAlwaysOnTop,
      parkColor: parkColor ?? this.parkColor,
    ).validated();
  }

  RouteStyleConfig validated() {
    double clamp(double v, double min, double max) =>
        v.isNaN ? min : (v < min ? min : (v > max ? max : v));

    return RouteStyleConfig(
      schemaVersion: schemaVersion,
      carMode: carMode,
    freeDrawEnabled: freeDrawEnabled,
      fitToRoadWidth: fitToRoadWidth,
      snapToleranceMeters: clamp(snapToleranceMeters, 5, 150),
      lineCap: lineCap,
      lineJoin: lineJoin,
      simplifyPercent: clamp(simplifyPercent, 0, 100),
      mainWidth: clamp(mainWidth, 2, 20),
      casingWidth: clamp(casingWidth, 0, 30),
      mainColor: mainColor,
      casingColor: casingColor,
      casingRainbowEnabled: casingRainbowEnabled,
      opacity: clamp(opacity, 0, 1),
      widthScale3d: clamp(widthScale3d, 0.5, 3.0),
      thickness3d: clamp(thickness3d, 0.6, 1.8),
      casingThickness3d: clamp(casingThickness3d, 0.5, 2.5),
      elevationPx: clamp(elevationPx, 0, 40),
      sidesEnabled: sidesEnabled,
      sidesIntensity: clamp(sidesIntensity, 0, 1),
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
      buildings3dEnabled: buildings3dEnabled,
      buildingOpacity: clamp(buildingOpacity, 0, 1),
      routeAlwaysOnTop: routeAlwaysOnTop,
      parkColor: parkColor,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'carMode': carMode,
    'freeDrawEnabled': freeDrawEnabled,
      'fitToRoadWidth': fitToRoadWidth,
      'snapToleranceMeters': snapToleranceMeters,
      'lineCap': lineCap.name,
      'lineJoin': lineJoin.name,
      'simplifyPercent': simplifyPercent,
      'mainWidth': mainWidth,
      'casingWidth': casingWidth,
      'mainColor': _colorToHexArgb(mainColor),
      'casingColor': _colorToHexArgb(casingColor),
      'casingRainbowEnabled': casingRainbowEnabled,
      'opacity': opacity,
      'widthScale3d': widthScale3d,
      'thickness3d': thickness3d,
      'casingThickness3d': casingThickness3d,
      'elevationPx': elevationPx,
      'sidesEnabled': sidesEnabled,
      'sidesIntensity': sidesIntensity,
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
      'buildings3dEnabled': buildings3dEnabled,
      'buildingOpacity': buildingOpacity,
      'routeAlwaysOnTop': routeAlwaysOnTop,
      if (parkColor != null) 'parkColor': parkColor!.value,
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
      freeDrawEnabled: json['freeDrawEnabled'] is bool
          ? json['freeDrawEnabled'] as bool
          : false,
      fitToRoadWidth: json['fitToRoadWidth'] is bool
          ? json['fitToRoadWidth'] as bool
          : false,
      snapToleranceMeters: (json['snapToleranceMeters'] is num)
          ? (json['snapToleranceMeters'] as num).toDouble()
          : 35.0,
      lineCap: parseCap(json['lineCap'] as String?),
      lineJoin: parseJoin(json['lineJoin'] as String?),
      simplifyPercent: (json['simplifyPercent'] is num)
          ? (json['simplifyPercent'] as num).toDouble()
          : 15.0,
      mainWidth: (json['mainWidth'] is num)
          ? (json['mainWidth'] as num).toDouble()
          : 7.0,
      casingWidth: (json['casingWidth'] is num)
          ? (json['casingWidth'] as num).toDouble()
          : 11.0,
      mainColor:
          _colorFromHexArgb(json['mainColor'] as String?) ??
          const Color(0xFF1A73E8),
      casingColor:
          _colorFromHexArgb(json['casingColor'] as String?) ??
          const Color(0xFF0B1B2B),
      casingRainbowEnabled: json['casingRainbowEnabled'] is bool
          ? json['casingRainbowEnabled'] as bool
          : false,
      opacity: (json['opacity'] is num)
          ? (json['opacity'] as num).toDouble()
          : 1.0,
      widthScale3d: (json['widthScale3d'] is num)
          ? (json['widthScale3d'] as num).toDouble()
          : 1.0,
      thickness3d: (json['thickness3d'] is num)
          ? (json['thickness3d'] as num).toDouble()
          : 1.0,
      casingThickness3d: (json['casingThickness3d'] is num)
          ? (json['casingThickness3d'] as num).toDouble()
          : 1.0,
      elevationPx: (json['elevationPx'] is num)
          ? (json['elevationPx'] as num).toDouble()
          : 0.0,
      sidesEnabled: json['sidesEnabled'] is bool
          ? json['sidesEnabled'] as bool
          : false,
      sidesIntensity: (json['sidesIntensity'] is num)
          ? (json['sidesIntensity'] as num).toDouble()
          : 0.70,
      shadowEnabled: json['shadowEnabled'] is bool
          ? json['shadowEnabled'] as bool
          : true,
      shadowOpacity: (json['shadowOpacity'] is num)
          ? (json['shadowOpacity'] as num).toDouble()
          : 0.40,
      shadowBlur: (json['shadowBlur'] is num)
          ? (json['shadowBlur'] as num).toDouble()
          : 2.0,
      glowEnabled: json['glowEnabled'] is bool
          ? json['glowEnabled'] as bool
          : true,
      glowOpacity: (json['glowOpacity'] is num)
          ? (json['glowOpacity'] as num).toDouble()
          : 0.55,
      glowBlur: (json['glowBlur'] is num)
          ? (json['glowBlur'] as num).toDouble()
          : 6.0,
      glowWidth: (json['glowWidth'] is num)
          ? (json['glowWidth'] as num).toDouble()
          : 6.0,
      dashEnabled: json['dashEnabled'] is bool
          ? json['dashEnabled'] as bool
          : false,
      dashLength: (json['dashLength'] is num)
          ? (json['dashLength'] as num).toDouble()
          : 2.0,
      dashGap: (json['dashGap'] is num)
          ? (json['dashGap'] as num).toDouble()
          : 1.0,
      pulseEnabled: json['pulseEnabled'] is bool
          ? json['pulseEnabled'] as bool
          : false,
      pulseSpeed: (json['pulseSpeed'] is num)
          ? (json['pulseSpeed'] as num).toDouble()
          : 35.0,
      gradientEnabled: json['gradientEnabled'] is bool
          ? json['gradientEnabled'] as bool
          : false,
      rainbowEnabled: json['rainbowEnabled'] is bool
          ? json['rainbowEnabled'] as bool
          : false,
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
      buildings3dEnabled: json['buildings3dEnabled'] is bool
          ? json['buildings3dEnabled'] as bool
          : true,
      buildingOpacity: (json['buildingOpacity'] is num)
          ? (json['buildingOpacity'] as num).toDouble()
          : 0.60,
      routeAlwaysOnTop: json['routeAlwaysOnTop'] is bool
          ? json['routeAlwaysOnTop'] as bool
          : false,
      parkColor: json['parkColor'] is int
          ? Color(json['parkColor'] as int)
          : null,
    );

    return cfg.validated();
  }

  static String _colorToHexArgb(Color c) {
    final a = ((c.a * 255).round())
        .clamp(0, 255)
        .toRadixString(16)
        .padLeft(2, '0');
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
