import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../session/session_scope.dart';
import '../session/require_signin.dart';
import '../services/favorites_service.dart';

enum MapTab { ville, tracking, visiter, encadrement, food }

class HomeMapPage extends StatefulWidget {
  const HomeMapPage({super.key});

  @override
  State<HomeMapPage> createState() => _HomeMapPageState();
}

class _HomeMapPageState extends State<HomeMapPage> {
  final MapController _mapController = MapController();

  // Position + rotation
  LatLng? _userLatLng;
  bool _followHeading = false;
  double _rotationRad = 0.0; // flutter_map rotation en radians
  StreamSubscription<CompassEvent>? _compassSub;

  // Style boutons
  static const _btnSize = 52.0;

  MapTab _tab = MapTab.ville;

  Stream<QuerySnapshot<Map<String, dynamic>>> _placesStream() {
    // Tu peux filtrer par type selon _tab si tu veux
    return FirebaseFirestore.instance
        .collection('places')
        .where('active', isEqualTo: true)
        .snapshots();
  }

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    final ok = await _ensureLocationPermission();
    if (!ok) return;

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    _userLatLng = LatLng(pos.latitude, pos.longitude);

    if (mounted) setState(() {});
  }

  Future<bool> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return false;
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  Future<void> _recenterToUser() async {
    final ok = await _ensureLocationPermission();
    if (!ok) return;

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final target = LatLng(pos.latitude, pos.longitude);
    setState(() => _userLatLng = target);

    _mapController.move(target, 15.2);
  }

  void _toggleCompassMode() {
    setState(() {
      _followHeading = !_followHeading;
    });

    if (_followHeading) {
      _compassSub?.cancel();
      _compassSub = FlutterCompass.events?.listen((event) {
        final headingDeg = event.heading;
        if (headingDeg == null) return;

        final rad = -(headingDeg * math.pi / 180.0);

        setState(() => _rotationRad = rad);
        _mapController.rotate(rad);
      });
    } else {
      _compassSub?.cancel();
      _compassSub = null;

      setState(() => _rotationRad = 0.0);
      _mapController.rotate(0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);

    final start = _userLatLng ?? const LatLng(16.241, -61.533);

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: start,
              initialZoom: 13,
              initialRotation: _rotationRad,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.maslive.app',
              ),

              if (_userLatLng != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _userLatLng!,
                      width: 44,
                      height: 44,
                      child: _userDot(),
                    ),
                  ],
                ),

              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _placesStream(),
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox.shrink();

                  final markers = snap.data!.docs.map((doc) {
                    final d = doc.data();
                    final lat = (d['lat'] as num).toDouble();
                    final lng = (d['lng'] as num).toDouble();
                    final name = (d['name'] ?? 'Lieu') as String;

                    return Marker(
                      point: LatLng(lat, lng),
                      width: 44,
                      height: 44,
                      child: GestureDetector(
                        onTap: () => _openPlaceSheet(
                          context,
                          session: session,
                          placeId: doc.id,
                          name: name,
                          payload: d,
                        ),
                        child: const Icon(Icons.location_on,
                            size: 44, color: Color(0xFFFF7A00)),
                      ),
                    );
                  }).toList();

                  return MarkerLayer(markers: markers);
                },
              ),
            ],
          ),

          // Search pill
          Positioned(
            left: 14,
            right: 74,
            top: MediaQuery.of(context).padding.top + 10,
            child: _SearchPill(onAccountTap: () {
              Navigator.pushNamed(context, '/account');
            }),
          ),

          // Boutons (boussole + recentrer)
          Positioned(
            right: 14,
            top: MediaQuery.of(context).padding.top + 92,
            child: Column(
              children: [
                _roundAction(
                  icon: _followHeading ? Icons.explore_rounded : Icons.explore_outlined,
                  tooltip: _followHeading ? 'Suivi orientation (ON)' : 'Nord réel (OFF)',
                  onTap: _toggleCompassMode,
                ),
                const SizedBox(height: 12),
                _roundAction(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Recentrer',
                  onTap: _recenterToUser,
                ),
              ],
            ),
          ),

          // Tabs à droite (couches)
          Positioned(
            right: 10,
            top: MediaQuery.of(context).padding.top + 170,
            bottom: 24,
            child: _RightTabs(
              value: _tab,
              onChanged: (t) => setState(() => _tab = t),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: _btnSize,
          height: _btnSize,
          child: Tooltip(
            message: tooltip,
            child: Icon(icon, size: 24, color: Colors.black.withValues(alpha: 0.78)),
          ),
        ),
      ),
    );
  }

  Widget _userDot() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF1A73E8),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            color: Colors.black.withValues(alpha: 0.18),
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Center(
        child: Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Future<void> _openPlaceSheet(
    BuildContext context, {
    required dynamic session,
    required String placeId,
    required String name,
    required Map<String, dynamic> payload,
  }) async {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('Type: ${payload['type'] ?? '-'}'),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.directions),
                    label: const Text('Itinéraire'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  tooltip: 'Favori (connexion requise)',
                  onPressed: () async {
                    await requireSignIn(
                      context,
                      session: SessionScope.of(context),
                      onSignedIn: () async {
                        await FavoritesService.instance.toggleFavoritePlace(
                          placeId,
                          payload: {'name': name},
                        );
                      },
                    );
                  },
                  icon: const Icon(Icons.favorite_border),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

// ✅ Search pill
class _SearchPill extends StatelessWidget {
  const _SearchPill({required this.onAccountTap});
  final VoidCallback onAccountTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(18),
      color: Colors.white,
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            const SizedBox(width: 12),
            const Icon(Icons.search),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Recherche / Ville',
                  style: TextStyle(color: Colors.black54)),
            ),
            IconButton(
              onPressed: onAccountTap,
              icon: const Icon(Icons.person),
            ),
          ],
        ),
      ),
    );
  }
}

// ✅ Right tabs (onglets verticaux)
class _RightTabs extends StatelessWidget {
  const _RightTabs({required this.value, required this.onChanged});
  final MapTab value;
  final ValueChanged<MapTab> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(MapTab t, IconData icon, String label) {
      final selected = value == t;
      return GestureDetector(
        onTap: () => onChanged(t),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.black87),
              ),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.white)),
            ],
          ),
        ),
      );
    }

    return Container(
      width: 70,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            tab(MapTab.ville, Icons.location_city, 'Ville'),
            tab(MapTab.tracking, Icons.location_searching, 'Tracking'),
            tab(MapTab.visiter, Icons.place, 'Visiter'),
            tab(MapTab.encadrement, Icons.shield_outlined, 'Encad.'),
            tab(MapTab.food, Icons.restaurant, 'Food'),
          ],
        ),
      ),
    );
  }
}
