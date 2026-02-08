import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'assistant_step_by_step/build_circuit_map.dart'
    show buildCircuitMap, LngLat;

/// Éditeur de périmètre pour un circuit MarketMap
///
/// Firestore: marketMap/{countryId}/events/{eventId}/circuits/{circuitId}
/// Champ 'perimeter': [ {lat: double, lng: double}, ... ]
class MarketMapPerimeterPage extends StatefulWidget {
  const MarketMapPerimeterPage({
    super.key,
    required this.countryId,
    required this.eventId,
    required this.circuitId,
  });

  final String countryId;
  final String eventId;
  final String circuitId;

  @override
  State<MarketMapPerimeterPage> createState() => _MarketMapPerimeterPageState();
}

class _MarketMapPerimeterPageState extends State<MarketMapPerimeterPage> {
  final _db = FirebaseFirestore.instance;

  static const double _minRadiusMeters = 200;
  static const double _maxRadiusMeters = 5000;
  static const double _radiusStepMeters = 100;

  bool _loading = true;
  bool _saving = false;
  bool _locked = false;

  _PerimeterMode _mode = _PerimeterMode.circle;
  // Centre du cercle de périmètre
  LngLat? _center;
  // Rayon en mètres
  double _radiusMeters = 1000;
  // Approximations polyligne pour affichage sur la carte
  List<LngLat> _perimeter = const [];

  DocumentReference<Map<String, dynamic>> get _circuitRef => _db
      .collection('marketMap')
      .doc(widget.countryId)
      .collection('events')
      .doc(widget.eventId)
      .collection('circuits')
      .doc(widget.circuitId);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snap = await _circuitRef.get();
      final data = snap.data() ?? const <String, dynamic>{};

      final modeData = data['perimeterMode'];
      final mode = modeData == 'points'
          ? _PerimeterMode.points
          : _PerimeterMode.circle;

      final centerData = data['center'] as Map<String, dynamic>?;
      final radiusData = data['radiusMeters'];
      final perimeterData = data['perimeter'];
      final locked = (data['perimeterLocked'] as bool?) ?? false;

      LngLat? center;
      if (centerData != null) {
        final lat = centerData['lat'];
        final lng = centerData['lng'];
        if (lat is num && lng is num) {
          center = (lng: lng.toDouble(), lat: lat.toDouble());
        }
      }

      List<LngLat> perimeter = const [];
      if (perimeterData is List) {
        final pts = <LngLat>[];
        for (final raw in perimeterData) {
          if (raw is Map) {
            final lat = raw['lat'];
            final lng = raw['lng'];
            if (lat is num && lng is num) {
              pts.add((lng: lng.toDouble(), lat: lat.toDouble()));
            }
          }
        }
        perimeter = pts;
      }

      if (!mounted) return;
      setState(() {
        _center = center;
        _mode = mode;
        _radiusMeters = (radiusData is num)
            ? radiusData.toDouble().clamp(_minRadiusMeters, 20000.0)
            : 1000;

        if (_mode == _PerimeterMode.points) {
          _perimeter = perimeter;
        } else {
          _perimeter = _buildCirclePerimeter(
            center: _center,
            radiusMeters: _radiusMeters,
          );
        }
        _locked = locked;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _onTapMap(LngLat p) {
    if (_locked) return;

    if (_mode == _PerimeterMode.points) {
      setState(() {
        _perimeter = [..._perimeter, p];
      });
      return;
    }

    setState(() {
      _center = p;
      _perimeter = _buildCirclePerimeter(
        center: _center,
        radiusMeters: _radiusMeters,
      );
    });
  }

  void _setMode(_PerimeterMode mode) {
    if (_locked) return;
    if (_mode == mode) return;

    setState(() {
      _mode = mode;
      if (_mode == _PerimeterMode.circle) {
        _perimeter = _buildCirclePerimeter(
          center: _center,
          radiusMeters: _radiusMeters,
        );
      } else {
        // Mode points : on garde les points existants si déjà tracés.
        // Sinon, on repart du périmètre actuel uniquement si c'est déjà un polygone.
      }
    });
  }

  void _bumpRadius(int deltaSteps) {
    if (_locked) return;
    if (_mode != _PerimeterMode.circle) return;

    setState(() {
      final next = (_radiusMeters + (deltaSteps * _radiusStepMeters)).clamp(
        _minRadiusMeters,
        _maxRadiusMeters,
      );
      _radiusMeters = next;
      _perimeter = _buildCirclePerimeter(
        center: _center,
        radiusMeters: _radiusMeters,
      );
    });
  }

  void _undoLastPoint() {
    if (_locked) return;
    if (_mode != _PerimeterMode.points) return;
    if (_perimeter.isEmpty) return;

    setState(() {
      _perimeter = _perimeter.sublist(0, _perimeter.length - 1);
    });
  }

  void _clear() {
    if (_locked) return;
    setState(() {
      _center = null;
      _perimeter = const [];
    });
  }

  List<LngLat> _buildCirclePerimeter({
    required LngLat? center,
    required double radiusMeters,
  }) {
    if (center == null || radiusMeters <= 0) return const [];

    const int segments = 64;
    final pts = <LngLat>[];
    final latRad = center.lat * math.pi / 180.0;
    const earthRadius = 6371000.0; // m

    for (int i = 0; i <= segments; i++) {
      final theta = (2 * math.pi * i) / segments;
      final dx = radiusMeters * math.cos(theta) / earthRadius;
      final dy = radiusMeters * math.sin(theta) / earthRadius;

      final lat2 = center.lat + (dy * 180.0 / math.pi);
      final lng2 =
          center.lng +
          (dx * 180.0 / math.pi) / math.cos(latRad == 0 ? 0.0001 : latRad);

      pts.add((lng: lng2, lat: lat2));
    }
    return pts;
  }

  Future<void> _save({bool lockAfter = true}) async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final isCircle = _mode == _PerimeterMode.circle;

      late final LngLat center;
      late final Map<String, dynamic> bounds;

      if (isCircle) {
        final c = _center;
        if (c == null) {
          throw Exception('Centre non défini');
        }
        center = c;

        const earthRadius = 6371000.0; // m
        final latDelta = (_radiusMeters / earthRadius) * 180.0 / math.pi;
        final latRad = center.lat * math.pi / 180.0;
        final lngDelta =
            (_radiusMeters / earthRadius) *
            180.0 /
            (math.pi * (latRad == 0 ? 0.0001 : math.cos(latRad)));

        bounds = {
          'sw': {'lat': center.lat - latDelta, 'lng': center.lng - lngDelta},
          'ne': {'lat': center.lat + latDelta, 'lng': center.lng + lngDelta},
        };
      } else {
        if (_perimeter.length < 3) {
          throw Exception('Au moins 3 points requis');
        }

        var minLat = _perimeter.first.lat;
        var maxLat = _perimeter.first.lat;
        var minLng = _perimeter.first.lng;
        var maxLng = _perimeter.first.lng;
        for (final p in _perimeter.skip(1)) {
          if (p.lat < minLat) minLat = p.lat;
          if (p.lat > maxLat) maxLat = p.lat;
          if (p.lng < minLng) minLng = p.lng;
          if (p.lng > maxLng) maxLng = p.lng;
        }

        center = (lng: (minLng + maxLng) / 2.0, lat: (minLat + maxLat) / 2.0);
        bounds = {
          'sw': {'lat': minLat, 'lng': minLng},
          'ne': {'lat': maxLat, 'lng': maxLng},
        };
      }

      // Périmètre polyligne pour affichage éventuel
      final perimeter = _perimeter
          .map((p) => {'lat': p.lat, 'lng': p.lng})
          .toList();

      final update = <String, dynamic>{
        'perimeterMode': isCircle ? 'circle' : 'points',
        'center': {'lat': center.lat, 'lng': center.lng},
        if (isCircle) 'radiusMeters': _radiusMeters,
        'perimeter': perimeter,
        'bounds': bounds,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (lockAfter) {
        update['perimeterLocked'] = true;
      }

      await _circuitRef.update(update);

      if (!mounted) return;
      setState(() {
        _locked = lockAfter ? true : _locked;
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lockAfter
                ? '✓ Périmètre sauvegardé et verrouillé'
                : '✓ Périmètre sauvegardé',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur sauvegarde périmètre: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Périmètre du circuit')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'marketMap/${widget.countryId}/events/${widget.eventId}/circuits/${widget.circuitId}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ToggleButtons(
                              isSelected: [
                                _mode == _PerimeterMode.points,
                                _mode == _PerimeterMode.circle,
                              ],
                              onPressed: _locked
                                  ? null
                                  : (i) => _setMode(
                                      i == 0
                                          ? _PerimeterMode.points
                                          : _PerimeterMode.circle,
                                    ),
                              children: const [
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10),
                                  child: Text('Point par point'),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10),
                                  child: Text('Cercle (1 point)'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _locked
                            ? 'Périmètre VERROUILLÉ (lecture seule).'
                            : _mode == _PerimeterMode.points
                            ? 'Clique sur la carte pour ajouter des points au périmètre.'
                            : 'Clique sur la carte pour définir le centre du cercle.',
                        style: TextStyle(
                          fontSize: 13,
                          color: _locked
                              ? Colors.red.shade700
                              : Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: buildCircuitMap(
                        perimeter: _perimeter,
                        route: const [],
                        segments: const [],
                        locked: _locked,
                        onTap: _onTapMap,
                        showMask: true,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Réinitialiser le périmètre',
                        onPressed: _locked ? null : _clear,
                        icon: const Icon(Icons.refresh),
                      ),
                      if (_mode == _PerimeterMode.points) ...[
                        IconButton(
                          tooltip: 'Annuler le dernier point',
                          onPressed: _locked || _perimeter.isEmpty
                              ? null
                              : _undoLastPoint,
                          icon: const Icon(Icons.undo),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Text(
                        _mode == _PerimeterMode.circle
                            ? (_center == null
                                  ? 'Aucun centre défini'
                                  : 'Centre défini • Diamètre ~ ${(2 * _radiusMeters).toStringAsFixed(0)} m')
                            : 'Points: ${_perimeter.length}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const Spacer(),
                      if (!_locked && _mode == _PerimeterMode.circle) ...[
                        IconButton(
                          tooltip: 'Réduire le diamètre',
                          onPressed: _center == null
                              ? null
                              : () => _bumpRadius(-1),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        IconButton(
                          tooltip: 'Augmenter le diamètre',
                          onPressed: _center == null
                              ? null
                              : () => _bumpRadius(1),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => _save(lockAfter: false),
                        child: const Text('Sauvegarder (draft)'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _perimeter.isEmpty || _saving
                            ? null
                            : () async {
                                await _save(lockAfter: true);
                                if (!context.mounted) return;
                                Navigator.of(context).pop();
                              },
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: const Text('Valider le périmètre'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

enum _PerimeterMode { points, circle }
