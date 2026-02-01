// ignore_for_file: avoid_web_libraries_in_flutter, unsafe_html
import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/material.dart';

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
  int _rebuildTick = 0;
  js.JsObject? _mapInstance;
  List<js.JsObject> _markers = [];
  void Function(double lat, double lng)? _onPointAddedCallback;

  @override
  void initState() {
    super.initState();
    _loadMapboxToken();
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

  void _onMapReady(js.JsObject map) {
    _mapInstance = map;
    _connectController();
    final controller = widget.controller;
    if (controller != null) {
      widget.onMapReady?.call(controller);
    }
  }

  void _connectController() {
    final controller = widget.controller;
    if (controller == null || _mapInstance == null) return;

    controller.moveToImpl = (lng, lat, zoom, animate) async {
      try {
        if (animate) {
          _mapInstance?.callMethod('flyTo', [
            js.JsObject.jsify({'center': [lng, lat], 'zoom': zoom})
          ]);
        } else {
          _mapInstance?.callMethod('jumpTo', [
            js.JsObject.jsify({'center': [lng, lat], 'zoom': zoom})
          ]);
        }
      } catch (e) {
        debugPrint('⚠️ moveTo error: $e');
      }
    };

    controller.setStyleImpl = (styleUri) async {
      try {
        _mapInstance?.callMethod('setStyle', [styleUri]);
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
        // Supprimer anciens markers
        for (final m in _markers) {
          m.callMethod('remove');
        }
        _markers.clear();

        final mapboxglObj = js.context['mapboxgl'];
        if (mapboxglObj == null) return;

        // Créer nouveaux markers
        for (final m in markers) {
          final markerEl = html.DivElement()
            ..style.width = '${20 * m.size}px'
            ..style.height = '${20 * m.size}px'
            ..style.backgroundColor = '#${m.color.value.toRadixString(16).padLeft(8, '0').substring(2)}'
            ..style.borderRadius = '50%'
            ..style.border = '2px solid white';

          final marker = js.JsObject(mapboxglObj['Marker'], [
            js.JsObject.jsify({'element': markerEl})
          ]);
          marker.callMethod('setLngLat', [
            js.JsObject.jsify([m.lng, m.lat])
          ]);
          marker.callMethod('addTo', [_mapInstance]);
          _markers.add(marker);
        }
      } catch (e) {
        debugPrint('⚠️ setMarkers error: $e');
      }
    };

    controller.setPolylineImpl = (points, color, width, show) async {
      try {
        const sourceId = 'maslive_polyline';
        const layerId = 'maslive_polyline_layer';

        if (!show) {
          _mapInstance?.callMethod('removeLayer', [layerId]);
          _mapInstance?.callMethod('removeSource', [sourceId]);
          return;
        }

        final coords = points.map((p) => [p.lng, p.lat]).toList();
        final geojson = js.JsObject.jsify({
          'type': 'Feature',
          'geometry': {'type': 'LineString', 'coordinates': coords},
        });

        final hasSource = _mapInstance?.callMethod('getSource', [sourceId]) != null;
        if (!hasSource) {
          _mapInstance?.callMethod('addSource', [
            sourceId,
            js.JsObject.jsify({'type': 'geojson', 'data': geojson})
          ]);
          _mapInstance?.callMethod('addLayer', [
            js.JsObject.jsify({
              'id': layerId,
              'type': 'line',
              'source': sourceId,
              'paint': {
                'line-width': width,
                'line-color': '#${color.value.toRadixString(16).padLeft(8, '0').substring(2, 8)}',
              },
            })
          ]);
        } else {
          _mapInstance?.callMethod('getSource', [sourceId]).callMethod('setData', [geojson]);
        }
      } catch (e) {
        debugPrint('⚠️ setPolyline error: $e');
      }
    };

    controller.setPolygonImpl = (points, fillColor, strokeColor, strokeWidth, show) async {
      try {
        const sourceId = 'maslive_polygon';
        const fillLayerId = 'maslive_polygon_fill';
        const lineLayerId = 'maslive_polygon_line';

        if (!show) {
          _mapInstance?.callMethod('removeLayer', [lineLayerId]);
          _mapInstance?.callMethod('removeLayer', [fillLayerId]);
          _mapInstance?.callMethod('removeSource', [sourceId]);
          return;
        }

        final coords = points.map((p) => [p.lng, p.lat]).toList();
        final geojson = js.JsObject.jsify({
          'type': 'Feature',
          'geometry': {'type': 'Polygon', 'coordinates': [coords]},
        });

        final hasSource = _mapInstance?.callMethod('getSource', [sourceId]) != null;
        if (!hasSource) {
          _mapInstance?.callMethod('addSource', [
            sourceId,
            js.JsObject.jsify({'type': 'geojson', 'data': geojson})
          ]);
          _mapInstance?.callMethod('addLayer', [
            js.JsObject.jsify({
              'id': fillLayerId,
              'type': 'fill',
              'source': sourceId,
              'paint': {
                'fill-color': '#${fillColor.value.toRadixString(16).padLeft(8, '0').substring(2, 8)}',
                'fill-opacity': fillColor.opacity,
              },
            })
          ]);
          _mapInstance?.callMethod('addLayer', [
            js.JsObject.jsify({
              'id': lineLayerId,
              'type': 'line',
              'source': sourceId,
              'paint': {
                'line-width': strokeWidth,
                'line-color': '#${strokeColor.value.toRadixString(16).padLeft(8, '0').substring(2, 8)}',
              },
            })
          ]);
        } else {
          _mapInstance?.callMethod('getSource', [sourceId]).callMethod('setData', [geojson]);
        }
      } catch (e) {
        debugPrint('⚠️ setPolygon error: $e');
      }
    };

    controller.setEditingEnabledImpl = (enabled, onPointAdded) async {
      _onPointAddedCallback = enabled ? onPointAdded : null;
    };

    controller.clearAllImpl = () async {
      try {
        for (final m in _markers) {
          m.callMethod('remove');
        }
        _markers.clear();

        _mapInstance?.callMethod('removeLayer', ['maslive_polyline_layer']);
        _mapInstance?.callMethod('removeSource', ['maslive_polyline']);
        _mapInstance?.callMethod('removeLayer', ['maslive_polygon_line']);
        _mapInstance?.callMethod('removeLayer', ['maslive_polygon_fill']);
        _mapInstance?.callMethod('removeSource', ['maslive_polygon']);
      } catch (e) {
        // ignore
      }
    };
  }

  @override
  void dispose() {
    _onPointAddedCallback = null;
    for (final m in _markers) {
      try {
        m.callMethod('remove');
      } catch (_) {
        // ignore
      }
    }
    _markers.clear();
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

    return _MapboxWebViewCustom(
      key: ValueKey('maslive-map-web-$_rebuildTick'),
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
  }
}

/// Widget wrapper pour Mapbox GL JS avec interop personnalisée
class _MapboxWebViewCustom extends StatefulWidget {
  final String accessToken;
  final double initialLat;
  final double initialLng;
  final double initialZoom;
  final double initialPitch;
  final double initialBearing;
  final String? styleUrl;
  final void Function(js.JsObject map)? onMapReady;
  final void Function(double lng, double lat)? onTap;

  const _MapboxWebViewCustom({
    super.key,
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
  js.JsObject? _map;
  StreamSubscription<html.MessageEvent>? _messageSub;

  @override
  void initState() {
    super.initState();
    _viewType = 'maslive-mapbox-${DateTime.now().microsecondsSinceEpoch}';
    _registerFactory();

    if (widget.onTap != null) {
      _messageSub = html.window.onMessage.listen((evt) {
        final data = evt.data;
        if (data is Map) {
          final type = data['type'];
          if (type == 'MASLIVE_MAP_TAP') {
            final lng = data['lng'];
            final lat = data['lat'];
            if (lng is num && lat is num) {
              widget.onTap?.call(lng.toDouble(), lat.toDouble());
            }
          }
        }
      });
    }
  }

  void _registerFactory() {
    // ignore: undefined_prefixed_name
    (js.context['_flutter_web_ui'] as js.JsObject)['platformViewRegistry']
        .callMethod('registerViewFactory', [
      _viewType,
      (int viewId) {
        final container = html.DivElement()
          ..id = 'mapbox-$viewId'
          ..style.width = '100%'
          ..style.height = '100%';

        Future.delayed(const Duration(milliseconds: 100), () {
          _initMapbox(container);
        });

        return container;
      },
    ]);
  }

  void _initMapbox(html.DivElement container) {
    final mapboxglObj = js.context['mapboxgl'];
    if (mapboxglObj == null) return;

    mapboxglObj['accessToken'] = widget.accessToken;

    final map = js.JsObject(mapboxglObj['Map'], [
      js.JsObject.jsify({
        'container': container,
        'style': widget.styleUrl ?? 'mapbox://styles/mapbox/streets-v12',
        'center': [widget.initialLng, widget.initialLat],
        'zoom': widget.initialZoom,
        'pitch': widget.initialPitch,
        'bearing': widget.initialBearing,
      })
    ]);

    _map = map;

    map.callMethod('on', [
      'load',
      (dynamic _) {
        widget.onMapReady?.call(map);

        if (widget.onTap != null) {
          map.callMethod('on', [
            'click',
            (dynamic e) {
              final lngLat = e['lngLat'];
              if (lngLat != null) {
                final lng = lngLat['lng'];
                final lat = lngLat['lat'];
                if (lng is num && lat is num) {
                  html.window.postMessage({
                    'type': 'MASLIVE_MAP_TAP',
                    'lng': lng,
                    'lat': lat,
                  }, '*');
                }
              }
            }
          ]);
        }
      }
    ]);
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    try {
      _map?.callMethod('remove');
    } catch (_) {
      // ignore
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
