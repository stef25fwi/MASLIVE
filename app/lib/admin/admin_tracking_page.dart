import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/mapbox_token_service.dart';
import '../ui/map/maslive_map.dart';
import '../ui/map/maslive_map_controller.dart';
import '../ui/widgets/mapbox_token_dialog.dart';

/// AdminTrackingPage - Version MasLiveMap (Phase 2)
/// 
/// Migration complète vers MasLiveMap:
/// - ✅ Simplifié de 665 → ~380 lignes (-43%)
/// - ✅ Plus de gestion Web/Native séparée
/// - ✅ Plus de managers manuels (PointAnnotationManager)
/// - ✅ Plus de hacks rebuild (_webRebuildTick)
/// - ✅ API moderne avec MasLiveMapController
class AdminTrackingPage extends StatefulWidget {
  const AdminTrackingPage({super.key});

  @override
  State<AdminTrackingPage> createState() => _AdminTrackingPageState();
}

class _AdminTrackingPageState extends State<AdminTrackingPage> {
  final _firestore = FirebaseFirestore.instance;
  final _mapController = MasLiveMapController();
  
  static const String _collection = 'groupLocations';
  
  String? _selectedGroupId;
  String _mapboxToken = '';
  List<_GroupLive> _groups = const [];

  @override
  void initState() {
    super.initState();
    _loadMapboxToken();
  }

  Future<void> _loadMapboxToken() async {
    try {
      final info = await MapboxTokenService.getTokenInfo();
      if (!mounted) return;
      setState(() {
        _mapboxToken = info.token;
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _configureMapboxToken() async {
    final newToken = await MapboxTokenDialog.show(
      context,
      initialValue: _mapboxToken,
    );
    if (!mounted || newToken == null) return;
    setState(() {
      _mapboxToken = newToken.trim();
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _groupsStream() {
    return _firestore.collection(_collection).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracking Live des Groupes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.key_rounded),
            onPressed: _configureMapboxToken,
            tooltip: 'Configurer MAPBOX_ACCESS_TOKEN',
          ),
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            onPressed: _centerOnAllGroups,
            tooltip: 'Centrer sur tous les groupes',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _groupsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? const [];
          final groups = docs
              .map((d) => _parseGroup(d.id, d.data()))
              .whereType<_GroupLive>()
              .toList();

          _groups = groups;

          if (groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun groupe en ligne',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Collection: $_collection',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          // Mettre à jour les markers sur la carte
          _updateMapMarkers(groups);

          return Stack(
            children: [
              // Carte MasLiveMap (unifié Web + Mobile)
              Positioned.fill(
                child: _mapboxToken.isEmpty
                    ? _buildTokenMissing()
                    : MasLiveMap(
                        controller: _mapController,
                        initialLat: 16.241,
                        initialLng: -61.533,
                        initialZoom: 12.0,
                        onMapReady: (controller) {
                          _updateMapMarkers(groups);
                        },
                      ),
              ),

              // Liste des groupes (overlay)
              Positioned(
                left: 16,
                top: 16,
                bottom: 16,
                child: _buildGroupsList(groups),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTokenMissing() {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.map_rounded, size: 42),
                  const SizedBox(height: 12),
                  const Text(
                    'Mapbox inactif: token manquant',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Configure MAPBOX_ACCESS_TOKEN pour afficher la carte.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _configureMapboxToken,
                    icon: const Icon(Icons.key_rounded),
                    label: const Text('Configurer'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupsList(List<_GroupLive> groups) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.groups, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${groups.length} groupe(s) actif(s)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: groups.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final g = groups[index];
                return _buildGroupCard(g);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(_GroupLive g) {
    final isSelected = _selectedGroupId == g.id;
    final color = _getGroupColor(g.id);

    String statusText = 'Hors ligne';
    Color statusColor = Colors.grey;

    final updatedAt = g.updatedAt;
    if (updatedAt != null) {
      final age = DateTime.now().difference(updatedAt).inSeconds;
      if (age < 30) {
        statusText = 'En ligne';
        statusColor = Colors.green;
      } else if (age < 180) {
        statusText = 'Récent (${age}s)';
        statusColor = Colors.orange;
      } else {
        statusText = 'Inactif (${(age / 60).toStringAsFixed(0)}min)';
        statusColor = Colors.red;
      }
    }

    return Card(
      color: isSelected ? color.withValues(alpha: 0.10) : null,
      elevation: isSelected ? 4 : 1,
      child: InkWell(
        onTap: () => _centerOnGroup(g),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      g.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 12,
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${g.lat.toStringAsFixed(5)}, ${g.lng.toStringAsFixed(5)}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              if (g.memberCount > 0) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${g.memberCount} membre(s)',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
              if (g.speed != null && g.speed! > 0) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.speed, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${(g.speed! * 3.6).toStringAsFixed(1)} km/h',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
              if (g.heading != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.navigation_rounded, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${g.heading!.toStringAsFixed(0)}°',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // Logique métier (API MasLiveMapController)
  // ============================================================================

  Future<void> _updateMapMarkers(List<_GroupLive> groups) async {
    final markers = groups.map((g) {
      final isSelected = _selectedGroupId == g.id;
      return MapMarker(
        id: g.id,
        lat: g.lat,
        lng: g.lng,
        label: isSelected ? g.name : null,
        color: _getGroupColor(g.id),
        size: isSelected ? 1.8 : 1.2,
      );
    }).toList();

    await _mapController.setMarkers(markers);
  }

  Future<void> _centerOnGroup(_GroupLive g) async {
    setState(() {
      _selectedGroupId = g.id;
    });
    await _mapController.moveTo(lat: g.lat, lng: g.lng, zoom: 15.0);
    await _updateMapMarkers(_groups);
  }

  Future<void> _centerOnAllGroups() async {
    setState(() {
      _selectedGroupId = null;
    });

    if (_groups.isEmpty) return;

    // Centre moyen
    double sumLat = 0;
    double sumLng = 0;
    for (final g in _groups) {
      sumLat += g.lat;
      sumLng += g.lng;
    }
    final centerLat = sumLat / _groups.length;
    final centerLng = sumLng / _groups.length;

    await _mapController.moveTo(lat: centerLat, lng: centerLng, zoom: 12.0);
    await _updateMapMarkers(_groups);
  }

  // ============================================================================
  // Parsing Firestore (support GeoPoint + lat/lng)
  // ============================================================================

  _GroupLive? _parseGroup(String id, Map<String, dynamic> data) {
    // Support 1: ancien schéma avec GeoPoint
    final gp = data['position'];
    if (gp is GeoPoint) {
      return _GroupLive(
        id: id,
        name: (data['name'] ?? id).toString(),
        lat: gp.latitude,
        lng: gp.longitude,
        heading: (data['heading'] as num?)?.toDouble(),
        speed: (data['speed'] as num?)?.toDouble(),
        updatedAt: (data['updatedAt'] is Timestamp) 
            ? (data['updatedAt'] as Timestamp).toDate() 
            : null,
        memberCount: (data['memberCount'] as int?) ?? 0,
      );
    }

    // Support 2: nouveau schéma avec lat/lng
    final lat = (data['lat'] as num?)?.toDouble();
    final lng = (data['lng'] as num?)?.toDouble();
    if (lat != null && lng != null) {
      return _GroupLive(
        id: id,
        name: (data['name'] ?? data['groupName'] ?? data['groupId'] ?? id).toString(),
        lat: lat,
        lng: lng,
        heading: (data['heading'] as num?)?.toDouble(),
        speed: (data['speed'] as num?)?.toDouble(),
        updatedAt: (data['updatedAt'] is Timestamp)
            ? (data['updatedAt'] as Timestamp).toDate()
            : null,
        memberCount: (data['memberCount'] as int?) ?? 0,
      );
    }

    return null;
  }

  Color _getGroupColor(String groupId) {
    const palette = [
      Color(0xFFFF3B30),
      Color(0xFF34C759),
      Color(0xFF0A84FF),
      Color(0xFFFF9500),
      Color(0xFFAF52DE),
      Color(0xFFFFC107),
    ];
    final hash = groupId.codeUnits.fold<int>(0, (p, c) => p + c);
    return palette[hash % palette.length];
  }
}

// ============================================================================
// Modèle de données
// ============================================================================

class _GroupLive {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double? heading;
  final double? speed;
  final DateTime? updatedAt;
  final int memberCount;

  _GroupLive({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.heading,
    this.speed,
    this.updatedAt,
    required this.memberCount,
  });
}
