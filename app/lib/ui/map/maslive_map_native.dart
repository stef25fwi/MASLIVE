import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'maslive_map_controller.dart';
import 'maslive_poi_style.dart';
import '../../services/mapbox_token_service.dart';

/// Implémentation Native (iOS/Android) de MasLiveMap
/// Utilise mapbox_maps_flutter avec API Phase 1 complète
class MasLiveMapNative extends StatefulWidget {
  final MasLiveMapController? controller;
  final double initialLng;
  final double initialLat;
  final double initialZoom;
  final double initialPitch;
  final double initialBearing;
  final String? styleUrl;
  final bool showUserLocation;
  final double? userLng;
  final double? userLat;
  final ValueChanged<MapPoint>? onTap;
  final void Function(MasLiveMapController)? onMapReady;

  const MasLiveMapNative({
    super.key,
    this.controller,
    required this.initialLng,
    required this.initialLat,
    required this.initialZoom,
    this.initialPitch = 0.0,
    this.initialBearing = 0.0,
    this.styleUrl,
    this.showUserLocation = false,
    this.userLng,
    this.userLat,
    this.onTap,
    this.onMapReady,
  });

  @override
  State<MasLiveMapNative> createState() => _MasLiveMapNativeState();
}

class _MasLiveMapNativeState extends State<MasLiveMapNative> {
  static const String _poiSourceId = 'src_pois';
  static const String _poiLayerId = 'ly_pois_circle';
  static const String _poiFillLayerId = 'ly_pois_fill';
  static const String _poiPatternLayerId = 'ly_pois_pattern';
  static const String _poiLineLayerId = 'ly_pois_line_solid';
  static const String _poiLineLayerDashedId = 'ly_pois_line_dashed';
  static const String _poiLineLayerDottedId = 'ly_pois_line_dotted';

  static const String _patDiag = 'maslive_pat_diag';
  static const String _patCross = 'maslive_pat_cross';
  static const String _patDots = 'maslive_pat_dots';

  // Route (style layers) pour support segments (Style Pro)
  static const String _routeSourceId = 'maslive_polyline';
  static const String _segmentsSourceId = 'maslive_polyline_segments';

  static const String _layerRouteShadow = 'maslive_polyline_shadow';
  static const String _layerRouteSideL = 'maslive_polyline_side_l';
  static const String _layerRouteSideR = 'maslive_polyline_side_r';
  static const String _layerRouteCasing = 'maslive_polyline_casing';
  static const String _layerRouteCore = 'maslive_polyline_core';
  static const String _layerRoutePlain = 'maslive_polyline_layer';

  ({
    List<MapPoint> points,
    Color color,
    double width,
    bool show,
    PolylineRenderOptions options,
  })?
  _pendingPolyline;

  MasLivePoiStyle _poiStyle = const MasLivePoiStyle();

  MapboxMap? _mapboxMap;
  PointAnnotationManager? _markersManager;
  PolylineAnnotationManager? _polylineManager;
  PolygonAnnotationManager? _polygonManager;
  PointAnnotationManager? _userLocationManager;
  bool _isMapReady = false;
  bool _styleLoaded = false;
  bool _didNotifyHostMapReady = false;
  void Function(double lat, double lng)? _onPointAddedCallback;

  bool _patternImagesReady = false;

  String _poisGeoJsonString = '{"type":"FeatureCollection","features":[]}';

  List<MapMarker>? _lastMarkers;
  ({
    List<MapPoint> points,
    Color fillColor,
    Color strokeColor,
    double strokeWidth,
    bool show,
  })?
  _lastPolygon;

  ({
    List<MapPoint> points,
    Color color,
    double width,
    bool show,
    PolylineRenderOptions options,
  })?
  _lastPolyline;

  String? _pendingStyleUrlToApply;
  String? _styleLoadError;

  String _normalizeMapboxStyleUri(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';

    Uri uri;
    try {
      uri = Uri.parse(value);
    } catch (_) {
      return value;
    }

    final host = uri.host.toLowerCase();

    // Cas fréquent: URL Mapbox Studio (page HTML) copiée depuis l'UI.
    // Ex: https://studio.mapbox.com/styles/{user}/{styleId}/edit
    // => mapbox://styles/{user}/{styleId}
    if (host == 'studio.mapbox.com') {
      final seg = uri.pathSegments;
      final stylesIndex = seg.indexOf('styles');
      if (stylesIndex != -1 && seg.length >= stylesIndex + 3) {
        final user = seg[stylesIndex + 1];
        final styleId = seg[stylesIndex + 2];
        if (user.isNotEmpty && styleId.isNotEmpty) {
          return 'mapbox://styles/$user/$styleId';
        }
      }
    }

    // Certains liens finissent par ".html" (HTML, non JSON). On tente d'enlever le suffixe.
    if (value.toLowerCase().endsWith('.html')) {
      return value.substring(0, value.length - 5);
    }

    return value;
  }

  String _friendlyStyleLoadError(Object error) {
    final msg = error.toString();
    final lower = msg.toLowerCase();
    if (lower.contains('403') || lower.contains('forbidden')) {
      return 'Accès Mapbox refusé (403). Vérifie les permissions/restrictions du token et l\'accès au style.';
    }
    if (lower.contains('401') || lower.contains('unauthorized')) {
      return 'Token Mapbox invalide (401). Vérifie MAPBOX_ACCESS_TOKEN (pk.*) et réessaie.';
    }
    if (lower.contains('network') || lower.contains('timeout')) {
      return 'Erreur réseau pendant le chargement du style. Vérifie la connexion et réessaie.';
    }
    return 'Impossible de charger le style Mapbox. ($msg)';
  }

  Future<void> _applyStyleUri(String styleUri, {MapboxMap? mapOverride}) async {
    final map = mapOverride ?? _mapboxMap;
    if (map == null) {
      _pendingStyleUrlToApply = styleUri;
      return;
    }

    if (mounted) {
      setState(() {
        _styleLoadError = null;
      });
    }

    _styleLoaded = false;
    try {
      await map.loadStyleURI(styleUri);
    } catch (e) {
      debugPrint('⚠️ loadStyleURI error: $e');
      if (!mounted) return;
      setState(() {
        _styleLoadError = _friendlyStyleLoadError(e);
      });
    }
  }

  void _notifyHostMapReadyIfNeeded() {
    if (_didNotifyHostMapReady) return;
    _didNotifyHostMapReady = true;

    final controller = widget.controller;
    if (controller != null) {
      widget.onMapReady?.call(controller);
    }
  }

  @override
  void initState() {
    super.initState();
    _initMapboxToken();
    _connectController();
  }

  @override
  void didUpdateWidget(covariant MasLiveMapNative oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      _connectController();
    }

    final oldStyle = _normalizeMapboxStyleUri(oldWidget.styleUrl ?? '');
    final newStyle = _normalizeMapboxStyleUri(widget.styleUrl ?? '');
    if (oldStyle == newStyle) return;

    final styleToApply = newStyle.isEmpty ? MapboxStyles.STANDARD : newStyle;
    unawaited(_applyStyleUri(styleToApply));
  }

  Future<void> _initMapboxToken() async {
    try {
      final info = await MapboxTokenService.getTokenInfo();
      if (info.token.isNotEmpty) {
        MapboxOptions.setAccessToken(info.token);
      }
    } catch (e) {
      debugPrint('⚠️ Erreur chargement token Mapbox: $e');
    }
  }

  void _connectController() {
    final controller = widget.controller;
    if (controller == null) return;

    controller.moveToImpl = (lng, lat, zoom, animate) async {
      if (_mapboxMap == null) return;
      final camera = CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: zoom,
      );
      if (animate) {
        await _mapboxMap!.flyTo(camera, MapAnimationOptions(duration: 1000));
      } else {
        await _mapboxMap!.setCamera(camera);
      }
    };

    controller.setStyleImpl = (styleUri) async {
      await _mapboxMap?.loadStyleURI(styleUri);
    };

    controller.setUserLocationImpl = (lng, lat, show) async {
      if (!show) {
        await _userLocationManager?.deleteAll();
        return;
      }
      await _ensureUserLocationManager();
      await _userLocationManager?.deleteAll();
      final opt = PointAnnotationOptions(
        geometry: Point(coordinates: Position(lng, lat)),
        iconImage: 'marker-15',
        iconSize: 1.5,
        iconColor: Colors.blue.toARGB32(),
      );
      await _userLocationManager?.create(opt);
    };

    controller.setMarkersImpl = (markers) async {
      _lastMarkers = List<MapMarker>.from(markers);
      await _ensureMarkersManager();
      await _markersManager?.deleteAll();
      for (final m in markers) {
        final opt = PointAnnotationOptions(
          geometry: Point(coordinates: Position(m.lng, m.lat)),
          iconImage: 'marker-15',
          iconSize: m.size,
          iconColor: m.color.toARGB32(),
          textField: m.label,
          textSize: 12.0,
          textOffset: const [0.0, 1.2],
          textColor: Colors.black.toARGB32(),
          textHaloColor: Colors.white.toARGB32(),
          textHaloWidth: 1.0,
        );
        await _markersManager?.create(opt);
      }
    };

    controller.setPolylineImpl = (points, color, width, show, options) async {
      if (!show) {
        _lastPolyline = null;
      } else {
        _lastPolyline = (
          points: List<MapPoint>.from(points),
          color: color,
          width: width,
          show: show,
          options: options,
        );
      }
      if (!show) {
        _pendingPolyline = null;
        await _removeRouteLayersAndSourcesIfAny();
        await _polylineManager?.deleteAll();
        return;
      }

      // Segments (Style Pro): rendu via style layers (expressions) pour parité Web.
      final segJson = options.segmentsGeoJson;
      final useSegments = segJson != null && segJson.trim().isNotEmpty;
      if (useSegments) {
        _pendingPolyline = (
          points: points,
          color: color,
          width: width,
          show: show,
          options: options,
        );
        await _polylineManager?.deleteAll();
        if (!_styleLoaded || _mapboxMap == null) {
          return;
        }
        await _renderSegmentedPolylineNative(
          points: points,
          color: color,
          width: width,
          options: options,
        );
        return;
      } else {
        _pendingPolyline = null;
        // Si on repasse en mode annotations, nettoyer les layers/sources route.
        await _removeRouteLayersAndSourcesIfAny();
      }

      await _ensurePolylineManager();
      await _polylineManager?.deleteAll();
      final coords = points.map((p) => Position(p.lng, p.lat)).toList();

      // Rendu type "itinéraire routier": plusieurs couches (shadow/casing/core/center)
      // ⚠️ Sur natif (annotations), pas de symbol line-placement simple → flèches/animation non gérées ici.
      final baseWidth = width;
      final shadowEnabled = options.shadow3d;
      final roadLike = options.roadLike;
          final thickness3d = (options.thickness3d ?? 1.0).clamp(0.6, 1.8);

      // Helpers de couleur
      int to255(double v) => (v * 255.0).round().clamp(0, 255);
      int argbWithAlpha(Color c, int a) =>
          Color.fromARGB(a, to255(c.r), to255(c.g), to255(c.b)).toARGB32();
      final shadowColor = argbWithAlpha(const Color(0xFF000000), 90);
      final casingColor = argbWithAlpha(const Color(0xFF000000), 140);
      final centerColor = argbWithAlpha(const Color(0xFFFFFFFF), 190);

      Future<void> addLine({
        required int lineColor,
        required double lineWidth,
      }) async {
        final opt = PolylineAnnotationOptions(
          geometry: LineString(coordinates: coords),
          lineColor: lineColor,
          lineWidth: lineWidth,
        );
        await _polylineManager?.create(opt);
      }

      if (!roadLike) {
        await addLine(lineColor: color.toARGB32(), lineWidth: baseWidth);
        return;
      }

      if (shadowEnabled) {
        await addLine(
          lineColor: shadowColor,
          lineWidth: baseWidth + (8.0 * thickness3d),
        );
      }
      await addLine(
        lineColor: casingColor,
        lineWidth: baseWidth + (5.0 * thickness3d),
      );
      await addLine(lineColor: color.toARGB32(), lineWidth: baseWidth);

      final centerWidth = (baseWidth * 0.33).clamp(1.0, baseWidth);
      await addLine(lineColor: centerColor, lineWidth: centerWidth);
    };

    controller.setPolygonImpl =
        (points, fillColor, strokeColor, strokeWidth, show) async {
          if (!show) {
            _lastPolygon = null;
          } else {
            _lastPolygon = (
              points: List<MapPoint>.from(points),
              fillColor: fillColor,
              strokeColor: strokeColor,
              strokeWidth: strokeWidth,
              show: show,
            );
          }
          if (!show) {
            await _polygonManager?.deleteAll();
            return;
          }
          await _ensurePolygonManager();
          await _polygonManager?.deleteAll();
          final coords = points.map((p) => Position(p.lng, p.lat)).toList();
          final opt = PolygonAnnotationOptions(
            geometry: Polygon(coordinates: [coords]),
            fillColor: fillColor.toARGB32(),
            fillOutlineColor: strokeColor.toARGB32(),
          );
          await _polygonManager?.create(opt);
        };

    controller.setEditingEnabledImpl = (enabled, onPointAdded) async {
      _onPointAddedCallback = enabled ? onPointAdded : null;
    };

    controller.clearAllImpl = () async {
      _lastMarkers = null;
      _lastPolyline = null;
      _pendingPolyline = null;
      _lastPolygon = null;
      await _markersManager?.deleteAll();
      await _polylineManager?.deleteAll();
      await _polygonManager?.deleteAll();
      await _userLocationManager?.deleteAll();
    };

    controller
        .fitBoundsImpl = (west, south, east, north, padding, animate) async {
      if (_mapboxMap == null) return;
      try {
        final bounds = CoordinateBounds(
          southwest: Point(coordinates: Position(west, south)),
          northeast: Point(coordinates: Position(east, north)),
          infiniteBounds: false,
        );
        final camera = await _mapboxMap!.cameraForCoordinateBounds(
          bounds,
          MbxEdgeInsets(
            top: padding,
            left: padding,
            bottom: padding,
            right: padding,
          ),
          0.0,
          0.0,
          null,
          null,
        );
        if (animate) {
          await _mapboxMap!.flyTo(camera, MapAnimationOptions(duration: 900));
        } else {
          await _mapboxMap!.setCamera(camera);
        }
      } catch (e) {
        debugPrint('⚠️ fitBounds native error: $e');
      }
    };

    controller.setMaxBoundsImpl = (west, south, east, north) async {
      if (_mapboxMap == null) return;
      try {
        if (west == null || south == null || east == null || north == null) {
          await _mapboxMap!.setBounds(CameraBoundsOptions(bounds: null));
          return;
        }
        final bounds = CoordinateBounds(
          southwest: Point(coordinates: Position(west, south)),
          northeast: Point(coordinates: Position(east, north)),
          infiniteBounds: false,
        );
        await _mapboxMap!.setBounds(CameraBoundsOptions(bounds: bounds));
      } catch (e) {
        debugPrint('⚠️ setMaxBounds native error: $e');
      }
    };

    controller.getCameraCenterImpl = () async {
      if (_mapboxMap == null) return null;
      try {
        final state = await _mapboxMap!.getCameraState();
        final center = state.center;
        final coords = center.coordinates;
        return MapPoint(coords.lng.toDouble(), coords.lat.toDouble());
      } catch (e) {
        debugPrint('⚠️ getCameraCenter native error: $e');
        return null;
      }
    };

    // POIs GeoJSON (Mapbox Pro)
    try {
      (controller as dynamic).setPoisGeoJsonImpl = (String fcJson) async {
        _poisGeoJsonString = fcJson;
        await _applyPoisGeoJsonIfReady();
      };
    } catch (_) {
      // Controller non compatible (pas de support POIs GeoJSON)
    }

    // POI style (Mapbox Pro)
    try {
      final current = (controller as dynamic).poiStyle;
      if (current is MasLivePoiStyle) {
        _poiStyle = current;
      }
    } catch (_) {
      // ignore
    }
    try {
      (controller as dynamic).setPoiStyleImpl = (MasLivePoiStyle style) async {
        _poiStyle = style;
        await _applyPoiStyleIfReady();
      };
    } catch (_) {
      // ignore
    }
  }

  Future<void> _applyPoiStyleIfReady() async {
    final map = _mapboxMap;
    if (map == null) return;
    if (!_styleLoaded) return;

    String cssHex(Color c) {
      final r = (c.r * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
      final g = (c.g * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
      final b = (c.b * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
      return '#${(r + g + b).toUpperCase()}';
    }

    final defaultFillHex = cssHex(_poiStyle.circleColor);
    final defaultStrokeHex = cssHex(_poiStyle.circleStrokeColor);

    final fillColorExpr = <dynamic>[
      'coalesce',
      ['to-color', ['get', 'fillColor']],
      ['to-color', defaultFillHex],
    ];
    final fillOpacityExpr = <dynamic>['coalesce', ['get', 'fillOpacity'], 0.20];
    final lineColorExpr = <dynamic>[
      'coalesce',
      ['to-color', ['get', 'strokeColor']],
      ['to-color', defaultStrokeHex],
    ];
    final lineWidthExpr = <dynamic>['coalesce', ['get', 'strokeWidth'], 2.0];

    try {
      await map.style.setStyleLayerProperty(
        _poiLayerId,
        'circle-radius',
        _poiStyle.circleRadius,
      );
    } catch (_) {
      // ignore
    }
    try {
      await map.style.setStyleLayerProperty(
        _poiLayerId,
        'circle-color',
        _poiStyle.circleColor.toARGB32(),
      );
    } catch (_) {
      // ignore
    }
    try {
      await map.style.setStyleLayerProperty(
        _poiLayerId,
        'circle-stroke-width',
        _poiStyle.circleStrokeWidth,
      );
    } catch (_) {
      // ignore
    }
    try {
      await map.style.setStyleLayerProperty(
        _poiLayerId,
        'circle-stroke-color',
        _poiStyle.circleStrokeColor.toARGB32(),
      );
    } catch (_) {
      // ignore
    }

    // Zones (Polygon)
    try {
      await map.style.setStyleLayerProperty(_poiFillLayerId, 'fill-color', fillColorExpr);
      await map.style.setStyleLayerProperty(
        _poiFillLayerId,
        'fill-opacity',
        fillOpacityExpr,
      );
    } catch (_) {
      // ignore
    }

    Future<void> applyLineStyle(String layerId) async {
      try {
        await map.style.setStyleLayerProperty(layerId, 'line-color', lineColorExpr);
      } catch (_) {
        // ignore
      }
      try {
        await map.style.setStyleLayerProperty(layerId, 'line-width', lineWidthExpr);
      } catch (_) {
        // ignore
      }
      try {
        await map.style.setStyleLayerProperty(layerId, 'line-opacity', 0.85);
      } catch (_) {
        // ignore
      }
    }

    await applyLineStyle(_poiLineLayerId);
    await applyLineStyle(_poiLineLayerDashedId);
    await applyLineStyle(_poiLineLayerDottedId);
  }

  Future<void> _applyPoisGeoJsonIfReady() async {
    final map = _mapboxMap;
    if (map == null) return;
    if (!_styleLoaded) return;

    await _ensurePoiPatternImages();

    // Remove + add source, puis layer si besoin.
    try {
      await map.style.removeStyleLayer(_poiLayerId);
    } catch (_) {
      // ignore
    }
    try {
      await map.style.removeStyleLayer('ly_pois_line');
    } catch (_) {
      // ignore (legacy)
    }
    try {
      await map.style.removeStyleLayer(_poiPatternLayerId);
    } catch (_) {
      // ignore
    }
    try {
      await map.style.removeStyleLayer(_poiLineLayerId);
    } catch (_) {
      // ignore
    }
    try {
      await map.style.removeStyleLayer(_poiLineLayerDashedId);
    } catch (_) {
      // ignore
    }
    try {
      await map.style.removeStyleLayer(_poiLineLayerDottedId);
    } catch (_) {
      // ignore
    }
    try {
      await map.style.removeStyleLayer(_poiFillLayerId);
    } catch (_) {
      // ignore
    }
    try {
      await map.style.removeStyleSource(_poiSourceId);
    } catch (_) {
      // ignore
    }

    // Si empty FeatureCollection => rien à afficher (mais on laisse la source absente)
    if (_poisGeoJsonString.contains('"features":[]')) {
      return;
    }

    try {
      await map.style.addSource(
        GeoJsonSource(id: _poiSourceId, data: _poisGeoJsonString),
      );
    } catch (_) {
      // ignore
    }

    // Zones (Polygon): fill + outline
    try {
      await map.style.addLayer(
        FillLayer(
          id: _poiFillLayerId,
          sourceId: _poiSourceId,
          fillColor: _poiStyle.circleColor.toARGB32(),
          fillOpacity: 0.20,
        ),
      );
      await map.style.setStyleLayerProperty(_poiFillLayerId, 'filter', [
        '==',
        ['geometry-type'],
        'Polygon',
      ]);

      // Style depuis properties (comme web): fillColor/fillOpacity
      await map.style.setStyleLayerProperty(_poiFillLayerId, 'fill-color', [
        'coalesce',
        ['get', 'fillColor'],
        _poiStyle.circleColor.toARGB32(),
      ]);
      await map.style.setStyleLayerProperty(_poiFillLayerId, 'fill-opacity', [
        'coalesce',
        ['get', 'fillOpacity'],
        0.20,
      ]);
    } catch (_) {
      // ignore
    }

    // Pattern overlay (Polygon) : fill-pattern avec alpha, au-dessus du fond
    try {
      await map.style.addLayer(
        FillLayer(
          id: _poiPatternLayerId,
          sourceId: _poiSourceId,
          fillOpacity: 0.55,
        ),
      );
      await map.style.setStyleLayerProperty(_poiPatternLayerId, 'filter', [
        'all',
        ['==', ['geometry-type'], 'Polygon'],
        ['has', 'fillPattern'],
      ]);
      await map.style.setStyleLayerProperty(
        _poiPatternLayerId,
        'fill-pattern',
        ['get', 'fillPattern'],
      );
      await map.style.setStyleLayerProperty(
        _poiPatternLayerId,
        'fill-opacity',
        ['coalesce', ['get', 'patternOpacity'], 0.55],
      );
    } catch (_) {
      // ignore
    }
    try {
      await map.style.addLayer(
        LineLayer(
          id: _poiLineLayerId,
          sourceId: _poiSourceId,
          lineColor: _poiStyle.circleStrokeColor.toARGB32(),
          lineWidth: 2.0,
          lineOpacity: 0.85,
        ),
      );
      await map.style.setStyleLayerProperty(_poiLineLayerId, 'filter', [
        'all',
        ['==', ['geometry-type'], 'Polygon'],
        [
          'any',
          ['!', ['has', 'strokeDash']],
          ['==', ['get', 'strokeDash'], 'solid'],
        ],
      ]);

      await map.style.setStyleLayerProperty(_poiLineLayerId, 'line-color', [
        'coalesce',
        ['get', 'strokeColor'],
        _poiStyle.circleStrokeColor.toARGB32(),
      ]);
      await map.style.setStyleLayerProperty(_poiLineLayerId, 'line-width', [
        'coalesce',
        ['get', 'strokeWidth'],
        2.0,
      ]);
    } catch (_) {
      // ignore
    }

    try {
      await map.style.addLayer(
        LineLayer(
          id: _poiLineLayerDashedId,
          sourceId: _poiSourceId,
          lineColor: _poiStyle.circleStrokeColor.toARGB32(),
          lineWidth: 2.0,
          lineOpacity: 0.85,
        ),
      );
      await map.style.setStyleLayerProperty(_poiLineLayerDashedId, 'filter', [
        'all',
        ['==', ['geometry-type'], 'Polygon'],
        ['==', ['get', 'strokeDash'], 'dashed'],
      ]);
      await map.style.setStyleLayerProperty(_poiLineLayerDashedId, 'line-dasharray', [4, 2]);

      await map.style.setStyleLayerProperty(_poiLineLayerDashedId, 'line-color', [
        'coalesce',
        ['get', 'strokeColor'],
        _poiStyle.circleStrokeColor.toARGB32(),
      ]);
      await map.style.setStyleLayerProperty(_poiLineLayerDashedId, 'line-width', [
        'coalesce',
        ['get', 'strokeWidth'],
        2.0,
      ]);
    } catch (_) {
      // ignore
    }

    try {
      await map.style.addLayer(
        LineLayer(
          id: _poiLineLayerDottedId,
          sourceId: _poiSourceId,
          lineColor: _poiStyle.circleStrokeColor.toARGB32(),
          lineWidth: 2.0,
          lineOpacity: 0.85,
        ),
      );
      await map.style.setStyleLayerProperty(_poiLineLayerDottedId, 'filter', [
        'all',
        ['==', ['geometry-type'], 'Polygon'],
        ['==', ['get', 'strokeDash'], 'dotted'],
      ]);
      await map.style.setStyleLayerProperty(_poiLineLayerDottedId, 'line-dasharray', [1, 2]);

      await map.style.setStyleLayerProperty(_poiLineLayerDottedId, 'line-color', [
        'coalesce',
        ['get', 'strokeColor'],
        _poiStyle.circleStrokeColor.toARGB32(),
      ]);
      await map.style.setStyleLayerProperty(_poiLineLayerDottedId, 'line-width', [
        'coalesce',
        ['get', 'strokeWidth'],
        2.0,
      ]);
    } catch (_) {
      // ignore
    }

    // Layer POIs: circles (simple, scalable)
    try {
      await map.style.addLayer(
        CircleLayer(
          id: _poiLayerId,
          sourceId: _poiSourceId,
          circleRadius: _poiStyle.circleRadius,
          circleColor: _poiStyle.circleColor.toARGB32(),
          circleStrokeColor: _poiStyle.circleStrokeColor.toARGB32(),
          circleStrokeWidth: _poiStyle.circleStrokeWidth,
        ),
      );
      await map.style.setStyleLayerProperty(_poiLayerId, 'filter', [
        '==',
        ['geometry-type'],
        'Point',
      ]);
    } catch (_) {
      // ignore
    }
  }

  Future<void> _ensureMarkersManager() async {
    if (_markersManager != null) return;
    _markersManager = await _mapboxMap?.annotations
        .createPointAnnotationManager();
  }

  Future<void> _ensurePolylineManager() async {
    if (_polylineManager != null) return;
    _polylineManager = await _mapboxMap?.annotations
        .createPolylineAnnotationManager();
  }

  Future<void> _ensurePolygonManager() async {
    if (_polygonManager != null) return;
    _polygonManager = await _mapboxMap?.annotations
        .createPolygonAnnotationManager();
  }

  Future<void> _ensureUserLocationManager() async {
    if (_userLocationManager != null) return;
    _userLocationManager = await _mapboxMap?.annotations
        .createPointAnnotationManager();
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    // Le controller peut être branché dès que l'instance MapboxMap existe,
    // même si le style/tiles ne sont pas encore complètement prêts.
    if (!_isMapReady) {
      _isMapReady = true;
      _connectController();
    }

    final pending = _pendingStyleUrlToApply;
    if (pending != null) {
      _pendingStyleUrlToApply = null;
      unawaited(_applyStyleUri(pending, mapOverride: mapboxMap));
    }

    // IMPORTANT: on NE notifie plus l'hôte ici.
    // SplashWrapperPage attend désormais un signal plus strict (Map fully loaded).
  }

  Future<void> _reapplyCachedOverlaysAfterStyleLoad() async {
    // Markers
    final markers = _lastMarkers;
    if (markers != null) {
      await _ensureMarkersManager();
      await _markersManager?.deleteAll();
      for (final m in markers) {
        final opt = PointAnnotationOptions(
          geometry: Point(coordinates: Position(m.lng, m.lat)),
          iconImage: 'marker-15',
          iconSize: m.size,
          iconColor: m.color.toARGB32(),
          textField: m.label,
          textSize: 12.0,
          textOffset: const [0.0, 1.2],
          textColor: Colors.black.toARGB32(),
          textHaloColor: Colors.white.toARGB32(),
          textHaloWidth: 1.0,
        );
        await _markersManager?.create(opt);
      }
    }

    // Polygon
    final polygon = _lastPolygon;
    if (polygon != null && polygon.show) {
      await _ensurePolygonManager();
      await _polygonManager?.deleteAll();
      final coords = polygon.points.map((p) => Position(p.lng, p.lat)).toList();
      final opt = PolygonAnnotationOptions(
        geometry: Polygon(coordinates: [coords]),
        fillColor: polygon.fillColor.toARGB32(),
        fillOutlineColor: polygon.strokeColor.toARGB32(),
      );
      await _polygonManager?.create(opt);
    }

    // Polyline
    final poly = _lastPolyline;
    if (poly != null && poly.show) {
      final segJson = poly.options.segmentsGeoJson;
      final useSegments = segJson != null && segJson.trim().isNotEmpty;
      if (useSegments) {
        _pendingPolyline = (
          points: poly.points,
          color: poly.color,
          width: poly.width,
          show: poly.show,
          options: poly.options,
        );
        await _polylineManager?.deleteAll();
        if (_styleLoaded && _mapboxMap != null) {
          await _renderSegmentedPolylineNative(
            points: poly.points,
            color: poly.color,
            width: poly.width,
            options: poly.options,
          );
        }
      } else {
        _pendingPolyline = null;
        await _removeRouteLayersAndSourcesIfAny();

        await _ensurePolylineManager();
        await _polylineManager?.deleteAll();
        final coords = poly.points.map((p) => Position(p.lng, p.lat)).toList();

        final baseWidth = poly.width;
        final shadowEnabled = poly.options.shadow3d;
        final roadLike = poly.options.roadLike;

        int to255(double v) => (v * 255.0).round().clamp(0, 255);
        int argbWithAlpha(Color c, int a) =>
            Color.fromARGB(a, to255(c.r), to255(c.g), to255(c.b)).toARGB32();
        final shadowColor = argbWithAlpha(const Color(0xFF000000), 90);
        final casingColor = argbWithAlpha(const Color(0xFF000000), 140);
        final centerColor = argbWithAlpha(const Color(0xFFFFFFFF), 190);

        Future<void> addLine({
          required int lineColor,
          required double lineWidth,
        }) async {
          final opt = PolylineAnnotationOptions(
            geometry: LineString(coordinates: coords),
            lineColor: lineColor,
            lineWidth: lineWidth,
          );
          await _polylineManager?.create(opt);
        }

        if (!roadLike) {
          await addLine(lineColor: poly.color.toARGB32(), lineWidth: baseWidth);
        } else {
          if (shadowEnabled) {
            await addLine(lineColor: shadowColor, lineWidth: baseWidth + 8.0);
          }
          await addLine(lineColor: casingColor, lineWidth: baseWidth + 5.0);
          await addLine(lineColor: poly.color.toARGB32(), lineWidth: baseWidth);
          final centerWidth = (baseWidth * 0.33).clamp(1.0, baseWidth);
          await addLine(lineColor: centerColor, lineWidth: centerWidth);
        }
      }
    }
  }

  @override
  void dispose() {
    _onPointAddedCallback = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalized = _normalizeMapboxStyleUri(widget.styleUrl ?? '');
    final styleUri = normalized.isEmpty ? MapboxStyles.STANDARD : normalized;

    final map = MapWidget(
      cameraOptions: CameraOptions(
        center: Point(
          coordinates: Position(widget.initialLng, widget.initialLat),
        ),
        zoom: widget.initialZoom,
        pitch: widget.initialPitch,
        bearing: widget.initialBearing,
      ),
      styleUri: styleUri,
      onMapCreated: _onMapCreated,
      // Mapbox: style chargé + toutes les tuiles visibles rendues.
      // On s'en sert pour masquer le splash au bon moment.
      onMapLoadedListener: (_) {
        _notifyHostMapReadyIfNeeded();
      },
      onStyleLoadedListener: (_) async {
        _styleLoaded = true;
        if (mounted) {
          setState(() {
            _styleLoadError = null;
          });
        }
        _patternImagesReady = false;
        await _applyPoisGeoJsonIfReady();
        await _applyPoiStyleIfReady();

        // Appliquer une polyline segmentée en attente (si setPolyline appelé avant style loaded)
        final pending = _pendingPolyline;
        if (pending != null) {
          final segJson = pending.options.segmentsGeoJson;
          final useSegments = segJson != null && segJson.trim().isNotEmpty;
          if (useSegments) {
            await _renderSegmentedPolylineNative(
              points: pending.points,
              color: pending.color,
              width: pending.width,
              options: pending.options,
            );
          }
        }

        // Après un reload de style (ou un changement de styleUrl), il faut restaurer
        // les overlays applicatifs (annotations + éventuels segments).
        await _reapplyCachedOverlaysAfterStyleLoad();
      },
      onTapListener: (gestureContext) async {
        final controller = widget.controller;

        // gestureContext.point est de type Point (Mapbox) avec coordinates
        final lngLat = gestureContext.point.coordinates;
        final lng = lngLat.lng.toDouble();
        final lat = lngLat.lat.toDouble();

        // 1) Hit-testing POI (si layer présent)
        bool didHitPoi = false;
        final map = _mapboxMap;
        if (map != null) {
          try {
            final res = await map.queryRenderedFeatures(
              RenderedQueryGeometry.fromScreenCoordinate(
                gestureContext.touchPosition,
              ),
              RenderedQueryOptions(
                layerIds: <String>[
                  _poiFillLayerId,
                  _poiPatternLayerId,
                  _poiLineLayerDottedId,
                  _poiLineLayerDashedId,
                  _poiLineLayerId,
                  _poiLayerId,
                ],
                filter: null,
              ),
            );
            if (res.isNotEmpty) {
              final feature = res.first?.queriedFeature.feature;
              if (feature != null) {
                final props =
                    (feature['properties'] as Map?)?.cast<String, dynamic>() ??
                    const <String, dynamic>{};
                final poiId = (props['poiId'] ?? feature['id'] ?? '')
                    .toString();
                if (poiId.isNotEmpty) {
                  didHitPoi = true;
                  try {
                    final cb =
                        (controller as dynamic).onPoiTap
                            as void Function(String)?;
                    cb?.call(poiId);
                  } catch (_) {
                    // ignore
                  }
                }
              }
            }
          } catch (_) {
            // ignore (style pas prêt / layer absent)
          }
        }

        if (didHitPoi) return;

        // 2) Mode édition: callback onPointAdded
        if (_onPointAddedCallback != null) {
          _onPointAddedCallback!(lat, lng);
        }

        // 3) Callback Mapbox Pro: onMapTap
        try {
          final cb =
              (controller as dynamic).onMapTap
                  as void Function(double, double)?;
          cb?.call(lat, lng);
        } catch (_) {
          // ignore
        }

        // 4) Callback onTap standard
        widget.onTap?.call(MapPoint(lng, lat));
      },
    );

    final err = _styleLoadError;
    if (err == null || err.isEmpty) return map;

    return Stack(
      children: [
        Positioned.fill(child: map),
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              color: Colors.black.withValues(alpha: 0.04),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 40),
                        const SizedBox(height: 10),
                        const Text(
                          'Style Mapbox non chargé',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          err,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _ensurePoiPatternImages() async {
    if (_patternImagesReady) return;
    final map = _mapboxMap;
    if (map == null) return;
    if (!_styleLoaded) return;

    Future<void> add(String id, MbxImage img) async {
      try {
        await map.style.addStyleImage(
          id,
          1.0,
          img,
          false,
          const [],
          const [],
          null,
        );
      } catch (_) {
        // ignore (déjà présent / style)
      }
    }

    try {
      await add(_patDiag, _buildPatternDiagImage());
      await add(_patCross, _buildPatternCrossImage());
      await add(_patDots, _buildPatternDotsImage());
      _patternImagesReady = true;
    } catch (_) {
      // ignore
    }
  }

  MbxImage _buildPatternDiagImage() {
    const w = 32;
    const h = 32;
    final data = Uint8List(w * h * 4);
    void setPx(int x, int y, int r, int g, int b, int a) {
      final idx = (y * w + x) * 4;
      data[idx] = r;
      data[idx + 1] = g;
      data[idx + 2] = b;
      data[idx + 3] = a;
    }

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final onLine = ((x - y) % 8 == 0) || ((x - y - 1) % 8 == 0);
        if (onLine) {
          setPx(x, y, 0, 0, 0, 96);
        } else {
          setPx(x, y, 0, 0, 0, 0);
        }
      }
    }

    return MbxImage(width: w, height: h, data: data);
  }

  MbxImage _buildPatternCrossImage() {
    const w = 32;
    const h = 32;
    final data = Uint8List(w * h * 4);
    void setPx(int x, int y, int r, int g, int b, int a) {
      final idx = (y * w + x) * 4;
      data[idx] = r;
      data[idx + 1] = g;
      data[idx + 2] = b;
      data[idx + 3] = a;
    }

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final d1 = ((x - y) % 10 == 0) || ((x - y - 1) % 10 == 0);
        final d2 = (((x + y) % 10) == 0) || (((x + y + 1) % 10) == 0);
        if (d1 || d2) {
          setPx(x, y, 0, 0, 0, 86);
        } else {
          setPx(x, y, 0, 0, 0, 0);
        }
      }
    }
    return MbxImage(width: w, height: h, data: data);
  }

  MbxImage _buildPatternDotsImage() {
    const w = 32;
    const h = 32;
    final data = Uint8List(w * h * 4);
    void setPx(int x, int y, int r, int g, int b, int a) {
      final idx = (y * w + x) * 4;
      data[idx] = r;
      data[idx + 1] = g;
      data[idx + 2] = b;
      data[idx + 3] = a;
    }

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final dx = (x - 3) % 8;
        final dy = (y - 3) % 8;
        final dot = dx >= 0 && dy >= 0 && dx < 2 && dy < 2;
        if (dot) {
          setPx(x, y, 0, 0, 0, 96);
        } else {
          setPx(x, y, 0, 0, 0, 0);
        }
      }
    }
    return MbxImage(width: w, height: h, data: data);
  }

  // -------------------------
  // Route native: rendu segments
  // -------------------------

  Future<void> _removeRouteLayersAndSourcesIfAny() async {
    final map = _mapboxMap;
    if (map == null) return;
    if (!_styleLoaded) return;

    // Layers
    for (final layerId in <String>[
      _layerRoutePlain,
      _layerRouteCore,
      _layerRouteCasing,
      _layerRouteSideL,
      _layerRouteSideR,
      _layerRouteShadow,
    ]) {
      try {
        await map.style.removeStyleLayer(layerId);
      } catch (_) {
        // ignore
      }
    }

    // Sources
    for (final sourceId in <String>[_segmentsSourceId, _routeSourceId]) {
      try {
        await map.style.removeStyleSource(sourceId);
      } catch (_) {
        // ignore
      }
    }
  }

  String _buildRouteFeatureCollectionJson(List<MapPoint> points) {
    if (points.length < 2) {
      return '{"type":"FeatureCollection","features":[]}';
    }
    final coords = [
      for (final p in points) [p.lng, p.lat],
    ];
    return jsonEncode({
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': <String, dynamic>{},
          'geometry': {'type': 'LineString', 'coordinates': coords},
        },
      ],
    });
  }

  Future<void> _tryAddRouteSource(String id, String data) async {
    try {
      await _mapboxMap?.style.addSource(GeoJsonSource(id: id, data: data));
    } catch (_) {
      // ignore
    }
  }

  Future<void> _tryAddRouteLayer(Layer layer) async {
    try {
      await _mapboxMap?.style.addLayer(layer);
    } catch (_) {
      // ignore
    }
  }

  Future<void> _ensureRouteLayersForSegments({
    required bool roadLike,
    required bool shadow3d,
    required double width,
    required double opacity,
    required double casingWidth,
    required int casingColor,
    String? lineCap,
    String? lineJoin,
  }) async {
    final map = _mapboxMap;
    if (map == null) return;
    if (!_styleLoaded) return;

    // Créer les layers (avec valeurs par défaut), puis config via setStyleLayerProperty.
    if (roadLike) {
      if (shadow3d) {
        await _tryAddRouteLayer(
          LineLayer(
            id: _layerRouteShadow,
            sourceId: _routeSourceId,
            lineColor: const Color(0xFF000000).toARGB32(),
            lineOpacity: opacity,
            lineWidth: width + 8.0,
            lineBlur: 1.2,
            lineJoin: LineJoin.ROUND,
            lineCap: LineCap.ROUND,
          ),
        );
      }

      // Faces latérales (relief visible): par défaut invisibles (opacity=0)
      // et configurées ensuite via setStyleLayerProperty.
      await _tryAddRouteLayer(
        LineLayer(
          id: _layerRouteSideL,
          sourceId: _segmentsSourceId,
          lineColor: const Color(0xFF1A73E8).toARGB32(),
          lineOpacity: 0.0,
          lineWidth: width + 2.0,
          lineBlur: 0.0,
          lineJoin: LineJoin.ROUND,
          lineCap: LineCap.ROUND,
        ),
      );
      await _tryAddRouteLayer(
        LineLayer(
          id: _layerRouteSideR,
          sourceId: _segmentsSourceId,
          lineColor: const Color(0xFF1A73E8).toARGB32(),
          lineOpacity: 0.0,
          lineWidth: width + 2.0,
          lineBlur: 0.0,
          lineJoin: LineJoin.ROUND,
          lineCap: LineCap.ROUND,
        ),
      );

      await _tryAddRouteLayer(
        LineLayer(
          id: _layerRouteCasing,
          sourceId: _routeSourceId,
          lineColor: casingColor,
          lineOpacity: opacity,
          lineWidth: casingWidth,
          lineJoin: LineJoin.ROUND,
          lineCap: LineCap.ROUND,
        ),
      );
      await _tryAddRouteLayer(
        LineLayer(
          id: _layerRouteCore,
          sourceId: _segmentsSourceId,
          lineColor: const Color(0xFF1A73E8).toARGB32(),
          lineOpacity: opacity,
          lineWidth: width,
          lineJoin: LineJoin.ROUND,
          lineCap: LineCap.ROUND,
        ),
      );
    } else {
      await _tryAddRouteLayer(
        LineLayer(
          id: _layerRoutePlain,
          sourceId: _segmentsSourceId,
          lineColor: const Color(0xFF1A73E8).toARGB32(),
          lineOpacity: opacity,
          lineWidth: width,
          lineJoin: LineJoin.ROUND,
          lineCap: LineCap.ROUND,
        ),
      );
    }

    // Cap/join: si fournis (web compat), appliquer via propriétés.
    final cap = (lineCap == 'butt' || lineCap == 'square' || lineCap == 'round')
        ? lineCap
        : null;
    final join =
        (lineJoin == 'bevel' || lineJoin == 'miter' || lineJoin == 'round')
        ? lineJoin
        : null;
    if (cap == null && join == null) return;
    for (final layerId in <String>[
      if (roadLike) ...[
        if (shadow3d) _layerRouteShadow,
        _layerRouteSideL,
        _layerRouteSideR,
        _layerRouteCasing,
        _layerRouteCore,
      ] else
        _layerRoutePlain,
    ]) {
      try {
        if (cap != null) {
          await map.style.setStyleLayerProperty(layerId, 'line-cap', cap);
        }
      } catch (_) {}
      try {
        if (join != null) {
          await map.style.setStyleLayerProperty(layerId, 'line-join', join);
        }
      } catch (_) {}
    }
  }

  Future<void> _applySegmentsExpressions({
    required bool roadLike,
    required double fallbackWidth,
    required double fallbackOpacity,
    required Color fallbackColor,
  }) async {
    final map = _mapboxMap;
    if (map == null) return;
    if (!_styleLoaded) return;

    // Les segments sont attendus avec propriétés:
    // - color: string (rgba(...) ou #RRGGBB/#AARRGGBB)
    // - width: number
    // - opacity: number
    // Note: sur natif, il est plus sûr de forcer la conversion en type "color"
    // pour éviter les divergences de parsing entre formats (#hex vs rgba()).
    final lineColorExpr = [
      'to-color',
      ['get', 'color'],
    ];
    // Zoom-aware width:
    // IMPORTANT: Mapbox n'autorise ['zoom'] qu'en entrée d'une expression
    // top-level 'step'/'interpolate'. Donc la propriété 'line-width' doit être
    // une expression 'interpolate' au niveau racine.
    final baseWidthExpr = <dynamic>[
      'coalesce',
      ['get', 'width'],
      fallbackWidth,
    ];
    final lineWidthExpr = <dynamic>[
      'interpolate',
      ['linear'],
      ['zoom'],
      10,
      <dynamic>['*', baseWidthExpr, 0.30],
      12,
      <dynamic>['*', baseWidthExpr, 0.50],
      14,
      <dynamic>['*', baseWidthExpr, 0.80],
      16,
      baseWidthExpr,
      22,
      baseWidthExpr,
    ];
    final lineOpacityExpr = [
      'coalesce',
      ['get', 'opacity'],
      fallbackOpacity,
    ];

    final layerId = roadLike ? _layerRouteCore : _layerRoutePlain;
    try {
      await map.style.setStyleLayerProperty(
        layerId,
        'line-color',
        lineColorExpr,
      );
      await map.style.setStyleLayerProperty(
        layerId,
        'line-width',
        lineWidthExpr,
      );
      await map.style.setStyleLayerProperty(
        layerId,
        'line-opacity',
        lineOpacityExpr,
      );
    } catch (_) {
      // Fallback: valeurs constantes (SDK sans expressions)
      try {
        await map.style.setStyleLayerProperty(
          layerId,
          'line-color',
          fallbackColor.toARGB32(),
        );
      } catch (_) {}
      try {
        await map.style.setStyleLayerProperty(
          layerId,
          'line-width',
          fallbackWidth,
        );
      } catch (_) {}
      try {
        await map.style.setStyleLayerProperty(
          layerId,
          'line-opacity',
          fallbackOpacity,
        );
      } catch (_) {}
    }

    // Appliquer des expressions aussi aux faces latérales (si roadLike).
    if (!roadLike) return;

    final sideBaseWidthExpr = <dynamic>['+', baseWidthExpr, 2.0];
    final sideWidthExpr = <dynamic>[
      'interpolate',
      ['linear'],
      ['zoom'],
      10,
      <dynamic>['*', sideBaseWidthExpr, 0.30],
      12,
      <dynamic>['*', sideBaseWidthExpr, 0.50],
      14,
      <dynamic>['*', sideBaseWidthExpr, 0.80],
      16,
      sideBaseWidthExpr,
      22,
      sideBaseWidthExpr,
    ];
    final sideOpacityExpr = <dynamic>['*', lineOpacityExpr, 0.55];

    for (final sideLayerId in <String>[_layerRouteSideL, _layerRouteSideR]) {
      try {
        await map.style.setStyleLayerProperty(
          sideLayerId,
          'line-color',
          lineColorExpr,
        );
        await map.style.setStyleLayerProperty(
          sideLayerId,
          'line-width',
          sideWidthExpr,
        );
        await map.style.setStyleLayerProperty(
          sideLayerId,
          'line-opacity',
          sideOpacityExpr,
        );
        await map.style.setStyleLayerProperty(
          sideLayerId,
          'line-blur',
          0.0,
        );
      } catch (_) {
        // Fallback: valeurs constantes (SDK sans expressions)
        try {
          await map.style.setStyleLayerProperty(
            sideLayerId,
            'line-color',
            fallbackColor.toARGB32(),
          );
        } catch (_) {}
        try {
          await map.style.setStyleLayerProperty(
            sideLayerId,
            'line-width',
            fallbackWidth + 2.0,
          );
        } catch (_) {}
        try {
          await map.style.setStyleLayerProperty(
            sideLayerId,
            'line-opacity',
            (fallbackOpacity * 0.55).clamp(0.0, 1.0),
          );
        } catch (_) {}
        try {
          await map.style.setStyleLayerProperty(
            sideLayerId,
            'line-blur',
            0.0,
          );
        } catch (_) {}
      }
    }
  }

  Future<void> _renderSegmentedPolylineNative({
    required List<MapPoint> points,
    required Color color,
    required double width,
    required PolylineRenderOptions options,
  }) async {
    final map = _mapboxMap;
    if (map == null) return;
    if (!_styleLoaded) return;
    if (points.length < 2) {
      await _removeRouteLayersAndSourcesIfAny();
      return;
    }

    // Nettoyage: éviter doublons si on réapplique.
    await _removeRouteLayersAndSourcesIfAny();

    final opacity = (options.opacity ?? 1.0).clamp(0.0, 1.0);
    final roadLike = options.roadLike;
    final shadow3d = options.shadow3d;
    final thickness3d = (options.thickness3d ?? 1.0).clamp(0.6, 1.8);
    final shadowOpacityFactor = (options.shadowOpacity ?? 0.25).clamp(0.0, 1.0);
    final shadowBlurBase = (options.shadowBlur ?? 1.2).clamp(0.0, 20.0);
    final segJson = options.segmentsGeoJson;
    if (segJson == null || segJson.trim().isEmpty) return;

    final casingWidth =
        (options.casingWidth != null && options.casingWidth! > 0)
        ? options.casingWidth!
        : (width + 5.0);
    final casingColor = (options.casingColor ?? const Color(0xFF000000))
        .toARGB32();

    final routeFc = _buildRouteFeatureCollectionJson(points);
    await _tryAddRouteSource(_routeSourceId, routeFc);
    await _tryAddRouteSource(_segmentsSourceId, segJson);

    await _ensureRouteLayersForSegments(
      roadLike: roadLike,
      shadow3d: shadow3d,
      width: width,
      opacity: opacity,
      casingWidth: casingWidth,
      casingColor: casingColor,
      lineCap: options.lineCap,
      lineJoin: options.lineJoin,
    );

    // Hauteur simulée (translate) – alignée avec le Web bridge.
    final elevationPx = (options.elevationPx ?? 0.0).clamp(0.0, 40.0);
    final translate = elevationPx > 0
        ? <double>[0.0, -elevationPx]
        : const <double>[0.0, 0.0];
    for (final layerId in <String>[
      if (roadLike) ...[
        if (shadow3d) _layerRouteShadow,
        _layerRouteSideL,
        _layerRouteSideR,
        _layerRouteCasing,
        _layerRouteCore,
      ] else
        _layerRoutePlain,
    ]) {
      try {
        await map.style.setStyleLayerProperty(layerId, 'line-translate', translate);
      } catch (_) {}
      try {
        await map.style.setStyleLayerProperty(
          layerId,
          'line-translate-anchor',
          'map',
        );
      } catch (_) {}
    }

    // Appliquer le même scaling de largeur sur les couches "roadLike" (casing/shadow)
    // pour éviter un tracé trop épais quand on dézoome.
    if (roadLike) {
      final casingWidthExpr = <dynamic>[
        'interpolate',
        ['linear'],
        ['zoom'],
        10,
        casingWidth * 0.30,
        12,
        casingWidth * 0.50,
        14,
        casingWidth * 0.80,
        16,
        casingWidth,
        22,
        casingWidth,
      ];
      try {
        await map.style.setStyleLayerProperty(
          _layerRouteCasing,
          'line-width',
          casingWidthExpr,
        );
      } catch (_) {
        // ignore
      }

      if (shadow3d) {
        final shadowWidth = width + (8.0 * thickness3d);
        final shadowWidthExpr = <dynamic>[
          'interpolate',
          ['linear'],
          ['zoom'],
          10,
          shadowWidth * 0.30,
          12,
          shadowWidth * 0.50,
          14,
          shadowWidth * 0.80,
          16,
          shadowWidth,
          22,
          shadowWidth,
        ];
        try {
          await map.style.setStyleLayerProperty(
            _layerRouteShadow,
            'line-width',
            shadowWidthExpr,
          );
        } catch (_) {
          // ignore
        }

        // Relief (ruban 3D): accentuer l'ombre (opacity/blur) + décalage viewport.
        final shadowOpacity = (opacity * shadowOpacityFactor).clamp(0.0, 1.0);
        final shadowBlur = (shadowBlurBase * thickness3d).clamp(0.0, 40.0);
        try {
          await map.style.setStyleLayerProperty(
            _layerRouteShadow,
            'line-opacity',
            shadowOpacity,
          );
        } catch (_) {}
        try {
          await map.style.setStyleLayerProperty(
            _layerRouteShadow,
            'line-blur',
            shadowBlur,
          );
        } catch (_) {}

        final relief = (thickness3d - 1.0);
        final shadowDx = (relief > 0) ? (relief * 3.0) : 0.0;
        final shadowDy = (relief > 0) ? (relief * 4.0) : 0.0;
        final shadowTranslate = <double>[shadowDx, shadowDy];
        try {
          await map.style.setStyleLayerProperty(
            _layerRouteShadow,
            'line-translate',
            shadowTranslate,
          );
        } catch (_) {}
        try {
          await map.style.setStyleLayerProperty(
            _layerRouteShadow,
            'line-translate-anchor',
            'viewport',
          );
        } catch (_) {}
      }

      // Relief (faces latérales): hauteur pilotée par thickness3d.
      final relief = (thickness3d - 1.0).clamp(0.0, 1.0);
      final sideDx = relief * 3.0;
      final sideDy = relief * 10.0;
      final sideTranslateL = <double>[-sideDx, -elevationPx + sideDy];
      final sideTranslateR = <double>[sideDx, -elevationPx + sideDy];

      for (final entry in <({String id, List<double> translate})>[
        (id: _layerRouteSideL, translate: sideTranslateL),
        (id: _layerRouteSideR, translate: sideTranslateR),
      ]) {
        try {
          await map.style.setStyleLayerProperty(
            entry.id,
            'line-translate',
            entry.translate,
          );
        } catch (_) {}
        try {
          await map.style.setStyleLayerProperty(
            entry.id,
            'line-translate-anchor',
            'map',
          );
        } catch (_) {}
        if (relief <= 0.01) {
          try {
            await map.style.setStyleLayerProperty(entry.id, 'line-opacity', 0.0);
          } catch (_) {}
        }
      }
    }

    // Appliquer expressions data-driven sur la layer principale.
    await _applySegmentsExpressions(
      roadLike: roadLike,
      fallbackWidth: width,
      fallbackOpacity: opacity,
      fallbackColor: color,
    );

    // Pour rester cohérent avec Web: pas de "center line" blanche en mode segments.
  }
}
