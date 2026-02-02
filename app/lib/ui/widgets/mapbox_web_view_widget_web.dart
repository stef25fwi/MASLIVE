// Web-only Mapbox GL JS implementation.
// ignore_for_file: avoid_web_libraries_in_flutter, unsafe_html, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;

import 'package:flutter/material.dart';

import 'mapbox_web_view_web.dart';

/// Widget Mapbox GL JS pour Flutter Web via HtmlElementView.
class MapboxWebView extends StatefulWidget {
  final String accessToken;
  final double initialLat;
  final double initialLng;
  final double initialZoom;
  final double initialPitch;
  final double initialBearing;
  final String? styleUrl;
  final double? userLat;
  final double? userLng;
  final bool showUserLocation;
  final ValueChanged<({double lng, double lat})>? onTapLngLat;
  final VoidCallback? onMapReady;
  final List<({double lng, double lat})> polyline;

  const MapboxWebView({
    super.key,
    required this.accessToken,
    this.initialLat = 16.2410,
    this.initialLng = -61.5340,
    this.initialZoom = 15.0,
    this.initialPitch = 45.0,
    this.initialBearing = 0.0,
    this.styleUrl,
    this.userLat,
    this.userLng,
    this.showUserLocation = false,
    this.onTapLngLat,
    this.onMapReady,
    this.polyline = const [],
  });

  @override
  State<MapboxWebView> createState() => _MapboxWebViewState();
}

class _MapboxWebViewState extends State<MapboxWebView> {
  late final String _viewType;
  String? _containerId;
  html.DivElement? _container;
  js.JsObject? _map;
  js.JsObject? _userMarker;
  StreamSubscription<html.MessageEvent>? _messageSub;
  StreamSubscription<html.Event>? _resizeSub;
  String? _error;
  bool _didNotifyReady = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'mapbox-web-view-${DateTime.now().microsecondsSinceEpoch}';
    _registerFactory();

    if (widget.accessToken.trim().isEmpty) {
      _error =
          'Token Mapbox manquant. Configure MAPBOX_ACCESS_TOKEN (ou MAPBOX_TOKEN legacy).';
    }

    _messageSub = html.window.onMessage.listen((evt) {
      final data = evt.data;
      if (widget.onTapLngLat == null) return;
      if (data is Map) {
        final type = data['type'];
        final containerId = data['containerId'];
        if (type != 'MASLIVE_MAP_TAP') return;
        if (_containerId != null && containerId != _containerId) return;
        final lng = data['lng'];
        final lat = data['lat'];
        if (lng is num && lat is num) {
          widget.onTapLngLat?.call((lng: lng.toDouble(), lat: lat.toDouble()));
        }
      }
    });

    _resizeSub = html.window.onResize.listen((_) {
      try {
        _map?.callMethod('resize');
      } catch (_) {
        // ignore
      }
    });
  }

  @override
  void didUpdateWidget(covariant MapboxWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_map == null && _container != null && widget.accessToken.isNotEmpty) {
      _initMapbox(_container!);
    }
    _updateUserMarker();
    _setPolylineGeoJson();
  }

  void _registerFactory() {
    registerMapboxViewFactory(_viewType, (int viewId) {
      final container = html.DivElement()
        ..id = 'mapbox-container-$viewId'
        ..style.width = '100%'
        ..style.height = '100%';

      _containerId ??= container.id;
      _container ??= container;

      Future.delayed(const Duration(milliseconds: 100), () {
        _initMapbox(container);
      });

      return container;
    });
  }

  void _initMapbox(html.DivElement container) {
    if (widget.accessToken.trim().isEmpty) {
      if (_error == null) {
        setState(() {
          _error =
              'Token Mapbox manquant. Configure MAPBOX_ACCESS_TOKEN (ou MAPBOX_TOKEN legacy).';
        });
      }
      return;
    }

    final mapboxglObj = js.context['mapboxgl'];
    if (mapboxglObj == null) {
      if (_error == null) {
        setState(() {
          _error =
              'Mapbox GL JS non chargé. Vérifie app/web/index.html (mapbox-gl.css + mapbox-gl.js).';
        });
      }
      return;
    }

    mapboxglObj['accessToken'] = widget.accessToken;

    final mapConfig = js.JsObject.jsify({
      'container': container,
      'style': widget.styleUrl ?? 'mapbox://styles/mapbox/streets-v12',
      'center': [widget.initialLng, widget.initialLat],
      'zoom': widget.initialZoom,
      'pitch': widget.initialPitch,
      'bearing': widget.initialBearing,
      'antialias': true,
      'logoPosition': 'top-left',
      'attributionControl': false,
    });

    final map = js.JsObject(mapboxglObj['Map'], [mapConfig]);
    _map = map;

    if (_error != null) {
      setState(() {
        _error = null;
      });
    }

    map.callMethod('on', [
      'load',
      (dynamic _) {
        final compassControl = js.JsObject(
          mapboxglObj['NavigationControl'],
          [
            js.JsObject.jsify({
              'showZoom': false,
              'showCompass': true,
            })
          ],
        );
        map.callMethod('addControl', [compassControl, 'top-right']);

        final zoomControl = js.JsObject(
          mapboxglObj['NavigationControl'],
          [
            js.JsObject.jsify({
              'showZoom': true,
              'showCompass': false,
            })
          ],
        );
        map.callMethod('addControl', [zoomControl, 'top-right']);

        final attributionControl = js.JsObject(
          mapboxglObj['AttributionControl'],
          [js.JsObject.jsify({'compact': true})],
        );
        map.callMethod('addControl', [attributionControl, 'top-left']);

        _add3dBuildings(map);
        _setPolylineGeoJson();

        if (widget.onTapLngLat != null && _containerId != null) {
          final id = _containerId!;
          try {
            js.context['__maslive_map_$id'] = map;
            js.context.callMethod('eval', [
              """(function(){
  try {
    var m = window['__maslive_map_$id'];
    if(!m) return;
    m.on('click', function(e){
      window.postMessage({type:'MASLIVE_MAP_TAP', containerId:'$id', lng:e.lngLat.lng, lat:e.lngLat.lat}, '*');
    });
  } catch(e) {}
})();""",
            ]);
          } catch (_) {
            // ignore
          }
        }

        _updateUserMarker();
        _setPolylineGeoJson();

        if (!_didNotifyReady) {
          _didNotifyReady = true;
          try {
            widget.onMapReady?.call();
          } catch (_) {
            // ignore
          }
        }

        try {
          Future.delayed(const Duration(milliseconds: 50), () {
            _map?.callMethod('resize');
          });
        } catch (_) {
          // ignore
        }
      },
    ]);
  }

  void _updateUserMarker() {
    final map = _map;
    if (map == null) return;

    final lat = widget.userLat;
    final lng = widget.userLng;
    if (!widget.showUserLocation || lat == null || lng == null) {
      try {
        _userMarker?.callMethod('remove');
      } catch (_) {
        // ignore
      }
      _userMarker = null;
      return;
    }

    final mapboxglObj = js.context['mapboxgl'];
    if (mapboxglObj == null) return;

    if (_userMarker == null) {
      try {
        final marker = js.JsObject(mapboxglObj['Marker']);
        marker.callMethod('setLngLat', [
          js.JsObject.jsify([lng, lat]),
        ]);
        marker.callMethod('addTo', [map]);
        _userMarker = marker;
      } catch (_) {
        // ignore
      }
    } else {
      try {
        _userMarker?.callMethod('setLngLat', [
          js.JsObject.jsify([lng, lat]),
        ]);
      } catch (_) {
        // ignore
      }
    }
  }

  void _setPolylineGeoJson() {
    final map = _map;
    if (map == null) return;

    final coords = widget.polyline.map((p) => [p.lng, p.lat]).toList();

    final geojson = js.JsObject.jsify({
      'type': 'Feature',
      'geometry': {
        'type': 'LineString',
        'coordinates': coords,
      },
      'properties': {},
    });

    const sourceId = 'maslive_polyline_src';
    const layerId = 'maslive_polyline_layer';

    try {
      final hasSource = map.callMethod('getSource', [sourceId]) != null;
      if (!hasSource) {
        map.callMethod('addSource', [
          sourceId,
          js.JsObject.jsify({'type': 'geojson', 'data': geojson})
        ]);

        map.callMethod('addLayer', [
          js.JsObject.jsify({
            'id': layerId,
            'type': 'line',
            'source': sourceId,
            'layout': {'line-join': 'round', 'line-cap': 'round'},
            'paint': {'line-width': 4, 'line-color': '#111111', 'line-opacity': 0.7},
          })
        ]);
      } else {
        // update data
        map.callMethod('getSource', [sourceId]).callMethod('setData', [geojson]);
      }
    } catch (_) {
      // ignore
    }
  }

  void _add3dBuildings(js.JsObject map) {
    try {
      final style = map.callMethod('getStyle');
      if (style == null) return;
      final layers = style['layers'];
      if (layers == null) return;

      String? labelLayerId;
      for (final layer in layers) {
        try {
          if (layer is Map && layer['type'] == 'symbol') {
            labelLayerId = layer['id']?.toString();
            break;
          }
        } catch (_) {
          // ignore
        }
      }

      map.callMethod('addLayer', [
        js.JsObject.jsify({
          'id': 'add-3d-buildings',
          'source': 'composite',
          'source-layer': 'building',
          'filter': ['==', 'extrude', 'true'],
          'type': 'fill-extrusion',
          'minzoom': 15,
          'paint': {
            'fill-extrusion-color': '#aaa',
            'fill-extrusion-height': [
              'interpolate',
              ['linear'],
              ['zoom'],
              15,
              0,
              15.05,
              ['get', 'height'],
            ],
            'fill-extrusion-base': [
              'interpolate',
              ['linear'],
              ['zoom'],
              15,
              0,
              15.05,
              ['get', 'min_height'],
            ],
            'fill-extrusion-opacity': 0.6,
          },
        }),
        if (labelLayerId != null) labelLayerId,
      ]);
    } catch (_) {
      // ignore
    }
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _resizeSub?.cancel();
    try {
      _userMarker?.callMethod('remove');
    } catch (_) {
      // ignore
    }
    try {
      _map?.callMethod('remove');
    } catch (_) {
      // ignore
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Container(
        color: Colors.black.withValues(alpha: 0.04),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      );
    }

    return HtmlElementView(viewType: _viewType);
  }
}
