import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../services/mapbox_token_service.dart';
import '../../ui/map/maslive_map.dart';
import '../../ui/map/maslive_map_controller.dart';
import '../../utils/mapbox_token_web_stub.dart'
  if (dart.library.html) '../../utils/mapbox_token_web_web.dart';
import 'mapbox_native_circuit_map.dart';

typedef LngLat = ({double lng, double lat});

Widget buildCircuitMap({
  required List<LngLat> perimeter,
  required List<LngLat> route,
  required List<({int startIndex, int endIndex, Color color, String name})>
  segments,
  required bool locked,
  required ValueChanged<LngLat> onTap,
  bool showMask = false,
  String? mapboxToken,
}) {
  final token = MapboxTokenService.getTokenSync(override: mapboxToken);

  if (kIsWeb) {
    // Assure la compat token côté Web, même si `mapboxToken` est passé via override.
    // (Sans persister en SharedPreferences.)
    if (token.trim().isNotEmpty) {
      writeWebMapboxToken(token);
    }

    return _MasLiveCircuitMapWeb(
      perimeter: perimeter,
      route: route,
      segments: segments,
      locked: locked,
      showMask: showMask,
      onTapLngLat: onTap,
    );
  }
  if (token.isNotEmpty) {
    // SDK Mapbox natif : token global.
    MapboxOptions.setAccessToken(token);
  }

  return MapboxNativeCircuitMap(
    perimeter: perimeter,
    route: route,
    segments: segments,
    locked: locked,
    showMask: showMask,
    onTapLngLat: onTap,
  );
}

class _MasLiveCircuitMapWeb extends StatefulWidget {
  const _MasLiveCircuitMapWeb({
    required this.perimeter,
    required this.route,
    required this.segments,
    required this.locked,
    required this.showMask,
    required this.onTapLngLat,
  });

  final List<LngLat> perimeter;
  final List<LngLat> route;
  final List<({int startIndex, int endIndex, Color color, String name})>
  segments;
  final bool locked;
  final bool showMask;
  final ValueChanged<LngLat> onTapLngLat;

  @override
  State<_MasLiveCircuitMapWeb> createState() => _MasLiveCircuitMapWebState();
}

class _MasLiveCircuitMapWebState extends State<_MasLiveCircuitMapWeb> {
  final MasLiveMapController _controller = MasLiveMapController();
  bool _ready = false;
  bool _renderScheduled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _MasLiveCircuitMapWeb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_ready) return;
    _scheduleRender();
  }

  void _onMapReady(MasLiveMapController ctrl) {
    _ready = true;
    _scheduleRender();
  }

  void _scheduleRender() {
    if (_renderScheduled) return;
    _renderScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _renderScheduled = false;
      if (!mounted || !_ready) return;
      _renderAll();
    });
  }

  Future<void> _renderAll() async {
    // Edition (tap->add point) uniquement si non verrouillé.
    await _controller.setEditingEnabled(
      enabled: !widget.locked,
      onPointAdded: (lat, lng) {
        if (widget.locked) return;
        widget.onTapLngLat((lng: lng, lat: lat));
      },
    );

    // Nettoyage léger: on repart d'un état stable.
    await _controller.clearAll();

    // Périmètre (polygon).
    final perimeter = _closed(widget.perimeter);
    final showPerimeter = perimeter.length >= 4; // fermé = min 4 points
    if (showPerimeter) {
      final fill = widget.showMask
          ? const Color(0xFF000000).withValues(alpha: 0.12)
          : const Color(0x00000000);
      await _controller.setPolygon(
        points: [for (final p in perimeter) MapPoint(p.lng, p.lat)],
        fillColor: fill,
        strokeColor: const Color(0xFFFF3B30),
        strokeWidth: 3.0,
        show: true,
      );

      // Limite de pan/scroll approximative sur la zone du périmètre.
      final b = _boundsOf(perimeter);
      if (b != null) {
        await _controller.setMaxBounds(
          west: b.west,
          south: b.south,
          east: b.east,
          north: b.north,
        );
      }
    } else {
      await _controller.setPolygon(points: const [], show: false);
      await _controller.setMaxBounds(west: null, south: null, east: null, north: null);
    }

    // Route + segments (polyline).
    final route = widget.route;
    final showRoute = route.length >= 2;
    final segJson = _segmentsFeatureCollectionJson(route, widget.segments);

    if (showRoute) {
      await _controller.setPolyline(
        points: [for (final p in route) MapPoint(p.lng, p.lat)],
        color: const Color(0xFF1A73E8),
        width: 6.0,
        show: true,
        roadLike: false,
        shadow3d: false,
        showDirection: false,
        segmentsGeoJson: segJson,
      );
    } else {
      await _controller.setPolyline(points: const [], show: false);
    }
  }

  static List<LngLat> _closed(List<LngLat> points) {
    if (points.isEmpty) return const [];
    if (points.length == 1) return [points.first, points.first];
    final first = points.first;
    final last = points.last;
    final alreadyClosed = (first.lng == last.lng) && (first.lat == last.lat);
    if (alreadyClosed) return List<LngLat>.from(points);
    return [...points, first];
  }

  static ({double west, double south, double east, double north})? _boundsOf(
    List<LngLat> points,
  ) {
    if (points.isEmpty) return null;
    double minLng = points.first.lng;
    double maxLng = points.first.lng;
    double minLat = points.first.lat;
    double maxLat = points.first.lat;
    for (final p in points) {
      if (p.lng < minLng) minLng = p.lng;
      if (p.lng > maxLng) maxLng = p.lng;
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
    }
    return (west: minLng, south: minLat, east: maxLng, north: maxLat);
  }

  static String? _segmentsFeatureCollectionJson(
    List<LngLat> route,
    List<({int startIndex, int endIndex, Color color, String name})> segments,
  ) {
    if (route.length < 2 || segments.isEmpty) return null;

    final features = <Map<String, dynamic>>[];
    for (final s in segments) {
      final a = s.startIndex.clamp(0, route.length - 1);
      final b = s.endIndex.clamp(0, route.length - 1);
      if (b <= a) continue;

      final coords = route
          .sublist(a, b + 1)
          .map((p) => <double>[p.lng, p.lat])
          .toList();

      final rgbHex =
          '#${s.color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2, 8)}';
      features.add({
        'type': 'Feature',
        'properties': {
          'color': rgbHex,
          'width': 8.0,
          'opacity': 1.0,
          'name': s.name,
        },
        'geometry': {
          'type': 'LineString',
          'coordinates': coords,
        },
      });
    }

    return jsonEncode({
      'type': 'FeatureCollection',
      'features': features,
    });
  }

  @override
  Widget build(BuildContext context) {
    final center = _centerFor(widget.perimeter, widget.route);
    return MasLiveMap(
      controller: _controller,
      initialLng: center.lng,
      initialLat: center.lat,
      initialZoom: 12.0,
      onMapReady: _onMapReady,
    );
  }

  static LngLat _centerFor(List<LngLat> perimeter, List<LngLat> route) {
    if (route.isNotEmpty) return route.first;
    if (perimeter.isNotEmpty) return perimeter.first;
    return (lng: -61.534, lat: 16.241);
  }
}
