import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../route_style_pro/services/route_style_pro_projection.dart';

/// ===============================
/// MarketMap Public Viewer (Mobile)
/// ===============================
/// Objectif:
/// - 1 seule instance MapWidget (pas de re-instanciation)
/// - Lecture Firestore uniquement (consultation)
/// - Route via GeoJsonSource + LineLayer
/// - POIs via GeoJsonSource + plusieurs CircleLayers (1 par layerId)
/// - Tap POI -> bottom sheet
///
/// Chemins Firestore:
/// marketMap/{countryId}/events/{eventId}/circuits/{circuitId}
/// marketMap/{countryId}/events/{eventId}/circuits/{circuitId}/layers/{layerId}
/// marketMap/{countryId}/events/{eventId}/circuits/{circuitId}/pois/{poiId}
class MarketMapPublicViewerPage extends StatefulWidget {
  final String countryId;
  final String eventId;

  /// Optionnel: pré-sélection circuit
  final String? initialCircuitId;

  /// Optionnel si tu ne set pas déjà le token dans main()
  final String? accessToken;

  /// Fallback style si circuit.styleUrl vide
  final String defaultStyleUri;

  const MarketMapPublicViewerPage({
    super.key,
    required this.countryId,
    required this.eventId,
    this.initialCircuitId,
    this.accessToken,
    this.defaultStyleUri = MapboxStyles.MAPBOX_STREETS,
  });

  @override
  State<MarketMapPublicViewerPage> createState() =>
      _MarketMapPublicViewerPageState();
}

class _MarketMapPublicViewerPageState extends State<MarketMapPublicViewerPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Mapbox
  MapboxMap? _map;
  bool _styleLoaded = false;
  String? _currentStyleUri;

  // Sources / Layers
  static const String _routeSourceId = 'mm_public_route_src';
  static const String _poiSourceId = 'mm_public_poi_src';

  static const String _routeCasingLayerId = 'mm_public_route_casing_layer';
  static const String _routeLayerId = 'mm_public_route_layer';
  final Set<String> _poiLayerIdsCreated = <String>{};

  // Selected circuit
  String? _selectedCircuitId;
  String _selectedCircuitName = '';
  bool _didAutoSelectFromList = false;

  // Streams
  StreamSubscription? _subCircuitDoc;
  StreamSubscription? _subLayers;
  StreamSubscription? _subPois;

  // UI toggles
  bool _showRoute = true;

  bool _routeCasingWantedVisible = false;

  // Layers config (local)
  final Map<String, _UiLayer> _uiLayersById = <String, _UiLayer>{};

  // Data cache
  String _routeGeoJsonString = _emptyFeatureCollection();
  String _poisGeoJsonString = _emptyFeatureCollection();
  final List<_PoiItem> _visiblePois = <_PoiItem>[];

  Map<String, dynamic>? _lastCircuitDocData;

  // Firestore refs
  CollectionReference<Map<String, dynamic>> get _circuitsCol => _db
      .collection('marketMap')
      .doc(widget.countryId)
      .collection('events')
      .doc(widget.eventId)
      .collection('circuits');

  DocumentReference<Map<String, dynamic>> _circuitRef(String circuitId) =>
      _circuitsCol.doc(circuitId);

  CollectionReference<Map<String, dynamic>> _layersCol(String circuitId) =>
      _circuitRef(circuitId).collection('layers');

  CollectionReference<Map<String, dynamic>> _poisCol(String circuitId) =>
      _circuitRef(circuitId).collection('pois');

  @override
  void initState() {
    super.initState();

    if (!kIsWeb && (widget.accessToken ?? '').trim().isNotEmpty) {
      MapboxOptions.setAccessToken(widget.accessToken!.trim());
    }

    _selectedCircuitId = widget.initialCircuitId;
  }

  @override
  void dispose() {
    _cancelCircuitSubs();
    super.dispose();
  }

  void _cancelCircuitSubs() {
    _subCircuitDoc?.cancel();
    _subLayers?.cancel();
    _subPois?.cancel();
    _subCircuitDoc = null;
    _subLayers = null;
    _subPois = null;
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _map = mapboxMap;
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData data) async {
    _styleLoaded = true;

    // Le rechargement du style remet les layers à zéro.
    _poiLayerIdsCreated.clear();

    await _ensureBaseSourcesAndLayers();
    await _rebuildPoiLayersFromUiState();
    if (_lastCircuitDocData != null) {
      await _applyRouteStyleFromCircuitDoc(_lastCircuitDocData!);
    }
    await _applyDataIfReady();
  }

  Future<void> _ensureBaseSourcesAndLayers() async {
    final map = _map;
    if (map == null) return;

    // Sources vides
    await _tryAddSource(_routeSourceId, _emptyFeatureCollection());
    await _tryAddSource(_poiSourceId, _emptyFeatureCollection());

    // Route layer
    await _tryAddLayer(
      LineLayer(
        id: _routeCasingLayerId,
        sourceId: _routeSourceId,
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
        lineOpacity: 0.95,
        lineWidth: 11.0,
        lineColor: const Color(0xFF0B1B2B).toARGB32(),
      ),
    );
    await _tryAddLayer(
      LineLayer(
        id: _routeLayerId,
        sourceId: _routeSourceId,
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
        lineOpacity: 0.95,
        lineWidth: 7.0,
        lineColor: const Color(0xFF00A3FF).toARGB32(),
      ),
    );

    // Clustering léger sur la source POI (optionnel)
    // -> si la version SDK ne supporte pas ces props, elles seront juste ignorées.
    try {
      await map.style.setStyleSourceProperty(_poiSourceId, 'cluster', true);
      await map.style.setStyleSourceProperty(_poiSourceId, 'clusterRadius', 55);
      await map.style.setStyleSourceProperty(
        _poiSourceId,
        'clusterMaxZoom',
        14,
      );
    } catch (_) {
      // ignore
    }
  }

  Future<void> _tryAddSource(String id, String data) async {
    try {
      await _map?.style.addSource(GeoJsonSource(id: id, data: data));
    } catch (_) {
      // ignore (déjà présent / style pas prêt)
    }
  }

  Future<void> _tryAddLayer(Layer layer) async {
    try {
      await _map?.style.addLayer(layer);
    } catch (_) {
      // ignore (déjà présent / style pas prêt)
    }
  }

  Future<void> _updateGeoJson(String sourceId, String fcJson) async {
    // Aligné sur le reste du repo: remove+add.
    try {
      await _map?.style.removeStyleSource(sourceId);
    } catch (_) {
      // ignore
    }
    await _tryAddSource(sourceId, fcJson);
  }

  Future<void> _applyDataIfReady() async {
    if (!_styleLoaded || _map == null) return;

    await _updateGeoJson(_routeSourceId, _routeGeoJsonString);
    await _updateGeoJson(_poiSourceId, _poisGeoJsonString);

    await _setLayerVisibility(_routeLayerId, _showRoute);
    await _setLayerVisibility(
      _routeCasingLayerId,
      _showRoute && _routeCasingWantedVisible,
    );

    // POI layers visibilités selon _uiLayersById
    for (final entry in _uiLayersById.entries) {
      final layerId = _poiLayerIdFor(entry.key);
      await _setLayerVisibility(layerId, entry.value.visible);
    }
  }

  Future<void> _setLayerVisibility(String layerId, bool visible) async {
    final map = _map;
    if (map == null) return;
    try {
      await map.style.setStyleLayerProperty(
        layerId,
        'visibility',
        visible ? 'visible' : 'none',
      );
    } catch (_) {
      // ignore
    }
  }

  Future<void> _applyRouteStyleFromCircuitDoc(Map<String, dynamic> d) async {
    final map = _map;
    if (map == null) return;
    if (!_styleLoaded) return;

    Future<void> safeSet(String layerId, String key, dynamic value) async {
      try {
        await map.style.setStyleLayerProperty(layerId, key, value);
      } catch (_) {
        // ignore
      }
    }

    final proCfg = tryParseRouteStylePro(d['routeStylePro']);
    if (proCfg != null) {
      final join = proCfg.lineJoin.name;
      final cap = proCfg.lineCap.name;
      final dash = proCfg.dashEnabled
          ? <double>[proCfg.dashLength, proCfg.dashGap]
          : <double>[1.0, 0.0];

      _routeCasingWantedVisible = proCfg.casingWidth > proCfg.mainWidth + 0.5;

      await safeSet(_routeLayerId, 'line-join', join);
      await safeSet(_routeLayerId, 'line-cap', cap);
      await safeSet(_routeLayerId, 'line-opacity', proCfg.opacity);
      await safeSet(_routeLayerId, 'line-width', proCfg.mainWidth);
      await safeSet(_routeLayerId, 'line-color', proCfg.mainColor.toARGB32());
      await safeSet(_routeLayerId, 'line-dasharray', dash);

      await safeSet(_routeCasingLayerId, 'line-join', join);
      await safeSet(_routeCasingLayerId, 'line-cap', cap);
      await safeSet(_routeCasingLayerId, 'line-opacity', proCfg.opacity);
      await safeSet(_routeCasingLayerId, 'line-width', proCfg.casingWidth);
      await safeSet(
        _routeCasingLayerId,
        'line-color',
        proCfg.casingColor.toARGB32(),
      );
      await safeSet(_routeCasingLayerId, 'line-dasharray', dash);

      if (mounted) setState(() {});
      return;
    }

    // Fallback legacy
    _routeCasingWantedVisible = false;
    final legacyAny = d['style'] ?? d['routeStyle'];
    final legacy = legacyAny is Map
        ? Map<String, dynamic>.from(legacyAny)
        : const <String, dynamic>{};

    final legacyColor =
        _parseHexColor(legacy['color']?.toString()) ?? const Color(0xFF00A3FF);
    final legacyWidth = (legacy['width'] as num?)?.toDouble() ?? 7.0;
    await safeSet(_routeLayerId, 'line-width', legacyWidth);
    await safeSet(_routeLayerId, 'line-color', legacyColor.toARGB32());
    await safeSet(_routeLayerId, 'line-opacity', 0.95);
    await safeSet(_routeLayerId, 'line-dasharray', <double>[1.0, 0.0]);
    if (mounted) setState(() {});
  }

  // -----------------------------
  // Circuits selection
  // -----------------------------

  Future<void> _selectCircuitFromDoc(
    String circuitId,
    Map<String, dynamic> data,
  ) async {
    setState(() {
      _selectedCircuitId = circuitId;
      _selectedCircuitName = (data['name'] ?? circuitId).toString();
    });

    _cancelCircuitSubs();

    // Style URL par circuit
    final styleUrl = (data['styleUrl'] as String?)?.trim();
    final wantedStyle = (styleUrl != null && styleUrl.isNotEmpty)
        ? styleUrl
        : widget.defaultStyleUri;

    if (_map != null &&
        wantedStyle != (_currentStyleUri ?? widget.defaultStyleUri)) {
      _currentStyleUri = wantedStyle;
      _styleLoaded = false;
      _poiLayerIdsCreated.clear();
      try {
        await _map!.loadStyleURI(wantedStyle);
      } catch (_) {
        try {
          await _map!.style.setStyleURI(wantedStyle);
        } catch (_) {
          // ignore
        }
      }
    }

    await _moveCameraToCircuit(data);

    // Circuit doc stream (route)
    _subCircuitDoc = _circuitRef(circuitId).snapshots().listen((snap) async {
      if (!snap.exists) return;
      final d = snap.data() ?? <String, dynamic>{};
      _lastCircuitDocData = d;
      _routeGeoJsonString =
          _buildRouteGeoJsonFromCircuitDoc(d) ?? _emptyFeatureCollection();
      await _applyRouteStyleFromCircuitDoc(d);
      await _applyDataIfReady();
    });

    // Layers stream (UI + layers style)
    _subLayers = _layersCol(circuitId).orderBy('order').snapshots().listen((
      qs,
    ) async {
      _uiLayersById.clear();

      for (final doc in qs.docs) {
        final d = doc.data();
        final label = (d['label'] ?? doc.id).toString();
        final visible = (d['isVisible'] as bool?) ?? true;
        final type = (d['type'] ?? '').toString();
        final style = d['style'];
        final styleColor = style is Map ? style['color'] : null;
        final colorHex = (d['color'] ?? styleColor)?.toString();
        _uiLayersById[doc.id] = _UiLayer(
          id: doc.id,
          label: label,
          type: type,
          visible: visible,
          colorHex: colorHex,
        );
      }

      if (_styleLoaded) {
        await _rebuildPoiLayersFromUiState();
        await _applyDataIfReady();
      }

      if (mounted) setState(() {});
    });

    // POIs stream (source unique)
    _subPois = _poisCol(circuitId)
        .where('isVisible', isEqualTo: true)
        .snapshots()
        .listen((qs) async {
          final features = <Map<String, dynamic>>[];
          final pois = <_PoiItem>[];

          for (final doc in qs.docs) {
            final d = doc.data();
            final coord = _parsePoiCoord(d);
            if (coord == null) continue;

            final layerId = (d['layerId'] ?? d['layerType'] ?? '').toString();
            final name = (d['name'] ?? d['title'] ?? '').toString();
            final desc = (d['description'] ?? d['desc'] ?? '').toString();
            final imageUrl = (d['imageUrl'] ?? '').toString();

            pois.add(
              _PoiItem(
                id: doc.id,
                layerId: layerId,
                name: name,
                desc: desc,
                imageUrl: imageUrl,
                lng: coord.$1,
                lat: coord.$2,
              ),
            );

            features.add({
              'type': 'Feature',
              'id': doc.id,
              'geometry': {
                'type': 'Point',
                'coordinates': [coord.$1, coord.$2],
              },
              'properties': {
                'id': doc.id,
                'name': name,
                'desc': desc,
                'imageUrl': imageUrl,
                'layerId': layerId,
              },
            });
          }

          _visiblePois
            ..clear()
            ..addAll(pois);

          _poisGeoJsonString = jsonEncode({
            'type': 'FeatureCollection',
            'features': features,
          });

          await _applyDataIfReady();
        });
  }

  Future<void> _moveCameraToCircuit(Map<String, dynamic> data) async {
    final map = _map;
    if (map == null) return;

    final center = data['center'];
    double? lat;
    double? lng;

    if (center is Map) {
      final a = center['lat'];
      final o = center['lng'];
      if (a is num && o is num) {
        lat = a.toDouble();
        lng = o.toDouble();
      }
    }

    final zoom = (data['initialZoom'] as num?)?.toDouble() ?? 13.5;

    if (lat != null && lng != null) {
      try {
        await map.setCamera(
          CameraOptions(
            center: Point(coordinates: Position(lng, lat)),
            zoom: zoom,
            pitch: 45.0,
          ),
        );
      } catch (_) {
        // ignore
      }
    }
  }

  // -----------------------------
  // POI layers per layerId
  // -----------------------------

  String _poiLayerIdFor(String layerId) => 'mm_public_poi_layer__$layerId';

  Future<void> _rebuildPoiLayersFromUiState() async {
    final map = _map;
    if (map == null) return;

    final style = map.style;

    // Remove layers that no longer exist
    final desired = _uiLayersById.keys.map(_poiLayerIdFor).toSet();
    final toRemove = _poiLayerIdsCreated.difference(desired).toList();
    for (final layerId in toRemove) {
      try {
        await style.removeStyleLayer(layerId);
      } catch (_) {
        // ignore
      }
      _poiLayerIdsCreated.remove(layerId);
    }

    // Create missing layers
    for (final entry in _uiLayersById.entries) {
      final layerDocId = entry.key;
      final uiLayer = entry.value;
      final layerId = _poiLayerIdFor(layerDocId);

      if (_poiLayerIdsCreated.contains(layerId)) continue;

      final color = _parseHexColor(uiLayer.colorHex) ?? const Color(0xFFFF6A00);

      try {
        await style.addLayer(
          CircleLayer(
            id: layerId,
            sourceId: _poiSourceId,
            circleRadius: 7.0,
            circleColor: color.toARGB32(),
            circleOpacity: 0.95,
            circleStrokeColor: Colors.white.toARGB32(),
            circleStrokeWidth: 2.0,
          ),
        );
      } catch (_) {
        // ignore
      }

      // Filter: feature.properties.layerId == layerDocId
      try {
        await style.setStyleLayerProperty(layerId, 'filter', [
          '==',
          ['get', 'layerId'],
          layerDocId,
        ]);
      } catch (_) {
        // ignore
      }

      _poiLayerIdsCreated.add(layerId);
    }
  }

  // -----------------------------
  // Build route GeoJSON
  // -----------------------------

  static String _emptyFeatureCollection() =>
      jsonEncode({'type': 'FeatureCollection', 'features': []});

  String? _buildRouteGeoJsonFromCircuitDoc(Map<String, dynamic> data) {
    final raw =
        data['route'] ??
        data['routePoints'] ??
        data['routeGeometry'] ??
        data['waypoints'];
    if (raw == null || raw is! List) return null;

    final coords = <List<double>>[];
    for (final it in raw) {
      final p = _parseRoutePoint(it);
      if (p != null) coords.add([p.$1, p.$2]);
    }
    if (coords.length < 2) return null;

    return jsonEncode({
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'id': 'route',
          'geometry': {'type': 'LineString', 'coordinates': coords},
          'properties': <String, dynamic>{},
        },
      ],
    });
  }

  (double, double)? _parseRoutePoint(dynamic it) {
    if (it is GeoPoint) return (it.longitude, it.latitude);

    if (it is Map) {
      final lat = it['lat'];
      final lng = it['lng'] ?? it['lon'];
      if (lat is num && lng is num) return (lng.toDouble(), lat.toDouble());
    }

    if (it is List && it.length >= 2) {
      final lng = it[0];
      final lat = it[1];
      if (lng is num && lat is num) return (lng.toDouble(), lat.toDouble());
    }

    return null;
  }

  (double, double)? _parsePoiCoord(Map<String, dynamic> d) {
    final gp = d['location'];
    if (gp is GeoPoint) return (gp.longitude, gp.latitude);

    final lat = d['lat'];
    final lng = d['lng'] ?? d['lon'];
    if (lat is num && lng is num) return (lng.toDouble(), lat.toDouble());

    final m = d['center'];
    if (m is Map) {
      final a = m['lat'];
      final o = m['lng'] ?? m['lon'];
      if (a is num && o is num) return (o.toDouble(), a.toDouble());
    }

    return null;
  }

  Color? _parseHexColor(String? hex) {
    if (hex == null) return null;
    var s = hex.trim();
    if (s.isEmpty) return null;
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 6) s = 'FF$s';
    if (s.length != 8) return null;
    final v = int.tryParse(s, radix: 16);
    if (v == null) return null;
    return Color(v);
  }

  // -----------------------------
  // Tap POI (nearest)
  // -----------------------------

  static double _distanceMeters({
    required double aLat,
    required double aLng,
    required double bLat,
    required double bLng,
  }) {
    const r = 6371000.0;
    final dLat = (bLat - aLat) * (math.pi / 180.0);
    final dLng = (bLng - aLng) * (math.pi / 180.0);
    final s1 = math.sin(dLat / 2.0);
    final s2 = math.sin(dLng / 2.0);
    final aa =
        s1 * s1 +
        math.cos(aLat * (math.pi / 180.0)) *
            math.cos(bLat * (math.pi / 180.0)) *
            s2 *
            s2;
    return 2.0 * r * math.asin(math.sqrt(aa));
  }

  Future<void> _onTapNative(ScreenCoordinate screenCoord) async {
    final map = _map;
    if (map == null) return;

    // Convert pixel -> coord géographique
    late final Position coord;
    try {
      final geo = await map.coordinateForPixel(screenCoord);
      coord = geo.coordinates;
    } catch (_) {
      return;
    }

    final tapLat = coord.lat.toDouble();
    final tapLng = coord.lng.toDouble();

    // Nearest POI (seulement ceux dont la couche est visible)
    _PoiItem? best;
    double bestMeters = double.infinity;

    for (final poi in _visiblePois) {
      final uiLayer = _uiLayersById[poi.layerId];
      if (uiLayer != null && uiLayer.visible == false) continue;

      final m = _distanceMeters(
        aLat: tapLat,
        aLng: tapLng,
        bLat: poi.lat,
        bLng: poi.lng,
      );
      if (m < bestMeters) {
        bestMeters = m;
        best = poi;
      }
    }

    // Seuil de sélection (mètres)
    if (best == null || bestMeters > 35.0) return;

    if (!mounted) return;
    final poi = best;
    final uiLayer = _uiLayersById[poi.layerId];
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              poi.name.isEmpty ? 'Point d’intérêt' : poi.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            if (uiLayer != null)
              Text(
                uiLayer.label,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            if (poi.desc.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(poi.desc),
            ],
            if (poi.imageUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  poi.imageUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 160,
                      color: Colors.black.withValues(alpha: 0.04),
                      alignment: Alignment.center,
                      child: const Text('Image indisponible'),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fermer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -----------------------------
  // UI: layer toggles
  // -----------------------------

  void _openLayersSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        final layers = _uiLayersById.values.toList()
          ..sort((a, b) => a.label.compareTo(b.label));

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Couches',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _showRoute
                        ? 'Masquer la route'
                        : 'Afficher la route',
                    onPressed: () async {
                      setState(() => _showRoute = !_showRoute);
                      await _setLayerVisibility(_routeLayerId, _showRoute);
                    },
                    icon: Icon(_showRoute ? Icons.route : Icons.route_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (layers.isEmpty)
                const Text('Aucune couche trouvée pour ce circuit.'),
              if (layers.isNotEmpty)
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemBuilder: (ctx, i) {
                      final l = layers[i];
                      return SwitchListTile(
                        value: l.visible,
                        title: Text(l.label),
                        subtitle: l.type.isNotEmpty ? Text(l.type) : null,
                        onChanged: (v) async {
                          setState(
                            () => _uiLayersById[l.id] = l.copyWith(visible: v),
                          );
                          await _setLayerVisibility(_poiLayerIdFor(l.id), v);
                        },
                      );
                    },
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemCount: layers.length,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // -----------------------------
  // Build
  // -----------------------------

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (kIsWeb) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'MarketMapPublicViewerPage: page mobile uniquement (Mapbox natif).',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedCircuitName.isEmpty ? 'Carte' : _selectedCircuitName,
        ),
        actions: [
          IconButton(
            tooltip: 'Couches',
            onPressed: _openLayersSheet,
            icon: const Icon(Icons.layers_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _circuitsCol
                  .where('isVisible', isEqualTo: true)
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Text('Erreur circuits: ${snap.error}');
                }
                if (!snap.hasData) {
                  return const LinearProgressIndicator(minHeight: 2);
                }

                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Text(
                    'Aucun circuit visible pour cet événement.',
                  );
                }

                // Choix initial
                _selectedCircuitId ??= docs.first.id;
                if (!docs.any((d) => d.id == _selectedCircuitId)) {
                  _selectedCircuitId = docs.first.id;
                }

                // Auto-sélection + wiring dès que la map est prête
                if (!_didAutoSelectFromList && _map != null) {
                  _didAutoSelectFromList = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    if (!mounted) return;
                    final doc = docs.firstWhere(
                      (d) => d.id == _selectedCircuitId,
                    );
                    await _selectCircuitFromDoc(doc.id, doc.data());
                  });
                }

                final items = docs.map((d) {
                  final name = (d.data()['name'] ?? d.id).toString();
                  return DropdownMenuItem(
                    value: d.id,
                    child: Text(name, overflow: TextOverflow.ellipsis),
                  );
                }).toList();

                return Row(
                  children: [
                    const Text('Circuit:'),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(
                          'marketmap-public-circuit-${_selectedCircuitId ?? 'none'}',
                        ),
                        initialValue: _selectedCircuitId,
                        items: items,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) async {
                          if (v == null) return;
                          final doc = docs.firstWhere((d) => d.id == v);
                          await _selectCircuitFromDoc(doc.id, doc.data());
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      tooltip: 'Recharger',
                      onPressed: () async {
                        final cid = _selectedCircuitId;
                        if (cid == null) return;
                        final doc = docs.firstWhere((d) => d.id == cid);
                        await _selectCircuitFromDoc(doc.id, doc.data());
                      },
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTapUp: (details) {
                final sc = ScreenCoordinate(
                  x: details.localPosition.dx,
                  y: details.localPosition.dy,
                );
                _onTapNative(sc);
              },
              child: MapWidget(
                key: const ValueKey('marketmap_public_map'),
                styleUri: _currentStyleUri ?? widget.defaultStyleUri,
                cameraOptions: CameraOptions(
                  center: Point(coordinates: Position(-61.533, 16.241)),
                  zoom: 13.0,
                  pitch: 45.0,
                ),
                onMapCreated: _onMapCreated,
                onStyleLoadedListener: _onStyleLoaded,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UiLayer {
  final String id;
  final String label;
  final String type;
  final bool visible;
  final String? colorHex;

  const _UiLayer({
    required this.id,
    required this.label,
    required this.type,
    required this.visible,
    this.colorHex,
  });

  _UiLayer copyWith({
    String? id,
    String? label,
    String? type,
    bool? visible,
    String? colorHex,
  }) {
    return _UiLayer(
      id: id ?? this.id,
      label: label ?? this.label,
      type: type ?? this.type,
      visible: visible ?? this.visible,
      colorHex: colorHex ?? this.colorHex,
    );
  }
}

class _PoiItem {
  final String id;
  final String layerId;
  final String name;
  final String desc;
  final String imageUrl;
  final double lng;
  final double lat;

  const _PoiItem({
    required this.id,
    required this.layerId,
    required this.name,
    required this.desc,
    required this.imageUrl,
    required this.lng,
    required this.lat,
  });
}
