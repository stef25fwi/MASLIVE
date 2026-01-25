// ignore_for_file: avoid_web_libraries_in_flutter
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

  const MapboxWebView({
    super.key,
    required this.accessToken,
    this.initialLat = 16.2410,
    this.initialLng = -61.5340,
    this.initialZoom = 15.0,
    this.initialPitch = 45.0,
    this.initialBearing = 0.0,
    this.styleUrl,
  });

  @override
  State<MapboxWebView> createState() => _MapboxWebViewState();
}

class _MapboxWebViewState extends State<MapboxWebView> {
  final String _viewType = 'mapbox-web-view';

  @override
  void initState() {
    super.initState();
    _registerFactory();
  }

  void _registerFactory() {
    registerMapboxViewFactory(
      _viewType,
      (int viewId) {
        final container = html.DivElement()
          ..id = 'mapbox-container-$viewId'
          ..style.width = '100%'
          ..style.height = '100%';

        // Initialiser Mapbox GL JS après un court délai pour s'assurer que le DOM est prêt
        Future.delayed(const Duration(milliseconds: 100), () {
          _initMapbox(container);
        });

        return container;
      },
    );
  }

  void _initMapbox(html.DivElement container) {
    // Vérifier que mapboxgl est disponible
    final mapboxgl = js.context['mapboxgl'];
    if (mapboxgl == null) return;
    
    // Définir le token
    mapboxgl['accessToken'] = widget.accessToken;

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
    final map = js.JsObject(mapboxgl['Map'], [mapConfig]);

    // Ajouter les contrôles de navigation après le chargement
    map.callMethod('on', ['load', (dynamic _) {
      final navigationControl = js.JsObject(mapboxgl['NavigationControl']);
      map.callMethod('addControl', [navigationControl]);

      // Ajouter les bâtiments 3D si disponible
      _add3dBuildings(map);
    }]);
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
  Widget build(BuildContext context) {
    return HtmlElementView(
      viewType: _viewType,
    );
  }
}
