import 'dart:ui' show Color;
import 'package:flutter/foundation.dart' show VoidCallback;

/// Contrôleur unifié pour MasLiveMap (Web + Mobile)
/// API agnostique de la plateforme sous-jacente
///
/// Phase 1: API complète pour édition/affichage Mapbox-only
class MasLiveMapController {
  /// Callback interne pour moveTo (branché par impl Web/Native via bindMoveToImpl)
  Future<void> Function(double lng, double lat, double zoom, bool animate)? _moveToImpl;

  /// Callback interne pour setStyle
  Future<void> Function(String styleUri)? _setStyleImpl;

  /// Callback interne pour setUserLocation
  Future<void> Function(double lng, double lat, bool show)? _setUserLocationImpl;

  /// Callback interne pour setMarkers
  Future<void> Function(List<MapMarker> markers)? _setMarkersImpl;

  /// Callback interne pour setPolyline
  Future<void> Function(
    List<MapPoint> points,
    Color color,
    double width,
    bool show,
    PolylineRenderOptions options,
  )? _setPolylineImpl;

  /// Callback interne pour setPolygon
  Future<void> Function(List<MapPoint> points, Color fillColor, Color strokeColor, double strokeWidth, bool show)? _setPolygonImpl;

  /// Callback interne pour setEditingEnabled
  Future<void> Function(bool enabled, void Function(double lat, double lng)? onPointAdded)? _setEditingEnabledImpl;

  /// Callback interne pour clearAll
  Future<void> Function()? _clearAllImpl;

  /// Callback interne pour fitBounds
  Future<void> Function(double west, double south, double east, double north, double padding, bool animate)?
      _fitBoundsImpl;

  /// Callback interne pour setMaxBounds
  Future<void> Function(double? west, double? south, double? east, double? north)? _setMaxBoundsImpl;

  /// Callback interne pour getCameraCenter
  Future<MapPoint?> Function()? _getCameraCenterImpl;

  // =====================================================================
  // SETTERS publics pour brancher les implémentations (Web/Native)
  // ⚠️ Ne PAS utiliser dans le code applicatif, réservés aux impl internes
  // =====================================================================

  /// @nodoc - Usage interne seulement
  set moveToImpl(Future<void> Function(double lng, double lat, double zoom, bool animate)? impl) {
    _moveToImpl = impl;
  }

  /// @nodoc - Usage interne seulement
  set setStyleImpl(Future<void> Function(String styleUri)? impl) {
    _setStyleImpl = impl;
  }

  /// @nodoc - Usage interne seulement
  set setUserLocationImpl(Future<void> Function(double lng, double lat, bool show)? impl) {
    _setUserLocationImpl = impl;
  }

  /// @nodoc - Usage interne seulement
  set setMarkersImpl(Future<void> Function(List<MapMarker> markers)? impl) {
    _setMarkersImpl = impl;
  }

  /// @nodoc - Usage interne seulement
  set setPolylineImpl(
    Future<void> Function(
      List<MapPoint> points,
      Color color,
      double width,
      bool show,
      PolylineRenderOptions options,
    )?
        impl,
  ) {
    _setPolylineImpl = impl;
  }

  /// @nodoc - Usage interne seulement
  set setPolygonImpl(Future<void> Function(List<MapPoint> points, Color fillColor, Color strokeColor, double strokeWidth, bool show)? impl) {
    _setPolygonImpl = impl;
  }

  /// @nodoc - Usage interne seulement
  set setEditingEnabledImpl(Future<void> Function(bool enabled, void Function(double lat, double lng)? onPointAdded)? impl) {
    _setEditingEnabledImpl = impl;
  }

  /// @nodoc - Usage interne seulement
  set clearAllImpl(Future<void> Function()? impl) {
    _clearAllImpl = impl;
  }

  /// @nodoc - Usage interne seulement
  set fitBoundsImpl(
    Future<void> Function(double west, double south, double east, double north, double padding, bool animate)? impl,
  ) {
    _fitBoundsImpl = impl;
  }

  /// @nodoc - Usage interne seulement
  set setMaxBoundsImpl(
    Future<void> Function(double? west, double? south, double? east, double? north)? impl,
  ) {
    _setMaxBoundsImpl = impl;
  }

  /// @nodoc - Usage interne seulement
  set getCameraCenterImpl(Future<MapPoint?> Function()? impl) {
    _getCameraCenterImpl = impl;
  }

  // =====================================================================
  // API PUBLIQUE (utilisable par les pages/widgets)
  // =====================================================================

  /// Déplacer la caméra vers une position
  Future<void> moveTo({
    required double lng,
    required double lat,
    double zoom = 15.0,
    bool animate = true,
  }) async {
    await _moveToImpl?.call(lng, lat, zoom, animate);
  }

  /// Changer le style de carte
  /// Styles Mapbox disponibles:
  /// - mapbox://styles/mapbox/streets-v12 (défaut)
  /// - mapbox://styles/mapbox/outdoors-v12 (sentiers)
  /// - mapbox://styles/mapbox/satellite-streets-v12 (satellite + routes)
  /// - mapbox://styles/mapbox/satellite-v9 (satellite pur)
  /// - mapbox://styles/mapbox/dark-v11, light-v11
  Future<void> setStyle(String styleUri) async {
    await _setStyleImpl?.call(styleUri);
  }

  /// Mettre à jour la position de l'utilisateur
  Future<void> setUserLocation({
    required double lng,
    required double lat,
    bool show = true,
  }) async {
    await _setUserLocationImpl?.call(lng, lat, show);
  }

  /// Afficher des marqueurs sur la carte
  /// Remplace tous les marqueurs existants
  Future<void> setMarkers(List<MapMarker> markers) async {
    await _setMarkersImpl?.call(markers);
  }

  /// Afficher une polyligne (parcours, trajet)
  Future<void> setPolyline({
    required List<MapPoint> points,
    Color color = const Color(0xFF0A84FF),
    double width = 4.0,
    bool show = true,
    bool roadLike = false,
    bool shadow3d = false,
    bool showDirection = false,
    bool animateDirection = false,
    double animationSpeed = 1.0,
    // Options avancées (principalement utiles sur Web via Mapbox GL JS)
    double? opacity,
    Color? casingColor,
    double? casingWidth,
    bool glowEnabled = false,
    Color? glowColor,
    double? glowWidth,
    double? glowOpacity,
    double? glowBlur,
    List<double>? dashArray,
    String? lineCap,
    String? lineJoin,
    String? segmentsGeoJson,
  }) async {
    await _setPolylineImpl?.call(
      points,
      color,
      width,
      show,
      PolylineRenderOptions(
        roadLike: roadLike,
        shadow3d: shadow3d,
        showDirection: showDirection,
        animateDirection: animateDirection,
        animationSpeed: animationSpeed,
        opacity: opacity,
        casingColor: casingColor,
        casingWidth: casingWidth,
        glowEnabled: glowEnabled,
        glowColor: glowColor,
        glowWidth: glowWidth,
        glowOpacity: glowOpacity,
        glowBlur: glowBlur,
        dashArray: dashArray,
        lineCap: lineCap,
        lineJoin: lineJoin,
        segmentsGeoJson: segmentsGeoJson,
      ),
    );
  }

  /// Afficher un polygone (zone, circuit fermé)
  Future<void> setPolygon({
    required List<MapPoint> points,
    Color fillColor = const Color(0x4D0A84FF),
    Color strokeColor = const Color(0xFF0A84FF),
    double strokeWidth = 2.0,
    bool show = true,
  }) async {
    await _setPolygonImpl?.call(points, fillColor, strokeColor, strokeWidth, show);
  }

  /// Active/désactive le mode édition (ajout de points par clic)
  Future<void> setEditingEnabled({
    required bool enabled,
    void Function(double lat, double lng)? onPointAdded,
  }) async {
    await _setEditingEnabledImpl?.call(enabled, onPointAdded);
  }

  /// Nettoie toutes les annotations (markers, polylines, polygons)
  Future<void> clearAll() async {
    await _clearAllImpl?.call();
  }

  /// Ajuste la caméra pour englober des bounds
  Future<void> fitBounds({
    required double west,
    required double south,
    required double east,
    required double north,
    double padding = 48.0,
    bool animate = true,
  }) async {
    await _fitBoundsImpl?.call(west, south, east, north, padding, animate);
  }

  /// Limite le déplacement de la carte à des bounds.
  /// Passer `null` pour désactiver le verrouillage.
  Future<void> setMaxBounds({
    double? west,
    double? south,
    double? east,
    double? north,
  }) async {
    await _setMaxBoundsImpl?.call(west, south, east, north);
  }

  /// Retourne le centre courant de la caméra (si supporté).
  Future<MapPoint?> getCameraCenter() async {
    return _getCameraCenterImpl?.call();
  }

  /// Dispose (à appeler dans le dispose du State)
  void dispose() {
    _moveToImpl = null;
    _setStyleImpl = null;
    _setUserLocationImpl = null;
    _setMarkersImpl = null;
    _setPolylineImpl = null;
    _setPolygonImpl = null;
    _setEditingEnabledImpl = null;
    _clearAllImpl = null;
    _fitBoundsImpl = null;
    _setMaxBoundsImpl = null;
    _getCameraCenterImpl = null;
  }
}

/// Options de rendu avancées pour une polyligne (itinéraire routier)
class PolylineRenderOptions {
  final bool roadLike;
  final bool shadow3d;
  final bool showDirection;
  final bool animateDirection;
  final double animationSpeed;

  // Options visuelles additionnelles (principalement implémentées côté Web)
  final double? opacity;
  final Color? casingColor;
  final double? casingWidth;
  final bool glowEnabled;
  final Color? glowColor;
  final double? glowWidth;
  final double? glowOpacity;
  final double? glowBlur;
  final List<double>? dashArray;
  final String? lineCap;
  final String? lineJoin;

  /// Optionnel (Web): GeoJSON FeatureCollection de segments.
  ///
  /// Permet d'appliquer des styles par segment via expressions (ex: rainbow/traffic/vanishing).
  /// Format attendu: FeatureCollection contenant des LineString avec properties:
  /// - color: string (CSS color)
  /// - width: number
  /// - opacity: number
  final String? segmentsGeoJson;

  const PolylineRenderOptions({
    this.roadLike = true,
    this.shadow3d = true,
    this.showDirection = true,
    this.animateDirection = false,
    this.animationSpeed = 1.0,
    this.opacity,
    this.casingColor,
    this.casingWidth,
    this.glowEnabled = false,
    this.glowColor,
    this.glowWidth,
    this.glowOpacity,
    this.glowBlur,
    this.dashArray,
    this.lineCap,
    this.lineJoin,
    this.segmentsGeoJson,
  });

  Map<String, dynamic> toJson() => {
        'roadLike': roadLike,
        'shadow3d': shadow3d,
        'showDirection': showDirection,
        'animateDirection': animateDirection,
        'animationSpeed': animationSpeed,
        if (opacity != null) 'opacity': opacity,
        if (casingWidth != null) 'casingWidth': casingWidth,
        if (casingColor != null) 'casingColor': _toHexRgb(casingColor!),
        'glowEnabled': glowEnabled,
        if (glowWidth != null) 'glowWidth': glowWidth,
        if (glowOpacity != null) 'glowOpacity': glowOpacity,
        if (glowBlur != null) 'glowBlur': glowBlur,
        if (glowColor != null) 'glowColor': _toHexRgb(glowColor!),
        if (dashArray != null) 'dashArray': dashArray,
        if (lineCap != null) 'lineCap': lineCap,
        if (lineJoin != null) 'lineJoin': lineJoin,
        if (segmentsGeoJson != null) 'segmentsGeoJson': segmentsGeoJson,
      };

  static String _toHexRgb(Color c) {
    final v = c.toARGB32().toRadixString(16).padLeft(8, '0');
    return '#${v.substring(2, 8)}';
  }
}

/// Modèle de données pour un point sur la carte
class MapPoint {
  final double lng;
  final double lat;

  const MapPoint(this.lng, this.lat);

  @override
  String toString() => 'MapPoint($lng, $lat)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapPoint && runtimeType == other.runtimeType && lng == other.lng && lat == other.lat;

  @override
  int get hashCode => lng.hashCode ^ lat.hashCode;
}

/// Modèle de données pour un marqueur (marker/pin)
class MapMarker {
  final String id;
  final double lng;
  final double lat;
  final Color color;
  final String? label;
  final double size;
  final void Function()? onTap;

  const MapMarker({
    required this.id,
    required this.lng,
    required this.lat,
    this.color = const Color(0xFF0A84FF),
    this.label,
    this.size = 1.0,
    this.onTap,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapMarker &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          lng == other.lng &&
          lat == other.lat &&
          color == other.color &&
          label == other.label &&
          size == other.size;

  @override
  int get hashCode =>
      id.hashCode ^
      lng.hashCode ^
      lat.hashCode ^
      color.hashCode ^
      (label?.hashCode ?? 0) ^
      size.hashCode;
}

/// Modèle de données pour un lieu (POI) - Legacy
@Deprecated('Utiliser MapMarker à la place')
class MapPlace {
  final String id;
  final double lng;
  final double lat;
  final String name;
  final String? category;
  final String? iconUrl;
  final VoidCallback? onTap;

  const MapPlace({
    required this.id,
    required this.lng,
    required this.lat,
    required this.name,
    this.category,
    this.iconUrl,
    this.onTap,
  });
}

/// Modèle de données pour un groupe (tracking) - Legacy
@Deprecated('Utiliser MapMarker à la place')
class MapGroup {
  final String id;
  final double lng;
  final double lat;
  final String name;
  final int memberCount;
  final String? color;
  final VoidCallback? onTap;

  const MapGroup({
    required this.id,
    required this.lng,
    required this.lat,
    required this.name,
    this.memberCount = 0,
    this.color,
    this.onTap,
  });
}

/// Style personnalisé pour un itinéraire - Legacy
@Deprecated('Utiliser les paramètres color/width de setPolyline')
class MapRouteStyle {
  final String color;
  final double width;
  final double opacity;

  const MapRouteStyle({
    this.color = '#3887be',
    this.width = 5.0,
    this.opacity = 0.75,
  });
}
