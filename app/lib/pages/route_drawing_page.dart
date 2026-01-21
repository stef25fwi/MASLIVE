import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/route_validator.dart';

class RouteDrawingPage extends StatefulWidget {
  const RouteDrawingPage({super.key, this.groupId});

  final String? groupId;

  @override
  State<RouteDrawingPage> createState() => _RouteDrawingPageState();
}

class _RouteDrawingPageState extends State<RouteDrawingPage> {
  final MapController _mapController = MapController();
  final List<LatLng> _points = [];
  final List<List<LatLng>> _history = []; // Undo stack
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  int? _editingPointIndex; // Index du point en édition
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _saveHistory();
      if (_editingPointIndex != null) {
        _points[_editingPointIndex!] = point;
        _editingPointIndex = null;
      } else {
        _points.add(point);
      }
    });
  }

  void _saveHistory() {
    _history.add(List<LatLng>.from(_points));
  }

  void _undoLastPoint() {
    if (_history.isNotEmpty) {
      setState(() {
        _points.clear();
        _points.addAll(_history.removeLast());
        _editingPointIndex = null;
      });
    }
  }

  void _deletePoint(int index) {
    setState(() {
      _saveHistory();
      _points.removeAt(index);
      _editingPointIndex = null;
    });
  }

  void _editPoint(int index) {
    setState(() {
      _editingPointIndex = _editingPointIndex == index ? null : index;
    });
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Effacer tous les points ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              setState(() {
                _points.clear();
                _history.clear();
                _editingPointIndex = null;
              });
              Navigator.pop(context);
            },
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveRoute() async {
    final validation = RouteValidator.validate(
      name: _nameController.text,
      points: _points,
    );

    if (validation != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ $validation')),
      );
      return;
    }

    // Avertir si doublons
    final dupes = RouteValidator.findDuplicates(_points);
    if (dupes.isNotEmpty && mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Points trop proches ?'),
          content: Text('${dupes.length} point(s) sont très proches. Continuer ?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continuer')),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _saving = true);

    try {
      final routeData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'points': _points.map((p) => {
          'lat': p.latitude,
          'lng': p.longitude,
        }).toList(),
        'distanceKm': RouteValidator.totalDistance(_points),
        'estimatedMinutes': RouteValidator.estimatedTime(_points).inMinutes,
        'groupId': widget.groupId,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('routes')
          .add(routeData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Parcours enregistré')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erreur: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracer un parcours'),
        elevation: 0,
        actions: [
          if (_points.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Annuler (Undo)',
              onPressed: _history.isNotEmpty ? _undoLastPoint : null,
            ),
          if (_points.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Tout effacer',
              onPressed: _clearAll,
            ),
        ],
      ),
      body: Column(
        children: [
          // Statistiques
          if (_points.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                border: Border(
                  bottom: BorderSide(color: Colors.blue.withValues(alpha: 0.2)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatTile(
                    icon: Icons.pin_drop,
                    label: '${_points.length} points',
                  ),
                  _StatTile(
                    icon: Icons.route,
                    label: '${RouteValidator.totalDistance(_points).toStringAsFixed(2)} km',
                  ),
                  _StatTile(
                    icon: Icons.timer_outlined,
                    label: _formatTime(RouteValidator.estimatedTime(_points)),
                  ),
                ],
              ),
            ),
          // Carte
          Expanded(
            flex: 3,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(16.241, -61.533),
                initialZoom: 13,
                onTap: _onMapTap,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.maslive.app',
                ),
                if (_points.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _points,
                        strokeWidth: 4,
                        color: Colors.blue,
                      ),
                    ],
                  ),
                if (_points.isNotEmpty)
                  MarkerLayer(
                    markers: [
                      for (int i = 0; i < _points.length; i++)
                        Marker(
                          point: _points[i],
                          width: _editingPointIndex == i ? 50 : 40,
                          height: _editingPointIndex == i ? 50 : 40,
                          child: GestureDetector(
                            onTap: () => _editPoint(i),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _editingPointIndex == i
                                    ? Colors.orange
                                    : (i == 0
                                        ? Colors.green
                                        : (i == _points.length - 1 ? Colors.red : Colors.blue)),
                                border: _editingPointIndex == i
                                    ? Border.all(color: Colors.white, width: 3)
                                    : null,
                              ),
                              child: Icon(
                                i == 0
                                    ? Icons.location_on
                                    : (i == _points.length - 1 ? Icons.location_on : Icons.circle),
                                color: Colors.white,
                                size: _editingPointIndex == i ? 24 : 18,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),

          // Formulaire + points list
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ListView(
                children: [
                  if (_points.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Tapez sur la carte pour ajouter des points',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Points du parcours',
                          style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 80,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _points.length,
                            itemBuilder: (_, i) {
                              final p = _points[i];
                              return GestureDetector(
                                onTap: () => _editPoint(i),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: _editingPointIndex == i
                                        ? Colors.orange.withValues(alpha: 0.15)
                                        : Colors.grey.withValues(alpha: 0.06),
                                    border: Border.all(
                                      color: _editingPointIndex == i
                                          ? Colors.orange
                                          : Colors.grey.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        i == 0 ? 'Départ' : (i == _points.length - 1 ? 'Arrivée' : 'Point $i'),
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        '${p.latitude.toStringAsFixed(3)}\n${p.longitude.toStringAsFixed(3)}',
                                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                                      ),
                                      Row(
                                        children: [
                                          if (_editingPointIndex == i)
                                            IconButton(
                                              iconSize: 16,
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              icon: const Icon(Icons.delete, color: Colors.red),
                                              onPressed: () => _deletePoint(i),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom du parcours *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.route),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (optionnel)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.notes),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _points.isEmpty ? null : _clearAll,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Effacer'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _saving || _points.isEmpty ? null : _saveRoute,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save),
                          label: Text(_saving ? 'Enregistrement...' : 'Enregistrer'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes % 60}m';
    }
    return '${d.inMinutes}m';
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatTile({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: Colors.blue),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
