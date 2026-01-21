import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'dart:math' as math;
import '../models/circuit_model.dart';

/// Page de gestion des circuits/parcours (CRUD complet)
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
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateCircuitDialog(),
            tooltip: 'Créer un parcours',
          ),
        ],
      ),
      body: Column(
        children: [
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
                    .where((circuit) =>
                        _searchQuery.isEmpty ||
                        circuit.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                        circuit.description.toLowerCase().contains(_searchQuery.toLowerCase()))
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
                // Mini carte
                SizedBox(
                  height: 200,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: circuit.points.isNotEmpty
                            ? LatLng(circuit.points.first.lat, circuit.points.first.lng)
                            : const LatLng(16.241, -61.533),
                        initialZoom: 13,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        ),
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: circuit.points.map((p) => LatLng(p.lat, p.lng)).toList(),
                              strokeWidth: 4,
                              color: Colors.blue,
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            if (circuit.points.isNotEmpty)
                              Marker(
                                point: LatLng(circuit.points.first.lat, circuit.points.first.lng),
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.flag,
                                  color: Colors.green,
                                  size: 30,
                                ),
                              ),
                            if (circuit.points.length > 1)
                              Marker(
                                point: LatLng(circuit.points.last.lat, circuit.points.last.lng),
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.flag,
                                  color: Colors.red,
                                  size: 30,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showEditCircuitDialog(circuit),
                      icon: const Icon(Icons.edit),
                      label: const Text('Modifier'),
                    ),
                    TextButton.icon(
                      onPressed: () => _togglePublishCircuit(circuit),
                      icon: Icon(circuit.isPublished ? Icons.unpublished : Icons.publish),
                      label: Text(circuit.isPublished ? 'Dépublier' : 'Publier'),
                    ),
                    TextButton.icon(
                      onPressed: () => _deleteCircuit(circuit),
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateCircuitDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Créer un parcours'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom du parcours',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              const Text(
                'Vous pourrez ajouter les points sur la carte après création',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Le nom est requis')),
                );
                return;
              }

              try {
                await _firestore.collection('circuits').add({
                  'name': nameController.text.trim(),
                  'description': descController.text.trim(),
                  'waypoints': [],
                  'isPublished': false,
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Parcours créé avec succès')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e')),
                  );
                }
              }
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  void _showEditCircuitDialog(Circuit circuit) {
    final nameController = TextEditingController(text: circuit.title);
    final descController = TextEditingController(text: circuit.description);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier le parcours'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom du parcours',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await _firestore.collection('circuits').doc(circuit.circuitId).update({
                  'name': nameController.text.trim(),
                  'description': descController.text.trim(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Parcours modifié avec succès')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e')),
                  );
                }
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePublishCircuit(Circuit circuit) async {
    try {
      await _firestore.collection('circuits').doc(circuit.circuitId).update({
        'isPublished': !circuit.isPublished,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              circuit.isPublished
                  ? 'Parcours dépublié'
                  : 'Parcours publié',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _deleteCircuit(Circuit circuit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Voulez-vous vraiment supprimer le parcours "${circuit.title}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('circuits').doc(circuit.circuitId).delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Parcours supprimé')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    }
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
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * math.pi / 180;
  }
}
