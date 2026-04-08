import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'
    hide LocationSettings;
import 'package:geolocator/geolocator.dart' hide Position;
import 'package:geolocator/geolocator.dart'
    as geo
    show Position, LocationSettings;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../ui/theme/maslive_theme.dart';
import '../ui/widgets/floating_glass_dock.dart';
import '../ui/widgets/gradient_icon_button.dart';
import '../ui/widgets/maslive_card.dart';
import '../ui/widgets/maslive_profile_icon.dart';
import '../ui/widgets/polaroid_poi_sheet.dart';
import '../services/auth_service.dart';
import '../services/geolocation_service.dart';
import '../services/language_service.dart';
import '../services/mapbox_token_service.dart';
import '../services/market_map_service.dart';
import '../services/poi_popup_service.dart';
import '../models/market_poi.dart';
import '../ui/widgets/marketmap_poi_selector_sheet.dart';
import '../services/poi_analytics_service.dart';
import '../utils/poi_normalizer.dart';
import '../utils/mapbox_style_url.dart';
import '../utils/startup_trace.dart';
import '../route_style_pro/services/route_style_pro_projection.dart';
import '../route_style_pro/models/route_style_config.dart';
import '../l10n/app_localizations.dart' as l10n;
import 'storex_shop_page.dart';
import 'splash_wrapper_page.dart' show mapReadyNotifier;

// Menu vertical: modes/actions (filtrage POIs)
enum _MapAction { visiter, food, assistance, parking, wc }

class HomeMapPage3D extends StatefulWidget {
  const HomeMapPage3D({super.key});

  @override
  State<HomeMapPage3D> createState() => _HomeMapPage3DState();
}

class _HomeMapPage3DState extends State<HomeMapPage3D>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ========== CONSTANTES ==========
  static const Duration _resizeDebounceDelay = Duration(milliseconds: 80);
  static const Duration _menuAnimationDuration = Duration(milliseconds: 300);
  static const Duration _mapReadyDelay = Duration(milliseconds: 80);
  static const Duration _navCloseDelay = Duration(milliseconds: 2500);
  static const Duration _deferredHomeInitDelay = Duration(milliseconds: 850);
  static const int _trackingIntervalSeconds = 15;
  static const int _gpsDistanceFilter = 8;
  static const Duration _gpsTimeout = Duration(seconds: 8);
  static const double _userMarkerIconSize = 1.5;
  static const Duration _cameraAnimationDuration = Duration(milliseconds: 800);
  static const double _defaultZoom = 13.0;
  static const double _userZoom = 15.5;
  static const double _defaultPitch = 45.0;
  static const double _minZoom3dBuildings = 14.5;
  // Offset vertical du menu d'actions pour ne pas chevaucher la boussole
  static const double _actionsMenuTopOffset = 162;

  // Anti-doublon: évite empilement de dialogs sur taps rapides.
  static const Duration _poiPopupDebounce = Duration(milliseconds: 650);
  bool _isPoiPopupShowing = false;
  DateTime? _lastPoiPopupAt;
  String? _lastPoiPopupId;

  // ========== ÉTAT UI ==========
  bool _showActionsMenu = false;
  bool _isResolvingMapboxToken = MapboxTokenService.getTokenSync().isEmpty;
  bool _didScheduleReadySignal = false;
  bool _didStartDeferredHomeInit = false;
  String _currentLanguageFlag = '';
  late AnimationController _menuAnimController;
  late Animation<Offset> _menuSlideAnimation;
  late Animation<double> _bottomBarIconsTranslateAnimation;
  _MapAction? _selectedAction;

  // ========== CARTE & GÉOLOCALISATION ==========
  MapboxMap? _mapboxMap;
  final GeolocationService _geo = GeolocationService.instance;

  // Fix universel rebuild + resize natif (iOS/Android/Web)
  int _mapTick = 0;
  bool _mapCanBeCreated = false;
  ui.Size? _lastSize;
  Timer? _debounce;

  StreamSubscription<geo.Position>? _positionSub;
  Position? _userPos; // Mapbox Position (lng, lat)
  final bool _followUser = true;
  bool _requestingGps = false;
  bool _isTracking = false;
  bool _isMapReady = false;
  bool _isGpsReady = false;

  String _runtimeMapboxToken = '';
  // ignore: unused_field
  String? _userGroupId;
  // ignore: unused_field
  bool _isSuperAdmin = false;

  static final Position _fallbackCenter = Position(-61.533, 16.241);

  // Annotations managers
  PointAnnotationManager? _userAnnotationManager;
  // ignore: unused_field
  PointAnnotationManager? _groupsAnnotationManager;
  // ignore: unused_field
  PolylineAnnotationManager? _circuitsAnnotationManager;

  // MarketMap POIs (wiring wizard)
  MarketMapService? _marketMapService;
  MarketMapPoiSelection _marketPoiSelection =
      const MarketMapPoiSelection.disabled();
  StreamSubscription? _marketPoisSub;
  List<MarketPoi> _marketPois = const <MarketPoi>[];

  // === MarketMap POIs (GeoJSON Layers) ===
  static const String _mmPoiSourceId = 'mm_pois_src';
  static const String _mmPoiLayerPrefix = 'mm_pois_layer__'; // + type
  static const String _mmPoiLiveBadgeLayerId = 'mm_pois_live_badge';
  GeoJsonSource? _mmPoiSource;
  final Set<String> _mmPoiLayerIds = <String>{};

  // === MarketMap Route (Style Pro via GeoJSON Layers) ===
  static const String _mmRouteSourceId = 'mm_route_src';
  static const String _mmRouteSegmentsSourceId = 'mm_route_segments_src';
  static const String _mmRouteLayerShadowId = 'mm_route_shadow';
  static const String _mmRouteLayerGlowId = 'mm_route_glow';
  static const String _mmRouteLayerSideLId = 'mm_route_side_l';
  static const String _mmRouteLayerSideRId = 'mm_route_side_r';
  static const String _mmRouteLayerCasingId = 'mm_route_casing';
  static const String _mmRouteLayerMainId = 'mm_route_main';

  bool _mmRouteRuntimeReady = false;
  Timer? _routeAnimTimer;
  int _routeAnimTick = 0;
  List<Position> _lastMarketRoutePts = const <Position>[];
  RouteStyleConfig? _lastMarketRouteProCfg;

  // Types supportés pour filtrage rapide par action
  static const List<String> _mmTypes = <String>[
    'visit',
    'food',
    'assistance',
    'parking',
    'wc',
    'market', // fallback
  ];

  String get _effectiveMapboxToken => _runtimeMapboxToken.isNotEmpty
      ? _runtimeMapboxToken
      : MapboxTokenService.getTokenSync();

  bool get _useMapboxTiles => _effectiveMapboxToken.isNotEmpty;

  MarketMapService get _marketMapServiceOrCreate =>
      _marketMapService ??= MarketMapService();

  @override
  void initState() {
    super.initState();
    StartupTrace.log('MAPBOX_NATIVE', 'HomeMapPage3D initState');

    // Observer pour détecter les changements de lifecycle et de métriques (resize, rotation)
    WidgetsBinding.instance.addObserver(this);

    // Initialisation du token Mapbox (peut être vide au démarrage)
    _initMapboxToken();

    // Synchroniser l'état de tracking avec le service
    _isTracking = _geo.isTracking;

    // Initialiser le drapeau de langue dès initState (pas de délai)
    _updateLanguageFlag();

    // Retente après 1er frame (service/langue et rendu emoji peuvent arriver après).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final before = _currentLanguageFlag;
      _updateLanguageFlag();
      if (!mounted) return;
      if (_currentLanguageFlag != before) {
        setState(() {});
      }
    });

    // Configuration de l'animation du menu latéral
    _menuAnimController = AnimationController(
      duration: _menuAnimationDuration,
      vsync: this,
    )..value = 0.0;
    final CurvedAnimation menuMotion = CurvedAnimation(
      parent: _menuAnimController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _menuSlideAnimation = Tween<Offset>(
      begin: const Offset(1.2, 0.0),
      end: Offset.zero,
    ).animate(menuMotion);
    _bottomBarIconsTranslateAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(menuMotion);

    // Chargement asynchrone des données essentielles
    _loadRuntimeMapboxToken(); // Token Mapbox dynamique
    // Préchargement des icônes pour éviter les retards d'affichage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(
        const AssetImage('assets/images/icon wc parking.png'),
        context,
      );
    });

    // Sécurité : si la carte a un token mais que le SDK Mapbox ne se charge
    // jamais (réseau coupé, token révoqué, etc.), on débloque le splash
    // après 6 secondes pour ne pas bloquer l'utilisateur.
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted && !_isMapReady && !mapReadyNotifier.value) {
        debugPrint(
          '⚠️ HomeMapPage3D: timeout 6s – carte non prête, déblocage splash',
        );
        _notifyMapReadyFallback();
      }
    });
  }

  void _initMapboxToken() {
    final info = MapboxTokenService.getTokenInfoSync(
      override: _runtimeMapboxToken,
    );
    final token = info.token;
    if (token.isEmpty) {
      StartupTrace.log(
        'MAPBOX_NATIVE',
        '_initMapboxToken empty source=${info.source} valid=${info.isValidFormat} code=${info.errorCode}',
      );
      debugPrint(
        '⚠️ HomeMapPage3D: _initMapboxToken → token vide (source sync)',
      );
      return;
    }
    StartupTrace.log(
      'MAPBOX_NATIVE',
      '_initMapboxToken source=${info.source} len=${token.length} pk=${info.isPublicPkToken}',
    );
    debugPrint(
      '✅ HomeMapPage3D: _initMapboxToken → token trouvé (len=${token.length})',
    );
    MapboxOptions.setAccessToken(token);
  }

  Future<void> _loadRuntimeMapboxToken() async {
    try {
      StartupTrace.log('MAPBOX_NATIVE', '_loadRuntimeMapboxToken start');
      final info = await MapboxTokenService.getTokenInfo();
      StartupTrace.log(
        'MAPBOX_NATIVE',
        '_loadRuntimeMapboxToken source=${info.source} len=${info.token.length} valid=${info.isValidFormat} pk=${info.isPublicPkToken} code=${info.errorCode}',
      );
      if (!mounted) return;
      setState(() {
        _isResolvingMapboxToken = false;
        _runtimeMapboxToken = info.token;
        if (_runtimeMapboxToken.isNotEmpty) {
          MapboxOptions.setAccessToken(_runtimeMapboxToken);
        }
      });
      // Si après le chargement async le token est toujours vide,
      // on débloque le splash pour éviter un loader infini.
      if (_runtimeMapboxToken.isEmpty && !mapReadyNotifier.value) {
        debugPrint(
          '⚠️ HomeMapPage3D: token Mapbox vide après chargement async, déblocage splash',
        );
        _notifyMapReadyFallback();
      }
    } catch (e) {
      StartupTrace.log('MAPBOX_NATIVE', '_loadRuntimeMapboxToken failed: $e');
      debugPrint('❌ HomeMapPage3D: erreur chargement token Mapbox: $e');
      if (mounted) {
        setState(() {
          _isResolvingMapboxToken = false;
        });
      }
      // En cas d'erreur, on débloque le splash.
      if (mounted && !mapReadyNotifier.value) {
        _notifyMapReadyFallback();
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _positionSub?.cancel();
    _marketPoisSub?.cancel();
    _routeAnimTimer?.cancel();
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

  bool _boolLike(dynamic value, {required bool fallback}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final raw = (value ?? '').toString().trim().toLowerCase();
    if (raw.isEmpty) return fallback;
    if (raw == 'true' || raw == '1' || raw == 'yes' || raw == 'on') return true;
    if (raw == 'false' || raw == '0' || raw == 'no' || raw == 'off') {
      return false;
    }
    return fallback;
  }

  String _normalizeLiveTableStateForBadge(dynamic raw) {
    final value = (raw ?? '').toString().trim().toLowerCase();
    switch (value) {
      case 'available':
      case 'open':
      case 'free':
      case 'green':
        return 'available';
      case 'limited':
      case 'few':
      case 'orange':
        return 'limited';
      case 'full':
      case 'busy':
      case 'closed':
      case 'complete':
      case 'red':
        return 'full';
      default:
        return '';
    }
  }

  String _resolveLiveTableBadgeState({
    required String poiType,
    required Map<String, dynamic> metadata,
    required dynamic rootPublished,
    required dynamic rootPremiumFeatures,
    required dynamic rootLiveTableSummary,
  }) {
    if (poiType != 'food') return '';

    final published = _boolLike(
      rootPublished ?? metadata['isPublished'] ?? metadata['published'],
      fallback: true,
    );
    if (!published) return '';

    final premiumFeatures = rootPremiumFeatures is Map
        ? Map<String, dynamic>.from(rootPremiumFeatures)
        : (metadata['premiumFeatures'] is Map
              ? Map<String, dynamic>.from(metadata['premiumFeatures'])
              : const <String, dynamic>{});

    final summary = rootLiveTableSummary is Map
        ? Map<String, dynamic>.from(rootLiveTableSummary)
        : (metadata['liveTableSummary'] is Map
              ? Map<String, dynamic>.from(metadata['liveTableSummary'])
              : const <String, dynamic>{});

    final liveTable = metadata['liveTable'] is Map
        ? Map<String, dynamic>.from(metadata['liveTable'])
        : const <String, dynamic>{};

    final premiumEnabled = _boolLike(
      premiumFeatures['liveTableStatusEnabled'] ??
          premiumFeatures['enabled'] ??
          liveTable['enabled'],
      fallback: false,
    );
    if (!premiumEnabled) return '';

    final state = _normalizeLiveTableStateForBadge(
      summary['state'] ?? liveTable['status'],
    );
    return state;
  }

  Future<void> _openMarketPoiSelector() async {
    final selection = await showMarketMapPoiSelectorSheet(
      context,
      service: _marketMapServiceOrCreate,
      initial: _marketPoiSelection,
      disableKeyboardInput: true,
    );
    if (selection == null) return;
    if (!mounted) return;

    setState(() {
      _marketPoiSelection = selection;
    });

    await _applyMarketPoiSelection(selection);
  }

  Future<void> _applyMarketPoiSelection(
    MarketMapPoiSelection selection, {
    bool resetPoiFilter = false,
  }) async {
    await _marketPoisSub?.cancel();
    _marketPoisSub = null;

    // Quand l'utilisateur change de carte/circuit, on ne doit pas afficher de POIs
    // tant qu'il n'a pas explicitement choisi un type via le menu vertical.
    if (resetPoiFilter && mounted) {
      setState(() => _selectedAction = null);
    }

    if (!selection.enabled ||
        selection.country == null ||
        selection.event == null ||
        selection.circuit == null) {
      if (!mounted) return;
      setState(() {
        _marketPois = const <MarketPoi>[];
      });
      await _renderMarketPoiMarkers();
      await _clearMarketCircuitRoute();
      return;
    }

    final circuit = selection.circuit!;
    final styleUrl = normalizeMapboxStyleUrl(circuit.styleUrl);
    if (styleUrl.isNotEmpty && _mapboxMap != null) {
      try {
        await _mapboxMap!.style.setStyleURI(styleUrl);
      } catch (e) {
        debugPrint('⚠️ Erreur chargement style circuit: $e');
      }
    }
    // IMPORTANT: un changement de style supprime les sources/layers runtime
    await _ensureMarketPoiGeoJsonRuntime(forceRebuild: true);

    // Tracé (route) + fitBounds sur le parcours.
    final didFit = await _renderMarketCircuitRoute(selection);
    if (!didFit) {
      final center = circuit.center;
      final lng = (center['lng'] ?? _fallbackCenter.lng).toDouble();
      final lat = (center['lat'] ?? _fallbackCenter.lat).toDouble();
      await _moveCameraTo(lng: lng, lat: lat, zoom: circuit.initialZoom);
    }

    _marketPoisSub = _marketMapServiceOrCreate
        .watchVisiblePois(
          countryId: selection.country!.id,
          eventId: selection.event!.id,
          circuitId: selection.circuit!.id,
          layerIds: selection.layerIds,
        )
        .listen((pois) async {
          if (!mounted) return;
          setState(() => _marketPois = pois);
          await _renderMarketPoiMarkers(); // GeoJSON update + visibility
        });
  }

  Future<void> _ensureCircuitRouteManager() async {
    final map = _mapboxMap;
    if (map == null) return;
    if (_circuitsAnnotationManager != null) return;
    try {
      _circuitsAnnotationManager = await map.annotations
          .createPolylineAnnotationManager();
    } catch (e) {
      debugPrint('⚠️ Erreur createPolylineAnnotationManager: $e');
    }
  }

  Future<void> _clearMarketCircuitRoute() async {
    _routeAnimTimer?.cancel();
    _routeAnimTimer = null;
    _routeAnimTick = 0;
    _lastMarketRoutePts = const <Position>[];
    _lastMarketRouteProCfg = null;

    // Clear Style Pro route layers (si présents)
    final map = _mapboxMap;
    if (map != null) {
      final empty = _emptyRouteFeatureCollection();
      try {
        await map.style.setStyleSourceProperty(_mmRouteSourceId, 'data', empty);
      } catch (_) {
        // ignore
      }
      try {
        await map.style.setStyleSourceProperty(
          _mmRouteSegmentsSourceId,
          'data',
          empty,
        );
      } catch (_) {
        // ignore
      }
    }

    try {
      await _circuitsAnnotationManager?.deleteAll();
    } catch (_) {
      // ignore
    }
  }

  static String _emptyRouteFeatureCollection() =>
      jsonEncode({'type': 'FeatureCollection', 'features': []});

  static String _routeFeatureCollection(List<Map<String, dynamic>> features) =>
      jsonEncode({'type': 'FeatureCollection', 'features': features});

  static String _toHexRgba(Color c, {required double opacity}) {
    // Compatible Mapbox style-spec (couleur CSS rgba)
    final a = opacity.clamp(0.0, 1.0);
    final r = ((c.r * 255).round()).clamp(0, 255);
    final g = ((c.g * 255).round()).clamp(0, 255);
    final b = ((c.b * 255).round()).clamp(0, 255);
    return 'rgba($r,$g,$b,${a.toStringAsFixed(3)})';
  }

  static String _toHexRgb(Color c) {
    final v = c.toARGB32().toRadixString(16).padLeft(8, '0');
    return '#${v.substring(2, 8)}';
  }

  static Color _hsvToColor(double h, double s, double v) {
    final hh = (h % 360) / 60.0;
    final chroma = v * s;
    final x = chroma * (1 - ((hh % 2) - 1).abs());
    final m = v - chroma;

    double r1 = 0, g1 = 0, b1 = 0;
    if (hh >= 0 && hh < 1) {
      r1 = chroma;
      g1 = x;
    } else if (hh < 2) {
      r1 = x;
      g1 = chroma;
    } else if (hh < 3) {
      g1 = chroma;
      b1 = x;
    } else if (hh < 4) {
      g1 = x;
      b1 = chroma;
    } else if (hh < 5) {
      r1 = x;
      b1 = chroma;
    } else {
      r1 = chroma;
      b1 = x;
    }

    final r = ((r1 + m) * 255).round().clamp(0, 255);
    final g = ((g1 + m) * 255).round().clamp(0, 255);
    final b = ((b1 + m) * 255).round().clamp(0, 255);
    return Color.fromARGB(255, r, g, b);
  }

  static Color _segmentColor(RouteStyleConfig cfg, int index, int animTick) {
    if (cfg.trafficDemoEnabled) {
      const traffic = [
        Color(0xFF22C55E), // vert
        Color(0xFFF59E0B), // orange
        Color(0xFFEF4444), // rouge
      ];
      return traffic[index % traffic.length];
    }

    if (cfg.rainbowEnabled) {
      final shift = (animTick % 360);
      final dir = cfg.rainbowReverse ? -1 : 1;
      final hue = (shift + dir * index * 14) % 360;
      return _hsvToColor(hue.toDouble(), cfg.rainbowSaturation, 1.0);
    }

    return cfg.mainColor;
  }

  static Color _segmentCasingColor(
    RouteStyleConfig cfg,
    int index,
    int animTick,
  ) {
    if (!cfg.effectiveCasingRainbowEnabled) return cfg.casingColor;
    final shift = (animTick % 360);
    final dir = cfg.rainbowReverse ? -1 : 1;
    final hue = (shift + dir * index * 14) % 360;
    return _hsvToColor(hue.toDouble(), cfg.rainbowSaturation, 1.0);
  }

  static String _buildSegmentsFeatureCollection(
    List<Position> pts,
    RouteStyleConfig cfg, {
    required int animTick,
  }) {
    if (pts.length < 2) return _emptyRouteFeatureCollection();

    final width = cfg.effectiveRenderedMainWidth;

    // Limite segments (perf)
    const maxSeg = 60;
    final step = max(1, ((pts.length - 1) / maxSeg).ceil());

    final features = <Map<String, dynamic>>[];
    int segIndex = 0;

    for (int i = 0; i < pts.length - 1; i += step) {
      final a = pts[i];
      final b = pts[min(i + step, pts.length - 1)];

      final t = segIndex / max(1, ((pts.length - 1) / step).floor());

      final baseOpacity = cfg.opacity;
      final opacity = cfg.vanishingEnabled
          ? (t <= cfg.vanishingProgress ? 0.25 : baseOpacity)
          : baseOpacity;

      final color = _segmentColor(cfg, segIndex, animTick);
      final casingColor = _segmentCasingColor(cfg, segIndex, animTick);

      features.add({
        'type': 'Feature',
        'properties': {
          'color': _toHexRgba(color, opacity: opacity),
          'casingColor': _toHexRgb(casingColor),
          'width': width,
          'opacity': opacity,
        },
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            [a.lng.toDouble(), a.lat.toDouble()],
            [b.lng.toDouble(), b.lat.toDouble()],
          ],
        },
      });
      segIndex++;
    }

    return _routeFeatureCollection(features);
  }

  static String _buildSolidFeatureCollection(
    List<Position> pts,
    RouteStyleConfig cfg,
  ) {
    if (pts.length < 2) return _emptyRouteFeatureCollection();
    final width = cfg.effectiveRenderedMainWidth;
    return _routeFeatureCollection([
      {
        'type': 'Feature',
        'properties': {
          'color': _toHexRgba(cfg.mainColor, opacity: cfg.opacity),
          'casingColor': _toHexRgb(cfg.casingColor),
          'width': width,
          'opacity': cfg.opacity,
        },
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            for (final p in pts) [p.lng.toDouble(), p.lat.toDouble()],
          ],
        },
      },
    ]);
  }

  void _syncMarketRouteAnimTimer(RouteStyleConfig cfg) {
    final needsAnim =
        cfg.pulseEnabled ||
        cfg.rainbowEnabled ||
        cfg.effectiveCasingRainbowEnabled;
    if (!needsAnim) {
      _routeAnimTimer?.cancel();
      _routeAnimTimer = null;
      return;
    }

    final periodMs =
        ((cfg.rainbowEnabled || cfg.effectiveCasingRainbowEnabled)
                ? (110 - (cfg.rainbowSpeed * 0.8)).clamp(25, 110)
                : (160 - (cfg.pulseSpeed * 1.0)).clamp(40, 160))
            .round();

    _routeAnimTimer?.cancel();
    _routeAnimTimer = Timer.periodic(Duration(milliseconds: periodMs), (_) {
      _routeAnimTick++;
      _renderMarketRoutePro(
        pts: _lastMarketRoutePts,
        cfg: _lastMarketRouteProCfg,
        fitCamera: false,
        animTick: _routeAnimTick,
      );
    });
  }

  Future<void> _ensureMarketRouteGeoJsonRuntime({
    bool forceRebuild = false,
  }) async {
    final map = _mapboxMap;
    if (map == null) return;

    // Petit retry car setStyleURI peut rendre le style indisponible quelques ms
    for (int attempt = 0; attempt < 6; attempt++) {
      try {
        final style = map.style;

        if (forceRebuild) {
          for (final layerId in <String>[
            _mmRouteLayerMainId,
            _mmRouteLayerCasingId,
            _mmRouteLayerSideLId,
            _mmRouteLayerSideRId,
            _mmRouteLayerGlowId,
            _mmRouteLayerShadowId,
          ]) {
            try {
              await style.removeStyleLayer(layerId);
            } catch (_) {
              // ignore
            }
          }
          try {
            await style.removeStyleSource(_mmRouteSegmentsSourceId);
          } catch (_) {
            // ignore
          }
          try {
            await style.removeStyleSource(_mmRouteSourceId);
          } catch (_) {
            // ignore
          }
          _mmRouteRuntimeReady = false;
        }

        if (_mmRouteRuntimeReady) return;

        // Sources
        try {
          await style.addSource(
            GeoJsonSource(
              id: _mmRouteSourceId,
              data: _emptyRouteFeatureCollection(),
            ),
          );
        } catch (_) {
          // ignore
        }
        try {
          await style.addSource(
            GeoJsonSource(
              id: _mmRouteSegmentsSourceId,
              data: _emptyRouteFeatureCollection(),
            ),
          );
        } catch (_) {
          // ignore
        }

        // Layers order: shadow -> glow -> sides -> casing -> main
        try {
          await style.addLayer(
            LineLayer(
              id: _mmRouteLayerShadowId,
              sourceId: _mmRouteSourceId,
              lineColor: const Color(0xFF000000).toARGB32(),
              lineOpacity: 0.0,
              lineWidth: 1.0,
              lineBlur: 0.0,
              lineJoin: LineJoin.ROUND,
              lineCap: LineCap.ROUND,
            ),
          );
        } catch (_) {
          // ignore
        }

        try {
          await style.addLayer(
            LineLayer(
              id: _mmRouteLayerGlowId,
              sourceId: _mmRouteSourceId,
              lineColor: const Color(0xFF1A73E8).toARGB32(),
              lineOpacity: 0.0,
              lineWidth: 1.0,
              lineBlur: 0.0,
              lineJoin: LineJoin.ROUND,
              lineCap: LineCap.ROUND,
            ),
          );
        } catch (_) {
          // ignore
        }

        // Faces latérales (côtés): même source/couleur que le tracé principal,
        // mais un peu plus transparent.
        try {
          await style.addLayer(
            LineLayer(
              id: _mmRouteLayerSideLId,
              sourceId: _mmRouteSegmentsSourceId,
              lineColor: const Color(0xFF1A73E8).toARGB32(),
              lineOpacity: 0.0,
              lineWidth: 7.0,
              lineBlur: 0.0,
              lineJoin: LineJoin.ROUND,
              lineCap: LineCap.ROUND,
            ),
          );
        } catch (_) {
          // ignore
        }

        try {
          await style.addLayer(
            LineLayer(
              id: _mmRouteLayerSideRId,
              sourceId: _mmRouteSegmentsSourceId,
              lineColor: const Color(0xFF1A73E8).toARGB32(),
              lineOpacity: 0.0,
              lineWidth: 7.0,
              lineBlur: 0.0,
              lineJoin: LineJoin.ROUND,
              lineCap: LineCap.ROUND,
            ),
          );
        } catch (_) {
          // ignore
        }

        try {
          await style.addLayer(
            LineLayer(
              id: _mmRouteLayerCasingId,
              sourceId: _mmRouteSegmentsSourceId,
              lineColor: const Color(0xFF0B1B2B).toARGB32(),
              lineOpacity: 1.0,
              lineWidth: 11.0,
              lineJoin: LineJoin.ROUND,
              lineCap: LineCap.ROUND,
            ),
          );
        } catch (_) {
          // ignore
        }

        try {
          await style.addLayer(
            LineLayer(
              id: _mmRouteLayerMainId,
              sourceId: _mmRouteSegmentsSourceId,
              lineColor: const Color(0xFF1A73E8).toARGB32(),
              lineOpacity: 1.0,
              lineWidth: 7.0,
              lineJoin: LineJoin.ROUND,
              lineCap: LineCap.ROUND,
            ),
          );
        } catch (_) {
          // ignore
        }

        _mmRouteRuntimeReady = true;
        return;
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 120));
      }
    }
  }

  Future<void> _renderMarketRoutePro({
    required List<Position> pts,
    required RouteStyleConfig? cfg,
    required bool fitCamera,
    int? animTick,
  }) async {
    final map = _mapboxMap;
    if (map == null) return;
    if (cfg == null) return;
    if (pts.length < 2) return;

    final c = cfg.validated();

    final width = c.effectiveRenderedMainWidth;
    final casingWidth = c.effectiveRenderedCasingWidth;
    final glowWidth = c.glowWidth * c.effectiveWidthScale3d;
    final elevationPx = c.effectiveElevationPx;
    final thickness3d = c.thickness3d;
    final sidesEnabled = c.effectiveSidesEnabled;
    final sidesIntensity = c.sidesIntensity.clamp(0.0, 1.0);

    await _ensureMarketRouteGeoJsonRuntime();

    final routeFc = _routeFeatureCollection([
      {
        'type': 'Feature',
        'properties': <String, dynamic>{},
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            for (final p in pts) [p.lng.toDouble(), p.lat.toDouble()],
          ],
        },
      },
    ]);

    final useSegments =
        c.rainbowEnabled ||
        c.trafficDemoEnabled ||
        c.vanishingEnabled ||
        c.effectiveCasingRainbowEnabled;
    final segmentsFc = useSegments
        ? _buildSegmentsFeatureCollection(
            pts,
            c,
            animTick: animTick ?? _routeAnimTick,
          )
        : _buildSolidFeatureCollection(pts, c);

    Future<void> safeSetSourceData(String sourceId, String data) async {
      try {
        await map.style.setStyleSourceProperty(sourceId, 'data', data);
      } catch (_) {
        try {
          await map.style.removeStyleSource(sourceId);
        } catch (_) {
          // ignore
        }
        try {
          await map.style.addSource(GeoJsonSource(id: sourceId, data: data));
        } catch (_) {
          // ignore
        }
      }
    }

    await safeSetSourceData(_mmRouteSourceId, routeFc);
    await safeSetSourceData(_mmRouteSegmentsSourceId, segmentsFc);

    Future<void> safeSet(String layerId, String key, dynamic value) async {
      try {
        await map.style.setStyleLayerProperty(layerId, key, value);
      } catch (_) {
        // ignore
      }
    }

    final join = c.lineJoin.name;
    final cap = c.lineCap.name;
    for (final layerId in <String>[
      _mmRouteLayerShadowId,
      _mmRouteLayerGlowId,
      _mmRouteLayerSideLId,
      _mmRouteLayerSideRId,
      _mmRouteLayerCasingId,
      _mmRouteLayerMainId,
    ]) {
      await safeSet(layerId, 'line-join', join);
      await safeSet(layerId, 'line-cap', cap);
    }

    final translateMap = (elevationPx > 0)
        ? <double>[0.0, -elevationPx]
        : const <double>[0.0, 0.0];
    for (final layerId in <String>[
      _mmRouteLayerGlowId,
      _mmRouteLayerSideLId,
      _mmRouteLayerSideRId,
      _mmRouteLayerCasingId,
      _mmRouteLayerMainId,
    ]) {
      await safeSet(layerId, 'line-translate', translateMap);
      await safeSet(layerId, 'line-translate-anchor', 'map');
    }

    final relief = max(0.0, thickness3d - 1.0);
    final shadowTranslate = <double>[relief * 3.0, relief * 4.0];
    await safeSet(_mmRouteLayerShadowId, 'line-translate', shadowTranslate);
    await safeSet(_mmRouteLayerShadowId, 'line-translate-anchor', 'viewport');

    // Côtés (faces latérales): décalage + intensité.
    final sideRelief = sidesEnabled ? max(0.12, relief) : relief;
    final sideDx = sideRelief * 3.0;
    final sideDy = sideRelief * 10.0;
    final sideTranslateL = <double>[-sideDx, -elevationPx + sideDy];
    final sideTranslateR = <double>[sideDx, -elevationPx + sideDy];

    await safeSet(_mmRouteLayerSideLId, 'line-translate', sideTranslateL);
    await safeSet(_mmRouteLayerSideRId, 'line-translate', sideTranslateR);
    await safeSet(_mmRouteLayerSideLId, 'line-translate-anchor', 'map');
    await safeSet(_mmRouteLayerSideRId, 'line-translate-anchor', 'map');

    final sideOpacityFactor = (0.55 * sidesIntensity).clamp(0.0, 1.0);
    await safeSet(_mmRouteLayerSideLId, 'line-color', ['get', 'color']);
    await safeSet(_mmRouteLayerSideRId, 'line-color', ['get', 'color']);
    await safeSet(_mmRouteLayerSideLId, 'line-width', [
      '+',
      ['get', 'width'],
      2,
    ]);
    await safeSet(_mmRouteLayerSideRId, 'line-width', [
      '+',
      ['get', 'width'],
      2,
    ]);
    await safeSet(
      _mmRouteLayerSideLId,
      'line-opacity',
      sidesEnabled
          ? [
              '*',
              ['get', 'opacity'],
              sideOpacityFactor,
            ]
          : 0.0,
    );
    await safeSet(
      _mmRouteLayerSideRId,
      'line-opacity',
      sidesEnabled
          ? [
              '*',
              ['get', 'opacity'],
              sideOpacityFactor,
            ]
          : 0.0,
    );
    await safeSet(_mmRouteLayerSideLId, 'line-blur', 0.0);
    await safeSet(_mmRouteLayerSideRId, 'line-blur', 0.0);

    // Shadow
    final shadowOpacity = c.effectiveShadowEnabled
        ? (c.shadowOpacity * c.opacity).clamp(0.0, 1.0)
        : 0.0;
    await safeSet(_mmRouteLayerShadowId, 'line-opacity', shadowOpacity);
    await safeSet(
      _mmRouteLayerShadowId,
      'line-width',
      max(1.0, casingWidth * thickness3d),
    );
    await safeSet(
      _mmRouteLayerShadowId,
      'line-blur',
      c.shadowBlur * thickness3d,
    );

    // Glow (+ pulse)
    double glowOpacity = c.effectiveGlowEnabled ? c.glowOpacity : 0.0;
    if (c.effectiveGlowEnabled && c.pulseEnabled) {
      final phase = ((animTick ?? _routeAnimTick) % 60) / 60.0;
      final wave = 0.5 + 0.5 * sin(2 * pi * phase);
      glowOpacity = (0.20 + wave * (c.glowOpacity - 0.20)).clamp(0.0, 1.0);
    }
    await safeSet(_mmRouteLayerGlowId, 'line-opacity', glowOpacity);
    await safeSet(
      _mmRouteLayerGlowId,
      'line-width',
      max(1.0, width + glowWidth),
    );
    await safeSet(_mmRouteLayerGlowId, 'line-blur', c.glowBlur);
    await safeSet(_mmRouteLayerGlowId, 'line-color', c.mainColor.toARGB32());

    // Casing
    final casingOpacity = (c.effectiveCasingWidth <= 0) ? 0.0 : c.opacity;
    await safeSet(_mmRouteLayerCasingId, 'line-opacity', casingOpacity);
    await safeSet(_mmRouteLayerCasingId, 'line-width', max(0.0, casingWidth));
    await safeSet(_mmRouteLayerCasingId, 'line-color', ['get', 'casingColor']);

    // Main layer from feature props
    await safeSet(_mmRouteLayerMainId, 'line-color', ['get', 'color']);
    await safeSet(_mmRouteLayerMainId, 'line-width', ['get', 'width']);
    await safeSet(_mmRouteLayerMainId, 'line-opacity', ['get', 'opacity']);

    if (c.dashEnabled) {
      await safeSet(_mmRouteLayerMainId, 'line-dasharray', [
        c.dashLength,
        c.dashGap,
      ]);
    } else {
      await safeSet(_mmRouteLayerMainId, 'line-dasharray', null);
    }

    // Évite tout mouvement caméra en mode animation
    if (!fitCamera) return;

    final bounds = _boundsFromPositions(pts);
    if (bounds == null) return;
    try {
      final camera = await map.cameraForCoordinateBounds(
        bounds,
        MbxEdgeInsets(top: 72, left: 72, bottom: 72, right: 72),
        0.0,
        0.0,
        null,
        null,
      );
      await map.flyTo(
        camera,
        MapAnimationOptions(duration: _cameraAnimationDuration.inMilliseconds),
      );
    } catch (_) {
      // ignore
    }
  }

  Future<bool> _renderMarketCircuitRoute(
    MarketMapPoiSelection selection,
  ) async {
    final map = _mapboxMap;
    if (map == null) return false;

    if (!selection.enabled ||
        selection.country == null ||
        selection.event == null ||
        selection.circuit == null) {
      return false;
    }

    try {
      final ref = _marketMapServiceOrCreate.circuitRef(
        countryId: selection.country!.id,
        eventId: selection.event!.id,
        circuitId: selection.circuit!.id,
      );
      final snap = await ref.get();
      final data = snap.data();
      if (data == null) return false;

      final rawRoute =
          data['route'] ??
          data['routePoints'] ??
          data['routeGeometry'] ??
          data['waypoints'];
      final pts = _parseRoutePoints(rawRoute);
      if (pts.length < 2) {
        await _clearMarketCircuitRoute();
        return false;
      }

      _lastMarketRoutePts = pts;

      // Style simple publié par le wizard
      final legacyAny = data['style'] ?? data['routeStyle'];
      final legacy = legacyAny is Map
          ? Map<String, dynamic>.from(legacyAny)
          : const <String, dynamic>{};

      final proCfg = tryParseRouteStylePro(data['routeStylePro']);

      // RouteStylePro: rendu EXACT via sources/layers (shadow/glow/casing/main/segments)
      if (proCfg != null) {
        _lastMarketRouteProCfg = proCfg;

        // Supprime toute ancienne polyline annotations (fallback legacy)
        try {
          await _circuitsAnnotationManager?.deleteAll();
        } catch (_) {
          // ignore
        }

        await _ensureMarketRouteGeoJsonRuntime();
        await _renderMarketRoutePro(
          pts: pts,
          cfg: proCfg,
          fitCamera: true,
          animTick: _routeAnimTick,
        );

        _syncMarketRouteAnimTimer(proCfg);
        return true;
      }

      // Pas de StylePro: s'assurer qu'on stoppe l'animation et vide les layers runtime
      _routeAnimTimer?.cancel();
      _routeAnimTimer = null;
      _lastMarketRouteProCfg = null;
      try {
        await map.style.setStyleSourceProperty(
          _mmRouteSourceId,
          'data',
          _emptyRouteFeatureCollection(),
        );
      } catch (_) {
        // ignore
      }
      try {
        await map.style.setStyleSourceProperty(
          _mmRouteSegmentsSourceId,
          'data',
          _emptyRouteFeatureCollection(),
        );
      } catch (_) {
        // ignore
      }

      await _ensureCircuitRouteManager();
      final manager = _circuitsAnnotationManager;
      if (manager == null) return false;

      // Rendu legacy (roadLike) si pas de StylePro
      final color =
          _parseHexColor(legacy['color']?.toString()) ??
          const Color(0xFF0A84FF);
      final width = (legacy['width'] as num?)?.toDouble() ?? 6.0;

      final roadLike = (legacy['roadLike'] as bool?) ?? true;
      final shadow3d = (legacy['shadow3d'] as bool?) ?? true;

      await manager.deleteAll();

      Future<void> addLine({
        required Color c,
        required double w,
        int? alpha,
      }) async {
        int to255(double v) => (v * 255.0).round().clamp(0, 255);
        final cc = alpha == null
            ? c
            : Color.fromARGB(alpha, to255(c.r), to255(c.g), to255(c.b));
        final options = PolylineAnnotationOptions(
          geometry: LineString(coordinates: pts),
          lineColor: cc.toARGB32(),
          lineWidth: w,
        );
        await manager.create(options);
      }

      if (proCfg != null) {
        int alphaFromOpacity(double v) => (v.clamp(0.0, 1.0) * 255).round();

        if (shadow3d) {
          final a = alphaFromOpacity(proCfg.shadowOpacity);
          await addLine(c: const Color(0xFF000000), w: width + 6.0, alpha: a);
        }

        final casingW = proCfg.casingWidth;
        if (casingW > width + 0.5) {
          final a = alphaFromOpacity(proCfg.opacity);
          await addLine(c: proCfg.casingColor, w: casingW, alpha: a);
        }

        final a = alphaFromOpacity(proCfg.opacity);
        await addLine(c: proCfg.mainColor, w: width, alpha: a);
      } else if (!roadLike) {
        await addLine(c: color, w: width);
      } else {
        if (shadow3d) {
          await addLine(c: const Color(0xFF000000), w: width + 8.0, alpha: 90);
        }
        await addLine(c: const Color(0xFF000000), w: width + 5.0, alpha: 140);
        await addLine(c: color, w: width);
        final centerWidth = (width * 0.33).clamp(1.0, width);
        await addLine(c: const Color(0xFFFFFFFF), w: centerWidth, alpha: 190);
      }

      final bounds = _boundsFromPositions(pts);
      if (bounds == null) return false;

      final camera = await map.cameraForCoordinateBounds(
        bounds,
        MbxEdgeInsets(top: 72, left: 72, bottom: 72, right: 72),
        0.0,
        0.0,
        null,
        null,
      );
      await map.flyTo(
        camera,
        MapAnimationOptions(duration: _cameraAnimationDuration.inMilliseconds),
      );
      return true;
    } catch (e) {
      debugPrint('⚠️ Erreur rendu tracé MarketMap: $e');
      return false;
    }
  }

  static List<Position> _parseRoutePoints(dynamic raw) {
    if (raw is! List) return const <Position>[];
    final pts = <Position>[];
    for (final it in raw) {
      final p = _parseRoutePoint(it);
      if (p != null) pts.add(p);
    }
    return pts;
  }

  static Position? _parseRoutePoint(dynamic it) {
    if (it is GeoPoint) return Position(it.longitude, it.latitude);

    if (it is Map) {
      final lat = it['lat'];
      final lng = it['lng'] ?? it['lon'];
      if (lat is num && lng is num) {
        return Position(lng.toDouble(), lat.toDouble());
      }
    }

    if (it is List && it.length >= 2) {
      final lng = it[0];
      final lat = it[1];
      if (lng is num && lat is num) {
        return Position(lng.toDouble(), lat.toDouble());
      }
    }

    return null;
  }

  static CoordinateBounds? _boundsFromPositions(List<Position> pts) {
    if (pts.length < 2) return null;
    double west = pts.first.lng.toDouble();
    double east = pts.first.lng.toDouble();
    double south = pts.first.lat.toDouble();
    double north = pts.first.lat.toDouble();
    for (final p in pts) {
      final lng = p.lng.toDouble();
      final lat = p.lat.toDouble();
      if (lng < west) west = lng;
      if (lng > east) east = lng;
      if (lat < south) south = lat;
      if (lat > north) north = lat;
    }
    return CoordinateBounds(
      southwest: Point(coordinates: Position(west, south)),
      northeast: Point(coordinates: Position(east, north)),
      infiniteBounds: false,
    );
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

  Future<void> _moveCameraTo({
    required double lng,
    required double lat,
    required double zoom,
  }) async {
    final map = _mapboxMap;
    if (map == null) return;

    try {
      final camera = CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: zoom,
      );
      await map.flyTo(
        camera,
        MapAnimationOptions(duration: _cameraAnimationDuration.inMilliseconds),
      );
    } catch (e) {
      debugPrint('⚠️ moveCameraTo error: $e');
    }
  }

  Future<void> _recenterOnUser() async {
    final map = _mapboxMap;
    final pos = _userPos;
    if (map == null || pos == null) return;

    try {
      await map.flyTo(
        CameraOptions(
          center: Point(coordinates: pos),
          zoom: _userZoom,
        ),
        MapAnimationOptions(
          duration: _cameraAnimationDuration.inMilliseconds,
          startDelay: 0,
        ),
      );
    } catch (e) {
      debugPrint('⚠️ recenterOnUser error: $e');
    }
  }

  Future<void> _adjustZoom(double delta) async {
    final map = _mapboxMap;
    if (map == null) return;

    try {
      final state = await map.getCameraState();
      final nextZoom = (state.zoom + delta).clamp(3.0, 20.0).toDouble();
      await map.flyTo(
        CameraOptions(
          center: state.center,
          zoom: nextZoom,
          pitch: state.pitch,
          bearing: state.bearing,
        ),
        MapAnimationOptions(duration: 220, startDelay: 0),
      );
    } catch (e) {
      debugPrint('⚠️ adjustZoom error: $e');
    }
  }

  Future<void> _renderMarketPoiMarkers() async {
    // =========================
    // MarketMap POIs (GeoJSON)
    // =========================

    if (_mapboxMap == null) return;

    // Si pas de selection -> vider
    if (!_marketPoiSelection.enabled ||
        _marketPoiSelection.country == null ||
        _marketPoiSelection.event == null ||
        _marketPoiSelection.circuit == null) {
      _marketPois = const <MarketPoi>[];
      await _ensureMarketPoiGeoJsonRuntime();
      await _updateMarketPoiGeoJson();
      await _applyPoiTypeVisibility();
      return;
    }

    await _ensureMarketPoiGeoJsonRuntime();
    await _updateMarketPoiGeoJson();
    await _applyPoiTypeVisibility();
  }

  String _mmLayerIdForType(String type) => '$_mmPoiLayerPrefix$type';

  String _typeFromPoi(MarketPoi poi) {
    // On essaie plusieurs champs possibles (robuste)
    // Ajuste si ton MarketPoi a un champ sûr (ex: poi.layerId)
    final dynamicAny = (poi as dynamic);

    String? pick(dynamic v) {
      final s = (v == null) ? '' : v.toString().trim();
      return s.isEmpty ? null : s;
    }

    final t =
        pick(dynamicAny.type) ??
        pick(dynamicAny.layerId) ??
        pick(dynamicAny.layerType) ??
        '';

    final norm = t.toLowerCase();
    if (_mmTypes.contains(norm)) return norm;

    // Mapping de compat (source de vérité: PoiNormalizer pour visit/food/wc)
    final normalized = PoiNormalizer.normalizePoiType(norm);
    if (normalized == PoiType.visit) return 'visit';
    if (normalized == PoiType.food) return 'food';
    if (normalized == PoiType.wc) return 'wc';

    return 'market';
  }

  String _labelFromPoi(MarketPoi poi) {
    final d = (poi as dynamic);
    final v = (d.name ?? d.title ?? '').toString().trim();
    return v;
  }

  String _descFromPoi(MarketPoi poi) {
    final d = (poi as dynamic);
    final v = (d.description ?? d.desc ?? '').toString().trim();
    return v;
  }

  (double, double)? _coordFromPoi(MarketPoi poi) {
    final d = (poi as dynamic);

    // Cas 1: champs lat/lng
    final lat = d.lat;
    final lng = d.lng;
    if (lat is num && lng is num) {
      return (lng.toDouble(), lat.toDouble());
    }

    // Cas 2: GeoPoint location
    final loc = d.location;
    if (loc is GeoPoint) {
      return (loc.longitude, loc.latitude);
    }

    return null;
  }

  static String _emptyPoiFeatureCollection() =>
      jsonEncode({'type': 'FeatureCollection', 'features': []});

  Future<void> _ensureMarketPoiGeoJsonRuntime({
    bool forceRebuild = false,
  }) async {
    final map = _mapboxMap;
    if (map == null) return;

    // Petit retry car setStyleURI peut rendre le style indisponible quelques ms
    for (int attempt = 0; attempt < 6; attempt++) {
      try {
        final style = map.style;

        // Si on force rebuild, on purge les layers runtime
        if (forceRebuild) {
          for (final layerId in _mmPoiLayerIds.toList()) {
            try {
              await style.removeStyleLayer(layerId);
            } catch (_) {
              // ignore
            }
            _mmPoiLayerIds.remove(layerId);
          }
          try {
            await style.removeStyleSource(_mmPoiSourceId);
          } catch (_) {
            // ignore
          }
          _mmPoiSource = null;
        }

        // Source
        if (_mmPoiSource == null) {
          try {
            await style.addSource(
              GeoJsonSource(
                id: _mmPoiSourceId,
                data: _emptyPoiFeatureCollection(),
              ),
            );
          } catch (_) {
            // ignore (déjà présent)
          }

          // Cluster (optionnel selon version SDK)
          try {
            await style.setStyleSourceProperty(_mmPoiSourceId, 'cluster', true);
            await style.setStyleSourceProperty(
              _mmPoiSourceId,
              'clusterRadius',
              55,
            );
            await style.setStyleSourceProperty(
              _mmPoiSourceId,
              'clusterMaxZoom',
              14,
            );
          } catch (_) {
            // ignore
          }

          _mmPoiSource = GeoJsonSource(id: _mmPoiSourceId, data: '');
        }

        // Layers par type (visit/food/...)
        for (final type in _mmTypes) {
          final layerId = _mmLayerIdForType(type);
          if (_mmPoiLayerIds.contains(layerId) && !forceRebuild) continue;

          // addLayer peut throw si déjà présent -> on ignore
          try {
            final color = _poiColorForType(type);
            final layer = CircleLayer(
              id: layerId,
              sourceId: _mmPoiSourceId,
              circleRadius: 7.0,
              circleColor: color.toARGB32(),
              circleOpacity: 0.95,
              circleStrokeColor: Colors.white.toARGB32(),
              circleStrokeWidth: 2.0,
            );
            await style.addLayer(layer);

            // Filter: ["==", ["get","type"], "food"]
            await style.setStyleLayerProperty(layerId, 'filter', [
              '==',
              ['get', 'type'],
              type,
            ]);
          } catch (_) {
            // ignore
          }

          _mmPoiLayerIds.add(layerId);
        }

        // Couche badge live tables (petit point coloré sur les POI food avec statut actif)
        if (!_mmPoiLayerIds.contains(_mmPoiLiveBadgeLayerId) || forceRebuild) {
          try {
            final badgeLayer = CircleLayer(
              id: _mmPoiLiveBadgeLayerId,
              sourceId: _mmPoiSourceId,
              circleRadius: 5.0,
              circleColor: 0xFF4CAF50, // override via expression ci-dessous
              circleOpacity: 1.0,
              circleStrokeColor: Colors.white.toARGB32(),
              circleStrokeWidth: 1.5,
            );
            await style.addLayer(badgeLayer);

            // Filtre: seulement les POI food avec un état live non vide
            await style.setStyleLayerProperty(
              _mmPoiLiveBadgeLayerId,
              'filter',
              [
                'all',
                [
                  '==',
                  ['get', 'type'],
                  'food',
                ],
                [
                  '!=',
                  ['get', 'liveTableState'],
                  '',
                ],
              ],
            );

            // Couleur dynamique par état live
            await style.setStyleLayerProperty(
              _mmPoiLiveBadgeLayerId,
              'circle-color',
              [
                'match',
                ['get', 'liveTableState'],
                'available',
                '#4CAF50',
                'limited',
                '#FF9800',
                'full',
                '#F44336',
                '#9E9E9E',
              ],
            );

            // Décalage en bas à droite du marker principal
            await style.setStyleLayerProperty(
              _mmPoiLiveBadgeLayerId,
              'circle-translate',
              [8.0, 8.0],
            );

            _mmPoiLayerIds.add(_mmPoiLiveBadgeLayerId);
          } catch (_) {
            // ignore
          }
        }

        return; // OK
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 120));
      }
    }
  }

  Future<void> _updateMarketPoiGeoJson() async {
    final map = _mapboxMap;
    if (map == null) return;
    if (_mmPoiSource == null) return;

    final feats = <Map<String, dynamic>>[];

    for (final poi in _marketPois) {
      final coord = _coordFromPoi(poi);
      if (coord == null) continue;

      final type = _typeFromPoi(poi);
      final name = _labelFromPoi(poi);
      final desc = _descFromPoi(poi);
      final d = (poi as dynamic);

      // Champs “fiche”
      String imageUrl = (d.imageUrl ?? d.photoUrl ?? d.image ?? '')
          .toString()
          .trim();
      final address = (d.address ?? d.adresse ?? d.locationLabel ?? '')
          .toString()
          .trim();

      // Horaires (supporte string OU map/list)
      final openingHoursRaw = d.openingHours ?? d.hours ?? d.horaires;
      final openingHours = (openingHoursRaw is String)
          ? openingHoursRaw.trim()
          : (openingHoursRaw != null ? jsonEncode(openingHoursRaw) : '');

      // Contacts / liens
      final phone = (d.phone ?? d.tel ?? d.telephone ?? '').toString().trim();
      final website = (d.website ?? d.site ?? '').toString().trim();
      final instagram = (d.instagram ?? d.ig ?? '').toString().trim();
      final facebook = (d.facebook ?? d.fb ?? '').toString().trim();
      final whatsapp = (d.whatsapp ?? '').toString().trim();
      final email = (d.email ?? '').toString().trim();
      final mapsUrl = (d.mapsUrl ?? d.googleMapsUrl ?? d.mapUrl ?? '')
          .toString()
          .trim();

      // Si tu as un champ metadata Map, on le merge aussi (optionnel)
      Map<String, dynamic> meta = <String, dynamic>{};
      try {
        final m = d.metadata;
        if (m is Map) {
          meta = Map<String, dynamic>.from(m);
        } else {
          final legacy = d.meta;
          if (legacy is Map) meta = Map<String, dynamic>.from(legacy);
        }
      } catch (_) {
        // ignore
      }

      // Flatten imageUrl depuis meta.image.url si nécessaire.
      if (imageUrl.isEmpty) {
        final img = meta['image'];
        if (img is Map) {
          final u = (img['url'] ?? img['downloadUrl'] ?? '').toString().trim();
          if (u.isNotEmpty) imageUrl = u;
        }
      }

      // État live tables pour le badge marker (food uniquement, premium actif).
      final liveTableState = _resolveLiveTableBadgeState(
        poiType: type,
        metadata: meta,
        rootPublished: d.isPublished ?? d.published,
        rootPremiumFeatures: d.premiumFeatures,
        rootLiveTableSummary: d.liveTableSummary,
      );

      feats.add({
        'type': 'Feature',
        'id': d.id?.toString() ?? '',
        'geometry': {
          'type': 'Point',
          'coordinates': [coord.$1, coord.$2],
        },
        'properties': {
          'type': type,
          'name': name,
          'desc': desc,
          'imageUrl': imageUrl,
          'lng': coord.$1,
          'lat': coord.$2,

          // fiche complète
          'address': address,
          'openingHours': openingHours,
          'phone': phone,
          'website': website,
          'instagram': instagram,
          'facebook': facebook,
          'whatsapp': whatsapp,
          'email': email,
          'mapsUrl': mapsUrl,

          // meta: explicitly JSON encode to ensure it survives Mapbox serialization
          'meta': meta.isNotEmpty ? jsonEncode(meta) : '',

          // Badge live tables (état disponibilité pour les POI food abonnés)
          'liveTableState': liveTableState,
        },
      });
    }

    final fc = {'type': 'FeatureCollection', 'features': feats};
    try {
      await map.style.setStyleSourceProperty(
        _mmPoiSourceId,
        'data',
        jsonEncode(fc),
      );
    } catch (_) {
      // Fallback: remove+add
      try {
        await map.style.removeStyleSource(_mmPoiSourceId);
      } catch (_) {
        // ignore
      }
      try {
        await map.style.addSource(
          GeoJsonSource(id: _mmPoiSourceId, data: jsonEncode(fc)),
        );
      } catch (_) {
        // ignore
      }
    }
  }

  Future<void> _applyPoiTypeVisibility() async {
    final map = _mapboxMap;
    if (map == null) return;

    final wanted = _actionToPoiType(_selectedAction); // visit/food/...
    for (final type in _mmTypes) {
      final layerId = _mmLayerIdForType(type);
      // Par défaut (aucun filtre sélectionné), on n'affiche AUCUN POI.
      // Les POIs apparaissent uniquement après clic sur une icône du menu vertical.
      final visible = (wanted != null) && (type == wanted);
      try {
        await map.style.setStyleLayerProperty(
          layerId,
          'visibility',
          visible ? 'visible' : 'none',
        );
      } catch (_) {
        // ignore
      }
    }
    // Badge live tables: visible uniquement quand la couche food est active
    try {
      await map.style.setStyleLayerProperty(
        _mmPoiLiveBadgeLayerId,
        'visibility',
        (wanted == 'food') ? 'visible' : 'none',
      );
    } catch (_) {
      // ignore
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _bootstrapLocation();
    }
  }

  @override
  void didChangeMetrics() {
    // Détecte : rotation, split-view, resize fenêtre, clavier virtuel
    super.didChangeMetrics();

    // LayoutBuilder détecte automatiquement les changements de taille et
    // déclenche _scheduleResize qui gère le _mapTick++.
    // On ne fait PAS de _mapTick++ ici pour éviter une double destruction /
    // recréation du MapWidget (flash noir + annotation managers orphelins).
    // Un setState() vide suffit à forcer un rebuild du LayoutBuilder.
    if (mounted) {
      try {
        setState(() {});
      } catch (e) {
        debugPrint('⚠️ Erreur didChangeMetrics: $e');
      }
    }
  }

  /// Planifie un resize de la carte avec debounce pour éviter les rebuilds excessifs.
  ///
  /// Cette méthode est appelée par LayoutBuilder à chaque changement de contraintes.
  /// Le debounce évite de rebuilder la carte 10+ fois pendant une animation de resize.
  ///
  /// **Pourquoi c'est nécessaire :** Le SDK Mapbox natif ne gère pas automatiquement
  /// le resize via Flutter. On force un rebuild avec une nouvelle ValueKey.
  void _scheduleResize(ui.Size size) {
    // Tant que la taille n'est pas exploitable, on ne crée pas la carte.
    if (!size.width.isFinite || !size.height.isFinite) return;
    if (size.width <= 0 || size.height <= 0) return;

    // Première taille valide : autoriser immédiatement la création de la carte
    // pour éviter le flash noir (le debounce suivant gère les resize ultérieurs).
    if (!_mapCanBeCreated) {
      _lastSize = size;
      _debounce?.cancel();
      if (mounted) {
        setState(() {
          _mapCanBeCreated = true;
          _mapTick++;
        });
        debugPrint(
          '✅ Map first create: ${size.width.toInt()}x${size.height.toInt()} (tick: $_mapTick)',
        );
      }
      return;
    }

    // Ignorer si la taille n'a pas changé (optimisation)
    if (_lastSize == size) return;
    _lastSize = size;

    // Annuler le timer précédent (debounce)
    _debounce?.cancel();

    // Attendre que le resize soit stabilisé avant de rebuilder
    _debounce = Timer(_resizeDebounceDelay, () {
      if (!mounted) return; // Sécurité supplémentaire

      try {
        // Incrémenter le tick force Flutter à recréer le MapWidget avec une nouvelle Key.
        // On réinitialise l’état carte car l’ancienne instance sera détruite.
        setState(() {
          _mapCanBeCreated = true;
          _mapTick++;
          _isMapReady = false;
          _mapboxMap = null;
          _userAnnotationManager = null;
          _groupsAnnotationManager = null;
          _circuitsAnnotationManager = null;
        });
        debugPrint(
          '✅ Map rebuild: ${size.width.toInt()}x${size.height.toInt()} (tick: $_mapTick)',
        );
      } catch (e) {
        debugPrint('⚠️ Erreur _scheduleResize: $e');
      }
    });
  }

  /// Initialise la géolocalisation au démarrage de la page.
  ///
  /// 1. Vérifie les permissions GPS
  /// 2. Récupère la position initiale
  /// 3. Met à jour le marqueur utilisateur
  /// 4. Démarre le stream de positions
  Future<void> _bootstrapLocation() async {
    if (defaultTargetPlatform == TargetPlatform.linux &&
        !File('/var/run/dbus/system_bus_socket').existsSync()) {
      debugPrint('⚠️ GPS ignoré: DBus indisponible sur Linux headless');
      if (mounted) {
        setState(() => _isGpsReady = true);
      } else {
        _isGpsReady = true;
      }
      return;
    }

    final ok = await _ensureLocationPermission(request: true);

    if (ok) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: geo.LocationSettings(
            accuracy: LocationAccuracy.best,
            timeLimit: _gpsTimeout,
          ),
        );
        final p = Position(pos.longitude, pos.latitude);
        if (mounted) {
          setState(() {
            _userPos = p;
          });
          await _updateUserMarker();
        }
      } on TimeoutException catch (e) {
        debugPrint('⏱️ Timeout GPS: $e');
      } catch (e) {
        debugPrint('⚠️ Erreur GPS: $e');
      }
    }

    if (mounted) {
      setState(() => _isGpsReady = true);
    } else {
      _isGpsReady = true;
    }

    if (!ok) return;
    _startUserPositionStream();
  }

  /// Vérifie et demande les permissions de géolocalisation.
  ///
  /// Retourne true si les permissions sont accordées, false sinon.
  Future<bool> _ensureLocationPermission({required bool request}) async {
    // Éviter les requêtes concurrentes
    if (_requestingGps) return false;
    _requestingGps = true;

    try {
      // 1. Vérifier si le service de localisation est activé
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        return false;
      }

      // 2. Vérifier les permissions
      var permission = await Geolocator.checkPermission();

      // 3. Demander la permission si nécessaire et autorisé
      if (permission == LocationPermission.denied && request) {
        permission = await Geolocator.requestPermission();
      }

      // 4. Gérer les permissions refusées
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

  /// Démarre le stream de mise à jour de la position utilisateur en temps réel.
  ///
  /// Le filtre de distance évite les mises à jour trop fréquentes pour de petits mouvements.
  void _startUserPositionStream() {
    _positionSub?.cancel();

    const settings = geo.LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: _gpsDistanceFilter, // Mise à jour tous les 8 mètres
    );

    try {
      _positionSub = Geolocator.getPositionStream(locationSettings: settings)
          .listen(
            (pos) {
              final p = Position(pos.longitude, pos.latitude);
              if (!mounted) return;

              setState(() {
                _userPos = p;
                if (!_isGpsReady) {
                  _isGpsReady = true;
                }
              });

              _updateUserMarker();

              if (_followUser) {
                _mapboxMap?.flyTo(
                  CameraOptions(
                    center: Point(coordinates: p),
                    zoom: _userZoom,
                  ),
                  MapAnimationOptions(
                    duration: _cameraAnimationDuration.inMilliseconds,
                    startDelay: 0,
                  ),
                );
              }
            },
            onError: (error) {
              debugPrint('⚠️ Erreur stream position: $error');
              if (mounted) {
                setState(() => _isGpsReady = false);
              }
            },
            cancelOnError: false, // Continue à écouter même après une erreur
          );
    } catch (e) {
      debugPrint('⚠️ Impossible de démarrer le stream GPS: $e');
      if (mounted) {
        setState(() => _isGpsReady = false);
      }
    }
  }

  /// Notifie que la carte est prête après un court délai.
  ///
  /// Utilisé par splash_wrapper_page pour masquer le splash screen.
  void _checkIfReady() {
    if (!_isMapReady || mapReadyNotifier.value || _didScheduleReadySignal) {
      return;
    }
    _didScheduleReadySignal = true;
    StartupTrace.log('MAPBOX_NATIVE', '_checkIfReady scheduling notifier=true');
    Future.delayed(_mapReadyDelay, () {
      _didScheduleReadySignal = false;
      if (!mounted || mapReadyNotifier.value) return;
      StartupTrace.log(
        'MAPBOX_NATIVE',
        '_checkIfReady set mapReadyNotifier=true',
      );
      mapReadyNotifier.value = true;
      _startDeferredHomeInit();
    });
  }

  /// Débloque le splash même si la carte n'a pas pu être initialisée
  /// (ex: token Mapbox absent). Évite le loader infini.
  void _notifyMapReadyFallback() {
    if (mapReadyNotifier.value || _didScheduleReadySignal) return;
    _didScheduleReadySignal = true;
    StartupTrace.log(
      'MAPBOX_NATIVE',
      '_notifyMapReadyFallback scheduling notifier=true',
    );
    Future.delayed(_mapReadyDelay, () {
      _didScheduleReadySignal = false;
      if (mounted && !mapReadyNotifier.value) {
        StartupTrace.log(
          'MAPBOX_NATIVE',
          '_notifyMapReadyFallback set mapReadyNotifier=true',
        );
        debugPrint(
          '🔓 HomeMapPage3D: _notifyMapReadyFallback → déblocage splash',
        );
        mapReadyNotifier.value = true;
      }
    });
  }

  /// Met à jour le marqueur de position utilisateur sur la carte.
  ///
  /// Supprime l'ancien marqueur et crée un nouveau pour éviter les doublons.
  Future<void> _updateUserMarker() async {
    // Early returns pour optimiser les performances
    if (!mounted) return;

    final manager = _userAnnotationManager;
    final pos = _userPos;
    if (manager == null || pos == null) return;

    try {
      // Supprimer tous les marqueurs existants (évite les doublons)
      await manager.deleteAll();

      // Créer le nouveau marqueur à la position actuelle
      final options = PointAnnotationOptions(
        geometry: Point(coordinates: pos),
        iconImage: 'user-location-icon',
        iconSize: _userMarkerIconSize,
      );

      await manager.create(options);
    } catch (e) {
      debugPrint('⚠️ Erreur update user marker: $e');
    }
  }

  /// Ajoute les bâtiments 3D à la carte pour un effet de profondeur.
  ///
  /// Les bâtiments apparaissent uniquement au-delà du zoom 14.5 pour optimiser les performances.
  Future<void> _add3dBuildings() async {
    if (!mounted) return;

    final map = _mapboxMap;
    if (map == null) return;

    try {
      final style = map.style;

      // Configuration du layer d'extrusion 3D
      final layer =
          FillExtrusionLayer(id: 'maslive-3d-buildings', sourceId: 'composite')
            ..sourceLayer = 'building'
            ..minZoom =
                _minZoom3dBuildings // Visible uniquement en zoom rapproché
            ..fillExtrusionColor = const Color(0xFFD1D5DB)
                .toARGB32() // Gris clair
            ..fillExtrusionOpacity =
                0.7 // Semi-transparent
            ..fillExtrusionHeight =
                20.0 // Hauteur basée sur les données OSM
            ..fillExtrusionBase = 0.0; // Pas de surélévation de base

      // Filtre : seulement les bâtiments avec propriété "extrude"
      layer.filter = const [
        '==',
        ['get', 'extrude'],
        'true',
      ];

      await style.addLayer(layer);
    } catch (e) {
      debugPrint('⚠️ Erreur ajout bâtiments 3D: $e');
    }
  }

  /// Callback appelé quand le MapWidget Mapbox est initialisé.
  ///
  /// Configure tous les aspects de la carte : gestes 3D, bâtiments, annotation managers.
  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    if (!mounted) return;
    StartupTrace.log('MAPBOX_NATIVE', '_onMapCreated start');
    _mapboxMap = mapboxMap;

    try {
      await mapboxMap.logo.updateSettings(LogoSettings(enabled: false));
      await mapboxMap.attribution.updateSettings(
        AttributionSettings(enabled: false, clickable: false),
      );

      // 1. Activer tous les gestes 3D (rotation, inclinaison, zoom)
      await mapboxMap.gestures.updateSettings(
        GesturesSettings(
          pitchEnabled: true, // Inclinaison vertical
          rotateEnabled: true, // Rotation à deux doigts
          scrollEnabled: true, // Pan/déplacement
          pinchToZoomEnabled: true, // Zoom pinch
        ),
      );

      // Guard: si le MapWidget a été recréé entre-temps, abandonner.
      if (_mapboxMap != mapboxMap) {
        StartupTrace.log('MAPBOX_NATIVE', '_onMapCreated stale after gestures');
        return;
      }
    } catch (e) {
      StartupTrace.log('MAPBOX_NATIVE', '_onMapCreated failed: $e');
      debugPrint('⚠️ Erreur configuration carte: $e');
    }

    // Guard final : vérifier que cette instance est toujours la courante.
    if (_mapboxMap != mapboxMap) {
      StartupTrace.log('MAPBOX_NATIVE', '_onMapCreated stale before ready');
      return;
    }

    // 2. Marquer la carte comme prête dès que l'instance est interactive.
    if (mounted) {
      setState(() {
        _isMapReady = true;
      });
      _checkIfReady();
      StartupTrace.log('MAPBOX_NATIVE', '_onMapCreated map ready');
    }

    unawaited(_finishMapSetupAfterReady(mapboxMap));
  }

  Future<void> _finishMapSetupAfterReady(MapboxMap mapboxMap) async {
    if (_mapboxMap != mapboxMap) return;

    await _add3dBuildings();
    if (_mapboxMap != mapboxMap) return;

    try {
      _userAnnotationManager = await mapboxMap.annotations
          .createPointAnnotationManager();
      _groupsAnnotationManager = await mapboxMap.annotations
          .createPointAnnotationManager();
      _circuitsAnnotationManager = await mapboxMap.annotations
          .createPolylineAnnotationManager();
    } catch (e) {
      debugPrint('⚠️ Erreur création annotation managers: $e');
    }

    await _updateUserMarker();
    await _renderMarketPoiMarkers();

    if (_lastSize != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduleResize(_lastSize!);
      });
    }
  }

  void _startDeferredHomeInit() {
    if (_didStartDeferredHomeInit) return;
    _didStartDeferredHomeInit = true;

    Future<void>.delayed(_deferredHomeInitDelay, () {
      if (!mounted) return;
      unawaited(_bootstrapLocation());
      unawaited(_loadUserGroupId());
    });
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData data) async {
    // Style reload => runtime layers/sources sont perdus
    _mmRouteRuntimeReady = false;

    // Re-ajoute ce qui dépend du style
    await _add3dBuildings();

    // Rebuild POIs si sélection active
    await _ensureMarketPoiGeoJsonRuntime(forceRebuild: true);
    await _updateMarketPoiGeoJson();
    await _applyPoiTypeVisibility();

    // Rebuild route Pro si active
    if (_lastMarketRouteProCfg != null && _lastMarketRoutePts.length >= 2) {
      await _ensureMarketRouteGeoJsonRuntime(forceRebuild: true);
      await _renderMarketRoutePro(
        pts: _lastMarketRoutePts,
        cfg: _lastMarketRouteProCfg,
        fitCamera: false,
        animTick: _routeAnimTick,
      );
    }
  }

  Future<void> _onMapTap(ScreenCoordinate sc) async {
    final map = _mapboxMap;
    if (map == null) return;

    // Si pas de sélection MarketMap active, on ignore
    if (!_marketPoiSelection.enabled ||
        _marketPoiSelection.country == null ||
        _marketPoiSelection.event == null ||
        _marketPoiSelection.circuit == null) {
      return;
    }

    // Nos layers POI GeoJSON: mm_pois_layer__visit / food / wc / ...
    final layerIds = _mmTypes.map(_mmLayerIdForType).toList();

    try {
      final res = await map.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenCoordinate(sc),
        RenderedQueryOptions(layerIds: layerIds, filter: null),
      );

      if (res.isEmpty) return;

      // Sélectionner la meilleure feature:
      // - prioriser les POIs non-cluster
      // - fallback cluster si rien d'autre
      final allFeatures = <Map<String, dynamic>>[];
      for (final item in res) {
        final f = item?.queriedFeature.feature;
        if (f is Map<String, dynamic>) {
          allFeatures.add(f);
        }
      }
      if (allFeatures.isEmpty) return;

      bool isClusterProps(Map<String, dynamic> props) {
        return (props['cluster'] == true) ||
            (props['cluster']?.toString() == 'true');
      }

      Map<String, dynamic> asProps(Map<String, dynamic> feature) {
        return (feature['properties'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
      }

      bool isValidPoiProps(Map<String, dynamic> props) {
        final type = (props['type'] ?? props['layerType'] ?? '')
            .toString()
            .trim();
        if (type.isEmpty) return false;
        return _mmTypes.contains(type);
      }

      Map<String, dynamic>? bestNonCluster;
      for (final f in allFeatures) {
        final props = asProps(f);
        if (isClusterProps(props)) continue;
        if (!isValidPoiProps(props)) continue;
        bestNonCluster = f;
        break;
      }

      final feature = bestNonCluster ?? allFeatures.first;

      final rawFeatureId = feature['id'];

      String? asNonEmptyString(dynamic v) {
        final s = (v ?? '').toString().trim();
        return s.isEmpty ? null : s;
      }

      final props =
          (feature['properties'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};

      // --- Cluster handling (si cluster:true sur la source) ---
      final isCluster =
          (props['cluster'] == true) ||
          (props['cluster']?.toString() == 'true');

      if (isCluster) {
        // Zoom sur le cluster (simple)
        // On récupère le point du cluster si dispo
        final geom = feature['geometry'];
        if (geom is Map && geom['type'] == 'Point') {
          final coords = geom['coordinates'];
          if (coords is List && coords.length >= 2) {
            final lng = (coords[0] as num).toDouble();
            final lat = (coords[1] as num).toDouble();
            // zoom +1.5 (ajuste)
            await map.easeTo(
              CameraOptions(
                center: Point(coordinates: Position(lng, lat)),
                zoom: (_defaultZoom + 2.0),
              ),
              MapAnimationOptions(duration: 450),
            );
          }
        }
        return;
      }

      // --- POI normal ---
      final poiId =
          asNonEmptyString(props['id']) ?? asNonEmptyString(rawFeatureId);

      final name = (props['name'] ?? props['title'] ?? '').toString();
      final desc = (props['desc'] ?? props['description'] ?? '').toString();
      final type = (props['type'] ?? props['layerType'] ?? '').toString();

      // Image URL: supporte aussi meta.image.url (retour admin)
      String imageUrl = (props['imageUrl'] ?? props['photoUrl'] ?? '')
          .toString();
      final lng = (props['lng'] is num)
          ? (props['lng'] as num).toDouble()
          : null;
      final lat = (props['lat'] is num)
          ? (props['lat'] as num).toDouble()
          : null;

      final address = (props['address'] ?? '').toString();
      final openingHours = (props['openingHours'] ?? '').toString();
      final phone = (props['phone'] ?? '').toString();
      final website = (props['website'] ?? '').toString();
      final instagram = (props['instagram'] ?? '').toString();
      final facebook = (props['facebook'] ?? '').toString();
      final whatsapp = (props['whatsapp'] ?? '').toString();
      final email = (props['email'] ?? '').toString();
      final mapsUrl = (props['mapsUrl'] ?? '').toString();

      Map<String, dynamic>? meta;
      final metaRaw = props['meta'] ?? props['metadata'];
      if (metaRaw is Map) {
        try {
          meta = Map<String, dynamic>.from(metaRaw);
        } catch (_) {
          meta = metaRaw.map((k, v) => MapEntry(k.toString(), v));
        }
      } else if (metaRaw is String && metaRaw.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(metaRaw);
          if (decoded is Map) {
            meta = Map<String, dynamic>.from(decoded);
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ Failed to parse meta JSON: $metaRaw');
          }
        }
      }

      // Certaines impls peuvent exposer `image` directement dans props.
      if (meta == null) {
        final imgRaw = props['image'];
        if (imgRaw is Map) {
          try {
            meta = <String, dynamic>{
              'image': Map<String, dynamic>.from(imgRaw),
            };
          } catch (_) {
            meta = <String, dynamic>{
              'image': imgRaw.map((k, v) => MapEntry(k.toString(), v)),
            };
          }
        }
      }

      // Compléter imageUrl depuis meta.image.url si besoin
      if (imageUrl.trim().isEmpty && meta != null) {
        final img = meta['image'];
        if (img is Map) {
          final url = (img['url'] ?? img['downloadUrl'] ?? '')
              .toString()
              .trim();
          if (url.isNotEmpty) {
            imageUrl = url;
            if (kDebugMode) {
              debugPrint('ℹ️ POI imageUrl completed from meta.image.url');
            }
          }
        }
      }

      final hasImageInMeta = (() {
        if (meta == null) return false;
        final img = meta['image'];
        if (img is! Map) return false;
        final u = (img['url'] ?? img['downloadUrl'] ?? '').toString().trim();
        return u.isNotEmpty;
      })();

      // Détecter si une fiche descriptive existe (signal explicite)
      final rootPopupEnabled =
          props['popupEnabled'] ?? props['hasPopup'] ?? props['hasCard'];
      final hasExplicitPopupFlag =
          PoiPopupService.parseBool(
            (meta ?? const <String, dynamic>{})['popupEnabled'] ??
                rootPopupEnabled,
          ) !=
          null;
      final hasPolaroidMeta =
          meta != null &&
          (meta.containsKey('polaroid') || meta.containsKey('image'));
      final hasAnyCardData =
          name.trim().isNotEmpty ||
          desc.trim().isNotEmpty ||
          imageUrl.trim().isNotEmpty ||
          address.trim().isNotEmpty ||
          openingHours.trim().isNotEmpty ||
          phone.trim().isNotEmpty ||
          website.trim().isNotEmpty ||
          instagram.trim().isNotEmpty ||
          facebook.trim().isNotEmpty ||
          whatsapp.trim().isNotEmpty ||
          email.trim().isNotEmpty ||
          mapsUrl.trim().isNotEmpty;
      final hasCard = hasExplicitPopupFlag || hasPolaroidMeta || hasAnyCardData;

      if (!hasCard) {
        if (kDebugMode) {
          debugPrint(
            'ℹ️ POI tap: no card detected => skip (id=${poiId ?? "?"}, type=$type, name="$name", hasImage=$imageUrl, hasAnyCardData=$hasAnyCardData, metaKeys=${meta?.keys.toList() ?? []})',
          );
        }
        return;
      }

      // Si popup désactivé => POI non cliquable (ex: WC)
      final bool popupEnabled = PoiPopupService.isPopupEnabled(
        type: type,
        meta: meta,
        rootPopupEnabled: rootPopupEnabled,
        requireImage: true,
        hasImage: imageUrl.trim().isNotEmpty || hasImageInMeta,
      );

      if (!popupEnabled) {
        if (kDebugMode) {
          debugPrint(
            'ℹ️ POI tap: card exists but popup disabled => skip (id=${poiId ?? "?"}, type=$type, popupEnabledRaw=${(meta ?? const <String, dynamic>{})['popupEnabled'] ?? rootPopupEnabled})',
          );
        }
        return;
      }

      // Anti-doublon (taps rapides)
      final now = DateTime.now();
      final lastAt = _lastPoiPopupAt;
      if (_isPoiPopupShowing) {
        if (kDebugMode) {
          debugPrint(
            'ℹ️ POI tap: popup already showing => ignore (id=${poiId ?? "?"})',
          );
        }
        return;
      }
      if (lastAt != null && now.difference(lastAt) < _poiPopupDebounce) {
        if (_lastPoiPopupId != null &&
            poiId != null &&
            _lastPoiPopupId == poiId) {
          if (kDebugMode) {
            debugPrint('ℹ️ POI tap: debounced duplicate => ignore (id=$poiId)');
          }
          return;
        }
      }
      _lastPoiPopupAt = now;
      _lastPoiPopupId = poiId;

      if (!mounted) return;
      unawaited(
        _showPoiPolaroid(
          poiId: poiId,
          countryId: _marketPoiSelection.country?.id,
          eventId: _marketPoiSelection.event?.id,
          circuitId: _marketPoiSelection.circuit?.id,
          title: name.isEmpty ? 'Point d\'intérêt' : name,
          description: desc,
          category: type,
          imageUrl: imageUrl.isEmpty ? null : imageUrl,
          lng: lng,
          lat: lat,
          address: address,
          openingHours: openingHours,
          phone: phone,
          website: website,
          instagram: instagram,
          facebook: facebook,
          whatsapp: whatsapp,
          email: email,
          mapsUrl: mapsUrl,
          meta: meta ?? const <String, dynamic>{},
        ),
      );

      if (kDebugMode) {
        debugPrint(
          '✅ POI tap: show polaroid (id=${poiId ?? "?"}, type=$type, hasImage=${imageUrl.trim().isNotEmpty}, name="$name")',
        );
      }
    } catch (e) {
      debugPrint('⚠️ Tap POI queryRenderedFeatures error: $e');
    }
  }

  /// Affiche un overlay style "polaroïd" pour un POI.
  Future<void> _showPoiPolaroid({
    String? poiId,
    String? countryId,
    String? eventId,
    String? circuitId,
    required String title,
    required String description,
    required String category,
    String? imageUrl,
    double? lng,
    double? lat,

    // fiche complète
    String address = '',
    String openingHours = '',
    String phone = '',
    String website = '',
    String instagram = '',
    String facebook = '',
    String whatsapp = '',
    String email = '',
    String mapsUrl = '',
    Map<String, dynamic> meta = const <String, dynamic>{},
  }) async {
    if (_isPoiPopupShowing) return;
    _isPoiPopupShowing = true;

    if (kDebugMode) {
      debugPrint(
        '📍 POI Polaroid: opening sheet (title=$title, imageUrl=${(imageUrl ?? "").isEmpty ? "empty" : "present"}, metaKeys=${meta.keys.toList()}, metaImage=${(meta['image'] as Map?)?.keys.toList() ?? []})',
      );
    }

    // Analytics: uniquement si on ouvre réellement la polaroid
    unawaited(
      PoiAnalyticsService.instance.logPoiPolaroidOpen(
        type: category,
        hasImage: (imageUrl ?? '').trim().isNotEmpty,
        title: title,
      ),
    );

    try {
      await showPolaroidPoiSheet(
        context: context,
        title: title,
        description: description.isEmpty
            ? 'Aucune description disponible'
            : description,
        imageUrl: (imageUrl ?? '').trim().isEmpty ? null : imageUrl,
        meta: meta,
        hours: openingHours,
        phone: phone,
        website: website,
        whatsapp: whatsapp,
        email: email,
        address: address,
        mapsUrl: mapsUrl,
        lat: lat,
        lng: lng,
        countryId: countryId,
        eventId: eventId,
        circuitId: circuitId,
        poiId: poiId,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ POI polaroid display error: $e');
      }
    } finally {
      _isPoiPopupShowing = false;
    }
  }

  /// Démarre ou arrête le tracking GPS de la position utilisateur.
  ///
  /// Le tracking partage la position avec le groupe de l'utilisateur à intervalles réguliers.
  Future<void> _toggleTracking() async {
    // Arrêter le tracking si déjà actif
    if (_isTracking) {
      _geo.stopTracking();
      if (mounted) {
        setState(() => _isTracking = false);
      }
      return;
    }

    // Vérifier l'authentification
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }

    // Charger le profil utilisateur
    final profile = await AuthService.instance.getUserProfile(uid);
    if (!mounted) return;

    final groupId = profile?.groupId;
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

  Future<void> _loadUserGroupId() async {
    try {
      if (Firebase.apps.isEmpty) return;
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

  void _updateLanguageFlag() {
    try {
      final langService = Get.find<LanguageService>();
      _currentLanguageFlag = langService.getLanguageFlag(
        langService.currentLanguageCode,
      );
    } catch (_) {
      // En cas d'erreur (service non prêt), ne rien afficher.
      _currentLanguageFlag = '';
    }
  }

  void _cycleLanguage() {
    final langService = Get.find<LanguageService>();
    final langs = ['fr', 'en', 'es'];
    final current = langService.currentLanguageCode;
    final idx = langs.indexOf(current);
    final next = langs[(idx + 1) % langs.length];
    langService.changeLanguage(next);
    // Mettre à jour le drapeau immédiatement (pas de délai Obx)
    _updateLanguageFlag();
    setState(() {});
  }

  void _selectAction(_MapAction action, String label) {
    setState(() => _selectedAction = action);
    _renderMarketPoiMarkers();
  }

  void _toggleActionsMenu() {
    if (_showActionsMenu) {
      _menuAnimController.reverse();
      Future.delayed(_menuAnimationDuration, () {
        if (mounted && _showActionsMenu) {
          setState(() => _showActionsMenu = false);
        }
      });
      return;
    }

    setState(() => _showActionsMenu = true);
    // Démarrer l'animation immédiatement depuis la position cachée (droite)
    _menuAnimController.forward(from: 0.0);
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

  Future<void> _showMapProjectsSelector() async {
    final selection = await showMarketMapCircuitSelectorSheet(
      context,
      service: _marketMapServiceOrCreate,
      initial: _marketPoiSelection.enabled ? _marketPoiSelection : null,
      disableKeyboardInput: true,
    );
    if (selection == null || !mounted) return;

    setState(() {
      _marketPoiSelection = selection;
    });

    await _applyMarketPoiSelection(selection, resetPoiFilter: true);
  }

  void _openMarketplaceForSelectedEvent() {
    final countryId = _marketPoiSelection.country?.id;
    final countryName = _marketPoiSelection.country?.name;
    final eventId = _marketPoiSelection.event?.id;
    final eventName = _marketPoiSelection.event?.name;
    final circuitId = _marketPoiSelection.circuit?.id;
    final circuitName = _marketPoiSelection.circuit?.name;

    Navigator.pushNamed(
      context,
      '/boutique-photo',
      arguments: <String, dynamic>{
        if (countryId != null && countryId.trim().isNotEmpty)
          'countryId': countryId,
        if (countryName != null && countryName.trim().isNotEmpty)
          'countryName': countryName,
        if (eventId != null && eventId.trim().isNotEmpty) 'eventId': eventId,
        if (eventName != null && eventName.trim().isNotEmpty)
          'eventName': eventName,
        if (circuitId != null && circuitId.trim().isNotEmpty)
          'circuitId': circuitId,
        if (circuitName != null && circuitName.trim().isNotEmpty)
          'circuitName': circuitName,
      },
    );
  }

  /// Ferme automatiquement le menu de navigation après un délai.
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

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder capture les changements de taille du widget parent.
    // Essentiel pour détecter : resize fenêtre, rotation, split-screen, clavier
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = ui.Size(constraints.maxWidth, constraints.maxHeight);
        // PostFrameCallback garantit que le resize est appelé APRÈS
        // que le layout soit terminé, évitant les conflits avec setState
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scheduleResize(size);
        });

        return _buildContent(context, size);
      },
    );
  }

  Widget _buildContent(BuildContext context, ui.Size size) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final bottomDockOffset = bottomInset + 10.0;

    const bottomActionSize = 60.0;
    const bottomActionIconSize = 26.0;
    const bottomBarHeight = 84.0;
    const collapsedDockWidth = 84.0;
    final expandedDockWidth = (size.width - 24)
        .clamp(collapsedDockWidth, 304.0)
        .toDouble();

    if (!_useMapboxTiles && _isResolvingMapboxToken) {
      return const Scaffold(
        body: Center(
          child: SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
      );
    }

    if (!_useMapboxTiles) {
      return Scaffold(
        appBar: AppBar(title: const Text('Carte 3D')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 64,
                  color: Colors.orange,
                ),
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
        statusBarColor: Colors.transparent, // Rend le fond transparent
        statusBarIconBrightness: Brightness.dark, // Icônes noires
        statusBarBrightness: Brightness.light,
        systemStatusBarContrastEnforced:
            false, // Désactive le filtre automatique
        systemNavigationBarColor: Colors.transparent, // Navigation transparente
        systemNavigationBarContrastEnforced:
            false, // Désactive le filtre navigation
      ),
      child: Scaffold(
        extendBody:
            true, // Permet à la carte de passer SOUS la barre de navigation
        extendBodyBehindAppBar:
            true, // IMPORTANT : la carte passera sous la barre d'état
        body: Stack(
          clipBehavior: Clip.none,
          children: [
            // Carte Mapbox 3D - Occupe tout l'écran
            Positioned.fill(
              child: RepaintBoundary(
                // Optimise les performances de rendu
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: Container(
                    color:
                        Colors.black, // Couleur de fond pendant le chargement
                    child: _mapCanBeCreated
                        ? MapWidget(
                            key: ValueKey(
                              'map_${size.width.toInt()}x${size.height.toInt()}_$_mapTick',
                            ),
                            styleUri: 'mapbox://styles/mapbox/streets-v12',
                            cameraOptions: CameraOptions(
                              center: Point(
                                coordinates: _userPos ?? _fallbackCenter,
                              ),
                              zoom: _userPos != null ? _userZoom : _defaultZoom,
                              pitch: _defaultPitch,
                              bearing: 0.0,
                            ),
                            onMapCreated: _onMapCreated,
                            onStyleLoadedListener: _onStyleLoaded,
                            onTapListener: (gestureContext) {
                              _onMapTap(gestureContext.touchPosition);
                            },
                          )
                        : const SizedBox.expand(),
                  ),
                ),
              ),
            ),

            // Boussole (demi-flèche rouge)
            const Positioned(top: 104, right: 14, child: _HalfRedCompass()),

            Positioned(
              left: 14,
              top: 10,
              child: SafeArea(
                child: _MapTopLeftControls(
                  canRecenter: _userPos != null,
                  onRecenter: () {
                    _recenterOnUser();
                  },
                  onZoomIn: () {
                    _adjustZoom(1.0);
                  },
                  onZoomOut: () {
                    _adjustZoom(-1.0);
                  },
                ),
              ),
            ),

            // Overlay actions menu
            if (_showActionsMenu)
              Positioned.fill(
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
                        margin: const EdgeInsets.only(
                          right: -6,
                          top: _actionsMenuTopOffset,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(30),
                          ),
                          boxShadow: MasliveTheme.floatingShadow,
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(30),
                          ),
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 0,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.58),
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(30),
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.42),
                                ),
                              ),
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _ActionItem(
                                      label: 'Carte',
                                      icon: Icons.map_rounded,
                                      selected: _marketPoiSelection.enabled,
                                      onTap: () {
                                        _showMapProjectsSelector();
                                        _closeNavWithDelay();
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    _ActionItem(
                                      label: 'POIs',
                                      icon: Icons.place_rounded,
                                      selected: _marketPoiSelection.enabled,
                                      onTap: () {
                                        _openMarketPoiSelector();
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
                                      label: '',
                                      iconWidget: Image.asset(
                                        'assets/images/icon wc parking.png',
                                        fit: BoxFit.cover,
                                        filterQuality: FilterQuality.high,
                                      ),
                                      fullBleed: true,
                                      showBorder: false,
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
                                      iconWidget: Center(
                                        child: _currentLanguageFlag.isEmpty
                                            ? const SizedBox.shrink()
                                            : Text(
                                                _currentLanguageFlag,
                                                style: const TextStyle(
                                                  fontSize: 32,
                                                  height: 1,
                                                ),
                                              ),
                                      ),
                                      fullBleed: true,
                                      tintOnSelected: false,
                                      showBorder: false,
                                      selected:
                                          _selectedAction == _MapAction.wc,
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
                      ),
                    ),
                  ),
                ),
              ),

            // Tracking pill
            if (_isTracking)
              Positioned(
                left: 16,
                right: 16,
                bottom: bottomDockOffset + bottomBarHeight + 12,
                child: _TrackingPill(
                  isTracking: _isTracking,
                  onToggle: _toggleTracking,
                ),
              ),

            // Bottom bar
            Positioned(
              right: 12,
              bottom: bottomDockOffset,
              child: AnimatedBuilder(
                animation: _bottomBarIconsTranslateAnimation,
                builder: (context, child) {
                  final reveal = Curves.easeOutCubic.transform(
                    _bottomBarIconsTranslateAnimation.value
                        .clamp(0.0, 1.0)
                        .toDouble(),
                  );
                  final dockWidth = ui.lerpDouble(
                    collapsedDockWidth,
                    expandedDockWidth,
                    reveal,
                  )!;

                  return SizedBox(width: dockWidth, child: child);
                },
                child: MasliveFloatingGlassDock(
                  height: bottomBarHeight,
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
                  child: Row(
                    children: [
                      AnimatedBuilder(
                        animation: _bottomBarIconsTranslateAnimation,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            StreamBuilder<User?>(
                              stream: AuthService.instance.authStateChanges,
                              builder: (context, snap) {
                                final user = snap.data;
                                final pseudo =
                                    (user?.displayName ??
                                            user?.email ??
                                            'Profil')
                                        .trim();

                                return Tooltip(
                                  message: pseudo.isEmpty ? 'Profil' : pseudo,
                                  child: InkWell(
                                    onTap: () {
                                      if (user != null) {
                                        Navigator.pushNamed(
                                          context,
                                          '/account-ui',
                                        );
                                      } else {
                                        Navigator.pushNamed(context, '/login');
                                      }
                                    },
                                    customBorder: const CircleBorder(),
                                    child: MasliveProfileIcon(
                                      size: bottomActionSize,
                                      badgeSizeRatio: 0.22,
                                      showBadge: user != null,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 12),
                          ],
                        ),
                        builder: (context, child) {
                          final progress =
                              _bottomBarIconsTranslateAnimation.value;
                          final reveal = progress.clamp(0.0, 1.0).toDouble();
                          return IgnorePointer(
                            ignoring: reveal < 0.95,
                            child: Opacity(
                              opacity: reveal,
                              child: ClipRect(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: reveal,
                                  child: Transform.translate(
                                    offset: Offset(-96.0 * (1.0 - reveal), 0),
                                    child: child,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const Spacer(),
                      AnimatedBuilder(
                        animation: _bottomBarIconsTranslateAnimation,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            MasliveGradientIconButton(
                              icon: Icons.shopping_bag_rounded,
                              size: bottomActionSize,
                              iconSize: bottomActionIconSize,
                              tooltip: l10n.AppLocalizations.of(context)!.shop,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const StorexShopPage(
                                      shopId: 'global',
                                      groupId: 'MASLIVE',
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 10),
                            MasliveGradientIconButton(
                              icon: Icons.photo_library_outlined,
                              size: bottomActionSize,
                              iconSize: bottomActionIconSize,
                              tooltip: _marketPoiSelection.event != null
                                  ? 'Médias de l’événement'
                                  : 'Marché des médias',
                              onTap: _openMarketplaceForSelectedEvent,
                            ),
                          ],
                        ),
                        builder: (context, child) {
                          final progress =
                              _bottomBarIconsTranslateAnimation.value;
                          final reveal = progress.clamp(0.0, 1.0).toDouble();
                          return IgnorePointer(
                            ignoring: reveal < 0.95,
                            child: Opacity(
                              opacity: reveal,
                              child: ClipRect(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  widthFactor: reveal,
                                  child: Transform.translate(
                                    offset: Offset(200.0 * (1.0 - reveal), 0),
                                    child: child,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      MasliveGradientIconButton(
                        icon: Icons.menu_rounded,
                        size: bottomActionSize,
                        iconSize: bottomActionIconSize,
                        tooltip: l10n.AppLocalizations.of(context)!.menu,
                        onTap: () {
                          _toggleActionsMenu();
                        },
                      ),
                    ],
                  ),
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
  final IconData? icon;
  final Widget? iconWidget;
  final bool selected;
  final VoidCallback onTap;
  final bool fullBleed;
  final bool tintOnSelected;
  final bool showBorder;

  static const double _buttonSize = 56;
  static const double _iconSize = 26;
  static const double _iconSizeNoLabel = 30;

  const _ActionItem({
    required this.label,
    this.icon,
    this.iconWidget,
    required this.selected,
    required this.onTap,
    this.fullBleed = false,
    this.tintOnSelected = true,
    this.showBorder = true,
  }) : assert(icon != null || iconWidget != null);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _buttonSize,
        height: _buttonSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.92),
          border: showBorder
              ? Border.all(
                  color: selected ? MasliveTheme.pink : MasliveTheme.divider,
                  width: selected ? 2.0 : 1.0,
                )
              : null,
          boxShadow: selected ? MasliveTheme.cardShadow : const [],
        ),
        child: fullBleed
            ? ClipOval(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ?iconWidget,
                    if (icon != null)
                      Center(
                        child: Icon(
                          icon,
                          size: _iconSize,
                          color: selected && tintOnSelected
                              ? MasliveTheme.pink
                              : MasliveTheme.textPrimary,
                        ),
                      ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (iconWidget != null)
                    IconTheme(
                      data: IconThemeData(
                        size: label.isEmpty ? _iconSizeNoLabel : _iconSize,
                        color: selected && tintOnSelected
                            ? MasliveTheme.pink
                            : MasliveTheme.textPrimary,
                      ),
                      child: iconWidget!,
                    )
                  else
                    Icon(
                      icon,
                      size: label.isEmpty ? _iconSizeNoLabel : _iconSize,
                      color: selected && tintOnSelected
                          ? MasliveTheme.pink
                          : MasliveTheme.textPrimary,
                    ),
                  if (label.isNotEmpty) const SizedBox(height: 4),
                  if (label.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: selected
                              ? Colors.white
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

class _HalfRedCompass extends StatelessWidget {
  const _HalfRedCompass();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.92),
        boxShadow: MasliveTheme.cardShadow,
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.navigation_rounded,
              size: 26,
              color: Color(0xFF111827),
            ),
            ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: 0.5,
                child: const Icon(
                  Icons.navigation_rounded,
                  size: 26,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapTopLeftControls extends StatelessWidget {
  const _MapTopLeftControls({
    required this.canRecenter,
    required this.onRecenter,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final bool canRecenter;
  final VoidCallback onRecenter;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MapOverlayControlButton(
          icon: Icons.my_location_rounded,
          onTap: canRecenter ? onRecenter : null,
        ),
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(18),
            boxShadow: MasliveTheme.cardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MapOverlayControlButton(
                icon: Icons.add_rounded,
                onTap: onZoomIn,
                embedded: true,
              ),
              Container(
                width: 36,
                height: 1,
                color: MasliveTheme.divider.withValues(alpha: 0.7),
              ),
              _MapOverlayControlButton(
                icon: Icons.remove_rounded,
                onTap: onZoomOut,
                embedded: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MapOverlayControlButton extends StatelessWidget {
  const _MapOverlayControlButton({
    required this.icon,
    required this.onTap,
    this.embedded = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(embedded ? 18 : 20),
        child: SizedBox(
          width: embedded ? 36 : 44,
          height: embedded ? 36 : 44,
          child: Icon(
            icon,
            size: embedded ? 20 : 22,
            color: onTap == null
                ? MasliveTheme.textSecondary.withValues(alpha: 0.45)
                : const Color(0xFF111827),
          ),
        ),
      ),
    );

    if (embedded) return child;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        boxShadow: MasliveTheme.cardShadow,
      ),
      child: child,
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
                      ? 'Actif (${_HomeMapPage3DState._trackingIntervalSeconds}s)'
                      : 'Inactif',
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
