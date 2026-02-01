import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'dart:math' as math;
import '../models/circuit_model.dart';
import '../pages/circuit_draw_page.dart';
import '../services/mapbox_token_service.dart';
import '../ui/widgets/mapbox_web_view_platform.dart';

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
            icon: const Icon(Icons.edit_location_alt),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CircuitDrawPage()),
            ),
            tooltip: 'Dessiner un nouveau circuit',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateCircuitDialog(),
            tooltip: 'Créer un parcours (formulaire)',
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

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
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

                if (!mounted || !dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Parcours créé avec succès')),
                );
              } catch (e) {
                if (!mounted || !dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text('Erreur: $e')),
                );
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

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
            onPressed: () => Navigator.pop(dialogContext),
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

                if (!mounted || !dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Parcours modifié avec succès')),
                );
              } catch (e) {
                if (!mounted || !dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text('Erreur: $e')),
                );
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
    if (!mounted) return;
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

  /// Rendu mini-carte pour affichage circuit (web: MapboxWebView, mobile: Mapbox + AbsorbPointer)
  Widget _buildCircuitMap(Circuit circuit) {
    if (circuit.points.isEmpty) {
      return Container(
        color: Colors.grey[200],
        child: const Center(child: Text('Aucun tracé')),
      );
    }

    final center = circuit.points.first;

    if (kIsWeb) {
      // Web: MapboxWebView statique (pas de polyline pour l'instant)
      return FutureBuilder<String>(
        future: MapboxTokenService.getToken(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Container(color: Colors.grey[200], child: const Center(child: CircularProgressIndicator()));
          }
          return MapboxWebView(
            accessToken: snapshot.data!,
            initialLat: center.lat,
            initialLng: center.lng,
            initialZoom: 13.0,
          );
        },
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
    final lineCoords = circuit.points.map((p) => Position(p.lng, p.lat)).toList();
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
