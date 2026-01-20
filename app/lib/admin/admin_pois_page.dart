import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../models/place_model.dart';
import '../theme/maslive_theme.dart';

/// Page de gestion des POIs (Points d'Intérêt) - CRUD complet
class AdminPOIsPage extends StatefulWidget {
  const AdminPOIsPage({Key? key}) : super(key: key);

  @override
  State<AdminPOIsPage> createState() => _AdminPOIsPageState();
}

class _AdminPOIsPageState extends State<AdminPOIsPage> {
  final _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';
  String? _filterLayer;

  final _poiLayers = [
    'ville',
    'tracking',
    'visiter',
    'encadrement',
    'food',
    'wc',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des POIs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreatePOIDialog(),
            tooltip: 'Créer un POI',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche et filtres
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher un POI...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Tous'),
                        selected: _filterLayer == null,
                        onSelected: (_) => setState(() => _filterLayer = null),
                      ),
                      ..._poiLayers.map((layer) => Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: FilterChip(
                              label: Text(_getLayerLabel(layer)),
                              selected: _filterLayer == layer,
                              onSelected: (_) => setState(() => _filterLayer = layer),
                            ),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Liste des POIs
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('places')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var pois = snapshot.data!.docs
                    .map((doc) => Place.fromFirestore(doc))
                    .where((poi) {
                      if (_searchQuery.isNotEmpty &&
                          !poi.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
                        return false;
                      }
                      // Filter by type
                      if (_filterLayer != null) {
                        final typeString = Place._typeToString(poi.type);
                        if (typeString != _filterLayer) {
                          return false;
                        }
                      }
                      return true;
                    })
                    .toList();

                if (pois.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.place_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun POI trouvé',
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
                  itemCount: pois.length,
                  itemBuilder: (context, index) {
                    final poi = pois[index];
                    return _buildPOICard(poi);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPOICard(Place poi) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getLayerColor(poi.layer),
          child: Icon(
            _getLayerIcon(poi.layer),
            color: Colors.white,
          ),
        ),
        title: Text(
          poi.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(poi.description),
            const SizedBox(height: 4),
            Chip(
              label: Text(_getLayerLabel(poi.layer)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: _getLayerColor(poi.layer).withOpacity(0.2),
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
                        initialCenter: poi.position,
                        initialZoom: 15,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: poi.position,
                              width: 40,
                              height: 40,
                              child: Icon(
                                _getLayerIcon(poi.layer),
                                color: _getLayerColor(poi.layer),
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Coordonnées
                Text(
                  'Position: ${poi.position.latitude.toStringAsFixed(5)}, ${poi.position.longitude.toStringAsFixed(5)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showEditPOIDialog(poi),
                      icon: const Icon(Icons.edit),
                      label: const Text('Modifier'),
                    ),
                    TextButton.icon(
                      onPressed: () => _deletePOI(poi),
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

  void _showCreatePOIDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final latController = TextEditingController(text: '16.241');
    final lngController = TextEditingController(text: '-61.533');
    String selectedLayer = 'ville';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Créer un POI'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom du POI',
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
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedLayer,
                  decoration: const InputDecoration(
                    labelText: 'Catégorie',
                    border: OutlineInputBorder(),
                  ),
                  items: _poiLayers
                      .map((layer) => DropdownMenuItem(
                            value: layer,
                            child: Row(
                              children: [
                                Icon(_getLayerIcon(layer), size: 20),
                                const SizedBox(width: 8),
                                Text(_getLayerLabel(layer)),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedLayer = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: latController,
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: lngController,
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
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
                  final lat = double.parse(latController.text);
                  final lng = double.parse(lngController.text);

                  await _firestore.collection('places').add({
                    'name': nameController.text.trim(),
                    'description': descController.text.trim(),
                    'layer': selectedLayer,
                    'position': GeoPoint(lat, lng),
                    'createdAt': FieldValue.serverTimestamp(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('POI créé avec succès')),
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
      ),
    );
  }

  void _showEditPOIDialog(Place poi) {
    final nameController = TextEditingController(text: poi.name);
    final descController = TextEditingController(text: poi.description);
    final latController = TextEditingController(text: poi.position.latitude.toString());
    final lngController = TextEditingController(text: poi.position.longitude.toString());
    String selectedLayer = poi.layer;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Modifier le POI'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom du POI',
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
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedLayer,
                  decoration: const InputDecoration(
                    labelText: 'Catégorie',
                    border: OutlineInputBorder(),
                  ),
                  items: _poiLayers
                      .map((layer) => DropdownMenuItem(
                            value: layer,
                            child: Row(
                              children: [
                                Icon(_getLayerIcon(layer), size: 20),
                                const SizedBox(width: 8),
                                Text(_getLayerLabel(layer)),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedLayer = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: latController,
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: lngController,
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
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
                  final lat = double.parse(latController.text);
                  final lng = double.parse(lngController.text);

                  await _firestore.collection('places').doc(poi.id).update({
                    'name': nameController.text.trim(),
                    'description': descController.text.trim(),
                    'layer': selectedLayer,
                    'position': GeoPoint(lat, lng),
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('POI modifié avec succès')),
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
      ),
    );
  }

  Future<void> _deletePOI(Place poi) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Voulez-vous vraiment supprimer le POI "${poi.name}" ?'),
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
        await _firestore.collection('places').doc(poi.id).delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('POI supprimé')),
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

  String _getLayerLabel(String layer) {
    switch (layer) {
      case 'ville':
        return 'Ville';
      case 'tracking':
        return 'Tracking';
      case 'visiter':
        return 'À visiter';
      case 'encadrement':
        return 'Assistance';
      case 'food':
        return 'Food';
      case 'wc':
        return 'WC';
      default:
        return layer;
    }
  }

  IconData _getLayerIcon(String layer) {
    switch (layer) {
      case 'ville':
        return Icons.location_city;
      case 'tracking':
        return Icons.my_location;
      case 'visiter':
        return Icons.map;
      case 'encadrement':
        return Icons.shield;
      case 'food':
        return Icons.restaurant;
      case 'wc':
        return Icons.wc;
      default:
        return Icons.place;
    }
  }

  Color _getLayerColor(String layer) {
    switch (layer) {
      case 'ville':
        return Colors.blue;
      case 'tracking':
        return Colors.green;
      case 'visiter':
        return Colors.purple;
      case 'encadrement':
        return Colors.orange;
      case 'food':
        return Colors.red;
      case 'wc':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
}
