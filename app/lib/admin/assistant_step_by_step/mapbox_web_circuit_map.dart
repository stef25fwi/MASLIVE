import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

typedef LngLat = ({double lng, double lat});

class MapboxWebCircuitMap extends StatefulWidget {
  const MapboxWebCircuitMap({
    super.key,
    required this.mapboxToken,
    required this.perimeter,
    required this.route,
    required this.segments,
    required this.onTapLngLat,
  });

  final String mapboxToken;
  final List<LngLat> perimeter;
  final List<LngLat> route;
  final List<({int startIndex, int endIndex, Color color, String name})>
  segments;
  final ValueChanged<LngLat> onTapLngLat;

  @override
  State<MapboxWebCircuitMap> createState() => _MapboxWebCircuitMapState();
}

class _MapboxWebCircuitMapState extends State<MapboxWebCircuitMap> {
  late final String _viewType;
  late final String _divId;
  StreamSubscription<html.MessageEvent>? _messageSub;
  bool _jsInitialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    final stamp = DateTime.now().microsecondsSinceEpoch;
    _divId = 'maslive-map-$stamp';
    _viewType = 'maslive-mapbox-view-$stamp';

    _messageSub = html.window.onMessage.listen((evt) {
      final data = evt.data;
      if (data is! Map) return;
      if (data['type'] != 'MASLIVE_MAP_TAP') return;

      // Compat: le JS historique n'envoyait pas containerId.
      final containerId = data['containerId'];
      if (containerId is String && containerId != _divId) return;

      final lngRaw = data['lng'];
      final latRaw = data['lat'];
      if (lngRaw is! num || latRaw is! num) return;

      widget.onTapLngLat((lng: lngRaw.toDouble(), lat: latRaw.toDouble()));
    });

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final el = html.DivElement()
        ..id = _divId
        ..style.width = '100%'
        ..style.height = '100%';

      // Attendre plus longtemps pour que mapboxgl soit disponible
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        _initJsIfNeeded();
        _pushDataToJs();
      });

      return el;
    });
  }

  @override
  void didUpdateWidget(covariant MapboxWebCircuitMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initJsIfNeeded();
    _pushDataToJs();
  }

  void _initJsIfNeeded() {
    if (_jsInitialized) {
      if (kDebugMode) print('⏭️  Mapbox déjà initialisé');
      return;
    }
    if (widget.mapboxToken.isEmpty) {
      if (_error == null) {
        setState(() {
          _error =
              'Token Mapbox manquant. Configure MAPBOX_ACCESS_TOKEN (ou MAPBOX_TOKEN legacy).';
        });
      }
      if (kDebugMode) print('❌ Token vide');
      return;
    }

    final api = js.context['masliveMapbox'];
    if (api == null) {
      if (_error == null) {
        setState(() {
          _error =
              'Mapbox JS non chargé (masliveMapbox absent). Vérifie app/web/mapbox_circuit.js et app/web/index.html.';
        });
      }
      if (kDebugMode) print('❌ API masliveMapbox non trouvée');
      return;
    }

    final center = _centerFor(widget.perimeter, widget.route);

    try {
      if (kDebugMode) {
        print('🗺️ Initialisation Mapbox...');
        print('  • Token: ${widget.mapboxToken.substring(0, 10)}...');
        print('  • Container: $_divId');
        print('  • Coordonnées: [${center.lng}, ${center.lat}]');
      }
      
      final result = api.callMethod('init', [
        _divId,
        widget.mapboxToken,
        [center.lng, center.lat],
        12,
      ]);
      
      if (result == true) {
        if (kDebugMode) print('✅ Mapbox initialisé avec succès');
        _jsInitialized = true;
        if (_error != null) {
          setState(() {
            _error = null;
          });
        }
        // Attendre le chargement complet de la carte
        Future.delayed(const Duration(milliseconds: 500), () {
          _pushDataToJs();
        });
      } else {
        if (kDebugMode) print('⚠️  Résultat init: $result');
        throw Exception('init() retourné: $result');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erreur d\'initialisation Mapbox: $e');
      if (_error == null) {
        setState(() {
          _error = 'Erreur d\'initialisation Mapbox (JS): $e';
        });
      }
    }
  }

  void _pushDataToJs() {
    final api = js.context['masliveMapbox'];
    if (api == null) {
      if (kDebugMode) print('❌ masliveMapbox API non disponible');
      return;
    }

    try {
      if (kDebugMode) print('📤 Envoi des données GeoJSON à Mapbox...');
      
      final result = api.callMethod('setData', [
        js.JsObject.jsify({
          'perimeter': _perimeterGeoJson(widget.perimeter),
          'route': _routeGeoJson(widget.route),
          'segments': _segmentsGeoJson(widget.route, widget.segments),
        }),
      ]);
      
      if (result == true) {
        if (kDebugMode) print('✅ Données envoyées avec succès');
      } else {
        if (kDebugMode) print('⚠️  Réponse setData: $result');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erreur _pushDataToJs: $e');
    }
  }

  LngLat _centerFor(List<LngLat> perimeter, List<LngLat> route) {
    if (route.isNotEmpty) return route.first;
    if (perimeter.isNotEmpty) return perimeter.first;
    return (lng: -61.534, lat: 16.241);
  }

  Map<String, dynamic> _fc(List<Map<String, dynamic>> features) => {
    'type': 'FeatureCollection',
    'features': features,
  };

  Map<String, dynamic> _lineString(
    List<LngLat> points, {
    Map<String, dynamic>? properties,
  }) {
    return {
      'type': 'Feature',
      'properties': properties ?? <String, dynamic>{},
      'geometry': {
        'type': 'LineString',
        'coordinates': points.map((p) => [p.lng, p.lat]).toList(),
      },
    };
  }

  Map<String, dynamic> _perimeterGeoJson(List<LngLat> perimeter) {
    if (perimeter.length < 2) return _fc([]);
    final closed = _close(perimeter);
    return _fc([
      _lineString(closed, properties: {'color': '#00AEEF', 'width': 3}),
    ]);
  }

  Map<String, dynamic> _routeGeoJson(List<LngLat> route) {
    if (route.length < 2) return _fc([]);
    return _fc([
      _lineString(route, properties: {'color': '#1A73E8', 'width': 6}),
    ]);
  }

  Map<String, dynamic> _segmentsGeoJson(
    List<LngLat> route,
    List<({int startIndex, int endIndex, Color color, String name})> segments,
  ) {
    if (route.length < 2 || segments.isEmpty) return _fc([]);

    final features = <Map<String, dynamic>>[];
    for (final s in segments) {
      final start = s.startIndex.clamp(0, route.length - 1);
      final end = s.endIndex.clamp(0, route.length - 1);
      if (end <= start) continue;

      final pts = route.sublist(start, end + 1);
      if (pts.length < 2) continue;

      features.add(
        _lineString(
          pts,
          properties: {'name': s.name, 'color': _toHex(s.color), 'width': 8},
        ),
      );
    }

    return _fc(features);
  }

  List<LngLat> _close(List<LngLat> pts) {
    if (pts.isEmpty) return pts;
    final first = pts.first;
    final last = pts.last;
    if (first.lng == last.lng && first.lat == last.lat) return pts;
    return [...pts, first];
  }

  String _toHex(Color c) {
    final r = c.red.toRadixString(16).padLeft(2, '0');
    final g = c.green.toRadixString(16).padLeft(2, '0');
    final b = c.blue.toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(error, textAlign: TextAlign.center),
        ),
      );
    }

    return HtmlElementView(viewType: _viewType);
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _messageSub = null;
    super.dispose();
  }
}
