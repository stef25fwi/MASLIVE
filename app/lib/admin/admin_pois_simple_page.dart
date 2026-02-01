import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../services/mapbox_token_service.dart';
import '../ui/widgets/mapbox_web_view_platform.dart';

/// Page de gestion des POIs (Points d'Intérêt) - Version Mapbox
class AdminPOIsSimplePage extends StatefulWidget {
  const AdminPOIsSimplePage({super.key});

  @override
  State<AdminPOIsSimplePage> createState() => _AdminPOIsSimplePageState();
}

class _AdminPOIsSimplePageState extends State<AdminPOIsSimplePage> {
  final _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';
  String? _filterType;

  final _types = ['market', 'visit', 'food', 'wc'];

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
          // Barre de recherche
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
                // Filtres par type
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Tous'),
                        selected: _filterType == null,
                        onSelected: (_) => setState(() => _filterType = null),
                      ),
                      ..._types.map((type) => Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: FilterChip(
                              label: Text(_getTypeLabel(type)),
                              selected: _filterType == type,
                              onSelected: (_) => setState(() => _filterType = type),
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
              stream: _firestore.collection('pois').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var pois = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = data['name'] as String? ?? '';
                  final type = data['type'] as String? ?? '';

                  if (_searchQuery.isNotEmpty &&
                      !name.toLowerCase().contains(_searchQuery.toLowerCase())) {
                    return false;
                  }

                  if (_filterType != null && type != _filterType) {
                    return false;
                  }

                  return true;
                }).toList();

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
                  padding: const EdgeInsets.all(16),
                  itemCount: pois.length,
                  itemBuilder: (context, index) {
                    final doc = pois[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildPOICard(doc.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPOICard(String poiId, Map<String, dynamic> data) {
    final name = data['name'] as String? ?? 'Sans nom';
    final type = data['type'] as String? ?? 'market';
    final lat = (data['lat'] as num?)?.toDouble() ?? 0.0;
    final lng = (data['lng'] as num?)?.toDouble() ?? 0.0;
    final city = data['city'] as String? ?? '';
    final active = data['active'] as bool? ?? true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getTypeColor(type),
          child: Icon(
            _getTypeIcon(type),
            color: Colors.white,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(city),
            const SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text(_getTypeLabel(type)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: _getTypeColor(type).withValues(alpha: 0.2),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
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
                    child: _buildMiniMap(lat, lng, type),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Coordonnées: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}'),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showEditPOIDialog(poiId, data),
                      icon: const Icon(Icons.edit),
                      label: const Text('Modifier'),
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

  String _getTypeLabel(String type) {
    switch (type) {
      case 'market':
        return 'Marché';
      case 'visit':
        return 'Visite';
      case 'food':
        return 'Restaurant';
      case 'wc':
        return 'Toilettes';
      default:
        return type;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'market':
        return Icons.store;
      case 'visit':
        return Icons.location_city;
      case 'food':
        return Icons.restaurant;
      case 'wc':
        return Icons.wc;
      default:
        return Icons.place;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'market':
        return Colors.orange;
      case 'visit':
        return Colors.purple;
      case 'food':
        return Colors.red;
      case 'wc':
        return Colors.teal;
      default:
        return Colors.blue;
    }
  }

  void _showCreatePOIDialog() {
    final nameController = TextEditingController();
    final cityController = TextEditingController();
    final latController = TextEditingController();
    final lngController = TextEditingController();
    String selectedType = _types.first;

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Créer un POI'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: cityController,
                  decoration: const InputDecoration(
                    labelText: 'Ville',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                  items: _types
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(_getTypeLabel(type)),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedType = value);
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
                  final lat = double.tryParse(latController.text) ?? 0.0;
                  final lng = double.tryParse(lngController.text) ?? 0.0;

                  await _firestore.collection('pois').add({
                    'name': nameController.text.trim(),
                    'type': selectedType,
                    'city': cityController.text.trim(),
                    'lat': lat,
                    'lng': lng,
                    'rating': 4.0,
                    'active': true,
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  if (!mounted || !dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('POI créé avec succès')),
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
      ),
    );
  }

  void _showEditPOIDialog(String poiId, Map<String, dynamic> data) {
    final nameController = TextEditingController(text: data['name']);
    final cityController = TextEditingController(text: data['city']);
    final latController = TextEditingController(text: data['lat']?.toString());
    final lngController = TextEditingController(text: data['lng']?.toString());
    String selectedType = data['type'] ?? _types.first;

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Modifier le POI'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: cityController,
                  decoration: const InputDecoration(
                    labelText: 'Ville',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                  items: _types
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(_getTypeLabel(type)),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedType = value);
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
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _deletePOI(poiId, data['name']);
                  },
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text('Supprimer', style: TextStyle(color: Colors.red)),
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
                  final lat = double.tryParse(latController.text) ?? 0.0;
                  final lng = double.tryParse(lngController.text) ?? 0.0;

                  await _firestore.collection('pois').doc(poiId).update({
                    'name': nameController.text.trim(),
                    'type': selectedType,
                    'city': cityController.text.trim(),
                    'lat': lat,
                    'lng': lng,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  if (!mounted || !dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('POI modifié avec succès')),
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
      ),
    );
  }

  Future<void> _deletePOI(String poiId, String poiName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Voulez-vous vraiment supprimer "$poiName" ?'),
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
        await _firestore.collection('pois').doc(poiId).delete();

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

  Widget _buildMiniMap(double lat, double lng, String type) {
    final token = MapboxTokenService.getTokenSync().trim();
    if (token.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        child: const Center(
          child: Text('Token Mapbox manquant', style: TextStyle(fontSize: 12)),
        ),
      );
    }

    if (kIsWeb) {
      return MapboxWebView(
        key: ValueKey('poi-$lat-$lng'),
        accessToken: token,
        initialLat: lat,
        initialLng: lng,
        initialZoom: 15.0,
        initialPitch: 0.0,
        initialBearing: 0.0,
        styleUrl: 'mapbox://styles/mapbox/streets-v12',
        showUserLocation: false,
        onMapReady: () {},
      );
    }

    // Mobile: StaticImage ou simple MapWidget non-interactif
    final initialCamera = CameraOptions(
      center: Point(coordinates: Position(lng, lat)),
      zoom: 15.0,
      pitch: 0.0,
      bearing: 0.0,
    );

    return AbsorbPointer(
      child: MapWidget(
        key: ValueKey('poi-native-$lat-$lng'),
        cameraOptions: initialCamera,
        styleUri: 'mapbox://styles/mapbox/streets-v12',
        onMapCreated: (map) {},
      ),
    );
  }
}

