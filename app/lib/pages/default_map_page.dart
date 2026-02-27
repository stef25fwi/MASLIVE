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
import '../ui/widgets/mapbox_token_dialog.dart';
import '../ui/widgets/marketmap_poi_selector_sheet.dart';
import '../route_style_pro/services/route_style_pro_projection.dart';
import '../ui/map/maslive_map.dart';
import '../ui/map/maslive_map_controller.dart'
    show MapMarker, MapPoint, MasLiveMapController;
import 'splash_wrapper_page.dart' show mapReadyNotifier;
import '../l10n/app_localizations.dart' as l10n;
import '../services/market_map_service.dart';
import '../models/market_poi.dart';
import '../utils/web_viewport_resize.dart';
import 'storex_shop_page.dart';
import 'home_vertical_nav.dart';

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
  MarketMapService? _marketMapService;
  MarketMapPoiSelection _marketPoiSelection =
      const MarketMapPoiSelection.disabled();
  StreamSubscription? _marketPoisSub;
  List<MarketPoi> _marketPois = const <MarketPoi>[];
  List<MapMarker> _marketPoiMarkers = const <MapMarker>[];
  final MasLiveMapController _mapController = MasLiveMapController();

  bool _isMasLiveMapReady = false;
  List<MapPoint> _marketRoutePoints = const <MapPoint>[];
  Map<String, dynamic> _marketRouteStyle = const <String, dynamic>{};
  ({double west, double south, double east, double north})? _marketRouteBounds;

  MarketMapService _getMarketMapService() {
    return _marketMapService ??= MarketMapService();
  }

  List<MapMarker> _composeMarkers() {
    final markers = List<MapMarker>.from(_marketPoiMarkers);
    final lat = _userLat;
    final lng = _userLng;
    if (lat != null && lng != null) {
      markers.add(
        MapMarker(id: 'user-location', lng: lng, lat: lat, size: 1.2),
      );
    }
    return markers;
  }

  Future<void> _syncMarkersToMap() async {
    await _mapController.setMarkers(_composeMarkers());
  }

  Future<void> _configureMapboxToken() async {
    final current = MapboxTokenService.getTokenSync();
    final newToken = await MapboxTokenDialog.show(
      context,
      initialValue: current,
    );
    if (!mounted) return;
    if (newToken == null) return;
    setState(() {
      // Le token est déjà stocké dans SharedPreferences via MapboxTokenDialog.
      // Un rebuild suffit pour que la page re-tente l'initialisation.
    });
  }

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

    final canShowMap = kIsWeb && MapboxTokenService.getTokenSync().isNotEmpty;
    if (canShowMap) {
      _bootstrapLocation();
      _loadUserGroupId();
    }

    // Préchargement des icônes pour éviter les retards d'affichage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(
        const AssetImage('assets/images/icon wc parking.png'),
        context,
      );
    });

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

    if (!selection.enabled ||
        selection.country == null ||
        selection.event == null ||
        selection.circuit == null) {
      if (!mounted) return;
      setState(() {
        _marketPois = const <MarketPoi>[];
        _marketPoiMarkers = const <MapMarker>[];
        _marketRoutePoints = const <MapPoint>[];
        _marketRouteStyle = const <String, dynamic>{};
        _marketRouteBounds = null;
      });

      // Masquer le tracé sans effacer les marqueurs.
      if (_isMasLiveMapReady) {
        unawaited(
          _mapController.setPolyline(points: const <MapPoint>[], show: false),
        );
      }
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

      // Nouveau widget Map -> on attend son onMapReady pour appliquer le tracé.
      _isMasLiveMapReady = false;
      _marketRoutePoints = const <MapPoint>[];
      _marketRouteStyle = const <String, dynamic>{};
      _marketRouteBounds = null;
      _mapRebuildTick++;
    });

    // Charger le tracé publié (marketMap/.../circuits/.../route) + style.
    unawaited(_loadAndCacheMarketRoute(selection));

    _marketPoisSub = _getMarketMapService()
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

  Future<void> _loadAndCacheMarketRoute(MarketMapPoiSelection selection) async {
    if (!selection.enabled ||
        selection.country == null ||
        selection.event == null ||
        selection.circuit == null) {
      return;
    }

    final expectedCircuitId = selection.circuit!.id;

    try {
      final ref = _getMarketMapService().circuitRef(
        countryId: selection.country!.id,
        eventId: selection.event!.id,
        circuitId: expectedCircuitId,
      );
      final snap = await ref.get();
      final data = snap.data();
      if (data == null || !mounted) return;

      // Eviter d'appliquer un résultat obsolète si l'utilisateur a changé de circuit.
      if (!_marketPoiSelection.enabled ||
          _marketPoiSelection.circuit?.id != expectedCircuitId) {
        return;
      }

      final rawRoute =
          data['route'] ??
          data['routePoints'] ??
          data['routeGeometry'] ??
          data['waypoints'];
      final points = _parseRoutePoints(rawRoute);
      final legacyAny = data['style'] ?? data['routeStyle'];
      final legacy = legacyAny is Map
          ? Map<String, dynamic>.from(legacyAny)
          : const <String, dynamic>{};

      final proCfg = tryParseRouteStylePro(data['routeStylePro']);
      final style = proCfg != null
          ? projectProToLegacyStyle(proCfg, base: legacy)
          : legacy;
      final bounds = _boundsFromPoints(points);

      setState(() {
        _marketRoutePoints = points;
        _marketRouteStyle = style;
        _marketRouteBounds = bounds;
      });

      await _applyCachedMarketRouteToMap();
    } catch (e) {
      debugPrint('⚠️ Erreur chargement tracé MarketMap: $e');
    }
  }

  Future<void> _applyCachedMarketRouteToMap() async {
    if (!mounted) return;
    if (!_isMasLiveMapReady) return;
    if (!_marketPoiSelection.enabled || _marketPoiSelection.circuit == null)
      return;

    final pts = _marketRoutePoints;
    if (pts.length < 2) {
      // Fallback: bounds du circuit si disponibles.
      final b = _marketPoiSelection.circuit!.bounds;
      if (b != null) {
        final sw = b['sw'];
        final ne = b['ne'];
        if (sw is Map && ne is Map) {
          final swMap = sw;
          final neMap = ne;
          final west = (swMap['lng'] as num?)?.toDouble();
          final south = (swMap['lat'] as num?)?.toDouble();
          final east = (neMap['lng'] as num?)?.toDouble();
          final north = (neMap['lat'] as num?)?.toDouble();
          if (west != null && south != null && east != null && north != null) {
            await _mapController.fitBounds(
              west: west,
              south: south,
              east: east,
              north: north,
              padding: 56,
              animate: true,
            );
          }
        }
      }
      return;
    }

    final style = _marketRouteStyle;
    final color =
        _parseHexColor(style['color']?.toString()) ?? const Color(0xFF0A84FF);
    final width = (style['width'] as num?)?.toDouble() ?? 6.0;
    final roadLike = (style['roadLike'] as bool?) ?? true;
    final shadow3d = (style['shadow3d'] as bool?) ?? true;
    final showDirection = (style['showDirection'] as bool?) ?? false;
    final animateDirection = (style['animateDirection'] as bool?) ?? false;
    final animationSpeed = (style['animationSpeed'] as num?)?.toDouble() ?? 1.0;

    await _mapController.setPolyline(
      points: pts,
      color: color,
      width: width,
      show: true,
      roadLike: roadLike,
      shadow3d: shadow3d,
      showDirection: showDirection,
      animateDirection: animateDirection,
      animationSpeed: animationSpeed,
    );

    final bounds = _marketRouteBounds ?? _boundsFromPoints(pts);
    if (bounds != null) {
      await _mapController.fitBounds(
        west: bounds.west,
        south: bounds.south,
        east: bounds.east,
        north: bounds.north,
        padding: 72,
        animate: true,
      );
    }
  }

  static List<MapPoint> _parseRoutePoints(dynamic raw) {
    if (raw is! List) return const <MapPoint>[];
    final pts = <MapPoint>[];
    for (final it in raw) {
      final p = _parseRoutePoint(it);
      if (p != null) pts.add(p);
    }
    return pts;
  }

  static MapPoint? _parseRoutePoint(dynamic it) {
    if (it is GeoPoint) return MapPoint(it.longitude, it.latitude);

    if (it is Map) {
      final lat = it['lat'];
      final lng = it['lng'] ?? it['lon'];
      if (lat is num && lng is num) {
        return MapPoint(lng.toDouble(), lat.toDouble());
      }
    }

    if (it is List && it.length >= 2) {
      final lng = it[0];
      final lat = it[1];
      if (lng is num && lat is num) {
        return MapPoint(lng.toDouble(), lat.toDouble());
      }
    }

    return null;
  }

  static ({double west, double south, double east, double north})?
  _boundsFromPoints(List<MapPoint> pts) {
    if (pts.length < 2) return null;
    double west = pts.first.lng;
    double east = pts.first.lng;
    double south = pts.first.lat;
    double north = pts.first.lat;
    for (final p in pts) {
      if (p.lng < west) west = p.lng;
      if (p.lng > east) east = p.lng;
      if (p.lat < south) south = p.lat;
      if (p.lat > north) north = p.lat;
    }
    return (west: west, south: south, east: east, north: north);
  }

  static Color? _parseHexColor(String? hex) {
    if (hex == null) return null;
    var s = hex.trim();
    if (s.isEmpty) return null;
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 6) s = 'FF$s';
    if (s.length != 8) return null;
    final v = int.tryParse(s, radix: 16);
    if (v == null) return null;
    return Color(v);
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

    unawaited(_syncMarkersToMap());
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
  }

  Future<void> _toggleTracking() async {
    if (_isTracking) {
      _geo.stopTracking();
      if (mounted) setState(() => _isTracking = false);
      return;
    }

    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }

    final groupId = _userGroupId;
    if (groupId == null || groupId.isEmpty) {
      return;
    }

    final ok = await _geo.startTracking(
      groupId: groupId,
      intervalSeconds: _trackingIntervalSeconds,
    );
    if (!mounted) return;
    setState(() => _isTracking = ok);
  }

  Future<void> _showMapProjectsSelector() async {
    final selection = await showMarketMapCircuitSelectorSheet(
      context,
      service: _getMarketMapService(),
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
          unawaited(_syncMarkersToMap());
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
        return false;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied && request) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        return false;
      }

      if (permission == LocationPermission.deniedForever) {
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
            unawaited(_syncMarkersToMap());
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
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.map_outlined, size: 56),
                  const SizedBox(height: 12),
                  const Text(
                    'Token Mapbox manquant',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Configure MAPBOX_ACCESS_TOKEN au build (recommandé)\n'
                    'ou renseigne-le via la UI (stockage local).\n\n'
                    'Source actuelle: ${MapboxTokenService.getTokenSourceSync()}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _configureMapboxToken,
                    icon: const Icon(Icons.settings),
                    label: const Text('Configurer le token'),
                  ),
                ],
              ),
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
            final menuTopOffset = topInset + 134;

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
                        child: MasLiveMap(
                          key: ValueKey('default-map-stable_$_mapRebuildTick'),
                          controller: _mapController,
                          initialLat: _projectCenterLat ?? _userLat ?? 16.2410,
                          initialLng: _projectCenterLng ?? _userLng ?? -61.5340,
                          initialZoom:
                              _projectZoom ?? (_userLat != null ? 15.0 : 13.0),
                          initialPitch: 0.0,
                          initialBearing: 0.0,
                          styleUrl: _styleUrl,
                          showUserLocation: false,
                          onTap: (_) {
                            // Pas d'action sur tap pour cette page
                          },
                          onMapReady: (_) {
                            _isMasLiveMapReady = true;
                            _notifyMapReady();
                            unawaited(_syncMarkersToMap());
                            unawaited(_applyCachedMarketRouteToMap());
                          },
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
                          child: HomeVerticalNavMenu(
                            margin: EdgeInsets.only(
                              right: 0,
                              top: menuTopOffset,
                            ),
                            horizontalPadding: 6,
                            verticalPadding: 10,
                            items: [
                              HomeVerticalNavItem(
                                label: 'Carte',
                                icon: Icons.layers_rounded,
                                selected: _marketPoiSelection.enabled,
                                onTap: () {
                                  _showMapProjectsSelector();
                                  _closeNavWithDelay();
                                },
                              ),
                              HomeVerticalNavItem(
                                label: 'Centrer',
                                icon: Icons.my_location_rounded,
                                selected: false,
                                onTap: () {
                                  _recenterOnUser();
                                  _closeNavWithDelay();
                                },
                              ),
                              HomeVerticalNavItem(
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
                              HomeVerticalNavItem(
                                label: l10n.AppLocalizations.of(context)!.visit,
                                icon: Icons.map_outlined,
                                selected: _selectedAction == _MapAction.visiter,
                                onTap: () {
                                  _selectAction(_MapAction.visiter, 'Visiter');
                                  _closeNavWithDelay();
                                },
                              ),
                              HomeVerticalNavItem(
                                label: l10n.AppLocalizations.of(context)!.food,
                                icon: Icons.fastfood_rounded,
                                selected: _selectedAction == _MapAction.food,
                                onTap: () {
                                  _selectAction(_MapAction.food, 'Food');
                                  _closeNavWithDelay();
                                },
                              ),
                              HomeVerticalNavItem(
                                label: l10n.AppLocalizations.of(
                                  context,
                                )!.assistance,
                                icon: Icons.shield_outlined,
                                selected:
                                    _selectedAction == _MapAction.assistance,
                                onTap: () {
                                  _selectAction(
                                    _MapAction.assistance,
                                    'Assistance',
                                  );
                                  _closeNavWithDelay();
                                },
                              ),
                              HomeVerticalNavItem(
                                label: '',
                                iconWidget: Image.asset(
                                  'assets/images/icon wc parking.png',
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.high,
                                ),
                                fullBleed: true,
                                showBorder: false,
                                selected: _selectedAction == _MapAction.parking,
                                onTap: () {
                                  _selectAction(_MapAction.parking, 'Parking');
                                  _closeNavWithDelay();
                                },
                              ),
                              HomeVerticalNavItem(
                                label: '',
                                iconWidget: Obx(() {
                                  final lang = Get.find<LanguageService>();
                                  final flag = lang.getLanguageFlag(
                                    lang.currentLanguageCode,
                                  );
                                  return Container(
                                    color: Colors.white,
                                    alignment: Alignment.center,
                                    child: Text(
                                      flag,
                                      style: const TextStyle(
                                        fontSize: 34,
                                        height: 1,
                                      ),
                                    ),
                                  );
                                }),
                                fullBleed: true,
                                tintOnSelected: false,
                                highlightBackgroundOnSelected: false,
                                showBorder: false,
                                selected: _selectedAction == _MapAction.wc,
                                onTap: () {
                                  _selectAction(_MapAction.wc, 'Langue');
                                  _cycleLanguage();
                                  _closeNavWithDelay();
                                },
                              ),
                            ],
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
                        MasliveGradientIconButton(
                          icon: Icons.shopping_bag_rounded,
                          tooltip: l10n.AppLocalizations.of(context)!.shop,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const StorexShopPage(
                                  shopId: "global",
                                  groupId: "MASLIVE",
                                ),
                              ),
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
            );
          },
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
              color: Colors.white.withValues(alpha: 0.92),
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
