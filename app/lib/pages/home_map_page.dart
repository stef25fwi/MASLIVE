import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../ui/theme/maslive_theme.dart';
import '../ui/widgets/gradient_header.dart';
import '../ui/widgets/gradient_icon_button.dart';
import '../ui/widgets/honeycomb_background.dart';
import '../ui/widgets/maslive_card.dart';
import '../models/place_model.dart';
import '../models/circuit_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/geolocation_service.dart';
import '../services/localization_service.dart';

enum _MapAction { ville, tracking, visiter, encadrement, food }

class HomeMapPage extends StatefulWidget {
  const HomeMapPage({super.key});

  @override
  State<HomeMapPage> createState() => _HomeMapPageState();
}

class _HomeMapPageState extends State<HomeMapPage>
    with TickerProviderStateMixin {
  _MapAction _selected = _MapAction.ville;
  bool _showActionsMenu = false;
  late AnimationController _menuAnimController;
  late Animation<Offset> _menuSlideAnimation;
  // ignore: unused_field
  late AnimationController _pulseController;
  // ignore: unused_field
  late Animation<double> _pulseAnimation;

  final MapController _mapController = MapController();
  final FirestoreService _firestore = FirestoreService();
  final GeolocationService _geo = GeolocationService.instance;
  final _circuitStream = FirestoreService().getPublishedCircuitsStream();

  StreamSubscription<Position>? _positionSub;
  LatLng? _userPos;
  bool _followUser = true;
  bool _requestingGps = false;
  bool _isTracking = false;

  static const LatLng _fallbackCenter = LatLng(16.241, -61.533);

  @override
  void initState() {
    super.initState();
    _isTracking = _geo.isTracking;
    _menuAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _menuSlideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _menuAnimController, curve: Curves.easeOut));
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseController.repeat();
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _bootstrapLocation();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _menuAnimController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _bootstrapLocation() async {
    final ok = await _ensureLocationPermission(request: true);
    if (!ok) return;
    _startUserPositionStream();
  }

  Future<bool> _ensureLocationPermission({required bool request}) async {
    if (_requestingGps) return false;
    _requestingGps = true;

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Active la localisation (GPS) pour centrer la carte.',
              ),
            ),
          );
        }
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && request) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission GPS refusée.')),
          );
        }
        return false;
      }

      return true;
    } finally {
      _requestingGps = false;
    }
  }

  void _startUserPositionStream() {
    _positionSub?.cancel();

    const settings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 8,
    );

    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen((pos) {
          final p = LatLng(pos.latitude, pos.longitude);
          if (!mounted) return;

          setState(() => _userPos = p);

          if (_followUser) {
            final z = _mapController.camera.zoom;
            _mapController.move(p, z < 12.5 ? 13.5 : z);
          }
        });
  }

  Future<void> _recenterOnUser() async {
    final ok = await _ensureLocationPermission(request: true);
    if (!ok) return;

    final pos = await Geolocator.getCurrentPosition(
      timeLimit: const Duration(seconds: 10),
      desiredAccuracy: LocationAccuracy.best,
    );

    final p = LatLng(pos.latitude, pos.longitude);
    if (!mounted) return;

    setState(() {
      _userPos = p;
      _followUser = true;
    });

    final z = _mapController.camera.zoom;
    _mapController.move(p, z < 12.5 ? 13.5 : z);
  }

  Stream<List<Place>> _placesStream() {
    switch (_selected) {
      case _MapAction.visiter:
        return _firestore.getPlacesByTypeStream(PlaceType.visit);
      case _MapAction.food:
        return _firestore.getPlacesByTypeStream(PlaceType.food);
      case _MapAction.encadrement:
        return _firestore.getPlacesByTypeStream(PlaceType.market);
      case _MapAction.tracking:
      case _MapAction.ville:
        return _firestore.getPlacesStream();
    }
  }

  String _placeLabel(PlaceType type) {
    switch (type) {
      case PlaceType.market:
        return 'Assistance';
      case PlaceType.visit:
        return 'À visiter';
      case PlaceType.food:
        return 'Food';
    }
  }

  Color _groupColor(String groupId) {
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

  List<LatLng> _circuitPoints(Circuit c) {
    final pts = <LatLng>[];
    pts.add(LatLng(c.start.lat, c.start.lng));
    for (final p in c.points) {
      pts.add(LatLng(p.lat, p.lng));
    }
    pts.add(LatLng(c.end.lat, c.end.lng));
    return pts;
  }

  IconData _placeIcon(PlaceType type) {
    switch (type) {
      case PlaceType.market:
        return Icons.health_and_safety_rounded;
      case PlaceType.visit:
        return Icons.attractions_rounded;
      case PlaceType.food:
        return Icons.restaurant_rounded;
    }
  }

  Color _placeColor(PlaceType type) {
    switch (type) {
      case PlaceType.market:
        return const Color(0xFF5B8CFF);
      case PlaceType.visit:
        return const Color(0xFFB35BFF);
      case PlaceType.food:
        return const Color(0xFFFF7A59);
    }
  }

  Marker _userMarker(LatLng p) {
    return Marker(
      point: p,
      width: 64,
      height: 64,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            final scale = 1.0 + (_pulseAnimation.value * 0.3);
            final opacity = 0.18 - (_pulseAnimation.value * 0.08);
            
            return Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 44 * scale,
                  height: 44 * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2F6BFF).withOpacity(opacity.clamp(0, 1)),
                  ),
                ),
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2F6BFF),
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Marker _placeMarker(Place place) {
    final color = _placeColor(place.type);
    final icon = _placeIcon(place.type);

    return Marker(
      point: place.location,
      width: 56,
      height: 56,
      child: GestureDetector(
        onTap: () => _openPlaceSheet(place),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.92),
            border: Border.all(color: color.withOpacity(0.45)),
            boxShadow: MasliveTheme.floatingShadow,
          ),
          child: Icon(icon, color: color, size: 26),
        ),
      ),
    );
  }

  Marker _groupMarker({
    required LatLng p,
    required String label,
    required double? heading,
    required Color color,
  }) {
    return Marker(
      point: p,
      width: 60,
      height: 60,
      child: GestureDetector(
        onTap: () => _openGroupSheet(label, p),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.92),
                border: Border.all(color: color.withOpacity(0.45)),
                boxShadow: MasliveTheme.floatingShadow,
              ),
            ),
            if (heading != null)
              Transform.rotate(
                angle: (heading) * (3.1415926535 / 180),
                child: Icon(
                  Icons.navigation_rounded,
                  size: 22,
                  color: color,
                ),
              )
            else
              Icon(
                Icons.wifi_tethering_rounded,
                size: 22,
                color: color,
              ),
            Positioned(
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  label.length <= 12 ? label : '${label.substring(0, 12)}…',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPlaceSheet(Place place) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.94),
              borderRadius: BorderRadius.circular(24),
              boxShadow: MasliveTheme.floatingShadow,
              border: Border.all(color: MasliveTheme.divider),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                          tooltip: 'Fermer',
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () {
                            _mapController.move(place.location, 15);
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.zoom_in_map_rounded),
                          label: const Text('Zoom'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _placeColor(place.type).withOpacity(0.14),
                          ),
                          child: Icon(
                            _placeIcon(place.type),
                            color: _placeColor(place.type),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _placeColor(place.type)
                                          .withOpacity(0.14),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color:
                                            _placeColor(place.type).withOpacity(0.4),
                                      ),
                                    ),
                                    child: Text(
                                      _placeLabel(place.type),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: _placeColor(place.type),
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                place.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${place.city} • ${place.rating.toStringAsFixed(1)}★',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: MasliveTheme.textSecondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Coordonnées: ${place.lat.toStringAsFixed(5)}, ${place.lng.toStringAsFixed(5)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: MasliveTheme.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    MasliveCard(
                      padding: const EdgeInsets.all(12),
                      radius: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Description',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Informations détaillées sur ce lieu. Ajoutez ici un descriptif plus long si disponible.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: MasliveTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openGroupSheet(String label, LatLng p) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.94),
              borderRadius: BorderRadius.circular(24),
              boxShadow: MasliveTheme.floatingShadow,
              border: Border.all(color: MasliveTheme.divider),
            ),
            child: Row(
              children: [
                const Icon(Icons.wifi_tethering_rounded),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Position: ${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: MasliveTheme.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _mapController.move(p, 14.5);
                    Navigator.pop(context);
                  },
                  child: const Text('Centrer'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleTracking() async {
    if (_isTracking) {
      _geo.stopTracking();
      setState(() => _isTracking = false);
      return;
    }

    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connecte-toi pour démarrer le tracking.'),
        ),
      );
      return;
    }

    final profile = await AuthService.instance.getUserProfile(uid);
    if (!mounted) return;
    final groupId = profile?.groupId;
    if (groupId == null || groupId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun groupId associé à ton profil.')),
      );
      return;
    }

    final ok = await _geo.startTracking(groupId: groupId, intervalSeconds: 15);
    if (!mounted) return;
    setState(() => _isTracking = ok);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? '✅ Tracking démarré (15s)' : '❌ Permissions GPS refusées',
        ),
      ),
    );
  }

  void _openLanguagePicker() {
    final loc = LocalizationService();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fermer',
      barrierColor: Colors.black.withOpacity(0.3),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        Widget item(AppLanguage lang, String label) {
          final selected = loc.language == lang;
          return ListTile(
            leading: Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected
                  ? MasliveTheme.textPrimary
                  : MasliveTheme.textSecondary,
            ),
            title: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: MasliveTheme.textPrimary,
              ),
            ),
            onTap: () {
              loc.setLanguage(lang);
              Navigator.pop(context);
            },
          );
        }

        return SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 80, 12, 0),
              constraints: const BoxConstraints(maxWidth: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.94),
                borderRadius: BorderRadius.circular(16),
                boxShadow: MasliveTheme.floatingShadow,
                border: Border.all(color: MasliveTheme.divider),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Langue',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: MasliveTheme.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Divider(height: 1),
                  item(AppLanguage.fr, 'Français'),
                  item(AppLanguage.en, 'English'),
                  item(AppLanguage.es, 'Español'),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: HoneycombBackground(
          opacity: 0.08,
          child: Stack(
            children: [
              Column(
                children: [
                  MasliveGradientHeader(
                    height: 60,
                    borderRadius: BorderRadius.zero,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    backgroundColor: Colors.white.withOpacity(0.50),
                    child: Row(
                      children: [
                      MasliveGradientIconButton(
                        icon: Icons.account_circle_rounded,
                        tooltip: 'Profil',
                        onTap: () =>
                            Navigator.pushNamed(context, '/account-ui'),
                      ),
                      const SizedBox(width: 12),
                      const Spacer(),
                      MasliveGradientIconButton(
                        icon: Icons.language_rounded,
                        tooltip: 'Langue',
                        onTap: _openLanguagePicker,
                      ),
                      const SizedBox(width: 10),
                      MasliveGradientIconButton(
                        icon: Icons.shopping_bag_rounded,
                        tooltip: 'Shop',
                        onTap: () => Navigator.pushNamed(context, '/shop-ui'),
                      ),
                      const SizedBox(width: 10),
                      MasliveGradientIconButton(
                        icon: Icons.menu_rounded,
                        tooltip: 'Menu',
                        onTap: () {
                          setState(() => _showActionsMenu = !_showActionsMenu);
                          if (_showActionsMenu) {
                            _menuAnimController.forward();
                          } else {
                            _menuAnimController.reverse();
                          }
                        },
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Stack(
                    children: [
                      // Carte (réelle) - plein écran
                      MasliveCard(
                        radius: 0,
                        padding: EdgeInsets.zero,
                        child: ClipRRect(
                          borderRadius: BorderRadius.zero,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              FlutterMap(
                                mapController: _mapController,
                                options: MapOptions(
                                  initialCenter: _userPos ?? _fallbackCenter,
                                  initialZoom: _userPos != null ? 13.5 : 12.5,
                                  onPositionChanged: (pos, hasGesture) {
                                    if (hasGesture) _followUser = false;
                                  },
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'com.maslive.app',
                                  ),

                                  if (_userPos != null)
                                    MarkerLayer(
                                      markers: [_userMarker(_userPos!)],
                                    ),

                                  StreamBuilder<List<Place>>(
                                    stream: _placesStream(),
                                    builder: (context, snap) {
                                      final places =
                                          snap.data ?? const <Place>[];
                                      if (places.isEmpty) {
                                        return const SizedBox.shrink();
                                      }
                                      return MarkerLayer(
                                        markers: places
                                            .map(_placeMarker)
                                            .toList(),
                                      );
                                    },
                                  ),

                                  if (_selected == _MapAction.tracking) ...[
                                    StreamBuilder<List<Circuit>>(
                                      stream: _circuitStream,
                                      builder: (context, snap) {
                                        final circuits = snap.data ?? const [];
                                        if (circuits.isEmpty) {
                                          return const SizedBox.shrink();
                                        }
                                        return PolylineLayer(
                                          polylines: circuits
                                              .where((c) => c.points.length >= 1)
                                              .map(
                                                (c) => Polyline(
                                                  points: _circuitPoints(c),
                                                  color: Colors.black.withOpacity(0.65),
                                                  strokeWidth: 4,
                                                ),
                                              )
                                              .toList(),
                                        );
                                      },
                                    ),
                                    StreamBuilder<
                                      QuerySnapshot<Map<String, dynamic>>
                                    >(
                                      stream: FirebaseFirestore.instance
                                          .collection('groups')
                                          .snapshots(),
                                      builder: (context, snap) {
                                        if (!snap.hasData) {
                                          return const SizedBox.shrink();
                                        }

                                        final markers = <Marker>[];
                                        for (final doc in snap.data!.docs) {
                                          final d = doc.data();
                                          final name = (d['name'] ?? doc.id)
                                              .toString();
                                          final loc =
                                              (d['lastLocation']
                                                  as Map<String, dynamic>?) ??
                                              const {};
                                          final lat = (loc['lat'] as num?)
                                              ?.toDouble();
                                          final lng = (loc['lng'] as num?)
                                              ?.toDouble();
                                          if (lat == null || lng == null)
                                            continue;

                                          final heading =
                                              (loc['heading'] as num?)
                                                  ?.toDouble();
                                          final updatedAt = loc['updatedAt'];
                                          if (updatedAt is Timestamp) {
                                            final age = DateTime.now()
                                                .difference(
                                                  updatedAt.toDate(),
                                                )
                                                .inSeconds;
                                            if (age > 180) continue;
                                          }

                                          markers.add(
                                            _groupMarker(
                                              p: LatLng(lat, lng),
                                              label: name,
                                              heading: heading,
                                              color: _groupColor(doc.id),
                                            ),
                                          );
                                        }

                                        if (markers.isEmpty) {
                                          return const SizedBox.shrink();
                                        }

                                        return MarkerLayer(markers: markers);
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Overlay actions - affiche quand burger cliqué
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () {
                            if (!_showActionsMenu) return;
                            setState(() => _showActionsMenu = false);
                            _menuAnimController.reverse();
                          },
                          onHorizontalDragEnd: (details) {
                            if (details.primaryVelocity! > 0 && _showActionsMenu) {
                              setState(() => _showActionsMenu = false);
                              _menuAnimController.reverse();
                            }
                          },
                          child: Container(
                            color: Colors.transparent,
                            child: Align(
                              alignment: Alignment.topRight,
                              child: SlideTransition(
                                position: _menuSlideAnimation,
                                child: IgnorePointer(
                                  ignoring: !_showActionsMenu,
                                  child: Container(
                                    width: 86,
                                    margin: const EdgeInsets.only(
                                      right: 4,
                                      top: 18,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.65),
                                      borderRadius: BorderRadius.circular(
                                        MasliveTheme.rPill,
                                      ),
                                      boxShadow: MasliveTheme.floatingShadow,
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    child: SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _ActionItem(
                                            label: 'Centrer',
                                            icon: Icons.my_location_rounded,
                                            selected: false,
                                            onTap: () {
                                              _recenterOnUser();
                                              setState(
                                                () =>
                                                    _showActionsMenu = false,
                                              );
                                              _menuAnimController.reverse();
                                            },
                                          ),
                                          const SizedBox(height: 8),
                                          _ActionItem(
                                            label: 'Tracking',
                                            icon: Icons.track_changes_rounded,
                                            selected:
                                                _selected ==
                                                _MapAction.tracking,
                                            onTap: () {
                                              setState(() {
                                                _selected =
                                                    _MapAction.tracking;
                                                _showActionsMenu = false;
                                              });
                                              _menuAnimController.reverse();
                                            },
                                          ),
                                          const SizedBox(height: 8),
                                          _ActionItem(
                                            label: 'Visiter',
                                            icon: Icons.map_outlined,
                                            selected:
                                                _selected ==
                                                _MapAction.visiter,
                                            onTap: () {
                                              setState(() {
                                                _selected =
                                                    _MapAction.visiter;
                                                _showActionsMenu = false;
                                              });
                                              _menuAnimController.reverse();
                                            },
                                          ),
                                          const SizedBox(height: 8),
                                          _ActionItem(
                                            label: 'Food',
                                            icon: Icons.fastfood_rounded,
                                            selected:
                                                _selected == _MapAction.food,
                                            onTap: () {
                                              setState(() {
                                                _selected = _MapAction.food;
                                                _showActionsMenu = false;
                                              });
                                              _menuAnimController.reverse();
                                            },
                                          ),
                                          const SizedBox(height: 8),
                                          _ActionItem(
                                            label: 'Assistance',
                                            icon: Icons.shield_outlined,
                                            selected:
                                                _selected ==
                                                _MapAction.encadrement,
                                            onTap: () {
                                              setState(() {
                                                _selected =
                                                    _MapAction.encadrement;
                                                _showActionsMenu = false;
                                              });
                                              _menuAnimController.reverse();
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      if (_selected == _MapAction.tracking)
                        Positioned(
                          left: 16,
                          right: 90,
                          bottom: 18,
                          child: _TrackingPill(
                            isTracking: _isTracking,
                            onToggle: _toggleTracking,
                          ),
                        ),

                      // Indicateur onglet - montre la nav bar cachée
                      if (!_showActionsMenu)
                        Positioned(
                          right: 90,
                          top: 18,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _showActionsMenu = true);
                              _menuAnimController.forward();
                            },
                            child: Container(
                              width: 12,
                              height: 70,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.65),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  bottomLeft: Radius.circular(12),
                                ),
                                boxShadow: MasliveTheme.floatingShadow,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ActionItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.85),
              border: Border.all(
                color: selected
                    ? MasliveTheme.pink
                    : MasliveTheme.divider,
                width: selected ? 2.0 : 1.0,
              ),
              boxShadow: selected ? MasliveTheme.cardShadow : const [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 28,
                  color: selected
                      ? MasliveTheme.pink
                      : MasliveTheme.textPrimary,
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: selected
                          ? MasliveTheme.pink
                          : MasliveTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
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
}

class _TrackingPill extends StatelessWidget {
  final bool isTracking;
  final VoidCallback onToggle;

  const _TrackingPill({required this.isTracking, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return MasliveCard(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isTracking ? Colors.green : Colors.black).withOpacity(
                0.08,
              ),
            ),
            child: Icon(
              isTracking
                  ? Icons.gps_fixed_rounded
                  : Icons.gps_not_fixed_rounded,
              color: isTracking ? Colors.green : MasliveTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tracking GPS',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  isTracking ? 'Actif (15s)' : 'Inactif',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: MasliveTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: onToggle,
            icon: Icon(isTracking ? Icons.stop_circle : Icons.play_circle),
            label: Text(isTracking ? 'Stop' : 'Start'),
          ),
        ],
      ),
    );
  }
}
