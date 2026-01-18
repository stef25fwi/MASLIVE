import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class TrackingLivePage extends StatefulWidget {
  const TrackingLivePage({super.key});

  @override
  State<TrackingLivePage> createState() => _TrackingLivePageState();
}

class _TrackingLivePageState extends State<TrackingLivePage>
    with TickerProviderStateMixin {
  final MapController _map = MapController();

  String? _followGroupId; // si non null => auto-follow
  final Map<String, List<LatLng>> _trails = {}; // trace par groupe (option)
  final int _maxTrailPoints = 120; // limite mémoire
  
  // Animation lerp : groupId -> (animController, animationPos)
  final Map<String, AnimationController> _animControllers = {};
  final Map<String, Animation<LatLng>> _animatedPositions = {};
  
  String _searchQuery = '';
  final int _maxAgeSeconds = 120; // 2 min

  @override
  void dispose() {
    for (final ctrl in _animControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _liveStream() {
    // ✅ Live : récupère tous les groupes actifs
    return FirebaseFirestore.instance
        .collection('group_locations')
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  void _pushTrail(String groupId, LatLng p) {
    final list = _trails.putIfAbsent(groupId, () => <LatLng>[]);
    // Évite les doublons identiques
    if (list.isNotEmpty) {
      final last = list.last;
      if ((last.latitude - p.latitude).abs() < 1e-7 &&
          (last.longitude - p.longitude).abs() < 1e-7) {
        return;
      }
    }
    list.add(p);
    if (list.length > _maxTrailPoints) {
      list.removeRange(0, list.length - _maxTrailPoints);
    }
  }

  void _maybeFollow(String groupId, LatLng p) {
    if (_followGroupId == groupId) {
      // recentre sans changer le zoom
      final z = _map.camera.zoom;
      _map.move(p, z);
    }
  }

  /// Crée ou met à jour l'animation lerp pour un groupe
  void _animatePosition(String groupId, LatLng targetPos, LatLng currentPos) {
    final existing = _animControllers[groupId];
    
    if (existing != null) {
      existing.forward(from: 0);
    } else {
      final ctrl = AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this,
      );
      _animControllers[groupId] = ctrl;
      
      ctrl.forward();
      ctrl.addListener(() {
        setState(() {
          // mise à jour du listener pour rebuild
        });
      });
    }

    final ctrl = _animControllers[groupId]!;
    final animation = Tween<LatLng>(
      begin: currentPos,
      end: targetPos,
    ).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeInOutCubic));
    
    _animatedPositions[groupId] = animation;
  }

  /// Vérifie si la position est trop vieille (> maxAgeSeconds)
  bool _isPositionStale(Timestamp? ts) {
    if (ts == null) return true;
    final age = DateTime.now().difference(ts.toDate()).inSeconds;
    return age > _maxAgeSeconds;
  }

  /// Filtre les groupes selon la recherche
  bool _matchesSearch(String groupId, String? groupName) {
    if (_searchQuery.isEmpty) return true;
    final query = _searchQuery.toLowerCase();
    return groupId.toLowerCase().contains(query) ||
        (groupName?.toLowerCase().contains(query) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: const MapOptions(
              initialCenter: LatLng(16.241, -61.533),
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.maslive.app',
              ),

              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _liveStream(),
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox.shrink();

                  final docs = snap.data!.docs;

                  final markers = <Marker>[];
                  final polylines = <Polyline>[];

                  for (final doc in docs) {
                    final d = doc.data();

                    final groupId = (d['groupId'] ?? doc.id).toString();
                    final name = (d['groupName'] ?? 'Groupe').toString();
                    final heading = (d['heading'] as num?)?.toDouble();
                    final updatedAt = d['updatedAt'] as Timestamp?;

                    // ✅ Filtre : âge max + recherche
                    if (_isPositionStale(updatedAt)) continue;
                    if (!_matchesSearch(groupId, name)) continue;

                    final lat = (d['lat'] as num?)?.toDouble();
                    final lng = (d['lng'] as num?)?.toDouble();
                    if (lat == null || lng == null) continue;

                    final targetPos = LatLng(lat, lng);
                    
                    // ✅ Animation lerp
                    final currentPos = _animatedPositions[groupId]?.value ?? targetPos;
                    _animatePosition(groupId, targetPos, currentPos);

                    // trace (option)
                    _pushTrail(groupId, targetPos);
                    if (_trails[groupId] != null && _trails[groupId]!.length >= 2) {
                      polylines.add(
                        Polyline(
                          points: _trails[groupId]!,
                          strokeWidth: 4,
                          color: Colors.orange.withValues(alpha: 0.4),
                        ),
                      );
                    }

                    // auto-follow si activé
                    _maybeFollow(groupId, currentPos);

                    markers.add(
                      Marker(
                        point: currentPos,
                        width: 54,
                        height: 54,
                        child: _GroupLiveMarker(
                          title: name,
                          heading: heading,
                          isFollowing: _followGroupId == groupId,
                          onTap: () => _openGroupSheet(
                            context,
                            groupId: groupId,
                            groupName: name,
                            point: currentPos,
                            heading: heading,
                          ),
                        ),
                      ),
                    );
                  }

                  return Stack(
                    children: [
                      PolylineLayer(polylines: polylines),
                      MarkerLayer(markers: markers),
                    ],
                  );
                },
              ),
            ],
          ),

          // Top bar iOS-like avec recherche
          Positioned(
            left: 14,
            right: 14,
            top: MediaQuery.of(context).padding.top + 10,
            child: Column(
              children: [
                _TopPill(
                  title: 'Tracking LIVE',
                  subtitle: _followGroupId == null
                      ? 'Sélectionne un groupe pour le suivre'
                      : 'Suivi: $_followGroupId',
                  onStopFollow: _followGroupId == null
                      ? null
                      : () => setState(() => _followGroupId = null),
                ),
                const SizedBox(height: 10),
                // Recherche / Filtre
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Filtrer groupe...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () =>
                                  setState(() => _searchQuery = ''),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openGroupSheet(
    BuildContext context, {
    required String groupId,
    required String groupName,
    required LatLng point,
    required double? heading,
  }) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(groupName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Text('Position: ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}'),
            if (heading != null)
              Text('Direction: ${heading.toStringAsFixed(1)}°'),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      setState(() => _followGroupId = groupId);
                      final z = _map.camera.zoom;
                      _map.move(point, max(13.5, z));
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.location_searching),
                    label: const Text('Suivre'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final z = _map.camera.zoom;
                      _map.move(point, z);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.my_location),
                    label: const Text('Centrer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TopPill extends StatelessWidget {
  const _TopPill({
    required this.title,
    required this.subtitle,
    required this.onStopFollow,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onStopFollow;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(18),
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.wifi_tethering, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                ],
              ),
            ),
            if (onStopFollow != null)
              TextButton(
                onPressed: onStopFollow,
                child: const Text('Stop'),
              ),
          ],
        ),
      ),
    );
  }
}

class _GroupLiveMarker extends StatelessWidget {
  const _GroupLiveMarker({
    required this.title,
    required this.onTap,
    required this.isFollowing,
    required this.heading,
  });

  final String title;
  final VoidCallback onTap;
  final bool isFollowing;
  final double? heading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Halo
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFollowing ? Colors.black.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
            ),
          ),
          // ✅ Pin avec rotation (heading)
          Transform.rotate(
            angle: (heading ?? 0) * (pi / 180),
            child: const Icon(
              Icons.location_on,
              size: 46,
              color: Color(0xFFFF3B30),
            ),
          ),
          // Badge
          Positioned(
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _short(title),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _short(String s) {
    final t = s.trim();
    if (t.length <= 12) return t;
    return '${t.substring(0, 12)}…';
  }
}
