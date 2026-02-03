import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../services/mapbox_token_service.dart';
import '../services/auth_service.dart';
import '../services/geolocation_service.dart';
import '../services/language_service.dart';
import '../ui/theme/maslive_theme.dart';
import '../ui/widgets/gradient_header.dart';
import '../ui/widgets/gradient_icon_button.dart';
import '../ui/widgets/maslive_card.dart';
import '../ui/widgets/maslive_profile_icon.dart';
import '../ui/widgets/mapbox_web_view_platform.dart';
import '../ui/widgets/marketmap_poi_selector_sheet.dart';
import '../ui/map/maslive_map_controller.dart' show MapMarker;
import 'splash_wrapper_page.dart' show mapReadyNotifier;
import '../l10n/app_localizations.dart' as l10n;
import '../services/market_map_service.dart';
import '../models/market_poi.dart';
import '../utils/web_viewport_resize.dart';

// Menu vertical: modes/actions (pour refléter la sélection UI)
// Note: seul le tracking et les projets sont pleinement câblés ici.
enum _MapAction { visiter, food, assistance, parking, wc }

/// Page de carte par défaut avec Mapbox en plein écran
class DefaultMapPage extends StatefulWidget {
  const DefaultMapPage({super.key});

  @override
  State<DefaultMapPage> createState() => _DefaultMapPageState();
}

class _DefaultMapPageState extends State<DefaultMapPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // Constantes
  static const Duration _resizeDebounceDelay = Duration(milliseconds: 80);
  static const Duration _gpsTimeout = Duration(seconds: 8);
  static const int _gpsDistanceFilter = 8;
  static const Duration _menuAnimationDuration = Duration(milliseconds: 300);
  static const Duration _navCloseDelay = Duration(milliseconds: 1500);
  static const int _trackingIntervalSeconds = 15;

  ui.Size? _lastMapSize;
  int _mapRebuildTick = 0;
  Timer? _resizeDebounce;

  // Géolocalisation
  StreamSubscription<Position>? _positionSub;
  double? _userLat;
  double? _userLng;
  bool _requestingGps = false;
  bool _didNotifyMapReady = false;

  // UI
  bool _showActionsMenu = false;
  late AnimationController _menuAnimController;
  late Animation<Offset> _menuSlideAnimation;
  _MapAction? _selectedAction;

  // Tracking
  final GeolocationService _geo = GeolocationService.instance;
  bool _isTracking = false;
  String? _userGroupId;

  // Projets cartographiques
  String _styleUrl = 'mapbox://styles/mapbox/streets-v12';
  double? _projectCenterLat;
  double? _projectCenterLng;
  double? _projectZoom;

  // MarketMap POIs (wiring wizard)
  final MarketMapService _marketMapService = MarketMapService();
  MarketMapPoiSelection _marketPoiSelection = const MarketMapPoiSelection.disabled();
  StreamSubscription? _marketPoisSub;
  List<MarketPoi> _marketPois = const <MarketPoi>[];
  List<MapMarker> _marketPoiMarkers = const <MapMarker>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _isTracking = _geo.isTracking;

    _menuAnimController = AnimationController(
      duration: _menuAnimationDuration,
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

    // Si la carte ne peut pas être affichée (non-web / token manquant),
    // on ne bloque pas le splash indéfiniment.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!kIsWeb || MapboxTokenService.getTokenSync().isEmpty) {
        _notifyMapReady();
      }
    });
  }

  void _notifyMapReady() {
    if (_didNotifyMapReady) return;
    _didNotifyMapReady = true;
    if (!mapReadyNotifier.value) {
      mapReadyNotifier.value = true;
    }
  }

  @override
  void dispose() {
    _marketPoisSub?.cancel();
    _resizeDebounce?.cancel();
    _positionSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _menuAnimController.dispose();
    super.dispose();
  }

  Color _poiColorForType(String? type) {
    switch (type) {
      case 'food':
        return const Color(0xFFFF9800);
      case 'visit':
        return const Color(0xFF9B6BFF);
      case 'wc':
        return const Color(0xFF2196F3);
      case 'parking':
        return const Color(0xFF4CAF50);
      case 'assistance':
        return const Color(0xFFFFC107);
      case 'market':
      default:
        return const Color(0xFFE91E63);
    }
  }

  Future<void> _applyMarketPoiSelection(MarketMapPoiSelection selection) async {
    await _marketPoisSub?.cancel();
    _marketPoisSub = null;

    if (!selection.enabled || selection.country == null || selection.event == null || selection.circuit == null) {
      if (!mounted) return;
      setState(() {
        _marketPois = const <MarketPoi>[];
        _marketPoiMarkers = const <MapMarker>[];
      });
      return;
    }

    final circuit = selection.circuit!;
    final center = circuit.center;

    // Recentrer la carte sur le circuit choisi (via rebuild key)
    setState(() {
      _projectCenterLat = center['lat'];
      _projectCenterLng = center['lng'];
      _projectZoom = circuit.initialZoom;
      if (circuit.styleUrl != null && circuit.styleUrl!.trim().isNotEmpty) {
        _styleUrl = circuit.styleUrl!.trim();
      }
      _mapRebuildTick++;
    });

    _marketPoisSub = _marketMapService
        .watchVisiblePois(
          countryId: selection.country!.id,
          eventId: selection.event!.id,
          circuitId: selection.circuit!.id,
          layerIds: selection.layerIds,
        )
        .listen((pois) {
      if (!mounted) return;
      setState(() => _marketPois = pois);
      _refreshMarketPoiMarkers();
    });
  }

  String? _actionToPoiType(_MapAction? action) {
    switch (action) {
      case _MapAction.visiter:
        return 'visit';
      case _MapAction.food:
        return 'food';
      case _MapAction.assistance:
        return 'assistance';
      case _MapAction.parking:
        return 'parking';
      case _MapAction.wc:
        return 'wc';
      case null:
        return null;
    }
  }

  void _refreshMarketPoiMarkers() {
    if (!mounted) return;
    final filterType = _actionToPoiType(_selectedAction);
    final markers = _marketPois
        .where((p) => p.lat != 0.0 && p.lng != 0.0)
        .where((p) => filterType == null || p.type == filterType)
        .map(
          (p) => MapMarker(
            id: 'marketpoi:${p.id}',
            lng: p.lng,
            lat: p.lat,
            label: p.name,
            color: _poiColorForType(p.type),
            size: 1.0,
          ),
        )
        .toList();

    setState(() {
      _marketPoiMarkers = markers;
    });
  }

  Future<void> _loadUserGroupId() async {
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists || !mounted) return;
      final groupId = doc.data()?['groupId'] as String?;
      setState(() => _userGroupId = groupId);
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
    Future.delayed(_navCloseDelay, () {
      if (mounted && _showActionsMenu) {
        _menuAnimController.reverse();
        Future.delayed(_menuAnimationDuration, () {
          if (mounted && _showActionsMenu) {
            setState(() => _showActionsMenu = false);
          }
        });
      }
    });
  }

  void _recenterOnUser() {
    final lat = _userLat;
    final lng = _userLng;
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Position GPS indisponible pour centrer la carte.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _projectCenterLat = lat;
      _projectCenterLng = lng;
      _projectZoom = 15.5;
      _mapRebuildTick++;
    });
  }

  void _selectAction(_MapAction action, String label) {
    setState(() => _selectedAction = action);
    _refreshMarketPoiMarkers();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mode "$label" sélectionné.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _toggleTracking() async {
    if (_isTracking) {
      _geo.stopTracking();
      if (mounted) setState(() => _isTracking = false);
      return;
    }

    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connecte-toi pour démarrer le tracking.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    final groupId = _userGroupId;
    if (groupId == null || groupId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucun groupId associé à ton profil.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    final ok = await _geo.startTracking(
      groupId: groupId,
      intervalSeconds: _trackingIntervalSeconds,
    );
    if (!mounted) return;
    setState(() => _isTracking = ok);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '✅ Tracking démarré (${_trackingIntervalSeconds}s)'
              : '❌ Permissions GPS refusées',
        ),
      ),
    );
  }

  Future<void> _showMapProjectsSelector() async {
    final selection = await showMarketMapCircuitSelectorSheet(
      context,
      service: _marketMapService,
      initial: _marketPoiSelection.enabled ? _marketPoiSelection : null,
    );
    if (selection == null || !mounted) return;

    setState(() {
      _marketPoiSelection = selection;
    });

    await _applyMarketPoiSelection(selection);
  }


  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (mounted) {
      try {
        setState(() => _mapRebuildTick++);
      } catch (e) {
        debugPrint('⚠️ Erreur didChangeMetrics: $e');
      }
    }
  }

  void _scheduleResize(ui.Size size) {
    if (_lastMapSize == size) return;
    _lastMapSize = size;

    _resizeDebounce?.cancel();

    _resizeDebounce = Timer(_resizeDebounceDelay, () {
      if (!mounted) return;

      // Utiliser triggerWebViewportResize pour re-layout la carte sans tout recréer
      if (kIsWeb) {
        triggerWebViewportResize();
      }

      try {
        // Optionnel : ne pas incrémenter le tick si on veut éviter le reload WebGL
        // setState(() => _mapRebuildTick++);
        // On log juste la nouvelle taille
        debugPrint(
          '✅ Default map resize (soft): ${size.width.toInt()}x${size.height.toInt()} ',
        );
      } catch (e) {
        debugPrint('⚠️ Erreur _scheduleResize: $e');
      }
    });
  }

  /// Initialise la géolocalisation au démarrage
  Future<void> _bootstrapLocation() async {
    final ok = await _ensureLocationPermission(request: true);

    if (ok) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.best,
            timeLimit: _gpsTimeout,
          ),
        );
        if (mounted) {
          setState(() {
            _userLat = pos.latitude;
            _userLng = pos.longitude;
          });
        }
      } on TimeoutException catch (e) {
        debugPrint('⏱️ Timeout GPS: $e');
      } catch (e) {
        debugPrint('⚠️ Erreur GPS: $e');
      }
    }

    if (ok) {
      _startUserPositionStream();
    }
  }

  /// Vérifie et demande les permissions de géolocalisation
  Future<bool> _ensureLocationPermission({required bool request}) async {
    if (_requestingGps) return false;
    _requestingGps = true;

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Active la localisation (GPS).'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return false;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied && request) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permission GPS refusée.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return false;
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permission GPS refusée définitivement.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('⚠️ Erreur vérification permissions GPS: $e');
      return false;
    } finally {
      _requestingGps = false;
    }
  }

  /// Démarre le stream de position en temps réel
  void _startUserPositionStream() {
    _positionSub?.cancel();

    const settings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: _gpsDistanceFilter,
    );

    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen(
          (pos) {
            if (!mounted) return;
            setState(() {
              _userLat = pos.latitude;
              _userLng = pos.longitude;
            });
          },
          onError: (error) {
            debugPrint('⚠️ Erreur stream position: $error');
          },
          cancelOnError: false,
        );
  }

  @override
  Widget build(BuildContext context) {
    final token = MapboxTokenService.getTokenSync();

    if (!kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('Carte par défaut')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Cette page est uniquement disponible sur Web.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (token.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Carte par défaut')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Token Mapbox manquant.\nConfigure MAPBOX_ACCESS_TOKEN.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final size = ui.Size(constraints.maxWidth, constraints.maxHeight);
            final topInset = MediaQuery.of(context).padding.top;
            final menuTopOffset = topInset + 104;

            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scheduleResize(size);
            });

            return Stack(
              children: [
                // Bandeau blanc derrière la status bar
                if (topInset > 0)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: topInset,
                    child: const ColoredBox(color: Colors.white),
                  ),

                // Carte Mapbox en plein écran
                Positioned.fill(
                  child: RepaintBoundary(
                    child: SizedBox(
                      width: size.width,
                      height: size.height,
                      child: Container(
                        color: Colors.transparent,
                        child: MapboxWebView(
                          // Clé plus stable, indépendante de la taille précise (Mapbox gère le resize interne)
                          // On garde _mapRebuildTick seulement si on VEUT forcer un reload
                          key: ValueKey(
                            'default-map-stable_$_mapRebuildTick',
                          ),
                          accessToken: token,
                          initialLat: _projectCenterLat ?? _userLat ?? 16.2410,
                          initialLng: _projectCenterLng ?? _userLng ?? -61.5340,
                          initialZoom:
                              _projectZoom ?? (_userLat != null ? 15.0 : 13.0),
                          initialPitch: 0.0,
                          initialBearing: 0.0,
                          styleUrl: _styleUrl,
                          userLat: _userLat,
                          userLng: _userLng,
                          showUserLocation:
                              true, // Afficher le marqueur de position
                          markers: _marketPoiMarkers,
                          onMapReady: _notifyMapReady,
                        ),
                      ),
                    ),
                  ),
                ),

                // Overlay actions menu (vertical) + backdrop
                if (_showActionsMenu)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        _menuAnimController.reverse();
                        Future.delayed(_menuAnimationDuration, () {
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
                            margin: EdgeInsets.only(
                              right: 0,
                              top: menuTopOffset,
                            ),
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
                                    label: 'Carte',
                                    icon: Icons.layers_rounded,
                                    selected: _marketPoiSelection.enabled,
                                    onTap: () {
                                      // Reprend la fonctionnalité de l'ancienne icône "Projets"
                                      _showMapProjectsSelector();
                                      _closeNavWithDelay();
                                    },
                                  ),

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
                                    selected: _isTracking,
                                    onTap: () {
                                      _toggleTracking();
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
                                        _selectedAction == _MapAction.visiter,
                                    onTap: () {
                                      _selectAction(
                                        _MapAction.visiter,
                                        'Visiter',
                                      );
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
                                        _selectedAction == _MapAction.food,
                                    onTap: () {
                                      _selectAction(_MapAction.food, 'Food');
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
                                        _selectedAction ==
                                        _MapAction.assistance,
                                    onTap: () {
                                      _selectAction(
                                        _MapAction.assistance,
                                        'Assistance',
                                      );
                                      _closeNavWithDelay();
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  _ActionItem(
                                    label: l10n.AppLocalizations.of(
                                      context,
                                    )!.parking,
                                    icon: Icons.local_parking_rounded,
                                    selected:
                                        _selectedAction == _MapAction.parking,
                                    onTap: () {
                                      _selectAction(
                                        _MapAction.parking,
                                        'Parking',
                                      );
                                      _closeNavWithDelay();
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  _ActionItem(
                                    label: '',
                                    icon: Icons.wc_rounded,
                                    selected: _selectedAction == _MapAction.wc,
                                    onTap: () {
                                      _selectAction(_MapAction.wc, 'WC');
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

                // Tracking pill
                if (_isTracking)
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
                    backgroundColor: Colors.transparent,
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
                            Navigator.pushNamed(context, '/shop-ui');
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
            );
          },
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
                    color: selected
                        ? MasliveTheme.pink
                        : MasliveTheme.textSecondary,
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
                  isTracking
                      ? 'Actif (${_DefaultMapPageState._trackingIntervalSeconds}s)'
                      : 'Inactif',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: MasliveTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: onToggle,
            style: ElevatedButton.styleFrom(
              backgroundColor: isTracking
                  ? MasliveTheme.pink
                  : const Color(0xFF9B6BFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(isTracking ? 'Stop' : 'Start'),
          ),
        ],
      ),
    );
  }
}
