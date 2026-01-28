import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Représentation simple côté UI (lon, lat)
typedef LngLat = ({double lng, double lat});

class MapboxNativeCircuitMap extends StatefulWidget {
  const MapboxNativeCircuitMap({
    super.key,
    required this.perimeter, // polygone fermé (ou non, on fermera)
    required this.route, // liste de points
    required this.segments, // segments colorés
    required this.locked,
    this.showMask = false,
    required this.onTapLngLat, // tap sur la carte -> ajout point / etc
    this.styleUri = MapboxStyles.MAPBOX_STREETS,
  });

  final List<LngLat> perimeter;
  final List<LngLat> route;

  /// segments = portions du tracé (ex: de i..j) + couleur
  final List<({int startIndex, int endIndex, Color color, String name})>
  segments;

  final bool locked;
  final bool showMask;
  final ValueChanged<LngLat> onTapLngLat;
  final String styleUri;

  @override
  State<MapboxNativeCircuitMap> createState() => _MapboxNativeCircuitMapState();
}

class _MapboxNativeCircuitMapState extends State<MapboxNativeCircuitMap> {
  MapboxMap? _map;
  bool _styleReady = false;

  // IDs
  static const _srcPerimeter = "maslive_perimeter";
  static const _srcMask = "maslive_mask";
  static const _srcRoute = "maslive_route";
  static const _srcSegments = "maslive_segments";

  static const _layerMask = "maslive_mask_fill";
  static const _layerPerimeter = "maslive_perimeter_line";
  static const _layerRoute = "maslive_route_line";
  static const _layerSegments = "maslive_segments_line";
  static const _layerArrows = "maslive_route_arrows";

  static const _imgArrow = "maslive_arrow";

  @override
  void didUpdateWidget(covariant MapboxNativeCircuitMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_styleReady) _renderAll();
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _map = mapboxMap;
  }

  void _onMapTap(MapContentGestureContext context) {
    if (widget.locked) return;
    final coords = context.point.coordinates;
    widget.onTapLngLat((
      lng: coords.lng.toDouble(),
      lat: coords.lat.toDouble(),
    ));
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData data) async {
    _styleReady = true;
    await _ensureArrowImage();
    await _ensureBaseLayers();
    await _renderAll();
  }

  Future<void> _ensureArrowImage() async {
    // Ajoute une petite flèche dans le style, utilisée par SymbolLayer
    // Asset à créer : assets/map/arrow.png
    final bytes = await rootBundle.load('assets/map/arrow.png');
    final img = MbxImage(
      width: 64,
      height: 64,
      data: bytes.buffer.asUint8List(),
    );

    // addStyleImage(imageId, scale, image, sdf, stretchX, stretchY, content)
    // SDF=false ici.
    try {
      await _map?.style.addStyleImage(
        _imgArrow,
        1.0,
        img,
        false,
        const [],
        const [],
        null,
      );
    } catch (_) {
      // si déjà présent / ou selon versions, ignore
    }
  }

  Future<void> _ensureBaseLayers() async {
    // 1) Sources vides
    await _tryAddSource(_srcMask, _emptyFeatureCollection());
    await _tryAddSource(_srcPerimeter, _emptyFeatureCollection());
    await _tryAddSource(_srcRoute, _emptyFeatureCollection());
    await _tryAddSource(_srcSegments, _emptyFeatureCollection());

    // 2) Layers : masque gris hors périmètre
    await _tryAddLayer(
      FillLayer(
        id: _layerMask,
        sourceId: _srcMask,
        fillColor: const Color(0xFF000000).toARGB32(),
        fillOpacity: 0.35,
      ),
    );

    // 3) Périmètre (bord)
    await _tryAddLayer(
      LineLayer(
        id: _layerPerimeter,
        sourceId: _srcPerimeter,
        lineColor: const Color(0xFFFF3B30).toARGB32(),
        lineWidth: 3.0,
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
      ),
    );

    // 4) Route (ligne principale)
    await _tryAddLayer(
      LineLayer(
        id: _layerRoute,
        sourceId: _srcRoute,
        lineColor: const Color(0xFF1A73E8).toARGB32(),
        lineWidth: 6.0,
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
      ),
    );

    // 5) Segments (surcouche)
    // Utiliser les expressions Mapbox (Array syntax) pour accéder aux propriétés des features
    // Syntaxe: ['get', 'propertyName'] pour récupérer les valeurs
    // Note: Les couleurs doivent être converties en hex string dans les propriétés GeoJSON
    await _tryAddLayer(
      LineLayer(
        id: _layerSegments,
        sourceId: _srcSegments,
        lineColor: 0xFF1A73E8, // Couleur par défaut (bleu)
        lineWidth: 8.0, // Largeur par défaut
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
      ),
    );

    // 6) Flèches sens (symbol sur la ligne)
    await _tryAddLayer(
      SymbolLayer(
        id: _layerArrows,
        sourceId: _srcRoute,
        symbolPlacement: SymbolPlacement.LINE,
        iconImage: _imgArrow,
        iconRotationAlignment: IconRotationAlignment.MAP,
        iconAllowOverlap: true,
        symbolSpacing: 120.0,
        iconSize: 0.35,
      ),
    );
  }

  Future<void> _renderAll() async {
    // A) Périmètre (polygon)
    final perimeter = _closed(widget.perimeter);
    final perimeterFc = _featureCollection([
      _polygonFeature([perimeter.map(_toCoord).toList()]),
    ]);

    // B) Masque hors périmètre (un grand polygone “monde” avec un trou)
    // Outer ring : rectangle géant (évite les pôles)
    final outer = <List<double>>[
      [-180, -85],
      [180, -85],
      [180, 85],
      [-180, 85],
      [-180, -85],
    ];
    final hole = perimeter.map(_toCoord).toList();
    final maskFc = widget.showMask && perimeter.length >= 3
        ? _featureCollection([
            _polygonFeature([outer, hole]),
          ])
        : _emptyFeatureCollection();

    // C) Route
    final route = widget.route;
    final routeFc = route.length < 2
        ? _emptyFeatureCollection()
        : _featureCollection([_lineFeature(route.map(_toCoord).toList())]);

    // D) Segments
    final segFeatures = <Map<String, dynamic>>[];
    for (final s in widget.segments) {
      final a = s.startIndex.clamp(0, route.length - 1);
      final b = s.endIndex.clamp(0, route.length - 1);
      if (route.length < 2 || b <= a) continue;
      final coords = route.sublist(a, b + 1).map(_toCoord).toList();
      // Convertir la couleur en format hex string pour Mapbox
      final colorHex =
          '#${s.color.toARGB32().toRadixString(16).padLeft(8, '0')}';
      segFeatures.add(
        _lineFeature(
          coords,
          props: {"color": colorHex, "width": 8.0, "name": s.name},
        ),
      );
    }
    final segmentsFc = _featureCollection(segFeatures);

    // Update sources
    await _updateGeoJson(_srcPerimeter, perimeterFc);
    await _updateGeoJson(_srcMask, maskFc);
    await _updateGeoJson(_srcRoute, routeFc);
    await _updateGeoJson(_srcSegments, segmentsFc);
  }

  // ---- helpers style ----

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
    // Update la source GeoJSON
    // Utiliser setStyleSourceProperties pour mettre à jour les données
    try {
      // Supprimer et recréer pour mettre à jour les données
      await _map?.style.removeStyleSource(sourceId);
    } catch (_) {}
    await _tryAddSource(sourceId, fcJson);
  }

  // ---- geojson builders ----

  String _emptyFeatureCollection() =>
      jsonEncode({"type": "FeatureCollection", "features": []});

  String _featureCollection(List<Map<String, dynamic>> features) =>
      jsonEncode({"type": "FeatureCollection", "features": features});

  Map<String, dynamic> _lineFeature(
    List<List<double>> coords, {
    Map<String, dynamic>? props,
  }) => {
    "type": "Feature",
    "properties": props ?? {},
    "geometry": {"type": "LineString", "coordinates": coords},
  };

  Map<String, dynamic> _polygonFeature(
    List<List<List<double>>> rings, {
    Map<String, dynamic>? props,
  }) => {
    "type": "Feature",
    "properties": props ?? {},
    "geometry": {"type": "Polygon", "coordinates": rings},
  };

  List<double> _toCoord(LngLat p) => [p.lng, p.lat];

  List<LngLat> _closed(List<LngLat> pts) {
    if (pts.isEmpty) return pts;
    final first = pts.first;
    final last = pts.last;
    if ((first.lng == last.lng) && (first.lat == last.lat)) return pts;
    return [...pts, first];
  }

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      key: const ValueKey("maslive_map_native"),
      styleUri: widget.styleUri,
      cameraOptions: CameraOptions(
        zoom: 12.0,
        center: (widget.route.isNotEmpty)
            ? Point(
                coordinates: Position(
                  widget.route.first.lng,
                  widget.route.first.lat,
                ),
              )
            : Point(
                coordinates: Position(-61.551, 16.265),
              ), // défaut Guadeloupe
      ),
      onMapCreated: _onMapCreated,
      onStyleLoadedListener: _onStyleLoaded,
      onTapListener: _onMapTap,
    );
  }
}
