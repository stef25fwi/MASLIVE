import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' hide Position;
import 'package:geolocator/geolocator.dart' as geo show Position;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../ui/theme/maslive_theme.dart';
import '../ui/widgets/gradient_header.dart';
import '../ui/widgets/gradient_icon_button.dart';
import '../ui/widgets/maslive_card.dart';
import '../ui/widgets/maslive_profile_icon.dart';
import '../models/place_model.dart';
import '../models/circuit_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/geolocation_service.dart';
import '../services/localization_service.dart';
import '../services/language_service.dart';
import '../services/mapbox_token_service.dart';
import '../l10n/app_localizations.dart' as l10n;
import 'splash_wrapper_page.dart' show mapReadyNotifier;

const _mapboxAccessToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');
const _legacyMapboxToken = String.fromEnvironment('MAPBOX_TOKEN');

enum _MapAction { ville, tracking, visiter, encadrement, food, wc, parking }

class HomeMapPage3D extends StatefulWidget {
  const HomeMapPage3D({super.key});

  @override
  State<HomeMapPage3D> createState() => _HomeMapPage3DState();
}

class _HomeMapPage3DState extends State<HomeMapPage3D>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  _MapAction _selected = _MapAction.ville;
  bool _showActionsMenu = false;
  late AnimationController _menuAnimController;
  late Animation<Offset> _menuSlideAnimation;

  MapboxMap? _mapboxMap;
  final FirestoreService _firestore = FirestoreService();
  final GeolocationService _geo = GeolocationService.instance;
  final _circuitStream = FirestoreService().getPublishedCircuitsStream();

  StreamSubscription<geo.Position>? _positionSub;
  Position? _userPos; // Mapbox Position (lng, lat)
  bool _followUser = true;
  bool _requestingGps = false;
  bool _isTracking = false;
  bool _isMapReady = false;
  bool _isGpsReady = false;

  String _runtimeMapboxToken = '';
  String? _userGroupId;
  bool _isSuperAdmin = false;

  static const Position _fallbackCenter = Position(-61.533, 16.241);

  // Annotations managers
  PointAnnotationManager? _userAnnotationManager;
  PointAnnotationManager? _placesAnnotationManager;
  PointAnnotationManager? _groupsAnnotationManager;
  PolylineAnnotationManager? _circuitsAnnotationManager;

  String get _effectiveMapboxToken => _mapboxAccessToken.isNotEmpty
      ? _mapboxAccessToken
      : (_legacyMapboxToken.isNotEmpty
            ? _legacyMapboxToken
            : _runtimeMapboxToken);

  bool get _useMapboxTiles => _effectiveMapboxToken.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initMapboxToken();
    _isTracking = _geo.isTracking;
    _menuAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _menuSlideAnimation =
        Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _menuAnimController,
            curve: Curves.easeOut,
            reverseCurve: Curves.easeIn,
          ),
        );

    _bootstrapLocation();
    _loadUserGroupId();
    _loadRuntimeMapboxToken();
  }

  void _initMapboxToken() {
    if (_effectiveMapboxToken.isEmpty) {
      setState(() {
        _runtimeMapboxToken = '';
      });
      return;
    }
    MapboxOptions.setAccessToken(_effectiveMapboxToken);
  }

  Future<void> _loadRuntimeMapboxToken() async {
    try {
      final info = await MapboxTokenService.getTokenInfo();
      if (!mounted) return;
      setState(() {
        _runtimeMapboxToken = info.token;
        if (_runtimeMapboxToken.isNotEmpty) {
          MapboxOptions.setAccessToken(_runtimeMapboxToken);
        }
      });
    } catch (_) {
      // ignore
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSub?.cancel();
    _menuAnimController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _bootstrapLocation();
    }
  }

  Future<void> _bootstrapLocation() async {
    final ok = await _ensureLocationPermission(request: true);

    if (ok) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            timeLimit: Duration(seconds: 8),
          ),
        );
        final p = Position(pos.longitude, pos.latitude);
        if (mounted) {
          setState(() {
            _userPos = p;
          });
          _updateUserMarker();
        }
      } catch (e) {
        debugPrint('⚠️ Erreur GPS: $e');
      }
    }

    if (mounted) {
      setState(() => _isGpsReady = true);
    } else {
      _isGpsReady = true;
    }
    _checkIfReady();

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
              content: Text('Active la localisation (GPS) pour centrer la carte.'),
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
          final p = Position(pos.longitude, pos.latitude);
          if (!mounted) return;

          setState(() {
            _userPos = p;
            if (!_isGpsReady) {
              _isGpsReady = true;
              _checkIfReady();
            }
          });

          _updateUserMarker();

          if (_followUser) {
            _mapboxMap?.flyTo(
              CameraOptions(
                center: Point(coordinates: p),
                zoom: 15.5,
              ),
              MapAnimationOptions(duration: 800, startDelay: 0),
            );
          }
        });
  }

  void _checkIfReady() {
    if (_isMapReady && _isGpsReady && !mapReadyNotifier.value) {
      Future.delayed(const Duration(milliseconds: 300), () {
        mapReadyNotifier.value = true;
      });
    }
  }

  Future<void> _recenterOnUser() async {
    final ok = await _ensureLocationPermission(request: true);
    if (!ok) return;

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        timeLimit: Duration(seconds: 10),
      ),
    );

    final p = Position(pos.longitude, pos.latitude);
    if (!mounted) return;

    setState(() {
      _userPos = p;
      _followUser = true;
    });

    _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: p),
        zoom: 16.0,
        pitch: 45.0,
      ),
      MapAnimationOptions(duration: 1200, startDelay: 0),
    );
  }

  Future<void> _updateUserMarker() async {
    final manager = _userAnnotationManager;
    final pos = _userPos;
    if (manager == null || pos == null) return;

    try {
      await manager.deleteAll();
      
      final options = PointAnnotationOptions(
        geometry: Point(coordinates: pos),
        iconImage: 'user-location-icon',
        iconSize: 1.5,
      );

      await manager.create(options);
    } catch (e) {
      debugPrint('Erreur update user marker: $e');
    }
  }

  Future<void> _add3dBuildings() async {
    final map = _mapboxMap;
    if (map == null) return;

    try {
      final style = map.style;

      final layer = FillExtrusionLayer(
        id: 'maslive-3d-buildings',
        sourceId: 'composite',
      )
        ..sourceLayer = 'building'
        ..minZoom = 14.5
        ..fillExtrusionColor = const Color(0xFFD1D5DB).toARGB32()
        ..fillExtrusionOpacity = 0.7
        ..fillExtrusionHeight = 20.0
        ..fillExtrusionBase = 0.0;

      layer.filter = const [
        '==',
        ['get', 'extrude'],
        'true',
      ];

      await style.addLayer(layer);
    } catch (e) {
      debugPrint('Erreur 3D buildings: $e');
    }
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    // Activer gestes 3D
    await mapboxMap.gestures.updateSettings(
      GesturesSettings(
        pitchEnabled: true,
        rotateEnabled: true,
        scrollEnabled: true,
        pinchToZoomEnabled: true,
      ),
    );

    // Ajouter bâtiments 3D
    await _add3dBuildings();

    // Créer annotation managers
    _userAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager();
    _placesAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager();
    _groupsAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager();
    _circuitsAnnotationManager = await mapboxMap.annotations.createPolylineAnnotationManager();

    setState(() {
      _isMapReady = true;
      _checkIfReady();
    });

    _updateUserMarker();
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

  Future<void> _loadUserGroupId() async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        final groupId = doc.data()?['groupId'] as String?;
        final role = doc.data()?['role'] as String?;
        final isAdmin = doc.data()?['isAdmin'] as bool? ?? false;

        final isSuperAdmin =
            role == 'superAdmin' ||
            role == 'superadmin' ||
            (isAdmin && (role == 'admin' || role == 'Admin'));

        if (groupId != null) {
          setState(() {
            _userGroupId = groupId;
            _isSuperAdmin = isSuperAdmin;
          });
        } else {
          setState(() => _isSuperAdmin = isSuperAdmin);
        }
      }
    } catch (e) {
      debugPrint('Erreur chargement groupId: $e');
    }
  }

  Gradient _headerLanguageFlagGradient() {
    final langService = Get.find<LanguageService>();
    switch (langService.currentLanguageCode) {
      case 'fr':
        return const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF0055A4), Color(0xFFFFFFFF), Color(0xFFEF4135)],
          stops: [0.0, 0.5, 1.0],
        );
      case 'en':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF012169), Color(0xFFC8102E)],
          stops: [0.4, 0.6],
        );
      case 'es':
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFC60B1E), Color(0xFFFFC400), Color(0xFFC60B1E)],
          stops: [0.0, 0.5, 1.0],
        );
      default:
        return const LinearGradient(
          colors: [Color(0xFF0066FF), Color(0xFF0066FF)],
        );
    }
  }

  String _headerLanguageCode() {
    final langService = Get.find<LanguageService>();
    return langService.currentLanguageCode.toUpperCase();
  }

  void _cycleLanguage() {
    final langService = Get.find<LanguageService>();
    final langs = ['fr', 'en', 'es'];
    final current = langService.currentLanguageCode;
    final idx = langs.indexOf(current);
    final next = langs[(idx + 1) % langs.length];
    langService.changeLanguage(next);
    setState(() {});
  }

  void _closeNavWithDelay() {
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && _showActionsMenu) {
        _menuAnimController.reverse();
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _showActionsMenu) {
            setState(() => _showActionsMenu = false);
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_useMapboxTiles) {
      return Scaffold(
        appBar: AppBar(title: const Text('Carte 3D')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 64, color: Colors.orange),
                const SizedBox(height: 24),
                const Text(
                  'Token Mapbox requis',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Configure MAPBOX_ACCESS_TOKEN pour activer la carte 3D.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Retour'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // Carte Mapbox 3D
            Positioned.fill(
              child: MapWidget(
                key: const ValueKey('mapbox-3d-map'),
                styleUri: 'mapbox://styles/mapbox/streets-v12',
                cameraOptions: CameraOptions(
                  center: Point(coordinates: _userPos ?? _fallbackCenter),
                  zoom: _userPos != null ? 15.5 : 13.0,
                  pitch: 45.0, // Vue 3D
                  bearing: 0.0,
                ),
                onMapCreated: _onMapCreated,
              ),
            ),

            // Overlay actions menu
            Positioned.fill(
              child: Visibility(
                visible: _showActionsMenu,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    _menuAnimController.reverse();
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (mounted) {
                        setState(() => _showActionsMenu = false);
                      }
                    });
                  },
                  child: Align(
                    alignment: Alignment.topRight,
                    child: SlideTransition(
                      position: _menuSlideAnimation,
                      child: Container(
                        margin: const EdgeInsets.only(right: 0, top: 52),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.65),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24),
                            bottom: Radius.circular(24),
                          ),
                        ),
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
                                  _closeNavWithDelay();
                                },
                              ),
                              const SizedBox(height: 8),
                              _ActionItem(
                                label: l10n.AppLocalizations.of(
                                  context,
                                )!.tracking,
                                icon: Icons.track_changes_rounded,
                                selected: _selected == _MapAction.tracking,
                                onTap: () {
                                  setState(() {
                                    _selected = _MapAction.tracking;
                                  });
                                  _closeNavWithDelay();
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

            // Tracking pill
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

            // Bottom bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: MasliveGradientHeader(
                height: 60,
                borderRadius: BorderRadius.zero,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                backgroundColor: Colors.white.withValues(alpha: 0.65),
                child: Row(
                  children: [
                    StreamBuilder<User?>(
                      stream: AuthService.instance.authStateChanges,
                      builder: (context, snap) {
                        final user = snap.data;
                        final pseudo =
                            (user?.displayName ?? user?.email ?? 'Profil').trim();

                        return Tooltip(
                          message: pseudo.isEmpty ? 'Profil' : pseudo,
                          child: InkWell(
                            onTap: () {
                              if (user != null) {
                                Navigator.pushNamed(context, '/account-ui');
                              } else {
                                Navigator.pushNamed(context, '/login');
                              }
                            },
                            customBorder: const CircleBorder(),
                            child: MasliveProfileIcon(
                              size: 46,
                              badgeSizeRatio: 0.22,
                              showBadge: user != null,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    const Spacer(),
                    Tooltip(
                      message: l10n.AppLocalizations.of(context)!.language,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _cycleLanguage,
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: _headerLanguageFlagGradient(),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF9B6BFF).withValues(alpha: 0.22),
                                  blurRadius: 18,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 10),
                                ),
                                BoxShadow(
                                  color: const Color(0xFFFF7AAE).withValues(alpha: 0.16),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _headerLanguageCode(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    MasliveGradientIconButton(
                      icon: Icons.shopping_bag_rounded,
                      tooltip: l10n.AppLocalizations.of(context)!.shop,
                      onTap: () {
                        Navigator.pushNamed(context, '/shop-ui');
                      },
                    ),
                    const SizedBox(width: 10),
                    MasliveGradientIconButton(
                      icon: Icons.menu_rounded,
                      tooltip: l10n.AppLocalizations.of(context)!.menu,
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
            ),
          ],
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
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.92),
          border: Border.all(
            color: selected ? MasliveTheme.pink : MasliveTheme.divider,
            width: selected ? 2.0 : 1.0,
          ),
          boxShadow: selected ? MasliveTheme.cardShadow : const [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: label.isEmpty ? 32 : 28,
              color: selected ? MasliveTheme.pink : MasliveTheme.textPrimary,
            ),
            if (label.isNotEmpty) const SizedBox(height: 4),
            if (label.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected ? MasliveTheme.pink : MasliveTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 8,
                  ),
                ),
              ),
          ],
        ),
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
              color: (isTracking ? Colors.green : Colors.black).withValues(
                alpha: 0.08,
              ),
            ),
            child: Icon(
              isTracking ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
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
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
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
