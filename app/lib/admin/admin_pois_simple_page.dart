import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../services/mapbox_token_service.dart';
import '../ui/widgets/mapbox_web_view_platform.dart';
import 'poi_marketmap_wizard_page.dart';

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
            icon: const Icon(Icons.auto_fix_high),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const POIMarketMapWizardPage()),
            ),
            tooltip: 'Créer via le Wizard (recommandé)',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: const Text(
              'Vue legacy (collection "pois"). La création est centralisée via le Wizard.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
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
        return Colors.blue;
      case 'food':
        return Colors.red;
      case 'wc':
        return Colors.teal;
      default:
        return Colors.blue;
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

