import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/route_validator.dart';

/// Page de dessin de routes (LEGACY flutter_map) - interactive editing
class RouteDrawingPageLegacy extends StatefulWidget {
  const RouteDrawingPageLegacy({super.key, this.groupId});

  final String? groupId;

  @override
  State<RouteDrawingPageLegacy> createState() => _RouteDrawingPageLegacyState();
}

class _RouteDrawingPageLegacyState extends State<RouteDrawingPageLegacy> {
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
        SnackBar(content: Text(validation)),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final routeData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'points': _points.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
        'distanceKm': RouteValidator.totalDistance(_points),
        'estimatedMinutes': RouteValidator.estimatedTime(_points).inMinutes,
        'groupId': widget.groupId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('routes').add(routeData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Route enregistrée avec succès')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dessiner une route (Legacy)'),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Annuler le dernier point',
              onPressed: _undoLastPoint,
            ),
          if (_points.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Tout effacer',
              onPressed: _clearAll,
            ),
        ],
      ),
      body: Row(
        children: [
          // Barre d'outils gauche
          Container(
            width: 80,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Column(
              children: [
                const SizedBox(height: 16),
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_location_alt),
                      tooltip: 'Ajouter un point\n(cliquez sur la carte)',
                      iconSize: 32,
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cliquez sur la carte pour ajouter un point'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_points.length}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    const Text('points'),
                  ],
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Form
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom de la route',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (optionnel)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  // Liste des points
                  Text(
                    'Points (${_points.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _points.isEmpty
                        ? const Center(
                            child: Text('Aucun point.\nCliquez sur la carte pour ajouter.'),
                          )
                        : ListView.builder(
                            itemCount: _points.length,
                            itemBuilder: (context, i) {
                              final p = _points[i];
                              final isEditing = _editingPointIndex == i;
                              return Card(
                                color: isEditing
                                    ? Theme.of(context).colorScheme.primaryContainer
                                    : null,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: i == 0
                                        ? Colors.green
                                        : (i == _points.length - 1 ? Colors.red : Colors.blue),
                                    child: Text('${i + 1}'),
                                  ),
                                  title: Text('${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}'),
                                  subtitle: isEditing
                                      ? const Text('Cliquez sur la carte pour déplacer')
                                      : null,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          isEditing ? Icons.edit_off : Icons.edit,
                                          color: isEditing ? Colors.orange : null,
                                        ),
                                        onPressed: () => _editPoint(i),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _deletePoint(i),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _points.length >= 2 && !_saving ? _saveRoute : null,
                      icon: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
                      label: Text(_saving ? 'Enregistrement...' : 'Enregistrer la route'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
