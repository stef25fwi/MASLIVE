import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
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
import '../models/map_preset_model.dart';
import '../pages/map_selector_page.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/geolocation_service.dart';
import '../services/localization_service.dart';
import '../services/language_service.dart';
import '../services/map_presets_service.dart';
import '../services/mapbox_token_service.dart';
import '../l10n/app_localizations.dart' as l10n;
import 'splash_wrapper_page.dart' show mapReadyNotifier;
import '../ui/widgets/mapbox_token_dialog.dart';
import '../ui/widgets/mapbox_web_view_platform.dart';

const _mapboxAccessToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');
const _legacyMapboxToken = String.fromEnvironment('MAPBOX_TOKEN');

enum _MapAction { ville, tracking, visiter, encadrement, food, wc, parking }

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
  final MapPresetsService _presetService = MapPresetsService();

  StreamSubscription<Position>? _positionSub;
  LatLng? _userPos;
  bool _followUser = true;
  bool _requestingGps = false;
  bool _isTracking = false;
  bool _isMapReady = false;
  bool _isGpsReady = false;

  String _runtimeMapboxToken = '';

  // Variables pour la gestion des cartes pré-enregistrées
  MapPresetModel? _selectedPreset;
  List<LayerModel> _currentPresetLayers = [];
  Map<String, bool> _activeLayers = {};
  String? _userGroupId;
  bool _isSuperAdmin = false;

  static const LatLng _fallbackCenter = LatLng(16.241, -61.533);

  String get _effectiveMapboxToken =>
      _mapboxAccessToken.isNotEmpty
        ? _mapboxAccessToken
        : (_legacyMapboxToken.isNotEmpty
          ? _legacyMapboxToken
          : _runtimeMapboxToken);

  bool get _useMapboxTiles => _effectiveMapboxToken.isNotEmpty;

  bool get _useMapboxGlWeb => kIsWeb && _effectiveMapboxToken.trim().isNotEmpty;

  void _markMapReadyIfNeeded() {
    if (_isMapReady) return;

    // Sur Web, Mapbox GL JS ne remonte pas un callback "ready" côté Flutter.
    // On marque la carte comme prête après le premier rendu pour débloquer le splash.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isMapReady) return;
      setState(() {
        _isMapReady = true;
        _checkIfReady();
      });
    });
  }

  @override
  void initState() {
    super.initState();
    debugPrint('🗺️ HomeMapPage: initState called');
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

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseController.repeat();
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _bootstrapLocation();
    _loadUserGroupId();
    _loadRuntimeMapboxToken();
  }

  Future<void> _loadRuntimeMapboxToken() async {
    try {
      final info = await MapboxTokenService.getTokenInfo();
      if (!mounted) return;
      setState(() {
        _runtimeMapboxToken = info.token;
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _configureMapboxToken() async {
    final newToken = await MapboxTokenDialog.show(
      context,
      initialValue: _effectiveMapboxToken,
    );
    if (!mounted || newToken == null) return;
    setState(() {
      _runtimeMapboxToken = newToken;
    });
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

    // Le splashscreen attend mapReadyNotifier.
    // Même sans GPS (permission refusée/service désactivé), on doit pouvoir afficher la carte.
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

          setState(() {
            _userPos = p;
            if (!_isGpsReady) {
              _isGpsReady = true;
              _checkIfReady();
            }
          });

          if (_followUser) {
            final z = _mapController.camera.zoom;
            _mapController.move(p, z < 12.5 ? 13.5 : z);
          }
        });
  }

  void _checkIfReady() {
    if (_isMapReady && _isGpsReady && !mapReadyNotifier.value) {
      debugPrint(
        '✅ HomeMapPage: Carte et GPS prêts, notification du splashscreen',
      );
      // Petit délai pour assurer le rendu complet avant de notifier
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
      case _MapAction.wc:
        return _firestore.getPlacesByTypeStream(PlaceType.wc);
      case _MapAction.parking:
        return _firestore.getPlacesStream();
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
      case PlaceType.wc:
        return 'WC';
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
      case PlaceType.wc:
        return Icons.wc_rounded;
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
      case PlaceType.wc:
        return const Color(0xFF00BFA6);
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
                    color: const Color(
                      0xFF2F6BFF,
                    ).withValues(alpha: opacity.clamp(0, 1)),
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
            color: Colors.white.withValues(alpha: 0.92),
            border: Border.all(color: color.withValues(alpha: 0.45)),
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
                color: Colors.white.withValues(alpha: 0.92),
                border: Border.all(color: color.withValues(alpha: 0.45)),
                boxShadow: MasliveTheme.floatingShadow,
              ),
            ),
            if (heading != null)
              Transform.rotate(
                angle: (heading) * (3.1415926535 / 180),
                child: Icon(Icons.navigation_rounded, size: 22, color: color),
              )
            else
              Icon(Icons.wifi_tethering_rounded, size: 22, color: color),
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
              color: Colors.white.withValues(alpha: 0.94),
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
                          tooltip: l10n.AppLocalizations.of(context)!.close,
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
                            color: _placeColor(
                              place.type,
                            ).withValues(alpha: 0.14),
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
                                      color: _placeColor(
                                        place.type,
                                      ).withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _placeColor(
                                          place.type,
                                        ).withValues(alpha: 0.4),
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
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${place.city} • ${place.rating.toStringAsFixed(1)}★',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: MasliveTheme.textSecondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Coordonnées: ${place.lat.toStringAsFixed(5)}, ${place.lng.toStringAsFixed(5)}',
                                style: Theme.of(context).textTheme.bodySmall
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
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Informations détaillées sur ce lieu. Ajoutez ici un descriptif plus long si disponible.',
                            style: Theme.of(context).textTheme.bodyMedium
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
              color: Colors.white.withValues(alpha: 0.94),
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

  Gradient _headerLanguageFlagGradient() {
    final langService = Get.find<LanguageService>();
    switch (langService.currentLanguageCode) {
      case 'fr':
        // Drapeau France: bleu, blanc, rouge (vertical)
        return const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF0055A4), Color(0xFFFFFFFF), Color(0xFFEF4135)],
          stops: [0.0, 0.5, 1.0],
        );
      case 'en':
        // Drapeau UK simplifié: bleu et rouge
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF012169), Color(0xFFC8102E)],
          stops: [0.4, 0.6],
        );
      case 'es':
        // Drapeau Espagne: rouge, jaune, rouge (horizontal)
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
    // Attendre 1,5 secondes avant de lancer l'animation de fermeture
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && _showActionsMenu) {
        _menuAnimController.reverse();

        // Attendre la fin de l'animation de glissement
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _showActionsMenu) {
            setState(() => _showActionsMenu = false);
          }
        });
      }
    });
  }

  /// Charge le groupId et le statut superadmin de l'utilisateur
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

        // Vérifie si l'utilisateur est superadmin
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
      debugPrint('Erreur lors du chargement du groupId: $e');
    }
  }

  /// Ouvre le sélecteur de cartes pré-enregistrées
  /// Seuls les superadmins peuvent modifier la sélection
  void _openMapSelector() {
    if (_userGroupId == null || _userGroupId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun groupe associé à ton profil.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapSelectorPage(
          groupId: _userGroupId!,
          initialPreset: _selectedPreset,
          isReadOnly: !_isSuperAdmin,
          onMapSelected: (preset, visibleLayers) {
            _applyPreset(preset, visibleLayers: visibleLayers);
          },
        ),
      ),
    );

    _closeNavWithDelay();
  }

  /// Menu rapide de sélection de carte (pour superadmin) avec confirmation
  Future<void> _openMapQuickMenu() async {
    if (!_isSuperAdmin) {
      _openMapSelector();
      return;
    }

    if (_userGroupId == null || _userGroupId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun groupe associé à ton profil.')),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.layers_rounded, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 10),
                  const Text(
                    'Cartes du groupe',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.settings),
                    tooltip: l10n.AppLocalizations.of(
                      context,
                    )!.openAdvancedSelector,
                    onPressed: () {
                      Navigator.pop(context);
                      _openMapSelector();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<MapPresetModel>>(
                stream: _presetService.getGroupPresetsStream(_userGroupId!),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final presets = snapshot.data ?? const <MapPresetModel>[];
                  if (presets.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Aucune carte enregistrée pour ce groupe.'),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: presets.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final preset = presets[index];
                      final isSelected = _selectedPreset?.id == preset.id;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(
                            0xFFB66CFF,
                          ).withValues(alpha: 0.16),
                          child: Icon(
                            Icons.map_rounded,
                            color: const Color(0xFF7C3AED),
                          ),
                        ),
                        title: Text(
                          preset.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          preset.description.isNotEmpty
                              ? preset.description
                              : 'Centre: ${preset.center.latitude.toStringAsFixed(3)}, ${preset.center.longitude.toStringAsFixed(3)}',
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Confirmer le chargement ?'),
                              content: Text(
                                'Charger "${preset.title}" et ses couches associées ?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Annuler'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Confirmer'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            Navigator.pop(context); // ferme le bottom sheet
                            _applyPreset(preset);
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );

    _closeNavWithDelay();
  }

  /// Applique un preset (centre la carte, configure les couches)
  void _applyPreset(MapPresetModel preset, {List<LayerModel>? visibleLayers}) {
    final layers = visibleLayers ?? preset.layers;

    setState(() {
      _selectedPreset = preset;
      _currentPresetLayers = List<LayerModel>.from(preset.layers);
      _activeLayers = {for (final layer in layers) layer.id: layer.visible};
      _mapController.move(preset.center, preset.zoom);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${preset.title} chargée (${layers.length} couche${layers.length != 1 ? 's' : ''} active${layers.length != 1 ? 's' : ''})',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _toggleLayer(String layerId, bool value) {
    setState(() {
      _activeLayers[layerId] = value;
    });

    final activeCount = _activeLayers.values.where((v) => v).length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Couches actives: $activeCount'),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  void _openLanguagePicker() {
    final loc = LocalizationService();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fermer',
      barrierColor: Colors.black.withValues(alpha: 0.3),
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
                color: Colors.white.withValues(alpha: 0.94),
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
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
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
                  item(AppLanguage.en, 'English'),
                  item(AppLanguage.fr, 'Français'),
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
            // Carte en arrière-plan plein écran
            Positioned.fill(
              child: Stack(
                fit: StackFit.expand,
                children: [
                    if (_useMapboxGlWeb)
                      Builder(
                        builder: (context) {
                          _markMapReadyIfNeeded();
                          final center = _userPos ?? _fallbackCenter;
                          return MapboxWebView(
                            accessToken: _effectiveMapboxToken,
                            initialLat: center.latitude,
                            initialLng: center.longitude,
                            initialZoom: _userPos != null ? 15.0 : 12.5,
                            initialPitch: 0.0,
                            initialBearing: 0.0,
                            styleUrl: 'mapbox://styles/mapbox/streets-v12',
                          );
                        },
                      ),
                    if (!_useMapboxGlWeb)
                      FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _userPos ?? _fallbackCenter,
                        initialZoom: _userPos != null ? 14.5 : 12.5,
                        onMapReady: () {
                          debugPrint(
                            '🗺️ HomeMapPage: Carte FlutterMap prête',
                          );
                          setState(() {
                            _isMapReady = true;
                            _checkIfReady();
                          });
                        },
                        onPositionChanged: (pos, hasGesture) {
                          if (hasGesture) _followUser = false;
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.maslive.app',
                        ),

                        RichAttributionWidget(
                          alignment:
                              AttributionAlignment.bottomLeft,
                          attributions: [
                            if (_useMapboxTiles)
                              const TextSourceAttribution(
                                '© Mapbox',
                              ),
                            const TextSourceAttribution(
                              '© OpenStreetMap contributors',
                            ),
                          ],
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
                              final circuits =
                                  snap.data ?? const [];
                              if (circuits.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return PolylineLayer(
                                polylines: circuits
                                    .where(
                                      (c) => c.points.isNotEmpty,
                                    )
                                    .map(
                                      (c) => Polyline(
                                        points: _circuitPoints(c),
                                        color: Colors.black
                                            .withValues(
                                              alpha: 0.65,
                                            ),
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
                                if (lat == null || lng == null) {
                                  continue;
                                }

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
                      ),
                    ],
                  ),
                ),

              if (!_useMapboxTiles)
                Positioned(
                  top:
                      MediaQuery.of(context).padding.top +
                      12,
                  left: 12,
                  right: 12,
                  child: MasliveCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: Colors.black87,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Mapbox inactif: MAPBOX_ACCESS_TOKEN manquant.\nAffichage temporaire OpenStreetMap.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                          ),
                        ),
                        TextButton(
                          onPressed: _configureMapboxToken,
                          child: const Text('Configurer'),
                        ),
                      ],
                    ),
                  ),
                ),

              // Overlay actions - affiche quand burger cliqué
              Positioned.fill(
                child: Visibility(
                  visible: _showActionsMenu,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      setState(() => _showActionsMenu = false);
                      _menuAnimController.reverse();
                    },
                    onHorizontalDragEnd: (details) {
                      if (details.primaryVelocity != null &&
                          details.primaryVelocity! > 0) {
                        setState(() => _showActionsMenu = false);
                        _menuAnimController.reverse();
                      }
                    },
                    child: Align(
                      alignment: Alignment.topRight,
                      child: SlideTransition(
                        position: _menuSlideAnimation,
                        child: Container(
                          margin: const EdgeInsets.only(
                            right: 0,
                            top: 52,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(
                              alpha: 0.65,
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24),
                              bottom: Radius.circular(24),
                            ),
                            boxShadow: const [],
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Bouton Cartes - visible seulement pour les superadmins
                                if (_isSuperAdmin)
                                  _ActionItem(
                                    label: 'Cartes',
                                    icon: Icons.layers_rounded,
                                    selected: _selectedPreset != null,
                                    onTap: _openMapQuickMenu,
                                  ),
                                if (_isSuperAdmin)
                                  const SizedBox(height: 8),
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
                                  selected:
                                      _selected ==
                                      _MapAction.tracking,
                                  onTap: () {
                                    setState(() {
                                      _selected = _MapAction.tracking;
                                    });
                                    _closeNavWithDelay();
                                  },
                                ),
                                const SizedBox(height: 8),
                                _ActionItem(
                                  label: l10n.AppLocalizations.of(
                                    context,
                                  )!.visit,
                                  icon: Icons.map_outlined,
                                  selected:
                                      _selected == _MapAction.visiter,
                                  onTap: () {
                                    setState(() {
                                      _selected = _MapAction.visiter;
                                    });
                                    _closeNavWithDelay();
                                  },
                                ),
                                const SizedBox(height: 8),
                                _ActionItem(
                                  label: l10n.AppLocalizations.of(
                                    context,
                                  )!.food,
                                  icon: Icons.fastfood_rounded,
                                  selected:
                                      _selected == _MapAction.food,
                                  onTap: () {
                                    setState(() {
                                      _selected = _MapAction.food;
                                    });
                                    _closeNavWithDelay();
                                  },
                                ),
                                const SizedBox(height: 8),
                                _ActionItem(
                                  label: l10n.AppLocalizations.of(
                                    context,
                                  )!.assistance,
                                  icon: Icons.shield_outlined,
                                  selected:
                                      _selected ==
                                      _MapAction.encadrement,
                                  onTap: () {
                                    setState(() {
                                      _selected =
                                          _MapAction.encadrement;
                                    });
                                    _closeNavWithDelay();
                                  },
                                ),
                                const SizedBox(height: 8),
                                _ActionItem(
                                  label: l10n.AppLocalizations.of(
                                    context,
                                  )!.parking,
                                  icon: Icons.local_parking_rounded,
                                  customText: 'P',
                                  color: const Color(0xFF0D97EB),
                                  selected:
                                      _selected == _MapAction.parking,
                                  onTap: () {
                                    setState(() {
                                      _selected = _MapAction.parking;
                                    });
                                    _closeNavWithDelay();
                                  },
                                ),
                                const SizedBox(height: 8),
                                _ActionItem(
                                  label: '',
                                  icon: Icons.wc_rounded,
                                  selected:
                                      _selected == _MapAction.wc,
                                  onTap: () {
                                    setState(() {
                                      _selected = _MapAction.wc;
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

              // Panneau rapide des couches actives (si un preset est chargé)
              if (_selectedPreset != null &&
                  _currentPresetLayers.isNotEmpty)
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: _selected == _MapAction.tracking ? 96 : 36,
                  child: _LayerQuickPanel(
                    layers: _currentPresetLayers,
                    activeLayers: _activeLayers,
                    onToggle: _toggleLayer,
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

              // Header déplacé en bas comme bottom bar
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
                            (user?.displayName ?? user?.email ?? 'Profil')
                                .trim();

                        return Tooltip(
                          message: pseudo.isEmpty ? 'Profil' : pseudo,
                          child: InkWell(
                            onTap: () {
                              if (user != null) {
                                _closeNavWithDelay();
                                Future.delayed(
                                  const Duration(milliseconds: 500),
                                  () {
                                    if (mounted) {
                                      Navigator.pushNamed(
                                        context,
                                        '/account-ui',
                                      );
                                    }
                                  },
                                );
                              } else {
                                _closeNavWithDelay();
                                Future.delayed(
                                  const Duration(milliseconds: 500),
                                  () {
                                    if (mounted) {
                                      Navigator.pushNamed(
                                        context,
                                        '/login',
                                      );
                                    }
                                  },
                                );
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
                          onLongPress: _openLanguagePicker,
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: _headerLanguageFlagGradient(),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF9B6BFF,
                                  ).withValues(alpha: 0.22),
                                  blurRadius: 18,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 10),
                                ),
                                BoxShadow(
                                  color: const Color(
                                    0xFFFF7AAE,
                                  ).withValues(alpha: 0.16),
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
                                  color: Colors.black.withValues(
                                    alpha: 0.5,
                                  ),
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
                        _closeNavWithDelay();
                        Future.delayed(
                          const Duration(milliseconds: 500),
                          () {
                            if (mounted) {
                              Navigator.pushNamed(context, '/shop-ui');
                            }
                          },
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    MasliveGradientIconButton(
                      icon: Icons.menu_rounded,
                      tooltip: l10n.AppLocalizations.of(context)!.menu,
                      onTap: () {
                        setState(
                          () => _showActionsMenu = !_showActionsMenu,
                        );
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
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  final String? customText;

  const _ActionItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.color,
    this.customText,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: customText != null
                  ? (color ?? MasliveTheme.pink)
                  : Colors.white.withValues(alpha: 0.92),
              border: Border.all(
                color: selected
                    ? (color ?? MasliveTheme.pink)
                    : MasliveTheme.divider,
                width: selected ? 2.0 : 1.0,
              ),
              boxShadow: selected ? MasliveTheme.cardShadow : const [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (customText != null) ...[
                  Text(
                    customText!,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                  if (label.isNotEmpty) const SizedBox(height: 2),
                  if (label.isNotEmpty)
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 9,
                        height: 1.0,
                      ),
                    ),
                ] else ...[
                  Icon(
                    icon,
                    size: label.isEmpty ? 32 : 28,
                    color: selected
                        ? (color ?? MasliveTheme.pink)
                        : (color ?? MasliveTheme.textPrimary),
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
                          color: selected
                              ? (color ?? MasliveTheme.pink)
                              : (color ?? MasliveTheme.textSecondary),
                          fontWeight: FontWeight.w700,
                          fontSize: 8,
                        ),
                      ),
                    ),
                ],
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
              color: (isTracking ? Colors.green : Colors.black).withValues(
                alpha: 0.08,
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

class _LayerQuickPanel extends StatelessWidget {
  final List<LayerModel> layers;
  final Map<String, bool> activeLayers;
  final void Function(String layerId, bool value) onToggle;

  const _LayerQuickPanel({
    required this.layers,
    required this.activeLayers,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: const [
              Icon(Icons.layers_rounded, size: 18, color: Color(0xFF7C3AED)),
              SizedBox(width: 8),
              Text(
                'Couches actives',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final layer in layers)
                FilterChip(
                  label: Text(
                    layer.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  avatar: Icon(
                    layer.iconName != null ? Icons.checklist_rtl : Icons.layers,
                    size: 18,
                  ),
                  selected: activeLayers[layer.id] ?? layer.visible,
                  onSelected: (value) => onToggle(layer.id, value),
                  selectedColor: const Color(
                    0xFFB66CFF,
                  ).withValues(alpha: 0.18),
                  checkmarkColor: const Color(0xFF7C3AED),
                  side: BorderSide(
                    color: (activeLayers[layer.id] ?? layer.visible)
                        ? const Color(0xFF7C3AED)
                        : Colors.grey.shade300,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
