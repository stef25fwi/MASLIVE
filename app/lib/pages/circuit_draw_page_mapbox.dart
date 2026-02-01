import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'legacy_stubs/circuit_draw_page_legacy_stub.dart';

/// Page de consultation de circuit (Mapbox display-only) + bouton "Éditer (legacy)"
class CircuitDrawPage extends StatefulWidget {
  const CircuitDrawPage({super.key, this.circuitId});

  final String? circuitId;

  @override
  State<CircuitDrawPage> createState() => _CircuitDrawPageState();
}

class _CircuitDrawPageState extends State<CircuitDrawPage> {
  final _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _circuitData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.circuitId != null) {
      _loadCircuit();
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadCircuit() async {
    try {
      final doc = await _firestore.collection('circuits').doc(widget.circuitId).get();
      if (doc.exists) {
        setState(() {
          _circuitData = doc.data();
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  List<({double lat, double lng})> _getPoints() {
    if (_circuitData == null) return [];
    final waypoints = _circuitData!['waypoints'] as List<dynamic>?;
    if (waypoints == null) return [];
    return waypoints.map((p) {
      if (p is Map) {
        return (lat: (p['lat'] as num).toDouble(), lng: (p['lng'] as num).toDouble());
      }
      return (lat: 0.0, lng: 0.0);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_circuitData?['title'] ?? 'Circuit'),
        actions: [
          FilledButton.tonalIcon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CircuitDrawPageLegacy()),
              );
            },
            icon: const Icon(Icons.edit),
            label: const Text('Éditer (legacy)'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _circuitData == null
              ? const Center(child: Text('Circuit introuvable'))
              : _buildCircuitDisplay(),
    );
  }

  Widget _buildCircuitDisplay() {
    final points = _getPoints();
    if (points.isEmpty) {
      return const Center(child: Text('Aucun tracé disponible'));
    }

    return Column(
      children: [
        // Info card
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue.withValues(alpha: 0.08),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _InfoTile(icon: Icons.pin_drop, label: '${points.length} points'),
              _InfoTile(icon: Icons.route, label: '${(_circuitData!['distanceKm'] ?? 0).toStringAsFixed(2)} km'),
            ],
          ),
        ),

        // Carte Mapbox (display-only)
        Expanded(child: _buildMap(points)),

        // Description
        if (_circuitData!['description']?.isNotEmpty == true)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, -2))],
            ),
            child: Text(_circuitData!['description'] ?? ''),
          ),
      ],
    );
  }

  Widget _buildMap(List<({double lat, double lng})> points) {
    if (points.isEmpty) {
      return Container(
        color: Colors.grey[200],
        child: const Center(child: Text('Aucun tracé')),
      );
    }

    final center = points.first;

    // Mobile: MapWidget + polyline + markers start/end
    return MapWidget(
      cameraOptions: CameraOptions(
        center: Point(coordinates: Position(center.lng, center.lat)),
        zoom: 13.0,
      ),
      onMapCreated: (MapboxMap map) => _renderCircuitOnMobile(map, points),
    );
  }

  Future<void> _renderCircuitOnMobile(MapboxMap map, List<({double lat, double lng})> points) async {
    if (points.isEmpty) return;

    // Polyline bleue
    final lineCoords = points.map((p) => Position(p.lng, p.lat)).toList();
    final polyManager = await map.annotations.createPolylineAnnotationManager();
    final polyOpts = PolylineAnnotationOptions(
      geometry: LineString(coordinates: lineCoords),
      lineColor: 0xFF1A73E8, // Color(0xFF1A73E8)
      lineWidth: 8.0,
    );
    await polyManager.create(polyOpts);

    // Markers: start (vert) et end (rouge)
    final pointManager = await map.annotations.createPointAnnotationManager();
    final start = points.first;
    final end = points.last;

    final startOpts = PointAnnotationOptions(
      geometry: Point(coordinates: Position(start.lng, start.lat)),
      iconImage: 'mapbox-marker-icon-default',
      iconColor: 0xFF4CAF50, // Colors.green
      iconSize: 1.2,
    );
    final endOpts = PointAnnotationOptions(
      geometry: Point(coordinates: Position(end.lng, end.lat)),
      iconImage: 'mapbox-marker-icon-default',
      iconColor: 0xFFF44336, // Colors.red
      iconSize: 1.2,
    );

    await pointManager.createMulti([startOpts, endOpts]);

    // Fit bounds
    final bbox = _calculateBounds(points);
    await map.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(bbox.$1, bbox.$2)),
        zoom: _calculateZoomLevel(bbox.$3, bbox.$4),
      ),
      MapAnimationOptions(duration: 1000),
    );
  }

  (double, double, double, double) _calculateBounds(List<({double lat, double lng})> points) {
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

    return (
      (minLng + maxLng) / 2, // center lng
      (minLat + maxLat) / 2, // center lat
      maxLng - minLng, // width
      maxLat - minLat, // height
    );
  }

  double _calculateZoomLevel(double width, double height) {
    final maxDim = width > height ? width : height;
    if (maxDim > 1.0) return 9.0;
    if (maxDim > 0.5) return 10.0;
    if (maxDim > 0.1) return 12.0;
    return 14.0;
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoTile({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.blue),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
