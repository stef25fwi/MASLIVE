// ignore_for_file: avoid_web_libraries_in_flutter, unsafe_html
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
// ignore: deprecated_member_use
import 'dart:html' as html;
// ignore: deprecated_member_use
import 'dart:js' as js;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import 'maslive_map_controller.dart';
import 'maslive_poi_style.dart';
import '../../services/mapbox_token_service.dart';

/// Implémentation Web de MasLiveMap
/// Utilise Mapbox GL JS via HtmlElementView avec API Phase 1 complète
class MasLiveMapWeb extends StatefulWidget {
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

  const MasLiveMapWeb({
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
  State<MasLiveMapWeb> createState() => _MasLiveMapWebState();
}

class _MasLiveMapWebState extends State<MasLiveMapWeb> {
  static const String _poiSourceId = 'src_pois';
  static const String _poiLayerId = 'ly_pois_circle';
  static const String _poiFillLayerId = 'ly_pois_fill';
  static const String _poiPatternLayerId = 'ly_pois_pattern';
  static const String _poiLineLayerId = 'ly_pois_line_solid';
  static const String _poiLineLayerDashedId = 'ly_pois_line_dashed';
  static const String _poiLineLayerDottedId = 'ly_pois_line_dotted';
  static const String _poiLineLayerLegacyId = 'ly_pois_line';

  static const String _patDiag = 'maslive_pat_diag';
  static const String _patCross = 'maslive_pat_cross';
  static const String _patDots = 'maslive_pat_dots';

  MasLivePoiStyle _poiStyle = const MasLivePoiStyle();

  String _mapboxToken = '';
  bool _isLoading = true;
  String? _initError;
  late final String _containerId;
  bool _isMapReady = false;
  void Function(double lat, double lng)? _onPointAddedCallback;
  Timer? _pendingResize;
  Size? _lastConstraintsSize;
  late final _MasliveMetricsObserver _metricsObserver;

  String _poisGeoJsonString = '{"type":"FeatureCollection","features":[]}';

  static const String _fallbackStyleUrl = 'mapbox://styles/mapbox/streets-v12';

  List<MapMarker>? _lastMarkers;
  ({
    List<MapPoint> points,
    Color color,
    double width,
    bool show,
    PolylineRenderOptions options,
  })?
  _lastPolyline;

  ({
    List<MapPoint> points,
    Color fillColor,
    Color strokeColor,
    double strokeWidth,
    bool show,
  })?
  _lastPolygon;

  String? _pendingStyleUrlToApply;
  int _styleChangeNonce = 0;

  (String? reason, String message) _splitInitError(String raw) {
    final trimmed = raw.trim();
    final re = RegExp(r'^\[([A-Z0-9_]+)\]\s*(.*)$');
    final m = re.firstMatch(trimmed);
    if (m == null) return (null, trimmed);
    return (m.group(1), (m.group(2) ?? '').trim());
  }

  String _normalizeMapboxStyleUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return value;

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
      final withoutHtml = value.substring(0, value.length - 5);
      return withoutHtml;
    }

    return value;
  }

  String? _friendlyHintForReason(String? reason) {
    switch (reason) {
      case 'TOKEN_MISSING':
        return 'Renseigne un token Mapbox public (pk.*) via `--dart-define=MAPBOX_ACCESS_TOKEN=...` au build, ou via l\'UI admin.';
      case 'TOKEN_INVALID':
        return 'Le token semble invalide/révoqué. Génére un nouveau token (pk.*) puis rebuild + redeploy.';
      case 'TOKEN_FORBIDDEN':
        return 'Le token est refusé (403). Vérifie restrictions du token, scopes et accès au style utilisé.';
      case 'MAPBOXGL_MISSING':
        return 'Les scripts Mapbox GL JS ne sont pas chargés. Désactive adblock/anti-tracker, ou autorise `api.mapbox.com` / `unpkg.com`.';
      case 'NETWORK_BLOCKED':
        return 'Le réseau/bloqueur empêche les requêtes Mapbox (styles/tiles). Essaie un autre réseau ou whitelist Mapbox.';
      case 'WEBGL_UNSUPPORTED':
        return 'WebGL est indisponible. Active l\'accélération matérielle ou teste un autre navigateur/appareil.';
      case 'CONTAINER_NOT_FOUND':
        return 'Problème DOM/transitoire. Un refresh suffit généralement.';
      case 'STYLE_NOT_JSON':
        return 'L\'URL de style pointe vers une page HTML (souvent un lien Mapbox Studio). Utilise `mapbox://styles/<user>/<styleId>` ou une URL API styles/v1.';
      default:
        return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _containerId = 'maslive-mapbox-${DateTime.now().microsecondsSinceEpoch}';
    _metricsObserver = _MasliveMetricsObserver(onMetrics: _scheduleResize);
    WidgetsBinding.instance.addObserver(_metricsObserver);
    _loadMapboxToken();
  }

  @override
  void didUpdateWidget(covariant MasLiveMapWeb oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      _connectController();
    }

    final oldStyle = _normalizeMapboxStyleUrl(oldWidget.styleUrl ?? '');
    final newStyle = _normalizeMapboxStyleUrl(widget.styleUrl ?? '');
    if (oldStyle == newStyle) return;

    final styleToApply = newStyle.isEmpty ? _fallbackStyleUrl : newStyle;

    if (!_isMapReady) {
      _pendingStyleUrlToApply = newStyle;
      // Depuis le "ready" strict (idle), la map peut exister bien avant le signal READY.
      // On tente donc un setStyle dès que possible pour que les previews (wizard) réagissent.
      try {
        _mbSetStyle(_containerId, styleToApply);
      } catch (e) {
        debugPrint('⚠️ setStyle (didUpdateWidget, map not ready yet) error: $e');
        return;
      }

      _scheduleResize();
      _scheduleReapplyOverlaysAfterStyleChange();
      return;
    }

    try {
      _mbSetStyle(_containerId, styleToApply);
    } catch (e) {
      debugPrint('⚠️ setStyle (didUpdateWidget) error: $e');
    }

    _scheduleResize();
    _scheduleReapplyOverlaysAfterStyleChange();
  }

  void _scheduleReapplyOverlaysAfterStyleChange() {
    final nonce = ++_styleChangeNonce;
    unawaited(_retryReapplyOverlaysWhenStyleReady(nonce));
  }

  Future<void> _retryReapplyOverlaysWhenStyleReady(int nonce) async {
    for (var attempt = 0; attempt < 35; attempt++) {
      if (!mounted || nonce != _styleChangeNonce) return;
      final map = _getMapForThisContainer();
      if (map != null) {
        try {
          final styleLoaded = map.callMethod('isStyleLoaded');
          if (styleLoaded == true) {
            await _reapplyCachedOverlays();
            return;
          }
        } catch (_) {
          // ignore
        }
      }
      await Future.delayed(const Duration(milliseconds: 120));
    }
  }

  Future<void> _reapplyCachedOverlays() async {
    if (!_isMapReady) return;

    // POIs (GeoJSON + layers)
    unawaited(_applyPoisGeoJsonIfReady());

    // Markers
    final markers = _lastMarkers;
    if (markers != null) {
      try {
        final markersJson = jsonEncode([
          for (final m in markers)
            {
              'id': m.id,
              'lng': m.lng,
              'lat': m.lat,
              'size': m.size,
              'color': '#${m.color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
              'label': m.label,
            }
        ]);
        _mbSetMarkers(_containerId, markersJson);
      } catch (e) {
        debugPrint('⚠️ reapply markers error: $e');
      }
    }

    // Polyline
    final poly = _lastPolyline;
    if (poly != null && poly.show) {
      try {
        final pointsJson = jsonEncode([
          for (final p in poly.points) {'lng': p.lng, 'lat': p.lat}
        ]);
        final colorHex = '#${poly.color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2, 8)}';
        final optionsJson = jsonEncode(poly.options.toJson());
        _mbSetPolyline(_containerId, pointsJson, colorHex, poly.width, true, optionsJson);
      } catch (e) {
        debugPrint('⚠️ reapply polyline error: $e');
      }
    }

    // Polygon
    final polyGon = _lastPolygon;
    if (polyGon != null && polyGon.show) {
      try {
        final pointsJson = jsonEncode([
          for (final p in polyGon.points) {'lng': p.lng, 'lat': p.lat}
        ]);
        final fillHex = '#${polyGon.fillColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2, 8)}';
        final strokeHex = '#${polyGon.strokeColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2, 8)}';
        _mbSetPolygon(
          _containerId,
          pointsJson,
          fillHex,
          polyGon.fillColor.a,
          strokeHex,
          polyGon.strokeWidth,
          true,
        );
      } catch (e) {
        debugPrint('⚠️ reapply polygon error: $e');
      }
    }
  }

  void _scheduleResize() {
    if (!_isMapReady) return;
    _pendingResize?.cancel();
    _pendingResize = Timer(const Duration(milliseconds: 80), () {
      if (!mounted || !_isMapReady) return;
      try {
        _mbResize(_containerId);
      } catch (_) {
        // ignore
      }
    });
  }

  js.JsObject? _getMapForThisContainer() {
    try {
      final bridge = js.context['MapboxBridge'];
      if (bridge is! js.JsObject) return null;

      // Multi-cartes: préférer getMap(containerId) si disponible.
      try {
        final hasGetMap = bridge.hasProperty('getMap');
        if (hasGetMap == true) {
          final m = bridge.callMethod('getMap', [_containerId]);
          if (m is js.JsObject) return m;
        }
      } catch (_) {
        // ignore
      }

      // Fallback legacy: MapboxBridge.map (global)
      final map = bridge['map'];
      if (map is! js.JsObject) return null;
      // Si on peut vérifier le container, on filtre.
      try {
        final container = map.callMethod('getContainer');
        if (container is html.Element) {
          if (container.id != _containerId) return null;
        } else if (container is js.JsObject) {
          final id = container['id'];
          if (id != _containerId) return null;
        }
      } catch (_) {
        // ignore
      }
      return map;
    } catch (_) {
      return null;
    }
  }

  Future<void> _removeLayerIfExists(js.JsObject map, String layerId) async {
    try {
      final layer = map.callMethod('getLayer', [layerId]);
      if (layer != null) {
        map.callMethod('removeLayer', [layerId]);
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _removeSourceIfExists(js.JsObject map, String sourceId) async {
    try {
      final src = map.callMethod('getSource', [sourceId]);
      if (src != null) {
        map.callMethod('removeSource', [sourceId]);
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _applyPoiStyleIfReady() async {
    final map = _getMapForThisContainer();
    if (map == null) return;

    dynamic jsValue(dynamic v) {
      try {
        if (v is Map || v is List) return js.JsObject.jsify(v);
      } catch (_) {
        // ignore
      }
      return v;
    }

    final defaultFillColor = masLiveColorToCssHex(_poiStyle.circleColor);
    final defaultStrokeColor = masLiveColorToCssHex(_poiStyle.circleStrokeColor);

    final fillColorExpr = <dynamic>['coalesce', ['get', 'fillColor'], defaultFillColor];
    final fillOpacityExpr = <dynamic>['coalesce', ['get', 'fillOpacity'], 0.20];
    final lineColorExpr = <dynamic>['coalesce', ['get', 'strokeColor'], defaultStrokeColor];
    final lineWidthExpr = <dynamic>['coalesce', ['get', 'strokeWidth'], 2.0];

    try {
      map.callMethod('setPaintProperty', [_poiLayerId, 'circle-radius', _poiStyle.circleRadius]);
    } catch (_) {
      // ignore
    }
    try {
      map.callMethod('setPaintProperty', [_poiLayerId, 'circle-color', masLiveColorToCssHex(_poiStyle.circleColor)]);
    } catch (_) {
      // ignore
    }
    try {
      map.callMethod('setPaintProperty', [_poiLayerId, 'circle-stroke-width', _poiStyle.circleStrokeWidth]);
    } catch (_) {
      // ignore
    }
    try {
      map.callMethod('setPaintProperty', [_poiLayerId, 'circle-stroke-color', masLiveColorToCssHex(_poiStyle.circleStrokeColor)]);
    } catch (_) {
      // ignore
    }

    // Zones (Polygon): fill + outline
    try {
      final fillLayer = map.callMethod('getLayer', [_poiFillLayerId]);
      if (fillLayer != null) {
        map.callMethod(
          'setPaintProperty',
          [_poiFillLayerId, 'fill-color', jsValue(fillColorExpr)],
        );
        map.callMethod(
          'setPaintProperty',
          [_poiFillLayerId, 'fill-opacity', jsValue(fillOpacityExpr)],
        );
      }
    } catch (_) {
      // ignore
    }

    Future<void> applyLineStyle(String layerId) async {
      try {
        final lineLayer = map.callMethod('getLayer', [layerId]);
        if (lineLayer == null) return;
      } catch (_) {
        return;
      }
      try {
        map.callMethod(
          'setPaintProperty',
          [layerId, 'line-color', jsValue(lineColorExpr)],
        );
      } catch (_) {
        // ignore
      }
      try {
        map.callMethod(
          'setPaintProperty',
          [layerId, 'line-width', jsValue(lineWidthExpr)],
        );
      } catch (_) {
        // ignore
      }
      try {
        map.callMethod('setPaintProperty', [layerId, 'line-opacity', 0.85]);
      } catch (_) {
        // ignore
      }
    }

    await applyLineStyle(_poiLineLayerId);
    await applyLineStyle(_poiLineLayerDashedId);
    await applyLineStyle(_poiLineLayerDottedId);
  }

  Future<void> _applyPoisGeoJsonIfReady() async {
    final map = _getMapForThisContainer();
    if (map == null) return;

    try {
      final styleLoaded = map.callMethod('isStyleLoaded');
      if (styleLoaded != true) {
        // Pas d'allowInterop ici: on retente un peu plus tard.
        unawaited(
          Future.delayed(const Duration(milliseconds: 120), _applyPoisGeoJsonIfReady),
        );
        return;
      }
    } catch (_) {
      // ignore
    }

    // Si FeatureCollection vide => remove
    try {
      final decoded = jsonDecode(_poisGeoJsonString);
      if (decoded is Map && decoded['type'] == 'FeatureCollection') {
        final feats = decoded['features'];
        if (feats is List && feats.isEmpty) {
          await _removeLayerIfExists(map, _poiLineLayerLegacyId);
          await _removeLayerIfExists(map, _poiLineLayerDottedId);
          await _removeLayerIfExists(map, _poiLineLayerDashedId);
          await _removeLayerIfExists(map, _poiLineLayerId);
          await _removeLayerIfExists(map, _poiPatternLayerId);
          await _removeLayerIfExists(map, _poiFillLayerId);
          await _removeLayerIfExists(map, _poiLayerId);
          await _removeSourceIfExists(map, _poiSourceId);
          return;
        }
      }
    } catch (_) {
      // ignore
    }

    // Upsert source
    try {
      final decoded = jsonDecode(_poisGeoJsonString);
      if (decoded is! Map) {
        return;
      }
      final data = js.JsObject.jsify(decoded);
      final src = map.callMethod('getSource', [_poiSourceId]);
      if (src == null) {
        map.callMethod('addSource', [
          _poiSourceId,
          js.JsObject.jsify({'type': 'geojson', 'data': data}),
        ]);
      } else {
        (src as js.JsObject).callMethod('setData', [data]);
      }
    } catch (_) {
      // ignore
    }

    // Ensure pattern images (style)
    try {
      await _ensurePoiPatternImages(map);
    } catch (_) {
      // ignore
    }

    // Ensure layers (Polygon zones + Point POIs)
    try {
      await _removeLayerIfExists(map, _poiLineLayerLegacyId);

      final fillExisting = map.callMethod('getLayer', [_poiFillLayerId]);
      if (fillExisting == null) {
        map.callMethod('addLayer', [
          js.JsObject.jsify({
            'id': _poiFillLayerId,
            'type': 'fill',
            'source': _poiSourceId,
            'filter': [
              '==',
              ['geometry-type'],
              'Polygon',
            ],
            'paint': {
              'fill-color': ['coalesce', ['get', 'fillColor'], masLiveColorToCssHex(_poiStyle.circleColor)],
              'fill-opacity': ['coalesce', ['get', 'fillOpacity'], 0.20],
            },
          })
        ]);
      }

      final patExisting = map.callMethod('getLayer', [_poiPatternLayerId]);
      if (patExisting == null) {
        map.callMethod('addLayer', [
          js.JsObject.jsify({
            'id': _poiPatternLayerId,
            'type': 'fill',
            'source': _poiSourceId,
            'filter': [
              'all',
              ['==', ['geometry-type'], 'Polygon'],
              ['has', 'fillPattern'],
            ],
            'paint': {
              'fill-pattern': ['get', 'fillPattern'],
              'fill-opacity': ['coalesce', ['get', 'patternOpacity'], 0.55],
            },
          })
        ]);
      }

      final commonLinePaint = <String, dynamic>{
        'line-color': ['coalesce', ['get', 'strokeColor'], masLiveColorToCssHex(_poiStyle.circleStrokeColor)],
        'line-width': ['coalesce', ['get', 'strokeWidth'], 2.0],
        'line-opacity': 0.85,
      };

      final lineExisting = map.callMethod('getLayer', [_poiLineLayerId]);
      if (lineExisting == null) {
        map.callMethod('addLayer', [
          js.JsObject.jsify({
            'id': _poiLineLayerId,
            'type': 'line',
            'source': _poiSourceId,
            'filter': [
              'all',
              ['==', ['geometry-type'], 'Polygon'],
              [
                'any',
                ['!', ['has', 'strokeDash']],
                ['==', ['get', 'strokeDash'], 'solid'],
              ],
            ],
            'paint': commonLinePaint,
          })
        ]);
      }

      final dashedExisting = map.callMethod('getLayer', [_poiLineLayerDashedId]);
      if (dashedExisting == null) {
        map.callMethod('addLayer', [
          js.JsObject.jsify({
            'id': _poiLineLayerDashedId,
            'type': 'line',
            'source': _poiSourceId,
            'filter': [
              'all',
              ['==', ['geometry-type'], 'Polygon'],
              ['==', ['get', 'strokeDash'], 'dashed'],
            ],
            'paint': {
              ...commonLinePaint,
              'line-dasharray': [4, 2],
            },
          })
        ]);
      }

      final dottedExisting = map.callMethod('getLayer', [_poiLineLayerDottedId]);
      if (dottedExisting == null) {
        map.callMethod('addLayer', [
          js.JsObject.jsify({
            'id': _poiLineLayerDottedId,
            'type': 'line',
            'source': _poiSourceId,
            'filter': [
              'all',
              ['==', ['geometry-type'], 'Polygon'],
              ['==', ['get', 'strokeDash'], 'dotted'],
            ],
            'paint': {
              ...commonLinePaint,
              'line-dasharray': [1, 2],
            },
          })
        ]);
      }

      final existing = map.callMethod('getLayer', [_poiLayerId]);
      if (existing == null) {
        map.callMethod('addLayer', [
          js.JsObject.jsify({
            'id': _poiLayerId,
            'type': 'circle',
            'source': _poiSourceId,
            'filter': [
              '==',
              ['geometry-type'],
              'Point',
            ],
            'paint': {
              'circle-radius': _poiStyle.circleRadius,
              'circle-color': masLiveColorToCssHex(_poiStyle.circleColor),
              'circle-stroke-width': _poiStyle.circleStrokeWidth,
              'circle-stroke-color': masLiveColorToCssHex(_poiStyle.circleStrokeColor),
            },
          })
        ]);
      }
    } catch (_) {
      // ignore
    }

    await _applyPoiStyleIfReady();
  }

  String? _hitTestPoiId(double lng, double lat) {
    final map = _getMapForThisContainer();
    if (map == null) return null;

    try {
      final layerPoint = map.callMethod('getLayer', [_poiLayerId]);
      final layerFill = map.callMethod('getLayer', [_poiFillLayerId]);
      final layerPattern = map.callMethod('getLayer', [_poiPatternLayerId]);
      final layerLine = map.callMethod('getLayer', [_poiLineLayerId]);
      final layerDashed = map.callMethod('getLayer', [_poiLineLayerDashedId]);
      final layerDotted = map.callMethod('getLayer', [_poiLineLayerDottedId]);
      if (layerPoint == null &&
          layerFill == null &&
          layerPattern == null &&
          layerLine == null &&
          layerDashed == null &&
          layerDotted == null) {
        return null;
      }
    } catch (_) {
      return null;
    }

    try {
      final point = map.callMethod('project', [
        [lng, lat]
      ]);
      final feats = map.callMethod('queryRenderedFeatures', [
        point,
        js.JsObject.jsify({
          'layers': <String>[
            _poiFillLayerId,
            _poiPatternLayerId,
            _poiLineLayerDottedId,
            _poiLineLayerDashedId,
            _poiLineLayerId,
            _poiLayerId,
          ],
        }),
      ]);
      if (feats is js.JsArray && feats.isNotEmpty) {
        final f = feats[0];
        if (f is js.JsObject) {
          final props = f['properties'];
          final poiId = (props is js.JsObject ? props['poiId'] : null) ?? f['id'];
          final id = (poiId ?? '').toString();
          return id.isEmpty ? null : id;
        }
      }
    } catch (_) {
      // ignore
    }
    return null;
  }

  Future<void> _ensurePoiPatternImages(js.JsObject map) async {
    bool has(String id) {
      try {
        final ok = map.callMethod('hasImage', [id]);
        return ok == true;
      } catch (_) {
        return false;
      }
    }

    void add(String id, html.CanvasElement canvas) {
      try {
        map.callMethod('addImage', [id, canvas]);
      } catch (_) {
        // ignore
      }
    }

    if (!has(_patDiag)) {
      add(_patDiag, _buildDiagPatternCanvas());
    }
    if (!has(_patCross)) {
      add(_patCross, _buildCrossPatternCanvas());
    }
    if (!has(_patDots)) {
      add(_patDots, _buildDotsPatternCanvas());
    }
  }

  html.CanvasElement _buildDiagPatternCanvas() {
    final c = html.CanvasElement(width: 32, height: 32);
    final ctx = c.context2D;
    ctx.clearRect(0, 0, 32, 32);
    ctx.strokeStyle = 'rgba(0,0,0,0.38)';
    ctx.lineWidth = 2;
    for (var i = -32; i <= 32; i += 8) {
      ctx
        ..beginPath()
        ..moveTo(i.toDouble(), 0)
        ..lineTo((i + 32).toDouble(), 32)
        ..stroke();
    }
    return c;
  }

  html.CanvasElement _buildCrossPatternCanvas() {
    final c = html.CanvasElement(width: 32, height: 32);
    final ctx = c.context2D;
    ctx.clearRect(0, 0, 32, 32);
    ctx.strokeStyle = 'rgba(0,0,0,0.34)';
    ctx.lineWidth = 2;
    for (var i = -32; i <= 32; i += 10) {
      ctx
        ..beginPath()
        ..moveTo(i.toDouble(), 0)
        ..lineTo((i + 32).toDouble(), 32)
        ..stroke();
      ctx
        ..beginPath()
        ..moveTo(i.toDouble(), 32)
        ..lineTo((i + 32).toDouble(), 0)
        ..stroke();
    }
    return c;
  }

  html.CanvasElement _buildDotsPatternCanvas() {
    final c = html.CanvasElement(width: 32, height: 32);
    final ctx = c.context2D;
    ctx.clearRect(0, 0, 32, 32);
    ctx.fillStyle = 'rgba(0,0,0,0.35)';
    for (var y = 3; y < 32; y += 8) {
      for (var x = 3; x < 32; x += 8) {
        ctx.fillRect(x.toDouble(), y.toDouble(), 2, 2);
      }
    }
    return c;
  }

  void _handleTapFromJs(double lng, double lat) {
    final controller = widget.controller;

    // 1) POI hit-test
    final poiId = _hitTestPoiId(lng, lat);
    if (poiId != null) {
      try {
        final cb = (controller as dynamic).onPoiTap as void Function(String)?;
        cb?.call(poiId);
        return;
      } catch (_) {
        // ignore
      }
    }

    // 2) Map tap
    if (_onPointAddedCallback != null) {
      _onPointAddedCallback!(lat, lng);
    }

    try {
      final cb = (controller as dynamic).onMapTap as void Function(double, double)?;
      cb?.call(lat, lng);
    } catch (_) {
      // ignore
    }

    widget.onTap?.call(MapPoint(lng, lat));
  }

  Future<void> _loadMapboxToken() async {
    try {
      final info = await MapboxTokenService.getTokenInfo();
      if (mounted) {
        setState(() {
          _mapboxToken = info.token;
          _isLoading = false;
          _initError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _mapboxToken = '';
          _isLoading = false;
          _initError = null;
        });
      }
    }
  }

  void _onMapReady() {
    _isMapReady = true;
    _connectController();
    unawaited(_applyPoisGeoJsonIfReady());
    // Important: après init (et après setStyle), la carte peut avoir une taille 0
    // si l'orientation vient de changer. On force un resize léger.
    _scheduleResize();
    final controller = widget.controller;
    if (controller != null) {
      widget.onMapReady?.call(controller);
    }

    final pending = _pendingStyleUrlToApply;
    if (pending != null) {
      _pendingStyleUrlToApply = null;
      final styleToApply = pending.trim().isEmpty ? _fallbackStyleUrl : pending.trim();
      try {
        _mbSetStyle(_containerId, styleToApply);
      } catch (e) {
        debugPrint('⚠️ setStyle (pending) error: $e');
      }
      _scheduleResize();
      _scheduleReapplyOverlaysAfterStyleChange();
    }
  }

  void _connectController() {
    final controller = widget.controller;
    if (controller == null || !_isMapReady) return;

    controller.moveToImpl = (lng, lat, zoom, animate) async {
      try {
        _mbMoveTo(_containerId, lng, lat, zoom, animate);
      } catch (e) {
        debugPrint('⚠️ moveTo error: $e');
      }
    };

    controller.setStyleImpl = (styleUri) async {
      try {
        _mbSetStyle(_containerId, styleUri);
      } catch (e) {
        debugPrint('⚠️ setStyle error: $e');
      }
    };

    controller.setUserLocationImpl = (lng, lat, show) async {
      // Géré via rebuild avec _rebuildTick (MapboxWebView gère showUserLocation)
      // Pour une implémentation complète, on pourrait ajouter/supprimer un marker JS
    };

    controller.setMarkersImpl = (markers) async {
      _lastMarkers = List<MapMarker>.from(markers);
      try {
        final markersJson = jsonEncode([
          for (final m in markers)
            {
              'id': m.id,
              'lng': m.lng,
              'lat': m.lat,
              'size': m.size,
              'color': '#${m.color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
              'label': m.label,
            }
        ]);
        _mbSetMarkers(_containerId, markersJson);
      } catch (e) {
        debugPrint('⚠️ setMarkers error: $e');
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
      try {
        final pointsJson = jsonEncode([
          for (final p in points) {'lng': p.lng, 'lat': p.lat}
        ]);
        final colorHex = '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2, 8)}';
        // Options avancées (itinéraire routier, flèches, animation, ombrage)
        final optionsJson = jsonEncode(options.toJson());
        _mbSetPolyline(_containerId, pointsJson, colorHex, width, show, optionsJson);
      } catch (e) {
        debugPrint('⚠️ setPolyline error: $e');
      }
    };

    controller.setPolygonImpl = (points, fillColor, strokeColor, strokeWidth, show) async {
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
      try {
        final pointsJson = jsonEncode([
          for (final p in points) {'lng': p.lng, 'lat': p.lat}
        ]);
        final fillHex = '#${fillColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2, 8)}';
        final strokeHex = '#${strokeColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2, 8)}';
        _mbSetPolygon(
          _containerId,
          pointsJson,
          fillHex,
          fillColor.a,
          strokeHex,
          strokeWidth,
          show,
        );
      } catch (e) {
        debugPrint('⚠️ setPolygon error: $e');
      }
    };

    controller.setEditingEnabledImpl = (enabled, onPointAdded) async {
      _onPointAddedCallback = enabled ? onPointAdded : null;
    };

    controller.clearAllImpl = () async {
      _lastMarkers = null;
      _lastPolyline = null;
      _lastPolygon = null;
      try {
        _mbClearAll(_containerId);
      } catch (e) {
        // ignore
      }
    };

    controller.fitBoundsImpl = (west, south, east, north, padding, animate) async {
      try {
        _mbFitBounds(_containerId, west, south, east, north, padding, animate);
      } catch (e) {
        debugPrint('⚠️ fitBounds error: $e');
      }
    };

    controller.setMaxBoundsImpl = (west, south, east, north) async {
      try {
        if (west == null || south == null || east == null || north == null) {
          _mbSetMaxBounds(_containerId, null);
          return;
        }
        final boundsJson = jsonEncode([
          [west, south],
          [east, north],
        ]);
        _mbSetMaxBounds(_containerId, boundsJson);
      } catch (e) {
        debugPrint('⚠️ setMaxBounds error: $e');
      }
    };

    controller.getCameraCenterImpl = () async {
      try {
        final raw = _mbGetCenter(_containerId);
        if (raw == null || raw.isEmpty) return null;
        final decoded = jsonDecode(raw);
        if (decoded is! Map) return null;
        final lng = decoded['lng'];
        final lat = decoded['lat'];
        if (lng is num && lat is num) {
          return MapPoint(lng.toDouble(), lat.toDouble());
        }
      } catch (e) {
        debugPrint('⚠️ getCenter error: $e');
      }
      return null;
    };

    // POIs GeoJSON (Mapbox Pro)
    try {
      (controller as dynamic).setPoisGeoJsonImpl = (String fcJson) async {
        _poisGeoJsonString = fcJson;
        await _applyPoisGeoJsonIfReady();
      };
    } catch (_) {
      // ignore
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

  @override
  void dispose() {
    _onPointAddedCallback = null;
    _pendingResize?.cancel();
    WidgetsBinding.instance.removeObserver(_metricsObserver);
    try {
      _mbDestroy(_containerId);
    } catch (_) {
      // ignore
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_mapboxToken.isEmpty) {
      return Container(
        color: Colors.grey.shade100,
        child: const Center(
          child: Text('Token Mapbox manquant'),
        ),
      );
    }

    final initError = _initError;
    if (initError != null && initError.isNotEmpty) {
      final (reason, cleanMsg) = _splitInitError(initError);
      final hint = _friendlyHintForReason(reason);
      final tokenLen = _mapboxToken.trim().length;
      final isPk = _mapboxToken.trim().startsWith('pk.') || _mapboxToken.trim().startsWith('pk_');
      final resolvedSource = MapboxTokenService.cachedSource;
      String mapboxGlLoadStatus = 'unknown';
      try {
        final s = js.context['__MAPBOXGL_LOAD_STATUS__'];
        if (s != null) mapboxGlLoadStatus = s.toString();
      } catch (_) {
        // ignore
      }
      return Container(
        color: Colors.grey.shade100,
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 56),
                const SizedBox(height: 12),
                const Text(
                  'Impossible d\'afficher la carte',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  cleanMsg,
                  textAlign: TextAlign.center,
                ),
                if (hint != null && hint.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    hint,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Raison: ${reason ?? 'inconnue'}\n'
                  'Token détecté: ${tokenLen > 0 ? 'oui' : 'non'} (len=$tokenLen, pk=${isPk ? 'oui' : 'non'})\n'
                  'Token source: $resolvedSource\n'
                  'Mapbox GL JS script: $mapboxGlLoadStatus\n'
                  'Si tu utilises un bloqueur (adblock) ou un réseau filtré,\n'
                  'les scripts https://api.mapbox.com peuvent être bloqués.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        if (w.isFinite && h.isFinite) {
          final size = Size(w, h);
          if (_lastConstraintsSize != size) {
            _lastConstraintsSize = size;
            // Après un changement de layout (rotation, split view, etc.)
            // il faut appeler map.resize() pour que Mapbox GL JS recalcule son canvas.
            WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleResize());
          }
        }

        return _MapboxWebViewCustom(
          key: ValueKey('maslive-map-web-$_containerId'),
          containerId: _containerId,
          accessToken: _mapboxToken,
          initialLat: widget.initialLat,
          initialLng: widget.initialLng,
          initialZoom: widget.initialZoom,
          initialPitch: widget.initialPitch,
          initialBearing: widget.initialBearing,
          styleUrl: _normalizeMapboxStyleUrl(widget.styleUrl ?? ''),
          onMapReady: _onMapReady,
          onTap: (lng, lat) {
            _handleTapFromJs(lng, lat);
          },
          onInitError: (msg) {
            if (!mounted) return;
            setState(() {
              _initError = msg;
            });
          },
        );
      },
    );
  }
}

/// Observer minimal pour déclencher un resize map sur changement de métriques.
/// On évite de mixer un `with WidgetsBindingObserver` sur le State (risque de conflits).
class _MasliveMetricsObserver with WidgetsBindingObserver {
  final VoidCallback onMetrics;
  _MasliveMetricsObserver({required this.onMetrics});

  @override
  void didChangeMetrics() {
    onMetrics();
  }
}

/// Widget wrapper pour Mapbox GL JS avec interop personnalisée
class _MapboxWebViewCustom extends StatefulWidget {
  final String containerId;
  final String accessToken;
  final double initialLat;
  final double initialLng;
  final double initialZoom;
  final double initialPitch;
  final double initialBearing;
  final String? styleUrl;
  final VoidCallback? onMapReady;
  final void Function(double lng, double lat)? onTap;
  final void Function(String message)? onInitError;

  const _MapboxWebViewCustom({
    super.key,
    required this.containerId,
    required this.accessToken,
    required this.initialLat,
    required this.initialLng,
    required this.initialZoom,
    this.initialPitch = 0.0,
    this.initialBearing = 0.0,
    this.styleUrl,
    this.onMapReady,
    this.onTap,
    this.onInitError,
  });

  @override
  State<_MapboxWebViewCustom> createState() => _MapboxWebViewCustomState();
}

class _MapboxWebViewCustomState extends State<_MapboxWebViewCustom> {
  static const int _maxInitAttempts = 120;

  late final String _viewType;
  html.DivElement? _containerEl;
  StreamSubscription<html.MessageEvent>? _messageSub;
  bool _didInit = false;
  bool _didReceiveErrorFromJs = false;
  int _initAttempts = 0;
  String? _lastTransientError;

  bool _tryInitElementViaDartJs(
    html.Element el,
    String containerId,
    String token,
    String optionsJson,
  ) {
    try {
      final v2 = js.context['MasliveMapboxV2'];
      if (v2 is js.JsObject) {
        final res = v2.callMethod('initElement', [el, containerId, token, optionsJson]);
        return res == true;
      }
    } catch (_) {
      // ignore
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _viewType = 'maslive-mapbox-${DateTime.now().microsecondsSinceEpoch}';
    _registerFactory();

    _messageSub = html.window.onMessage.listen((evt) {
      final raw = evt.data;
      final data = raw?.toString();
      if (data == null || data.isEmpty) return;
      try {
        final decoded = jsonDecode(data);
        if (decoded is! Map) return;
        final type = decoded['type'];
        final containerId = decoded['containerId'];
        if (containerId != widget.containerId) return;

        if (type == 'MASLIVE_MAP_READY') {
          widget.onMapReady?.call();
          return;
        }

        if (type == 'MASLIVE_MAP_TAP') {
          final lng = decoded['lng'];
          final lat = decoded['lat'];
          if (lng is num && lat is num) {
            widget.onTap?.call(lng.toDouble(), lat.toDouble());
          }
        }

        if (type == 'MASLIVE_MAP_ERROR') {
          final reason = decoded['reason']?.toString();
          final msg = decoded['message']?.toString() ?? 'Erreur Mapbox inconnue.';
          final fullMsg = (reason != null && reason.isNotEmpty) ? '[$reason] $msg' : msg;

          _didReceiveErrorFromJs = true;

          // Erreurs transitoires: on laisse l'init retenter tant qu'on n'a pas épuisé
          // quelques tentatives (races DOM / scripts lents).
          if (!_didInit && _initAttempts < _maxInitAttempts) {
            if (reason == 'CONTAINER_NOT_FOUND' || reason == 'MAPBOXGL_MISSING') {
              _lastTransientError = fullMsg;
              Future.delayed(const Duration(milliseconds: 120), _tryInit);
              return;
            }
          }

          widget.onInitError?.call(fullMsg);
          return;
        }
      } catch (_) {
        // ignore
      }
    });
  }

  void _registerFactory() {
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) {
        final container = html.DivElement();
        container.id = widget.containerId;
        container.style.width = '100%';
        container.style.height = '100%';
        _containerEl = container;

        // L'élément doit être réellement monté dans le DOM avant init Mapbox.
        // requestAnimationFrame donne une chance au layout/attach de se faire.
        html.window.requestAnimationFrame((_) {
          if (!mounted) return;
          _tryInit();
        });

        return container;
      },
    );
  }

  void _tryInit() {
    if (!mounted) return;
    if (_didInit) return;

    _initAttempts++;

    // IMPORTANT: le DivElement est créé dans le factory, mais peut ne pas être
    // encore attaché au DOM (HtmlElementView pas encore monté), surtout sur mobile.
    // Dans ce cas, l'init JS échoue avec CONTAINER_NOT_FOUND.
    try {
      final el = _containerEl;
      if (el == null) {
        if (_initAttempts < _maxInitAttempts) {
          Future.delayed(const Duration(milliseconds: 80), _tryInit);
          return;
        }

        widget.onInitError?.call('[CONTAINER_NOT_FOUND] Conteneur HTML introuvable (DOM).');
        return;
      } else {
        // Sur certains devices, l'élément est créé mais pas encore "connecté" au DOM.
        // Même avec un element direct, Mapbox peut échouer si pas attaché.
        try {
          if (el.isConnected != true && _initAttempts < _maxInitAttempts) {
            Future.delayed(const Duration(milliseconds: 80), _tryInit);
            return;
          }
        } catch (_) {
          // ignore
        }

        // Et parfois il est attaché, mais sans taille (layout pas prêt).
        try {
          final rect = el.getBoundingClientRect();
          if ((rect.width <= 0 || rect.height <= 0) && _initAttempts < _maxInitAttempts) {
            Future.delayed(const Duration(milliseconds: 80), _tryInit);
            return;
          }
          if (rect.width <= 0 || rect.height <= 0) {
            widget.onInitError?.call(
              '[CONTAINER_NOT_FOUND] Conteneur HTML présent mais sans taille (layout non prêt).',
            );
            return;
          }
        } catch (_) {
          // ignore
        }
      }
    } catch (_) {
      // ignore
    }

    final optionsJson = jsonEncode({
      'style': widget.styleUrl,
      'center': [widget.initialLng, widget.initialLat],
      'zoom': widget.initialZoom,
      'pitch': widget.initialPitch,
      'bearing': widget.initialBearing,
    });

    bool ok = false;
    try {
      final el = _containerEl;
      if (el != null) {
        ok = _tryInitElementViaDartJs(el, widget.containerId, widget.accessToken, optionsJson);
      } else {
        ok = _mbInit(widget.containerId, widget.accessToken, optionsJson) == true;
      }
    } catch (_) {
      ok = false;
    }

    if (ok) {
      _didInit = true;
      return;
    }

    // Si Mapbox GL JS n'est pas encore prêt (CDN lent), on retente brièvement.
    bool hasMapboxGl = true;
    try {
      hasMapboxGl = js.context.hasProperty('mapboxgl') == true;
    } catch (_) {
      hasMapboxGl = true;
    }

    if (!hasMapboxGl && _initAttempts < _maxInitAttempts) {
      Future.delayed(const Duration(milliseconds: 250), _tryInit);
      return;
    }

    // Sinon, on laisse le bridge JS poster MASLIVE_MAP_ERROR.
    // En fallback (si aucun message JS n'arrive), message générique après un court délai
    // pour éviter d'écraser la vraie cause (TOKEN_MISSING / WEBGL_UNSUPPORTED / ...).
    if (_didReceiveErrorFromJs) return;

    final transientHint = _lastTransientError;
    Future.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      if (_didInit) return;
      if (_didReceiveErrorFromJs) return;
      widget.onInitError?.call(transientHint ??
          'Initialisation Mapbox GL JS échouée (token invalide, scripts Mapbox bloqués, ou WebGL indisponible).');
    });
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    // Destruction gérée côté widget parent via _mbDestroy
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}

@JS('MasliveMapboxV2.init')
external bool _mbInit(String containerId, String token, String optionsJson);

@JS('MasliveMapboxV2.moveTo')
external void _mbMoveTo(String containerId, double lng, double lat, double zoom, bool animate);

@JS('MasliveMapboxV2.resize')
external void _mbResize(String containerId);

@JS('MasliveMapboxV2.setStyle')
external void _mbSetStyle(String containerId, String styleUrl);

@JS('MasliveMapboxV2.setMarkers')
external void _mbSetMarkers(String containerId, String markersJson);

@JS('MasliveMapboxV2.setPolyline')
external void _mbSetPolyline(
  String containerId,
  String pointsJson,
  String colorHex,
  double width,
  bool show,
  String optionsJson,
);

@JS('MasliveMapboxV2.setPolygon')
external void _mbSetPolygon(
  String containerId,
  String pointsJson,
  String fillColorHex,
  double fillOpacity,
  String strokeColorHex,
  double strokeWidth,
  bool show,
);

@JS('MasliveMapboxV2.clearAll')
external void _mbClearAll(String containerId);

@JS('MasliveMapboxV2.fitBounds')
external void _mbFitBounds(
  String containerId,
  double west,
  double south,
  double east,
  double north,
  double padding,
  bool animate,
);

@JS('MasliveMapboxV2.setMaxBounds')
external void _mbSetMaxBounds(String containerId, String? boundsJson);

@JS('MasliveMapboxV2.getCenter')
external String? _mbGetCenter(String containerId);

@JS('MasliveMapboxV2.destroy')
external void _mbDestroy(String containerId);
