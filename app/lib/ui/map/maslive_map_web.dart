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

  @override
  void initState() {
    super.initState();
    _containerId = 'maslive-mapbox-${DateTime.now().microsecondsSinceEpoch}';
    _metricsObserver = _MasliveMetricsObserver(onMetrics: _scheduleResize);
    WidgetsBinding.instance.addObserver(_metricsObserver);
    _loadMapboxToken();
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

    try {
      final layer = map.callMethod('getLayer', [_poiLayerId]);
      if (layer == null) return;
    } catch (_) {
      return;
    }

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
      final data = jsonDecode(_poisGeoJsonString);
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

    // Ensure layer
    try {
      final existing = map.callMethod('getLayer', [_poiLayerId]);
      if (existing == null) {
        map.callMethod('addLayer', [
          js.JsObject.jsify({
            'id': _poiLayerId,
            'type': 'circle',
            'source': _poiSourceId,
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
      final layer = map.callMethod('getLayer', [_poiLayerId]);
      if (layer == null) return null;
    } catch (_) {
      return null;
    }

    try {
      final point = map.callMethod('project', [
        [lng, lat]
      ]);
      final feats = map.callMethod('queryRenderedFeatures', [
        point,
        js.JsObject.jsify({'layers': <String>[_poiLayerId]}),
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
                  initError,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Token source: ${MapboxTokenService.getTokenSourceSync()}\n'
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
          styleUrl: widget.styleUrl,
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
  late final String _viewType;
  StreamSubscription<html.MessageEvent>? _messageSub;
  bool _didInit = false;
  int _initAttempts = 0;

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
          final msg = decoded['message']?.toString() ?? 'Erreur Mapbox inconnue.';
          widget.onInitError?.call(msg);
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

        Future.delayed(const Duration(milliseconds: 100), () {
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
    final optionsJson = jsonEncode({
      'style': widget.styleUrl,
      'center': [widget.initialLng, widget.initialLat],
      'zoom': widget.initialZoom,
      'pitch': widget.initialPitch,
      'bearing': widget.initialBearing,
    });

    bool ok = false;
    try {
      ok = _mbInit(widget.containerId, widget.accessToken, optionsJson) == true;
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

    if (!hasMapboxGl && _initAttempts < 10) {
      Future.delayed(const Duration(milliseconds: 250), _tryInit);
      return;
    }

    // Sinon, on laisse le bridge JS poster MASLIVE_MAP_ERROR. En fallback, message générique.
    widget.onInitError?.call(
      'Initialisation Mapbox GL JS échouée (token invalide, scripts Mapbox bloqués, ou WebGL indisponible).',
    );
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
