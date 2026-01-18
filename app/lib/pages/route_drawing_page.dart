import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RouteDrawingPage extends StatefulWidget {
  const RouteDrawingPage({super.key});

  @override
  State<RouteDrawingPage> createState() => _RouteDrawingPageState();
}

class _RouteDrawingPageState extends State<RouteDrawingPage> {
  final MapController _mapController = MapController();
  final List<LatLng> _points = [];
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _points.add(point);
    });
  }

  void _undoLastPoint() {
    if (_points.isNotEmpty) {
      setState(() {
        _points.removeLast();
      });
    }
  }

  void _clearAll() {
    setState(() {
      _points.clear();
    });
  }

  Future<void> _saveRoute() async {
    if (_points.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun point tracé')),
      );
      return;
    }

    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nom du parcours requis')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final routeData = {
        'name': _nameController.text,
        'description': _descriptionController.text,
        'points': _points.map((p) => {
          'lat': p.latitude,
          'lng': p.longitude,
        }).toList(),
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
        actions: [
          if (_points.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Annuler dernier point',
              onPressed: _undoLastPoint,
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
                      // Point de départ (vert)
                      Marker(
                        point: _points.first,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.green,
                          size: 40,
                        ),
                      ),
                      // Points intermédiaires (bleu)
                      for (int i = 1; i < _points.length - 1; i++)
                        Marker(
                          point: _points[i],
                          width: 30,
                          height: 30,
                          child: const Icon(
                            Icons.circle,
                            color: Colors.blue,
                            size: 12,
                          ),
                        ),
                      // Point d'arrivée (rouge) si plus de 1 point
                      if (_points.length > 1)
                        Marker(
                          point: _points.last,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),

          // Formulaire
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
                  Text(
                    'Points tracés: ${_points.length}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_points.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Départ: ${_points.first.latitude.toStringAsFixed(5)}, ${_points.first.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(fontSize: 12, color: Colors.green),
                    ),
                    if (_points.length > 1)
                      Text(
                        'Arrivée: ${_points.last.latitude.toStringAsFixed(5)}, ${_points.last.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                  ],
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 8),
                  const Text(
                    'Tapez sur la carte pour ajouter des points',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
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
