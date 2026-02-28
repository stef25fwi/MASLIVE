import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../services/mapbox_token_service.dart';
import '../../../ui/map/maslive_map.dart';
import '../../../ui/map/maslive_map_controller.dart';
import '../../models/route_style_config.dart';

class RouteStylePreviewMap extends StatefulWidget {
  final RouteStyleConfig config;
  final List<LatLng> route;
  final VoidCallback? onMapReady;

  const RouteStylePreviewMap({
    super.key,
    required this.config,
    required this.route,
    this.onMapReady,
  });

  @override
  State<RouteStylePreviewMap> createState() => _RouteStylePreviewMapState();
}

class _RouteStylePreviewMapState extends State<RouteStylePreviewMap> {
  // Web: réutilise MasLiveMap (interop GL JS)
  final _webController = MasLiveMapController();

  String? _lastWebBoundsKey;

  // Mobile: MapboxMaps
  MapboxMap? _map;
  bool _styleReady = false;

  Timer? _animTimer;
  int _animTick = 0;

  static const _srcRoute = 'rsp_route';
  static const _srcSegments = 'rsp_segments';

  static const _layerShadow = 'rsp_shadow';
  static const _layerGlow = 'rsp_glow';
  static const _layerCasing = 'rsp_casing';
  static const _layerMain = 'rsp_main';

  @override
  void initState() {
    super.initState();
    _warmUpToken();
    _syncTimers();
  }

  @override
  void didUpdateWidget(covariant RouteStylePreviewMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTimers();
    _render();
  }

  @override
  void dispose() {
    _animTimer?.cancel();
    _webController.dispose();
    super.dispose();
  }

  Future<void> _warmUpToken() async {
    await MapboxTokenService.warmUp();
    final token = MapboxTokenService.getTokenSync();
    if (!kIsWeb && token.trim().isNotEmpty) {
      MapboxOptions.setAccessToken(token);
    }
  }

  void _syncTimers() {
    final cfg = widget.config;
    final needsAnim = cfg.pulseEnabled || cfg.rainbowEnabled;
    if (!needsAnim) {
      _animTimer?.cancel();
      _animTimer = null;
      return;
    }

    // Periodic update (throttlé)
    final periodMs = (cfg.rainbowEnabled
            ? (110 - (cfg.rainbowSpeed * 0.8)).clamp(25, 110)
            : (160 - (cfg.pulseSpeed * 1.0)).clamp(40, 160))
        .round();

    _animTimer?.cancel();
    _animTimer = Timer.periodic(Duration(milliseconds: periodMs), (_) {
      _animTick++;
      _render(animTick: _animTick);
    });
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _map = mapboxMap;
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData data) async {
    _styleReady = true;
    await _ensureBaseStyle();
    await _render();
    widget.onMapReady?.call();
  }

  Future<void> _ensureBaseStyle() async {
    await _tryAddSource(_srcRoute, _emptyFeatureCollection());
    await _tryAddSource(_srcSegments, _emptyFeatureCollection());

    // Ordre des layers: shadow -> glow -> casing -> main
    await _tryAddLayer(
      LineLayer(
        id: _layerShadow,
        sourceId: _srcRoute,
        lineColor: const Color(0xFF000000).toARGB32(),
        lineOpacity: 0.0,
        lineWidth: 1.0,
        lineBlur: 0.0,
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
      ),
    );

    await _tryAddLayer(
      LineLayer(
        id: _layerGlow,
        sourceId: _srcRoute,
        lineColor: const Color(0xFF1A73E8).toARGB32(),
        lineOpacity: 0.0,
        lineWidth: 1.0,
        lineBlur: 0.0,
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
      ),
    );

    await _tryAddLayer(
      LineLayer(
        id: _layerCasing,
        sourceId: _srcRoute,
        lineColor: const Color(0xFF0B1B2B).toARGB32(),
        lineOpacity: 1.0,
        lineWidth: 11.0,
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
      ),
    );

    await _tryAddLayer(
      LineLayer(
        id: _layerMain,
        sourceId: _srcSegments,
        lineColor: const Color(0xFF1A73E8).toARGB32(),
        lineOpacity: 1.0,
        lineWidth: 7.0,
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
      ),
    );
  }

  Future<void> _render({int? animTick}) async {
    if (kIsWeb) {
      await _renderWeb(animTick: animTick);
      return;
    }
    if (!_styleReady || _map == null) return;

    final cfg = widget.config.validated();
    final pts = widget.route;

    final widthScale = cfg.widthScale3d;
    final mainWidth = cfg.mainWidth * widthScale;
    final casingWidth = cfg.casingWidth * widthScale;
    final glowWidth = cfg.glowWidth * widthScale;
    final elevationPx = cfg.elevationPx;

    // Update route source (ligne principale)
    final routeFc = (pts.length < 2)
        ? _emptyFeatureCollection()
        : _featureCollection([
            {
              'type': 'Feature',
              'properties': <String, dynamic>{},
              'geometry': {
                'type': 'LineString',
                'coordinates': [for (final p in pts) [p.lng, p.lat]],
              },
            }
          ]);

    await _updateGeoJson(_srcRoute, routeFc);

    // Section segments (rainbow/traffic/vanishing)
    final useSegments = cfg.rainbowEnabled || cfg.trafficDemoEnabled || cfg.vanishingEnabled;
    final segmentsFc = useSegments
        ? _buildSegmentsFeatureCollection(
            pts,
            cfg,
            animTick: animTick ?? _animTick,
          )
        : _buildSolidFeatureCollection(pts, cfg);
    await _updateGeoJson(_srcSegments, segmentsFc);

    // Map cap/join
    await _applyLineCaps(cfg);

    // Shadow
    final shadowOpacity = cfg.shadowEnabled ? cfg.shadowOpacity : 0.0;
    await _setLayerProps(_layerShadow, {
      'line-opacity': shadowOpacity,
      'line-width': math.max(1.0, casingWidth),
      'line-blur': cfg.shadowBlur,
    });

    // Glow (avec pulse optionnel)
    double glowOpacity = cfg.glowEnabled ? cfg.glowOpacity : 0.0;
    if (cfg.glowEnabled && cfg.pulseEnabled) {
      final phase = ((animTick ?? _animTick) % 60) / 60.0;
      final wave = 0.5 + 0.5 * math.sin(2 * math.pi * phase);
      glowOpacity = (0.20 + wave * (cfg.glowOpacity - 0.20)).clamp(0.0, 1.0);
    }
    await _setLayerProps(_layerGlow, {
      'line-opacity': glowOpacity,
      'line-width': math.max(1.0, casingWidth + glowWidth),
      'line-blur': cfg.glowBlur,
      'line-color': _argbInt(cfg.mainColor),
    });

    // Casing
    final casingOpacity = (cfg.casingWidth <= 0) ? 0.0 : cfg.opacity;
    await _setLayerProps(_layerCasing, {
      'line-opacity': casingOpacity,
      'line-width': math.max(0.0, casingWidth),
      'line-color': _argbInt(cfg.casingColor),
    });

    if (useSegments) {
      await _setLayerProps(_layerMain, {
        'line-color': ['get', 'color'],
        'line-width': ['get', 'width'],
        'line-opacity': ['get', 'opacity'],
      });
    } else {
      await _setLayerProps(_layerMain, {
        'line-color': ['get', 'color'],
        'line-width': ['get', 'width'],
        'line-opacity': ['get', 'opacity'],
      });
    }

    // Hauteur (translate) – appliquée à toutes les couches
    final translate = (elevationPx > 0)
        ? <double>[0.0, -elevationPx]
        : null;
    for (final layerId in <String>[
      _layerShadow,
      _layerGlow,
      _layerCasing,
      _layerMain,
    ]) {
      await _setLayerProps(layerId, {
        'line-translate': translate,
        'line-translate-anchor': translate != null ? 'map' : null,
      });
    }

    if (cfg.dashEnabled) {
      await _setLayerProps(_layerMain, {
        'line-dasharray': [cfg.dashLength, cfg.dashGap],
      });
    } else {
      await _setLayerProps(_layerMain, {
        'line-dasharray': null,
      });
    }

    // Recentrage simple
    if (pts.isNotEmpty) {
      final center = pts[pts.length ~/ 2];
      await _map!.setCamera(
        CameraOptions(
          center: Point(coordinates: Position(center.lng, center.lat)),
          zoom: 14.0,
        ),
      );
    }
  }

  Future<void> _renderWeb({int? animTick}) async {
    // Web: rendu "pro" via le bridge Mapbox GL JS (casing/glow/dash/opacity...).
    final cfg = widget.config.validated();
    if (widget.route.length < 2) {
      await _webController.clearAll();
      _lastWebBoundsKey = null;
      return;
    }

    final widthScale = cfg.widthScale3d;
    final mainWidth = cfg.mainWidth * widthScale;
    final casingWidth = cfg.casingWidth * widthScale;
    final glowWidth = cfg.glowWidth * widthScale;

    // Segments (rainbow/traffic/vanishing): FC GeoJSON avec propriétés color/width/opacity.
    final useSegments = cfg.rainbowEnabled || cfg.trafficDemoEnabled || cfg.vanishingEnabled;
    final segmentsGeoJson = useSegments
        ? _buildSegmentsFeatureCollection(
            widget.route,
            cfg,
            animTick: animTick ?? _animTick,
          )
        : null;

    // Bounds (fit seulement si la géométrie change)
    double minLat = widget.route.first.lat;
    double maxLat = widget.route.first.lat;
    double minLng = widget.route.first.lng;
    double maxLng = widget.route.first.lng;

    for (final p in widget.route) {
      minLat = math.min(minLat, p.lat);
      maxLat = math.max(maxLat, p.lat);
      minLng = math.min(minLng, p.lng);
      maxLng = math.max(maxLng, p.lng);
    }
    final boundsKey = '${minLng.toStringAsFixed(6)},${minLat.toStringAsFixed(6)},${maxLng.toStringAsFixed(6)},${maxLat.toStringAsFixed(6)}';

    final lineJoin = switch (cfg.lineJoin) {
      RouteLineJoin.round => 'round',
      RouteLineJoin.bevel => 'bevel',
      RouteLineJoin.miter => 'miter',
    };
    final lineCap = switch (cfg.lineCap) {
      RouteLineCap.round => 'round',
      RouteLineCap.butt => 'butt',
      RouteLineCap.square => 'square',
    };

    final shouldRoadLike = (cfg.casingWidth > 0) || cfg.shadowEnabled || cfg.glowEnabled;

    await _webController.setPolyline(
      points: [for (final p in widget.route) MapPoint(p.lng, p.lat)],
      color: cfg.mainColor,
      width: mainWidth,
      show: true,
      roadLike: shouldRoadLike,
      shadow3d: cfg.shadowEnabled,
      showDirection: false,
      animateDirection: cfg.pulseEnabled,
      animationSpeed: (cfg.pulseSpeed / 25.0).clamp(0.5, 5.0),

      opacity: cfg.opacity,

      casingColor: cfg.casingColor,
      casingWidth: cfg.casingWidth > 0 ? casingWidth : null,

      glowEnabled: cfg.glowEnabled,
      glowColor: cfg.mainColor,
      glowWidth: glowWidth,
      glowOpacity: cfg.glowOpacity,
      glowBlur: cfg.glowBlur,

      elevationPx: cfg.elevationPx,

      dashArray: cfg.dashEnabled ? [cfg.dashLength, cfg.dashGap] : null,
      lineCap: lineCap,
      lineJoin: lineJoin,

      segmentsGeoJson: segmentsGeoJson,
    );

    if (_lastWebBoundsKey != boundsKey) {
      _lastWebBoundsKey = boundsKey;
      await _webController.fitBounds(
        west: minLng,
        south: minLat,
        east: maxLng,
        north: maxLat,
        padding: 56,
        animate: false,
      );
    }
  }

  Future<void> _applyLineCaps(RouteStyleConfig cfg) async {
    final join = switch (cfg.lineJoin) {
      RouteLineJoin.round => 'round',
      RouteLineJoin.bevel => 'bevel',
      RouteLineJoin.miter => 'miter',
    };
    final cap = switch (cfg.lineCap) {
      RouteLineCap.round => 'round',
      RouteLineCap.butt => 'butt',
      RouteLineCap.square => 'square',
    };

    await _setLayerProps(_layerShadow, {'line-join': join, 'line-cap': cap});
    await _setLayerProps(_layerGlow, {'line-join': join, 'line-cap': cap});
    await _setLayerProps(_layerCasing, {'line-join': join, 'line-cap': cap});
    await _setLayerProps(_layerMain, {'line-join': join, 'line-cap': cap});
  }

  // --- Style helpers ---

  Future<void> _tryAddSource(String id, String data) async {
    try {
      await _map?.style.addSource(GeoJsonSource(id: id, data: data));
    } catch (_) {}
  }

  Future<void> _tryAddLayer(Layer layer) async {
    try {
      await _map?.style.addLayer(layer);
    } catch (_) {}
  }

  Future<void> _updateGeoJson(String sourceId, String fcJson) async {
    try {
      await _map?.style.removeStyleSource(sourceId);
    } catch (_) {}
    await _tryAddSource(sourceId, fcJson);
  }

  Future<void> _setLayerProps(String layerId, Map<String, dynamic> props) async {
    final map = _map;
    if (map == null) return;

    // setStyleLayerProperty est la voie la plus souple (expressions, get, etc.).
    for (final e in props.entries) {
      try {
        await map.style.setStyleLayerProperty(layerId, e.key, e.value);
      } catch (_) {
        // ignore
      }
    }
  }

  // --- GeoJSON ---

  String _emptyFeatureCollection() =>
      jsonEncode({'type': 'FeatureCollection', 'features': []});

  String _featureCollection(List<Map<String, dynamic>> features) =>
      jsonEncode({'type': 'FeatureCollection', 'features': features});

  String _buildSegmentsFeatureCollection(
    List<LatLng> pts,
    RouteStyleConfig cfg, {
    required int animTick,
  }) {
    if (pts.length < 2) return _emptyFeatureCollection();

    final width = cfg.mainWidth * cfg.widthScale3d;

    // Limite le nombre de segments (perf)
    final maxSeg = 60;
    final step = math.max(1, ((pts.length - 1) / maxSeg).ceil());

    final features = <Map<String, dynamic>>[];
    int segIndex = 0;

    for (int i = 0; i < pts.length - 1; i += step) {
      final a = pts[i];
      final b = pts[math.min(i + step, pts.length - 1)];

      final t = segIndex / math.max(1, ((pts.length - 1) / step).floor());

      final baseOpacity = cfg.opacity;
      final opacity = cfg.vanishingEnabled
          ? (t <= cfg.vanishingProgress ? 0.25 : baseOpacity)
          : baseOpacity;

      final color = _segmentColor(cfg, segIndex, animTick);

      features.add({
        'type': 'Feature',
        'properties': {
          'color': _toHexRgba(color, opacity: opacity),
          'width': width,
          'opacity': opacity,
        },
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            [a.lng, a.lat],
            [b.lng, b.lat],
          ],
        },
      });
      segIndex++;
    }

    return _featureCollection(features);
  }

  String _buildSolidFeatureCollection(List<LatLng> pts, RouteStyleConfig cfg) {
    if (pts.length < 2) return _emptyFeatureCollection();
    final width = cfg.mainWidth * cfg.widthScale3d;
    return _featureCollection([
      {
        'type': 'Feature',
        'properties': {
          'color': _toHexRgba(cfg.mainColor, opacity: cfg.opacity),
          'width': width,
          'opacity': cfg.opacity,
        },
        'geometry': {
          'type': 'LineString',
          'coordinates': [for (final p in pts) [p.lng, p.lat]],
        },
      }
    ]);
  }

  Color _segmentColor(RouteStyleConfig cfg, int index, int animTick) {
    if (cfg.trafficDemoEnabled) {
      const traffic = [
        Color(0xFF22C55E), // vert
        Color(0xFFF59E0B), // orange
        Color(0xFFEF4444), // rouge
      ];
      return traffic[index % traffic.length];
    }

    if (cfg.rainbowEnabled) {
      final shift = (animTick % 360);
      final dir = cfg.rainbowReverse ? -1 : 1;
      final hue = (shift + dir * index * 14) % 360;
      return _hsvToColor(
        hue.toDouble(),
        cfg.rainbowSaturation,
        1.0,
      );
    }

    // Fallback: mainColor
    return cfg.mainColor;
  }

  Color _hsvToColor(double h, double s, double v) {
    final hh = (h % 360) / 60.0;
    final c = v * s;
    final x = c * (1 - ((hh % 2) - 1).abs());
    final m = v - c;

    double r1 = 0, g1 = 0, b1 = 0;
    if (hh >= 0 && hh < 1) {
      r1 = c;
      g1 = x;
    } else if (hh < 2) {
      r1 = x;
      g1 = c;
    } else if (hh < 3) {
      g1 = c;
      b1 = x;
    } else if (hh < 4) {
      g1 = x;
      b1 = c;
    } else if (hh < 5) {
      r1 = x;
      b1 = c;
    } else {
      r1 = c;
      b1 = x;
    }

    final r = ((r1 + m) * 255).round().clamp(0, 255);
    final g = ((g1 + m) * 255).round().clamp(0, 255);
    final b = ((b1 + m) * 255).round().clamp(0, 255);
    return Color.fromARGB(255, r, g, b);
  }

  String _toHexRgba(Color c, {required double opacity}) {
    // Mapbox GL JS & style-spec acceptent bien les couleurs CSS rgba().
    // On évite les hex #RRGGBBAA (support variable selon environnements).
    final a = opacity.clamp(0.0, 1.0);
    final r = ((c.r * 255).round()).clamp(0, 255);
    final g = ((c.g * 255).round()).clamp(0, 255);
    final b = ((c.b * 255).round()).clamp(0, 255);
    return 'rgba($r,$g,$b,${a.toStringAsFixed(3)})';
  }

  int _argbInt(Color c) {
    final a = ((c.a * 255).round()).clamp(0, 255);
    final r = ((c.r * 255).round()).clamp(0, 255);
    final g = ((c.g * 255).round()).clamp(0, 255);
    final b = ((c.b * 255).round()).clamp(0, 255);
    return (a << 24) | (r << 16) | (g << 8) | b;
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      final initial = widget.route.isNotEmpty
          ? widget.route.first
          : (lat: 16.241, lng: -61.533);

      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: MasLiveMap(
          controller: _webController,
          initialLng: initial.lng,
          initialLat: initial.lat,
          initialZoom: 13.5,
          onMapReady: (_) {
            widget.onMapReady?.call();
            _renderWeb(animTick: _animTick);
          },
        ),
      );
    }

    final center = widget.route.isNotEmpty
        ? widget.route[widget.route.length ~/ 2]
        : (lat: 16.241, lng: -61.533);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: MapWidget(
        key: const ValueKey('route_style_preview_map'),
        styleUri: MapboxStyles.MAPBOX_STREETS,
        cameraOptions: CameraOptions(
          center: Point(coordinates: Position(center.lng, center.lat)),
          zoom: 13.5,
        ),
        onMapCreated: _onMapCreated,
        onStyleLoadedListener: _onStyleLoaded,
      ),
    );
  }
}
