import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'assistant_step_by_step/build_circuit_map.dart' show buildCircuitMap, LngLat;

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

  bool _loading = true;
  bool _saving = false;
  bool _locked = false;
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

      final centerData = data['center'] as Map<String, dynamic>?;
      final radiusData = data['radiusMeters'];
      final locked = (data['perimeterLocked'] as bool?) ?? false;

      LngLat? center;
      if (centerData != null) {
        final lat = centerData['lat'];
        final lng = centerData['lng'];
        if (lat is num && lng is num) {
          center = (lng: lng.toDouble(), lat: lat.toDouble());
        }
      }

      if (!mounted) return;
      setState(() {
        _center = center;
        _radiusMeters = (radiusData is num)
            ? radiusData.toDouble().clamp(100.0, 20000.0)
            : 1000;
        _perimeter = _buildCirclePerimeter(center: _center, radiusMeters: _radiusMeters);
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
    setState(() {
      _center = p;
      _perimeter = _buildCirclePerimeter(center: _center, radiusMeters: _radiusMeters);
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
      final lng2 = center.lng +
        (dx * 180.0 / math.pi) /
          math.cos(latRad == 0 ? 0.0001 : latRad);

      pts.add((lng: lng2, lat: lat2));
    }
    return pts;
  }

  Future<void> _save({bool lockAfter = true}) async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final center = _center;
      if (center == null) {
        throw Exception('Centre non défini');
      }

      // Périmètre polyligne pour affichage éventuel
      final perimeter = _perimeter
          .map((p) => {
                'lat': p.lat,
                'lng': p.lng,
              })
          .toList();

      // Bounds approximatifs (carré englobant le cercle)
        const earthRadius = 6371000.0; // m
        final latDelta = (_radiusMeters / earthRadius) * 180.0 / math.pi;
        final latRad = center.lat * math.pi / 180.0;
        final lngDelta = (_radiusMeters / earthRadius) * 180.0 /
          (math.pi * (latRad == 0 ? 0.0001 : math.cos(latRad)));

      final update = <String, dynamic>{
        'center': {
          'lat': center.lat,
          'lng': center.lng,
        },
        'radiusMeters': _radiusMeters,
        'perimeter': perimeter,
        'bounds': {
          'sw': {
            'lat': center.lat - latDelta,
            'lng': center.lng - lngDelta,
          },
          'ne': {
            'lat': center.lat + latDelta,
            'lng': center.lng + lngDelta,
          },
        },
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

      if (!mounted) return;
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
      if (!mounted) return;
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
      appBar: AppBar(
        title: const Text('Périmètre du circuit'),
      ),
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
                      Text(
                        _locked
                            ? 'Périmètre VERROUILLÉ (lecture seule).'
                            : 'Clique sur la carte pour ajouter des points au périmètre.',
                        style: TextStyle(
                          fontSize: 13,
                          color: _locked ? Colors.red.shade700 : Colors.grey.shade800,
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
                      const SizedBox(width: 8),
                      Text(
                        _center == null
                            ? 'Aucun centre défini'
                            : 'Centre défini • Rayon ~ ${_radiusMeters.toStringAsFixed(0)} m',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const Spacer(),
                      if (!_locked)
                        Expanded(
                          child: Slider(
                            min: 200,
                            max: 5000,
                            divisions: 24,
                            value: _radiusMeters.clamp(200, 5000),
                            label:
                                '${(_radiusMeters >= 1000 ? (_radiusMeters / 1000).toStringAsFixed(1) : _radiusMeters.toStringAsFixed(0))}${_radiusMeters >= 1000 ? ' km' : ' m'}',
                            onChanged: (v) {
                              setState(() {
                                _radiusMeters = v;
                                _perimeter = _buildCirclePerimeter(
                                  center: _center,
                                  radiusMeters: _radiusMeters,
                                );
                              });
                            },
                          ),
                        ),
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
                                if (!mounted) return;
                                Navigator.of(context).pop();
                              },
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
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
