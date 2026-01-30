// ignore_for_file: avoid_web_libraries_in_flutter, unsafe_html, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/material.dart';

import 'mapbox_web_view_stub.dart'
    if (dart.library.html) 'mapbox_web_view_web.dart';

/// Widget Mapbox GL JS pour Flutter Web via HtmlElementView
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
  }

  void _registerFactory() {
    registerMapboxViewFactory(_viewType, (int viewId) {
      final container = html.DivElement()
        ..id = 'mapbox-container-$viewId'
        ..style.width = '100%'
        ..style.height = '100%';

      _containerId ??= container.id;
      _container ??= container;

      // Initialiser Mapbox GL JS après un court délai pour s'assurer que le DOM est prêt
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

    // Vérifier que mapboxgl est disponible
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

    // Définir le token
    mapboxglObj['accessToken'] = widget.accessToken;

    // Créer la configuration de la carte
    final mapConfig = js.JsObject.jsify({
      'container': container,
      'style': widget.styleUrl ?? 'mapbox://styles/mapbox/streets-v12',
      'center': [widget.initialLng, widget.initialLat],
      'zoom': widget.initialZoom,
      'pitch': widget.initialPitch,
      'bearing': widget.initialBearing,
      'antialias': true,
    });

    // Créer la carte
    final map = js.JsObject(mapboxglObj['Map'], [mapConfig]);
    _map = map;

    if (_error != null) {
      setState(() {
        _error = null;
      });
    }

    // Ajouter les contrôles de navigation après le chargement
    map.callMethod('on', [
      'load',
      (dynamic _) {
        final navigationControl = js.JsObject(mapboxglObj['NavigationControl']);
        map.callMethod('addControl', [navigationControl]);

        // Ajouter les bâtiments 3D si disponible
        _add3dBuildings(map);

        // Installer un handler JS de click qui publie vers Flutter via postMessage
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

        // Force un resize après chargement pour gérer les changements d'orientation.
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
    final shouldShow = widget.showUserLocation && lat != null && lng != null;

    if (!shouldShow) {
      try {
        _userMarker?.callMethod('remove');
      } catch (_) {
        // ignore
      }
      _userMarker = null;
      return;
    }

    try {
      if (_userMarker == null) {
        final mapboxglObj = js.context['mapboxgl'];
        if (mapboxglObj == null) return;
        _userMarker = js.JsObject(mapboxglObj['Marker'], [
          js.JsObject.jsify({'color': '#2F80ED'}),
        ]);
        _userMarker!.callMethod('setLngLat', [
          [lng, lat],
        ]);
        _userMarker!.callMethod('addTo', [map]);
      } else {
        _userMarker!.callMethod('setLngLat', [
          [lng, lat],
        ]);
      }
    } catch (_) {
      // ignore
    }
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

    // Wrapper avec dimensions explicites pour Web
    return SizedBox.expand(child: HtmlElementView(viewType: _viewType));
  }

  void _add3dBuildings(js.JsObject map) {
    try {
      // Insérer la couche 3D buildings
      final buildingsLayer = js.JsObject.jsify({
        'id': '3d-buildings',
        'source': 'composite',
        'source-layer': 'building',
        'filter': ['==', 'extrude', 'true'],
        'type': 'fill-extrusion',
        'minzoom': 14.5,
        'paint': {
          'fill-extrusion-color': '#D1D5DB',
          'fill-extrusion-height': ['get', 'height'],
          'fill-extrusion-base': ['get', 'min_height'],
          'fill-extrusion-opacity': 0.72,
        },
      });

      map.callMethod('addLayer', [buildingsLayer]);
    } catch (e) {
      // Si la source composite n'existe pas, ignorer silencieusement
      debugPrint('Could not add 3D buildings: $e');
    }
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _messageSub = null;
    _resizeSub?.cancel();
    _resizeSub = null;
    try {
      _userMarker?.callMethod('remove');
    } catch (_) {
      // ignore
    }
    _userMarker = null;
    try {
      _map?.callMethod('remove');
    } catch (_) {
      // ignore
    }
    if (_containerId != null) {
      try {
        js.context.deleteProperty('__maslive_map_${_containerId!}');
      } catch (_) {
        // ignore
      }
    }
    _map = null;
    super.dispose();
  }
}
