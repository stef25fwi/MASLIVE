import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../map/maslive_map.dart';
import '../map/maslive_map_controller.dart';

enum _PerimeterUiMode { polygon, circle }

typedef _Bounds = ({double west, double south, double east, double north});

class ProCircuitWizardPage extends StatefulWidget {
  final String projectId;

  const ProCircuitWizardPage({super.key, required this.projectId});

  @override
  State<ProCircuitWizardPage> createState() => _ProCircuitWizardPageState();
}

class _ProCircuitWizardPageState extends State<ProCircuitWizardPage> {
  final _firestore = FirebaseFirestore.instance;
  final MasLiveMapController _mapController = MasLiveMapController();

  int _step = 2; // Step1 déjà fait via dialog côté entry page

  _PerimeterUiMode _mode = _PerimeterUiMode.polygon;

  final List<MapPoint> _polygonPoints = <MapPoint>[];

  MapPoint? _circleCenter;
  double _circleRadiusMeters = 250.0;

  // Step3 lock
  static const double _lockRadiusMeters = 100.0;
  MapPoint? _lockCenter;
  Timer? _lockEnforcer;
  bool _lockEnforcing = false;

  bool _isSaving = false;
  bool _didInitFromFirestore = false;

  @override
  void dispose() {
    _lockEnforcer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>> get _projectRef =>
      _firestore.collection('map_projects').doc(widget.projectId);

  Future<void> _loadExistingPerimeter(Map<String, dynamic> data) async {
    final rawMode = (data['perimeterMode'] as String?)?.trim();

    final perimeter = data['perimeter'];
    List<MapPoint> perimeterPoints = [];
    if (perimeter is List) {
      perimeterPoints = perimeter
          .whereType<Map>()
          .map((m) {
            final lng = m['lng'];
            final lat = m['lat'];
            if (lng is num && lat is num) {
              return MapPoint(lng.toDouble(), lat.toDouble());
            }
            return null;
          })
          .whereType<MapPoint>()
          .toList();
    }

    final circle = data['circle'];
    MapPoint? circleCenter;
    double? circleRadius;
    if (circle is Map) {
      final c = circle['center'];
      final r = circle['radiusMeters'];
      if (c is Map && r is num) {
        final lng = c['lng'];
        final lat = c['lat'];
        if (lng is num && lat is num) {
          circleCenter = MapPoint(lng.toDouble(), lat.toDouble());
          circleRadius = r.toDouble();
        }
      }
    }

    if (!mounted) return;

    if (rawMode == 'circle' && circleCenter != null && circleRadius != null) {
      _mode = _PerimeterUiMode.circle;
      _circleCenter = circleCenter;
      _circleRadiusMeters = circleRadius;
      _polygonPoints
        ..clear()
        ..addAll(perimeterPoints);
    } else {
      _mode = _PerimeterUiMode.polygon;
      _polygonPoints
        ..clear()
        ..addAll(perimeterPoints);
      if (_polygonPoints.isNotEmpty) {
        _circleCenter = null;
      }
    }

    final lock = data['lock'];
    if (lock is Map) {
      final c = lock['center'];
      if (c is Map) {
        final lng = c['lng'];
        final lat = c['lat'];
        if (lng is num && lat is num) {
          _lockCenter = MapPoint(lng.toDouble(), lat.toDouble());
        }
      }
    }

    await _renderStep();

    final initialFocus = _initialFocusPoint();
    if (initialFocus != null) {
      await _mapController.moveTo(lng: initialFocus.lng, lat: initialFocus.lat, zoom: 14.5, animate: false);
    }
  }

  MapPoint? _initialFocusPoint() {
    if (_step == 3 && _lockCenter != null) return _lockCenter;
    if (_mode == _PerimeterUiMode.circle && _circleCenter != null) {
      return _circleCenter;
    }
    if (_polygonPoints.isNotEmpty) return _polygonPoints.first;
    return null;
  }

  Future<void> _renderStep() async {
    await _mapController.clearAll();

    if (_mode == _PerimeterUiMode.polygon) {
      await _renderPolygonEditing();
      return;
    }

    await _renderCircleEditing();
  }

  Future<void> _renderPolygonEditing() async {
    // Markers numérotés
    await _mapController.setMarkers([
      for (int i = 0; i < _polygonPoints.length; i++)
        MapMarker(
          id: 'p$i',
          lng: _polygonPoints[i].lng,
          lat: _polygonPoints[i].lat,
          label: '${i + 1}',
          size: 1.1,
          color: const Color(0xFF0A84FF),
        ),
    ]);

    if (_polygonPoints.length >= 3) {
      // Step 3: on garde le périmètre visible, mais sans monopoliser la couche polygon
      // (le lock 100m est rendu en polygon). Donc on rend le périmètre en polyline.
      if (_step == 3) {
        await _mapController.setPolyline(
          points: [..._polygonPoints, _polygonPoints.first],
          color: const Color(0xFF0A84FF),
          width: 4,
          show: true,
          roadLike: false,
        );
      } else {
        await _mapController.setPolygon(
          points: [..._polygonPoints, _polygonPoints.first],
          fillColor: const Color(0x330A84FF),
          strokeColor: const Color(0xFF0A84FF),
          strokeWidth: 2,
          show: true,
        );
      }
    } else if (_polygonPoints.length >= 2) {
      await _mapController.setPolyline(
        points: _polygonPoints,
        color: const Color(0xFF0A84FF),
        width: 4,
        show: true,
        roadLike: false,
      );
    }

    if (_step == 3) {
      await _renderLockOverlay();
    }
  }

  Future<void> _renderCircleEditing() async {
    if (_circleCenter != null) {
      await _mapController.setMarkers([
        MapMarker(
          id: 'c',
          lng: _circleCenter!.lng,
          lat: _circleCenter!.lat,
          label: 'C',
          size: 1.2,
          color: const Color(0xFF0A84FF),
        ),
      ]);

      final circlePoints = _approxCirclePoints(
        center: _circleCenter!,
        radiusMeters: _circleRadiusMeters,
        samples: 48,
      );

      if (_step == 3) {
        await _mapController.setPolyline(
          points: circlePoints,
          color: const Color(0xFF0A84FF),
          width: 4,
          show: true,
          roadLike: false,
        );
      } else {
        await _mapController.setPolygon(
          points: circlePoints,
          fillColor: const Color(0x330A84FF),
          strokeColor: const Color(0xFF0A84FF),
          strokeWidth: 2,
          show: true,
        );
      }

      if (_step == 3) {
        await _renderLockOverlay();
      }
    }
  }

  Future<void> _renderLockOverlay() async {
    final center = _lockCenter ?? _computePerimeterCenter();
    if (center == null) return;
    _lockCenter = center;

    final lockCircle = _approxCirclePoints(
      center: center,
      radiusMeters: _lockRadiusMeters,
      samples: 48,
    );

    // On dessine le lock comme polygone (semi-transparent)
    await _mapController.setPolygon(
      points: lockCircle,
      fillColor: const Color(0x1AFF3B30),
      strokeColor: const Color(0xFFFF3B30),
      strokeWidth: 2,
      show: true,
    );

    await _mapController.setMarkers([
      // Re-render markers: perimeter markers + lock center
      if (_mode == _PerimeterUiMode.polygon)
        for (int i = 0; i < _polygonPoints.length; i++)
          MapMarker(
            id: 'p$i',
            lng: _polygonPoints[i].lng,
            lat: _polygonPoints[i].lat,
            label: '${i + 1}',
            size: 1.1,
            color: const Color(0xFF0A84FF),
          ),
      if (_mode == _PerimeterUiMode.circle && _circleCenter != null)
        MapMarker(
          id: 'c',
          lng: _circleCenter!.lng,
          lat: _circleCenter!.lat,
          label: 'C',
          size: 1.2,
          color: const Color(0xFF0A84FF),
        ),
      MapMarker(
        id: 'lock',
        lng: center.lng,
        lat: center.lat,
        label: '🔒',
        size: 1.2,
        color: const Color(0xFFFF3B30),
      ),
    ]);
  }

  MapPoint? _computePerimeterCenter() {
    if (_mode == _PerimeterUiMode.circle && _circleCenter != null) {
      return _circleCenter;
    }
    if (_polygonPoints.isEmpty) return null;

    double lng = 0;
    double lat = 0;
    for (final p in _polygonPoints) {
      lng += p.lng;
      lat += p.lat;
    }
    return MapPoint(lng / _polygonPoints.length, lat / _polygonPoints.length);
  }

  _Bounds? _boundsFromPoints(List<MapPoint> points) {
    if (points.isEmpty) return null;
    double west = points.first.lng;
    double east = points.first.lng;
    double south = points.first.lat;
    double north = points.first.lat;

    for (final p in points.skip(1)) {
      west = math.min(west, p.lng);
      east = math.max(east, p.lng);
      south = math.min(south, p.lat);
      north = math.max(north, p.lat);
    }

    // Petite marge pour éviter un fit trop serré
    final lngPad = (east - west).abs() * 0.1 + 0.0002;
    final latPad = (north - south).abs() * 0.1 + 0.0002;

    return (
      west: west - lngPad,
      south: south - latPad,
      east: east + lngPad,
      north: north + latPad,
    );
  }

  Future<void> _fitToPerimeter() async {
    final points = _currentPerimeterRenderPoints();
    final b = _boundsFromPoints(points);
    if (b == null) return;
    await _mapController.fitBounds(
      west: b.west,
      south: b.south,
      east: b.east,
      north: b.north,
      padding: 56,
      animate: true,
    );
  }

  List<MapPoint> _currentPerimeterRenderPoints() {
    if (_mode == _PerimeterUiMode.circle && _circleCenter != null) {
      return _approxCirclePoints(center: _circleCenter!, radiusMeters: _circleRadiusMeters, samples: 36);
    }
    if (_polygonPoints.length >= 3) {
      return [..._polygonPoints, _polygonPoints.first];
    }
    return [..._polygonPoints];
  }

  List<MapPoint> _currentPerimeterSavePoints() {
    if (_mode == _PerimeterUiMode.circle && _circleCenter != null) {
      final ring = _approxCirclePoints(center: _circleCenter!, radiusMeters: _circleRadiusMeters, samples: 36);
      // On évite de sauvegarder le point de fermeture en double.
      if (ring.length >= 2 && ring.first == ring.last) {
        return ring.sublist(0, ring.length - 1);
      }
      return ring;
    }
    return [..._polygonPoints];
  }

  Future<void> _applyLockConstraints() async {
    final center = _lockCenter;
    if (center == null) return;

    final bounds = _boundsForRadius(center: center, radiusMeters: _lockRadiusMeters);
    await _mapController.setMaxBounds(
      west: bounds.west,
      south: bounds.south,
      east: bounds.east,
      north: bounds.north,
    );

    _startLockEnforcer();
  }

  void _startLockEnforcer() {
    if (_lockEnforcing) return;
    _lockEnforcing = true;
    _lockEnforcer?.cancel();
    _lockEnforcer = Timer.periodic(const Duration(milliseconds: 350), (_) async {
      if (!mounted) return;
      if (_step != 3) return;
      final center = _lockCenter;
      if (center == null) return;

      final cameraCenter = await _mapController.getCameraCenter();
      if (cameraCenter == null) return;

      final d = _distanceMeters(center, cameraCenter);
      if (d > _lockRadiusMeters) {
        await _mapController.moveTo(lng: center.lng, lat: center.lat, zoom: 17.0, animate: true);
      }
    });
  }

  static _Bounds _boundsForRadius({required MapPoint center, required double radiusMeters}) {
    // Approximation locale (suffisante pour <= quelques km)
    final latRad = center.lat * math.pi / 180.0;
    final metersPerDegLat = 111320.0;
    final metersPerDegLng = 111320.0 * math.cos(latRad).abs().clamp(0.2, 1.0);

    final dLat = radiusMeters / metersPerDegLat;
    final dLng = radiusMeters / metersPerDegLng;

    return (
      west: center.lng - dLng,
      south: center.lat - dLat,
      east: center.lng + dLng,
      north: center.lat + dLat,
    );
  }

  static double _distanceMeters(MapPoint a, MapPoint b) {
    const R = 6371000.0;
    final dLat = (b.lat - a.lat) * math.pi / 180.0;
    final dLng = (b.lng - a.lng) * math.pi / 180.0;
    final lat1 = a.lat * math.pi / 180.0;
    final lat2 = b.lat * math.pi / 180.0;

    final sinDLat = math.sin(dLat / 2);
    final sinDLng = math.sin(dLng / 2);

    final h = sinDLat * sinDLat + math.cos(lat1) * math.cos(lat2) * sinDLng * sinDLng;
    return 2 * R * math.asin(math.sqrt(h));
  }

  static List<MapPoint> _approxCirclePoints({
    required MapPoint center,
    required double radiusMeters,
    int samples = 48,
  }) {
    final latRad = center.lat * math.pi / 180.0;
    final metersPerDegLat = 111320.0;
    final metersPerDegLng = 111320.0 * math.cos(latRad).abs().clamp(0.2, 1.0);

    final dLat = radiusMeters / metersPerDegLat;
    final dLng = radiusMeters / metersPerDegLng;

    final pts = <MapPoint>[];
    for (int i = 0; i < samples; i++) {
      final t = (i / samples) * 2 * math.pi;
      final lat = center.lat + math.sin(t) * dLat;
      final lng = center.lng + math.cos(t) * dLng;
      pts.add(MapPoint(lng, lat));
    }
    // Ferme le polygone
    if (pts.isNotEmpty) pts.add(pts.first);
    return pts;
  }

  Future<void> _saveStep2Perimeter() async {
    setState(() => _isSaving = true);
    try {
      final perimeterPoints = _currentPerimeterSavePoints();
      final perimeterJson = [
        for (final p in perimeterPoints)
          <String, double>{'lng': p.lng, 'lat': p.lat},
      ];

      final data = <String, dynamic>{
        'perimeterMode': _mode == _PerimeterUiMode.circle ? 'circle' : 'polygon',
        'perimeter': perimeterJson,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_mode == _PerimeterUiMode.circle && _circleCenter != null) {
        data['circle'] = {
          'center': {'lng': _circleCenter!.lng, 'lat': _circleCenter!.lat},
          'radiusMeters': _circleRadiusMeters,
        };
      } else {
        data['circle'] = FieldValue.delete();
      }

      await _projectRef.set(data, SetOptions(merge: true));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveStep3Lock() async {
    final center = _lockCenter ?? _computePerimeterCenter();
    if (center == null) return;

    setState(() => _isSaving = true);
    try {
      await _projectRef.set({
        'lock': {
          'center': {'lng': center.lng, 'lat': center.lat},
          'radiusMeters': _lockRadiusMeters,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _goToStep3() async {
    if (_mode == _PerimeterUiMode.polygon && _polygonPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins 3 points pour définir un périmètre.')),
      );
      return;
    }
    if (_mode == _PerimeterUiMode.circle && _circleCenter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Touchez la carte pour définir le centre du cercle.')),
      );
      return;
    }

    await _saveStep2Perimeter();

    if (!mounted) return;
    setState(() => _step = 3);

    await _renderStep();
    await _fitToPerimeter();
    await _applyLockConstraints();
  }

  Future<void> _backToStep2() async {
    _lockEnforcer?.cancel();
    _lockEnforcing = false;
    await _mapController.setMaxBounds();

    if (!mounted) return;
    setState(() => _step = 2);
    await _renderStep();
  }

  Future<void> _finish() async {
    await _saveStep3Lock();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _onMapTap(MapPoint p) async {
    if (_step == 3) {
      // Step3: pas de modification, uniquement lock/pan.
      return;
    }

    if (_mode == _PerimeterUiMode.polygon) {
      setState(() {
        _polygonPoints.add(p);
      });
      await _renderStep();
      return;
    }

    // mode cercle
    setState(() {
      _circleCenter = p;
    });
    await _renderStep();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _projectRef.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Wizard Pro')),
            body: Center(child: Text('Erreur: ${snap.error}')),
          );
        }

        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Wizard Pro')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final doc = snap.data!;
        final data = doc.data() ?? <String, dynamic>{};

        // On initialise l'état local une seule fois au premier snapshot.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_didInitFromFirestore) return;
          _didInitFromFirestore = true;
          _loadExistingPerimeter(data);
        });

        final title = (data['name'] as String?)?.trim();

        return Scaffold(
          appBar: AppBar(
            title: Text(title == null || title.isEmpty ? 'Wizard Pro' : 'Wizard Pro • $title'),
          ),
          body: Column(
            children: [
              Expanded(
                child: MasLiveMap(
                  controller: _mapController,
                  initialLng: _initialFocusPoint()?.lng ?? 2.3522,
                  initialLat: _initialFocusPoint()?.lat ?? 48.8566,
                  initialZoom: 14.0,
                  onTap: _onMapTap,
                  onMapReady: (_) async {
                    await _renderStep();
                    if (_step == 3) {
                      await _fitToPerimeter();
                      await _applyLockConstraints();
                    }
                  },
                ),
              ),
              Container(
                height: 240,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: const Border(top: BorderSide(color: Color(0x11000000))),
                ),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      _step == 2 ? 'Étape 2/3 • Périmètre' : 'Étape 3/3 • Verrouillage 100 m',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (_step == 2) ...[
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Libre'),
                            selected: _mode == _PerimeterUiMode.polygon,
                            onSelected: (v) async {
                              if (!v) return;
                              setState(() => _mode = _PerimeterUiMode.polygon);
                              await _renderStep();
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Cercle'),
                            selected: _mode == _PerimeterUiMode.circle,
                            onSelected: (v) async {
                              if (!v) return;
                              setState(() => _mode = _PerimeterUiMode.circle);
                              await _renderStep();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _mode == _PerimeterUiMode.polygon
                            ? 'Touchez la carte pour ajouter des points (marqueurs numérotés).'
                            : 'Touchez la carte pour définir le centre, puis ajustez le rayon.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      if (_mode == _PerimeterUiMode.circle) ...[
                        Row(
                          children: [
                            IconButton(
                              onPressed: () async {
                                setState(() {
                                  _circleRadiusMeters = math.max(25.0, _circleRadiusMeters - 25.0);
                                });
                                await _renderStep();
                              },
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text('${_circleRadiusMeters.toStringAsFixed(0)} m'),
                            IconButton(
                              onPressed: () async {
                                setState(() {
                                  _circleRadiusMeters = math.min(5000.0, _circleRadiusMeters + 25.0);
                                });
                                await _renderStep();
                              },
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      if (_mode == _PerimeterUiMode.polygon) ...[
                        Text('Points: ${_polygonPoints.length}', style: Theme.of(context).textTheme.bodySmall),
                        if (_polygonPoints.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          // Liste sous la carte (jamais par-dessus)
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _polygonPoints.length,
                            separatorBuilder: (_, _) => const Divider(height: 8),
                            itemBuilder: (context, i) {
                              final p = _polygonPoints[i];
                              return Row(
                                children: [
                                  SizedBox(
                                    width: 28,
                                    child: Text('${i + 1}.', style: Theme.of(context).textTheme.bodySmall),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${p.lat.toStringAsFixed(5)}, ${p.lng.toStringAsFixed(5)}',
                                      style: Theme.of(context).textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ] else ...[
                        Text(
                          _circleCenter == null
                              ? 'Centre: non défini'
                              : 'Centre: ${_circleCenter!.lat.toStringAsFixed(5)}, ${_circleCenter!.lng.toStringAsFixed(5)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                              child: const Text('Annuler'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _goToStep3,
                              child: _isSaving
                                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Text('Continuer'),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        'Rayon de verrouillage: ${_lockRadiusMeters.toStringAsFixed(0)} m',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Le déplacement de la carte est limité, et la caméra se recentre si vous sortez du rayon autorisé.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isSaving ? null : _backToStep2,
                              child: const Text('Retour'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _finish,
                              child: _isSaving
                                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Text('Terminer'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
