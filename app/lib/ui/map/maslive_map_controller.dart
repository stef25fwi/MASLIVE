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

  /// Callback interne pour getCameraState (centre + zoom/pitch/bearing)
  Future<MapCameraState?> Function()? _getCameraStateImpl;

  /// Callback interne pour régler min/max zoom
  Future<void> Function(double? minZoom, double? maxZoom)? _setZoomRangeImpl;

  /// Callback interne pour régler le pitch (inclinaison) de la caméra
  Future<void> Function(double pitch, bool animate)? _setPitchImpl;

  /// Callback interne pour régler les bâtiments 3D (web: fill-extrusion opacity/visibility)
  Future<void> Function(bool enabled, double opacity)? _setBuildings3dImpl;

  /// Callback interne pour régler la teinte des bâtiments 3D.
  Future<void> Function(Color? color)? _setBuildingsColorImpl;

  /// Callback interne pour régler la couleur des espaces verts (parcs, forêts)
  Future<void> Function(Color? color)? _setParkColorImpl;

  /// Callback interne pour régler la couleur de l'eau.
  Future<void> Function(Color? color)? _setWaterColorImpl;

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

  /// @nodoc - Usage interne seulement
  set getCameraStateImpl(Future<MapCameraState?> Function()? impl) {
    _getCameraStateImpl = impl;
  }

  /// @nodoc - Usage interne seulement
  set setZoomRangeImpl(Future<void> Function(double? minZoom, double? maxZoom)? impl) {
    _setZoomRangeImpl = impl;
  }

  /// @nodoc - Usage interne seulement
  set setPitchImpl(Future<void> Function(double pitch, bool animate)? impl) {
    _setPitchImpl = impl;
  }

  /// @nodoc - Usage interne seulement
  set setBuildings3dImpl(Future<void> Function(bool enabled, double opacity)? impl) {
    _setBuildings3dImpl = impl;
  }

  /// @nodoc - Usage interne seulement
  set setBuildingsColorImpl(Future<void> Function(Color? color)? impl) {
    _setBuildingsColorImpl = impl;
  }

  /// @nodoc - Usage interne seulement
  set setParkColorImpl(Future<void> Function(Color? color)? impl) {
    _setParkColorImpl = impl;
  }

  /// @nodoc - Usage interne seulement
  set setWaterColorImpl(Future<void> Function(Color? color)? impl) {
    _setWaterColorImpl = impl;
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

  /// Fixer la plage de zoom autorisée (min/max).
  Future<void> setZoomRange({double? minZoom, double? maxZoom}) async {
    await _setZoomRangeImpl?.call(minZoom, maxZoom);
  }

  /// Régler l'inclinaison de la caméra (pitch en degrés).
  Future<void> setPitch({required double pitch, bool animate = true}) async {
    await _setPitchImpl?.call(pitch, animate);
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
    double? shadowOpacity,
    double? shadowBlur,
    Color? casingColor,
    double? casingWidth,
    bool? casingRainbowEnabled,
    bool glowEnabled = false,
    Color? glowColor,
    double? glowWidth,
    double? glowOpacity,
    double? glowBlur,
    double? thickness3d,
    double? elevationPx,
    bool? routeAlwaysOnTop,
    bool? sidesEnabled,
    double? sidesIntensity,
    List<double>? dashArray,
    String? lineCap,
    String? lineJoin,
    String? segmentsGeoJson,
    bool? segmentsForMain,
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
        shadowOpacity: shadowOpacity,
        shadowBlur: shadowBlur,
        casingColor: casingColor,
        casingWidth: casingWidth,
        casingRainbowEnabled: casingRainbowEnabled,
        glowEnabled: glowEnabled,
        glowColor: glowColor,
        glowWidth: glowWidth,
        glowOpacity: glowOpacity,
        glowBlur: glowBlur,
        thickness3d: thickness3d,
        elevationPx: elevationPx,
        routeAlwaysOnTop: routeAlwaysOnTop,
        sidesEnabled: sidesEnabled,
        sidesIntensity: sidesIntensity,
        dashArray: dashArray,
        lineCap: lineCap,
        lineJoin: lineJoin,
        segmentsGeoJson: segmentsGeoJson,
        segmentsForMain: segmentsForMain,
      ),
    );
  }

  /// Activer/désactiver les bâtiments 3D et régler leur opacité.
  ///
  /// Web (Mapbox GL JS): applique sur la couche `fill-extrusion` (si présente).
  /// Mobile: no-op tant que l'impl native n'est pas branchée.
  Future<void> setBuildings3d({
    required bool enabled,
    required double opacity,
  }) async {
    await _setBuildings3dImpl?.call(enabled, opacity);
  }

  /// Définir la teinte des bâtiments 3D.
  ///
  /// Si color est null, conserve la teinte du style courant.
  Future<void> setBuildingsColor(Color? color) async {
    await _setBuildingsColorImpl?.call(color);
  }

  /// Définir la couleur des espaces verts (parcs, forêts, etc.)
  ///
  /// Web: applique la couleur sur les layers de type landuse/park.
  /// Mobile: no-op pour l'instant.
  /// Si color est null, réinitialise à la couleur du style par défaut.
  Future<void> setParkColor(Color? color) async {
    await _setParkColorImpl?.call(color);
  }

  /// Définir la couleur de l'eau.
  ///
  /// Si color est null, conserve la couleur du style courant.
  Future<void> setWaterColor(Color? color) async {
    await _setWaterColorImpl?.call(color);
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

  /// Retourne l'état courant complet de la caméra (si supporté).
  Future<MapCameraState?> getCameraState() async {
    final state = await _getCameraStateImpl?.call();
    if (state != null) return state;

    // Fallback compat: on n'a que le centre.
    final center = await _getCameraCenterImpl?.call();
    if (center == null) return null;
    return MapCameraState(
      center: center,
      zoom: double.nan,
      pitch: double.nan,
      bearing: double.nan,
    );
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
    _getCameraStateImpl = null;
    _setZoomRangeImpl = null;
    _setPitchImpl = null;
  }
}

/// État caméra (Mapbox Web + Native)
class MapCameraState {
  final MapPoint center;
  final double zoom;
  final double pitch;
  final double bearing;

  const MapCameraState({
    required this.center,
    required this.zoom,
    required this.pitch,
    required this.bearing,
  });

  @override
  String toString() =>
      'MapCameraState(center: $center, zoom: $zoom, pitch: $pitch, bearing: $bearing)';
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

  /// Opacité de l'ombre (si supporté par l'implémentation).
  final double? shadowOpacity;

  /// Blur de l'ombre (si supporté par l'implémentation).
  final double? shadowBlur;

  final Color? casingColor;
  final double? casingWidth;

  /// Si true, le casing utilise une couleur par segment (rainbow), si supporté.
  final bool? casingRainbowEnabled;
  final bool glowEnabled;
  final Color? glowColor;
  final double? glowWidth;
  final double? glowOpacity;
  final double? glowBlur;
  final List<double>? dashArray;
  final String? lineCap;
  final String? lineJoin;

  /// Facteur de relief (ruban 3D): accentue l'ombre (largeur/blur/offset).
  final double? thickness3d;

  /// Hauteur simulée (Mapbox): line-translate en pixels.
  final double? elevationPx;

  /// Si true, force le tracé à rester au-dessus des immeubles (ordre des layers).
  final bool? routeAlwaysOnTop;

  /// Faces latérales (côtés) du ruban 3D.
  final bool? sidesEnabled;

  /// Intensité des côtés (principalement opacité), 0..1.
  final double? sidesIntensity;

  /// Optionnel (Web): GeoJSON FeatureCollection de segments.
  ///
  /// Permet d'appliquer des styles par segment via expressions (ex: rainbow/traffic/vanishing).
  /// Format attendu: FeatureCollection contenant des LineString avec properties:
  /// - color: string (CSS color)
  /// - width: number
  /// - opacity: number
  final String? segmentsGeoJson;

  /// Optionnel (Web): si false, les segments servent seulement au casing
  /// (le tracé principal reste sur la source pleine).
  final bool? segmentsForMain;

  const PolylineRenderOptions({
    this.roadLike = true,
    this.shadow3d = true,
    this.showDirection = true,
    this.animateDirection = false,
    this.animationSpeed = 1.0,
    this.opacity,
    this.shadowOpacity,
    this.shadowBlur,
    this.casingColor,
    this.casingWidth,
    this.casingRainbowEnabled,
    this.glowEnabled = false,
    this.glowColor,
    this.glowWidth,
    this.glowOpacity,
    this.glowBlur,
    this.dashArray,
    this.lineCap,
    this.lineJoin,
    this.thickness3d,
    this.elevationPx,
    this.routeAlwaysOnTop,
    this.sidesEnabled,
    this.sidesIntensity,
    this.segmentsGeoJson,
    this.segmentsForMain,
  });

  Map<String, dynamic> toJson() => {
        'roadLike': roadLike,
        'shadow3d': shadow3d,
        'showDirection': showDirection,
        'animateDirection': animateDirection,
        'animationSpeed': animationSpeed,
        if (opacity != null) 'opacity': opacity,
        if (shadowOpacity != null) 'shadowOpacity': shadowOpacity,
        if (shadowBlur != null) 'shadowBlur': shadowBlur,
        if (casingWidth != null) 'casingWidth': casingWidth,
        if (casingColor != null) 'casingColor': _toHexRgb(casingColor!),
        if (casingRainbowEnabled != null)
          'casingRainbowEnabled': casingRainbowEnabled,
        'glowEnabled': glowEnabled,
        if (glowWidth != null) 'glowWidth': glowWidth,
        if (glowOpacity != null) 'glowOpacity': glowOpacity,
        if (glowBlur != null) 'glowBlur': glowBlur,
        if (glowColor != null) 'glowColor': _toHexRgb(glowColor!),
        if (thickness3d != null) 'thickness3d': thickness3d,
        if (elevationPx != null) 'elevationPx': elevationPx,
        if (routeAlwaysOnTop != null) 'routeAlwaysOnTop': routeAlwaysOnTop,
        if (sidesEnabled != null) 'sidesEnabled': sidesEnabled,
        if (sidesIntensity != null) 'sidesIntensity': sidesIntensity,
        if (dashArray != null) 'dashArray': dashArray,
        if (lineCap != null) 'lineCap': lineCap,
        if (lineJoin != null) 'lineJoin': lineJoin,
        if (segmentsGeoJson != null) 'segmentsGeoJson': segmentsGeoJson,
        if (segmentsForMain != null) 'segmentsForMain': segmentsForMain,
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
