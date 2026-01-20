import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Page de tracking en temps réel des groupes
class AdminTrackingPage extends StatefulWidget {
  const AdminTrackingPage({Key? key}) : super(key: key);

  @override
  State<AdminTrackingPage> createState() => _AdminTrackingPageState();
}

class _AdminTrackingPageState extends State<AdminTrackingPage> {
  final _firestore = FirebaseFirestore.instance;
  final MapController _mapController = MapController();
  String? _selectedGroupId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracking Live des Groupes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            onPressed: _centerOnGroups,
            tooltip: 'Centrer sur tous les groupes',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('groupLocations').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final groups = snapshot.data!.docs;

          if (groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun groupe en ligne',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return Stack(
            children: [
              // Carte avec tous les groupes
              FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: LatLng(16.241, -61.533),
                  initialZoom: 12,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  ),
                  MarkerLayer(
                    markers: groups.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final position = data['position'] as GeoPoint?;

                      if (position == null) return null;

                      final isSelected = _selectedGroupId == doc.id;
                      final color = _getGroupColor(doc.id);

                      return Marker(
                        point: LatLng(position.latitude, position.longitude),
                        width: isSelected ? 60 : 40,
                        height: isSelected ? 60 : 40,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedGroupId = isSelected ? null : doc.id;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: isSelected ? 4 : 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                Icons.group,
                                color: Colors.white,
                                size: isSelected ? 30 : 20,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).whereType<Marker>().toList(),
                  ),
                ],
              ),

              // Liste des groupes sur la gauche
              Positioned(
                left: 16,
                top: 16,
                bottom: 16,
                child: Container(
                  width: 280,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
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
                            Text(
                              '${groups.length} groupe(s) actif(s)',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: groups.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final doc = groups[index];
                            final data = doc.data() as Map<String, dynamic>;
                            return _buildGroupCard(doc.id, data);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGroupCard(String groupId, Map<String, dynamic> data) {
    final name = data['name'] as String? ?? groupId;
    final position = data['position'] as GeoPoint?;
    final heading = (data['heading'] as num?)?.toDouble();
    final speed = (data['speed'] as num?)?.toDouble();
    final updatedAt = data['updatedAt'] as Timestamp?;
    final memberCount = data['memberCount'] as int? ?? 0;

    final isSelected = _selectedGroupId == groupId;
    final color = _getGroupColor(groupId);

    String statusText = 'Hors ligne';
    Color statusColor = Colors.grey;

    if (updatedAt != null) {
      final age = DateTime.now().difference(updatedAt.toDate()).inSeconds;
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
      color: isSelected ? color.withOpacity(0.1) : null,
      elevation: isSelected ? 4 : 1,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedGroupId = isSelected ? null : groupId;
          });

          if (position != null) {
            _mapController.move(
              LatLng(position.latitude, position.longitude),
              15,
            );
          }
        },
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
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
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
              if (position != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
              if (memberCount > 0) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '$memberCount membre(s)',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
              if (speed != null && speed > 0) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.speed, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${(speed * 3.6).toStringAsFixed(1)} km/h',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
              if (heading != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Transform.rotate(
                      angle: heading * 3.14159 / 180,
                      child: Icon(
                        Icons.navigation,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${heading.toStringAsFixed(0)}°',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
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

  void _centerOnGroups() async {
    final snapshot = await _firestore.collection('groupLocations').get();

    if (snapshot.docs.isEmpty) return;

    final positions = snapshot.docs
        .map((doc) {
          final data = doc.data();
          final position = data['position'] as GeoPoint?;
          if (position == null) return null;
          return LatLng(position.latitude, position.longitude);
        })
        .whereType<LatLng>()
        .toList();

    if (positions.isEmpty) return;

    if (positions.length == 1) {
      _mapController.move(positions.first, 15);
      return;
    }

    // Calculer les limites
    double minLat = positions.first.latitude;
    double maxLat = positions.first.latitude;
    double minLng = positions.first.longitude;
    double maxLng = positions.first.longitude;

    for (final pos in positions) {
      minLat = pos.latitude < minLat ? pos.latitude : minLat;
      maxLat = pos.latitude > maxLat ? pos.latitude : maxLat;
      minLng = pos.longitude < minLng ? pos.longitude : minLng;
      maxLng = pos.longitude > maxLng ? pos.longitude : maxLng;
    }

    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );

    _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
  }

  Color _getGroupColor(String groupId) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.cyan,
    ];

    return colors[groupId.hashCode.abs() % colors.length];
  }
}
