import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'dart:async';
import 'dart:math' as math;
import '../models/circuit_model.dart';
import '../ui/map/maslive_map.dart';
import '../ui/map/maslive_map_controller.dart';

/// Page de gestion des circuits/parcours (CRUD complet) - Mapbox
class AdminCircuitsPage extends StatefulWidget {
  const AdminCircuitsPage({super.key});

  @override
  State<AdminCircuitsPage> createState() => _AdminCircuitsPageState();
}

class _AdminCircuitsPageState extends State<AdminCircuitsPage> {
  final _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des parcours'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            onPressed: () =>
                Navigator.of(context).pushNamed('/admin/circuit-wizard'),
            tooltip: 'Créer via le Wizard (recommandé)',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.25)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Création centralisée: utilisez le Wizard. Cette page affiche surtout les parcours legacy (collection circuits).',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un parcours...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Liste des circuits
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('circuits')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final circuits = snapshot.data!.docs
                    .map((doc) => Circuit.fromFirestore(doc))
                    .where(
                      (circuit) =>
                          _searchQuery.isEmpty ||
                          circuit.title.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          ) ||
                          circuit.description.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          ),
                    )
                    .toList();

                if (circuits.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.route, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun parcours',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: circuits.length,
                  itemBuilder: (context, index) {
                    final circuit = circuits[index];
                    return _buildCircuitCard(circuit);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircuitCard(Circuit circuit) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: circuit.isPublished ? Colors.green : Colors.orange,
          child: Icon(
            circuit.isPublished ? Icons.check_circle : Icons.pending,
            color: Colors.white,
          ),
        ),
        title: Text(
          circuit.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(circuit.description),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: Text('${circuit.points.length} points'),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                Chip(
                  label: Text(circuit.isPublished ? 'Publié' : 'Brouillon'),
                  backgroundColor: circuit.isPublished
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.orange.withValues(alpha: 0.2),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                if (circuit.points.isNotEmpty)
                  Chip(
                    label: Text(_calculateDistance(circuit)),
                    avatar: const Icon(Icons.straighten, size: 16),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mini carte Mapbox
                SizedBox(
                  height: 200,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildCircuitMap(circuit),
                  ),
                ),
                const SizedBox(height: 16),

                // Actions
                const Text(
                  'Lecture seule (legacy). Utilise le Wizard pour créer/modifier les parcours MarketMap.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _calculateDistance(Circuit circuit) {
    if (circuit.points.isEmpty) return '0 km';

    double totalDistance = 0;
    for (int i = 0; i < circuit.points.length - 1; i++) {
      final p1 = circuit.points[i];
      final p2 = circuit.points[i + 1];
      totalDistance += _distanceBetween(p1.lat, p1.lng, p2.lat, p2.lng);
    }

    if (totalDistance < 1) {
      return '${(totalDistance * 1000).toStringAsFixed(0)} m';
    }
    return '${totalDistance.toStringAsFixed(1)} km';
  }

  double _distanceBetween(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * math.pi / 180;
  }

  /// Rendu mini-carte pour affichage circuit (web: MasLiveMap, mobile: Mapbox + AbsorbPointer)
  Widget _buildCircuitMap(Circuit circuit) {
    if (circuit.points.isEmpty) {
      return Container(
        color: Colors.grey[200],
        child: const Center(child: Text('Aucun tracé')),
      );
    }

    final center = circuit.points.first;

    if (kIsWeb) {
      // Web: MasLiveMap (moteur unifié), mini-carte read-only.
      return AbsorbPointer(
        child: _CircuitMiniMapMasLive(circuit: circuit),
      );
    }

    // Mobile: MapWidget + AbsorbPointer (non-interactif) + polyline + markers
    return AbsorbPointer(
      child: MapWidget(
        cameraOptions: CameraOptions(
          center: Point(coordinates: Position(center.lng, center.lat)),
          zoom: 13.0,
        ),
        onMapCreated: (MapboxMap map) => _renderCircuitOnMobile(map, circuit),
      ),
    );
  }

  Future<void> _renderCircuitOnMobile(MapboxMap map, Circuit circuit) async {
    if (circuit.points.isEmpty) return;

    // Polyline bleue
    final lineCoords = circuit.points
        .map((p) => Position(p.lng, p.lat))
        .toList();
    final polyManager = await map.annotations.createPolylineAnnotationManager();
    final polyOpts = PolylineAnnotationOptions(
      geometry: LineString(coordinates: lineCoords),
      lineColor: 0xFF2196F3, // Colors.blue
      lineWidth: 4.0,
    );
    await polyManager.create(polyOpts);

    // Markers: start (vert) et end (rouge)
    final pointManager = await map.annotations.createPointAnnotationManager();
    final start = circuit.points.first;
    final end = circuit.points.last;

    final startOpts = PointAnnotationOptions(
      geometry: Point(coordinates: Position(start.lng, start.lat)),
      iconImage: 'mapbox-marker-icon-default', // icône par défaut (fallback)
      iconColor: 0xFF4CAF50, // Colors.green
      iconSize: 1.0,
    );
    final endOpts = PointAnnotationOptions(
      geometry: Point(coordinates: Position(end.lng, end.lat)),
      iconImage: 'mapbox-marker-icon-default',
      iconColor: 0xFFF44336, // Colors.red
      iconSize: 1.0,
    );

    await pointManager.createMulti([startOpts, endOpts]);
  }
}

/// Mini-carte web pour un circuit legacy, rendue via MasLiveMap (Mapbox unifié).
///
/// Important: widget isolé pour éviter de garder MapboxWebView sur cet écran.
class _CircuitMiniMapMasLive extends StatefulWidget {
  final Circuit? circuit;

  const _CircuitMiniMapMasLive({this.circuit});

  @override
  State<_CircuitMiniMapMasLive> createState() => _CircuitMiniMapMasLiveState();
}

class _CircuitMiniMapMasLiveState extends State<_CircuitMiniMapMasLive> {
  final MasLiveMapController _controller = MasLiveMapController();
  bool _didRender = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _render() async {
    if (_didRender) return;
    final circuit = widget.circuit;
    if (circuit == null || circuit.points.isEmpty) return;
    _didRender = true;

    await _controller.clearAll();

    await _controller.setPolyline(
      points: [for (final p in circuit.points) MapPoint(p.lng, p.lat)],
      color: const Color(0xFF2196F3),
      width: 4.0,
      show: true,
      roadLike: false,
      shadow3d: false,
      showDirection: false,
    );

    final start = circuit.points.first;
    final end = circuit.points.last;
    await _controller.setMarkers([
      MapMarker(id: 'start', lng: start.lng, lat: start.lat),
      MapMarker(id: 'end', lng: end.lng, lat: end.lat),
    ]);

    double minLat = circuit.points.first.lat;
    double maxLat = circuit.points.first.lat;
    double minLng = circuit.points.first.lng;
    double maxLng = circuit.points.first.lng;
    for (final p in circuit.points) {
      minLat = math.min(minLat, p.lat);
      maxLat = math.max(maxLat, p.lat);
      minLng = math.min(minLng, p.lng);
      maxLng = math.max(maxLng, p.lng);
    }
    await _controller.fitBounds(
      west: minLng,
      south: minLat,
      east: maxLng,
      north: maxLat,
      padding: 28,
      animate: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final circuit = widget.circuit;
    final center = (circuit != null && circuit.points.isNotEmpty)
        ? circuit.points.first
        : LocationPoint(lat: 16.241, lng: -61.533, label: '');

    return MasLiveMap(
      controller: _controller,
      initialLat: center.lat,
      initialLng: center.lng,
      initialZoom: 13.0,
      onMapReady: (_) {
        unawaited(_render());
      },
    );
  }
}
