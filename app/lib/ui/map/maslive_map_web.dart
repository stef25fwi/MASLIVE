// ignore_for_file: avoid_web_libraries_in_flutter, unsafe_html
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'maslive_map_controller.dart';
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
  String _mapboxToken = '';
  bool _isLoading = true;
  late final String _containerId;
  bool _isMapReady = false;
  void Function(double lat, double lng)? _onPointAddedCallback;
  Timer? _pendingResize;
  Size? _lastConstraintsSize;
  late final _MasliveMetricsObserver _metricsObserver;

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

  Future<void> _loadMapboxToken() async {
    try {
      final info = await MapboxTokenService.getTokenInfo();
      if (mounted) {
        setState(() {
          _mapboxToken = info.token;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _mapboxToken = '';
          _isLoading = false;
        });
      }
    }
  }

  void _onMapReady() {
    _isMapReady = true;
    _connectController();
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
            if (_onPointAddedCallback != null) {
              _onPointAddedCallback!(lat, lng);
            }
            widget.onTap?.call(MapPoint(lng, lat));
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
  });

  @override
  State<_MapboxWebViewCustom> createState() => _MapboxWebViewCustomState();
}

class _MapboxWebViewCustomState extends State<_MapboxWebViewCustom> {
  late final String _viewType;
  StreamSubscription<web.MessageEvent>? _messageSub;

  @override
  void initState() {
    super.initState();
    _viewType = 'maslive-mapbox-${DateTime.now().microsecondsSinceEpoch}';
    _registerFactory();

    _messageSub = web.window.onMessage.listen((evt) {
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
      } catch (_) {
        // ignore
      }
    });
  }

  void _registerFactory() {
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) {
        final container = web.document.createElement('div') as web.HTMLDivElement;
        container.id = widget.containerId;
        container.style.width = '100%';
        container.style.height = '100%';

        Future.delayed(const Duration(milliseconds: 100), () {
          final optionsJson = jsonEncode({
            'style': widget.styleUrl,
            'center': [widget.initialLng, widget.initialLat],
            'zoom': widget.initialZoom,
            'pitch': widget.initialPitch,
            'bearing': widget.initialBearing,
          });
          _mbInit(widget.containerId, widget.accessToken, optionsJson);
        });

        return container;
      },
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
