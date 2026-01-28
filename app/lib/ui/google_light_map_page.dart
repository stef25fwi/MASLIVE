import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class GoogleLightMapPage extends StatefulWidget {
  const GoogleLightMapPage({super.key});

  @override
  State<GoogleLightMapPage> createState() => _GoogleLightMapPageState();
}

class _GoogleLightMapPageState extends State<GoogleLightMapPage> {
  MapboxMap? _map;
  String? _styleJson;
  String? _error;

  // Exemple: Pointe-à-Pitre (remplace par ta position)
  static const double _lat = 16.2410;
  static const double _lng = -61.5340;

  static const String _buildingsLayerId = 'maslive-3d-buildings';

  @override
  void initState() {
    super.initState();
    _initMapboxToken();
    _loadStyle();
  }

  void _initMapboxToken() {
    const token = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');
    if (token.isEmpty) {
      setState(() {
        _error =
            'MAPBOX_ACCESS_TOKEN manquant. Lance avec --dart-define=MAPBOX_ACCESS_TOKEN=...';
      });
      return;
    }

    // API Mapbox Flutter SDK: token global
    MapboxOptions.setAccessToken(token);
  }

  Future<void> _loadStyle() async {
    final json = await rootBundle.loadString(
      'assets/map_styles/google_light.json',
    );
    if (!mounted) return;
    setState(() => _styleJson = json);
  }

  Future<void> _add3dBuildings(MapboxMap map) async {
    try {
      final style = map.style;

      final layer = FillExtrusionLayer(id: _buildingsLayerId, sourceId: 'composite')
        ..sourceLayer = 'building'
        ..minZoom = 14.5
        ..fillExtrusionColor = const Color(0xFFD1D5DB).toARGB32()
        ..fillExtrusionOpacity = 0.72
        // Note: sur cette version du SDK, height/base sont des doubles (pas d'expressions).
        // On applique une extrusion fixe (effet 3D lisible) sans dépendre des attributs.
        ..fillExtrusionHeight = 22.0
        ..fillExtrusionBase = 0.0;

      // Affiche uniquement les buildings “extrudables” si la donnée existe.
      // (Sur Mapbox Streets, c'est souvent un champ `extrude`.)
      layer.filter = const [
        '==',
        ['get', 'extrude'],
        'true',
      ];

      await style.addLayer(layer);
    } catch (_) {
      // Si la source/layer existe déjà ou si le style ne supporte pas cette source,
      // on ignore silencieusement (objectif: ne pas bloquer l’expérience).
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mapbox')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_error!, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    if (_styleJson == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey("mapbox-map"),
            // styleUri doit être une URI Mapbox ; le JSON est chargé dans onMapCreated
            styleUri: 'mapbox://styles/mapbox/streets-v12',
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(_lng, _lat)),
              zoom: 15.2,
              pitch: 45.0, // ✅ exploration (modéré)
              bearing: 0.0,
            ),
            onMapCreated: (mapboxMap) async {
              _map = mapboxMap;

              final styleJson = _styleJson;
              if (styleJson != null) {
                await mapboxMap.loadStyleJson(styleJson);
              }

              await _add3dBuildings(mapboxMap);

              // Optionnel: adoucir l’expérience (selon versions SDK)
              await _map?.gestures.updateSettings(
                GesturesSettings(
                  pitchEnabled: true,
                  rotateEnabled: true,
                  scrollEnabled: true,
                  pinchToZoomEnabled: true,
                ),
              );
            },
          ),

          // Petit bouton test pour “cinematic fly”
          Positioned(
            right: 14,
            bottom: 18,
            child: FloatingActionButton(
              onPressed: () async {
                final map = _map;
                if (map == null) return;

                await map.flyTo(
                  CameraOptions(
                    center: Point(coordinates: Position(_lng, _lat)),
                    zoom: 16.6,
                    pitch: 65.0,
                    bearing: 25.0,
                  ),
                  MapAnimationOptions(duration: 900, startDelay: 0),
                );
              },
              child: const Icon(Icons.navigation),
            ),
          ),
        ],
      ),
    );
  }
}
