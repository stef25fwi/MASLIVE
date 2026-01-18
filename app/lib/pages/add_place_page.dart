import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddPlacePage extends StatefulWidget {
  const AddPlacePage({super.key});

  @override
  State<AddPlacePage> createState() => _AddPlacePageState();
}

class _AddPlacePageState extends State<AddPlacePage> {
  final MapController _mapController = MapController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  
  LatLng? _selectedPoint;
  String _selectedType = 'ville';
  bool _saving = false;

  final List<Map<String, dynamic>> _types = [
    {'id': 'ville', 'label': 'Ville', 'icon': Icons.location_city, 'color': Colors.blue},
    {'id': 'visiter', 'label': 'À Visiter', 'icon': Icons.attractions, 'color': Colors.purple},
    {'id': 'food', 'label': 'Food', 'icon': Icons.restaurant, 'color': Colors.orange},
    {'id': 'shopping', 'label': 'Shopping', 'icon': Icons.shopping_bag, 'color': Colors.pink},
    {'id': 'hotel', 'label': 'Hébergement', 'icon': Icons.hotel, 'color': Colors.teal},
    {'id': 'plage', 'label': 'Plage', 'icon': Icons.beach_access, 'color': Colors.cyan},
    {'id': 'culture', 'label': 'Culture', 'icon': Icons.museum, 'color': Colors.amber},
    {'id': 'sport', 'label': 'Sport', 'icon': Icons.sports_soccer, 'color': Colors.green},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _selectedPoint = point;
    });
  }

  Future<void> _savePlace() async {
    if (_selectedPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une position sur la carte')),
      );
      return;
    }

    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nom du lieu requis')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final placeData = {
        'name': _nameController.text,
        'description': _descriptionController.text,
        'address': _addressController.text,
        'type': _selectedType,
        'lat': _selectedPoint!.latitude,
        'lng': _selectedPoint!.longitude,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('places')
          .add(placeData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Lieu enregistré')),
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

  Color _getTypeColor() {
    return _types.firstWhere(
      (t) => t['id'] == _selectedType,
      orElse: () => _types[0],
    )['color'] as Color;
  }

  IconData _getTypeIcon() {
    return _types.firstWhere(
      (t) => t['id'] == _selectedType,
      orElse: () => _types[0],
    )['icon'] as IconData;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter un lieu'),
      ),
      body: Column(
        children: [
          // Carte
          Expanded(
            flex: 2,
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
                if (_selectedPoint != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedPoint!,
                        width: 50,
                        height: 50,
                        child: Icon(
                          _getTypeIcon(),
                          color: _getTypeColor(),
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
            flex: 3,
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
                  if (_selectedPoint != null) ...[
                    Text(
                      'Position: ${_selectedPoint!.latitude.toStringAsFixed(5)}, ${_selectedPoint!.longitude.toStringAsFixed(5)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    const Text(
                      '📍 Tapez sur la carte pour sélectionner une position',
                      style: TextStyle(fontSize: 14, color: Colors.orange),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Type de lieu
                  const Text(
                    'Catégorie',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _types.map((type) {
                      final selected = _selectedType == type['id'];
                      return ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              type['icon'] as IconData,
                              size: 16,
                              color: selected ? Colors.white : type['color'] as Color,
                            ),
                            const SizedBox(width: 4),
                            Text(type['label'] as String),
                          ],
                        ),
                        selected: selected,
                        selectedColor: type['color'] as Color,
                        onSelected: (val) {
                          if (val) {
                            setState(() => _selectedType = type['id'] as String);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Nom
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom du lieu *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.label),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Adresse
                  TextField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Adresse',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Description
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.notes),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  // Bouton Enregistrer
                  FilledButton.icon(
                    onPressed: _saving ? null : _savePlace,
                    icon: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(_saving ? 'Enregistrement...' : 'Enregistrer le lieu'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
