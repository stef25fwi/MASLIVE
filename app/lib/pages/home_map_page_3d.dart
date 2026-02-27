import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'
    hide LocationSettings;
import 'package:geolocator/geolocator.dart' hide Position;
import 'package:geolocator/geolocator.dart'
    as geo
    show Position, LocationSettings;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ui/theme/maslive_theme.dart';
import '../ui/widgets/gradient_header.dart';
import '../ui/widgets/gradient_icon_button.dart';
import '../ui/widgets/maslive_card.dart';
import '../ui/widgets/maslive_profile_icon.dart';
import '../services/auth_service.dart';
import '../services/geolocation_service.dart';
import '../services/language_service.dart';
import '../services/mapbox_token_service.dart';
import '../services/market_map_service.dart';
import '../models/market_poi.dart';
import '../ui/widgets/marketmap_poi_selector_sheet.dart';
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
  static const Duration _mapReadyDelay = Duration(milliseconds: 300);
  static const Duration _navCloseDelay = Duration(milliseconds: 2500);
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
  static const double _actionsMenuTopOffset = 190;

  // ========== ÉTAT UI ==========
  bool _showActionsMenu = false;
  late AnimationController _menuAnimController;
  late Animation<Offset> _menuSlideAnimation;
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
  final MarketMapService _marketMapService = MarketMapService();
  MarketMapPoiSelection _marketPoiSelection =
      const MarketMapPoiSelection.disabled();
  StreamSubscription? _marketPoisSub;
  List<MarketPoi> _marketPois = const <MarketPoi>[];

  // === MarketMap POIs (GeoJSON Layers) ===
  static const String _mmPoiSourceId = 'mm_pois_src';
  static const String _mmPoiLayerPrefix = 'mm_pois_layer__'; // + type
  GeoJsonSource? _mmPoiSource;
  final Set<String> _mmPoiLayerIds = <String>{};

  // === MarketMap Route (Style Pro via GeoJSON Layers) ===
  static const String _mmRouteSourceId = 'mm_route_src';
  static const String _mmRouteSegmentsSourceId = 'mm_route_segments_src';
  static const String _mmRouteLayerShadowId = 'mm_route_shadow';
  static const String _mmRouteLayerGlowId = 'mm_route_glow';
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

  @override
  void initState() {
    super.initState();

    // Observer pour détecter les changements de lifecycle et de métriques (resize, rotation)
    WidgetsBinding.instance.addObserver(this);

    // Initialisation du token Mapbox (peut être vide au démarrage)
    _initMapboxToken();

    // Synchroniser l'état de tracking avec le service
    _isTracking = _geo.isTracking;

    // Configuration de l'animation du menu latéral
    _menuAnimController = AnimationController(
      duration: _menuAnimationDuration,
      vsync: this,
    )..value = 0.0;
    _menuSlideAnimation =
        Tween<Offset>(begin: const Offset(1.2, 0.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _menuAnimController,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );

    // Chargement asynchrone des données essentielles
    _bootstrapLocation(); // Permissions GPS + position initiale
    _loadUserGroupId(); // Données utilisateur Firebase
    _loadRuntimeMapboxToken(); // Token Mapbox dynamique
    // Préchargement des icônes pour éviter les retards d'affichage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(
        const AssetImage('assets/images/icon wc parking.png'),
        context,
      );
    });
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

  Future<void> _openMarketPoiSelector() async {
    final selection = await showMarketMapPoiSelectorSheet(
      context,
      service: _marketMapService,
      initial: _marketPoiSelection,
    );
    if (selection == null) return;
    if (!mounted) return;

    setState(() {
      _marketPoiSelection = selection;
    });

    await _applyMarketPoiSelection(selection);
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
      });
      await _renderMarketPoiMarkers();
      await _clearMarketCircuitRoute();
      return;
    }

    final circuit = selection.circuit!;
    final styleUrl = circuit.styleUrl?.trim();
    if (styleUrl != null && styleUrl.isNotEmpty && _mapboxMap != null) {
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

    _marketPoisSub = _marketMapService
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
        await map.style.setStyleSourceProperty(
          _mmRouteSourceId,
          'data',
          empty,
        );
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

  static Color _hsvToColor(double h, double s, double v) {
    final hh = (h % 360) / 60.0;
    final c = v * s;
    final x = c * (1 - ((hh % 2) - 1).abs());
    final m = v - c;

    double r1 = 0, g1 = 0, b1 = 0;
    if (hh >= 0 && hh < 1) {
      r1 = c;
      g1 = x;
    } else if (hh < 2) {
      r1 = x;
      g1 = c;
    } else if (hh < 3) {
      g1 = c;
      b1 = x;
    } else if (hh < 4) {
      g1 = x;
      b1 = c;
    } else if (hh < 5) {
      r1 = x;
      b1 = c;
    } else {
      r1 = c;
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

  static String _buildSegmentsFeatureCollection(
    List<Position> pts,
    RouteStyleConfig cfg, {
    required int animTick,
  }) {
    if (pts.length < 2) return _emptyRouteFeatureCollection();

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

      features.add({
        'type': 'Feature',
        'properties': {
          'color': _toHexRgba(color, opacity: opacity),
          'width': cfg.mainWidth,
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
    return _routeFeatureCollection([
      {
        'type': 'Feature',
        'properties': {
          'color': _toHexRgba(cfg.mainColor, opacity: cfg.opacity),
          'width': cfg.mainWidth,
          'opacity': cfg.opacity,
        },
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            for (final p in pts) [p.lng.toDouble(), p.lat.toDouble()],
          ],
        },
      }
    ]);
  }

  void _syncMarketRouteAnimTimer(RouteStyleConfig cfg) {
    final needsAnim = cfg.pulseEnabled || cfg.rainbowEnabled;
    if (!needsAnim) {
      _routeAnimTimer?.cancel();
      _routeAnimTimer = null;
      return;
    }

    final periodMs = (cfg.rainbowEnabled
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
            GeoJsonSource(id: _mmRouteSourceId, data: _emptyRouteFeatureCollection()),
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

        // Layers order: shadow -> glow -> casing -> main
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

        try {
          await style.addLayer(
            LineLayer(
              id: _mmRouteLayerCasingId,
              sourceId: _mmRouteSourceId,
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
      }
    ]);

    final useSegments =
        c.rainbowEnabled || c.trafficDemoEnabled || c.vanishingEnabled;
    final segmentsFc = useSegments
        ? _buildSegmentsFeatureCollection(pts, c, animTick: animTick ?? _routeAnimTick)
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
      _mmRouteLayerCasingId,
      _mmRouteLayerMainId,
    ]) {
      await safeSet(layerId, 'line-join', join);
      await safeSet(layerId, 'line-cap', cap);
    }

    // Shadow
    final shadowOpacity = c.shadowEnabled ? c.shadowOpacity : 0.0;
    await safeSet(_mmRouteLayerShadowId, 'line-opacity', shadowOpacity);
    await safeSet(_mmRouteLayerShadowId, 'line-width', max(1.0, c.casingWidth));
    await safeSet(_mmRouteLayerShadowId, 'line-blur', c.shadowBlur);

    // Glow (+ pulse)
    double glowOpacity = c.glowEnabled ? c.glowOpacity : 0.0;
    if (c.glowEnabled && c.pulseEnabled) {
      final phase = ((animTick ?? _routeAnimTick) % 60) / 60.0;
      final wave = 0.5 + 0.5 * sin(2 * pi * phase);
      glowOpacity = (0.20 + wave * (c.glowOpacity - 0.20)).clamp(0.0, 1.0);
    }
    await safeSet(_mmRouteLayerGlowId, 'line-opacity', glowOpacity);
    await safeSet(
      _mmRouteLayerGlowId,
      'line-width',
      max(1.0, c.casingWidth + c.glowWidth),
    );
    await safeSet(_mmRouteLayerGlowId, 'line-blur', c.glowBlur);
    await safeSet(_mmRouteLayerGlowId, 'line-color', c.mainColor.toARGB32());

    // Casing
    final casingOpacity = (c.casingWidth <= 0) ? 0.0 : c.opacity;
    await safeSet(_mmRouteLayerCasingId, 'line-opacity', casingOpacity);
    await safeSet(_mmRouteLayerCasingId, 'line-width', max(0.0, c.casingWidth));
    await safeSet(
      _mmRouteLayerCasingId,
      'line-color',
      c.casingColor.toARGB32(),
    );

    // Main layer from feature props
    await safeSet(_mmRouteLayerMainId, 'line-color', ['get', 'color']);
    await safeSet(_mmRouteLayerMainId, 'line-width', ['get', 'width']);
    await safeSet(_mmRouteLayerMainId, 'line-opacity', ['get', 'opacity']);

    if (c.dashEnabled) {
      await safeSet(_mmRouteLayerMainId, 'line-dasharray', [c.dashLength, c.dashGap]);
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
      final ref = _marketMapService.circuitRef(
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
        final color = _parseHexColor(legacy['color']?.toString()) ??
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
      if (lat is num && lng is num)
        return Position(lng.toDouble(), lat.toDouble());
    }

    if (it is List && it.length >= 2) {
      final lng = it[0];
      final lat = it[1];
      if (lng is num && lat is num)
        return Position(lng.toDouble(), lat.toDouble());
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

    // Mapping de compat (si tes couches utilisent d'autres noms)
    if (norm == 'visiter') return 'visit';
    if (norm == 'tour') return 'visit';
    if (norm == 'toilet' || norm == 'toilets') return 'wc';

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
      final imageUrl = (d.imageUrl ?? d.photoUrl ?? d.image ?? '')
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
        if (m is Map) meta = Map<String, dynamic>.from(m);
      } catch (_) {
        // ignore
      }

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

          // meta brute (si utile côté UI)
          'meta': meta,
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
      final visible = (wanted == null) ? true : (type == wanted);
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

    // Incrémente le tick pour forcer un rebuild de la carte via ValueKey
    // Protégé par mounted pour éviter les setState après dispose
    if (mounted) {
      try {
        setState(() => _mapTick++);
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

    // Ignorer si la taille n'a pas changé (optimisation)
    if (_lastSize == size) return;
    _lastSize = size;

    // Annuler le timer précédent (debounce)
    _debounce?.cancel();

    // Attendre que le resize soit stabilisé avant de rebuilder
    _debounce = Timer(_resizeDebounceDelay, () {
      if (!mounted) return; // Sécurité supplémentaire

      try {
        // 1) Autoriser la création de la carte seulement une fois que les contraintes
        // sont stabilisées (fix “premier layout” : carte initialisée trop tôt).
        // 2) Incrémenter le tick force Flutter à recréer le MapWidget avec une nouvelle Key.
        setState(() {
          _mapCanBeCreated = true;
          _mapTick++;
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
    _checkIfReady();

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

    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen(
          (pos) {
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
  }

  /// Notifie que la carte est prête après un court délai.
  ///
  /// Utilisé par splash_wrapper_page pour masquer le splash screen.
  void _checkIfReady() {
    if (_isMapReady && !mapReadyNotifier.value) {
      Future.delayed(_mapReadyDelay, () {
        if (mounted) {
          mapReadyNotifier.value = true;
        }
      });
    }
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
    _mapboxMap = mapboxMap;

    try {
      // 1. Activer tous les gestes 3D (rotation, inclinaison, zoom)
      await mapboxMap.gestures.updateSettings(
        GesturesSettings(
          pitchEnabled: true, // Inclinaison vertical
          rotateEnabled: true, // Rotation à deux doigts
          scrollEnabled: true, // Pan/déplacement
          pinchToZoomEnabled: true, // Zoom pinch
        ),
      );

      // 2. Ajouter les bâtiments 3D au style
      await _add3dBuildings();

      // 3. Créer les annotation managers pour les marqueurs
      _userAnnotationManager = await mapboxMap.annotations
          .createPointAnnotationManager();
      _groupsAnnotationManager = await mapboxMap.annotations
          .createPointAnnotationManager();
      _circuitsAnnotationManager = await mapboxMap.annotations
          .createPolylineAnnotationManager();
    } catch (e) {
      debugPrint('⚠️ Erreur configuration carte: $e');
    }

    // 4. Marquer la carte comme prête
    if (mounted) {
      setState(() {
        _isMapReady = true;
        _checkIfReady();
      });
    }

    // 5. Afficher le marqueur utilisateur si position disponible
    await _updateUserMarker();

    // 5b. MarketMap POIs via GeoJSON layers (plus scalable)
    await _renderMarketPoiMarkers(); // (on garde le nom, mais on change l'implémentation)

    // 6. Appliquer le resize initial si LayoutBuilder a déjà capturé la taille
    if (_lastSize != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduleResize(_lastSize!);
      });
    }
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

      final feature = res.first?.queriedFeature.feature;
      if (feature == null) return;

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
      final name = (props['name'] ?? '').toString();
      final desc = (props['desc'] ?? '').toString();
      final type = (props['type'] ?? '').toString();
      final imageUrl = (props['imageUrl'] ?? '').toString();
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
      final metaRaw = props['meta'];
      if (metaRaw is Map) {
        meta = metaRaw.map((k, v) => MapEntry(k.toString(), v));
      } else if (metaRaw is String && metaRaw.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(metaRaw);
          if (decoded is Map) {
            meta = decoded.map((k, v) => MapEntry(k.toString(), v));
          }
        } catch (_) {
          // ignore
        }
      }

      if (!mounted) return;
      _showPoiPolaroid(
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
      );
    } catch (e) {
      debugPrint('⚠️ Tap POI queryRenderedFeatures error: $e');
    }
  }

  /// Affiche un overlay style "polaroïd" pour un POI.
  void _showPoiPolaroid({
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
  }) {
    showGeneralDialog(
      context: context,
      barrierLabel: 'POI',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Center(
          child: _PolaroidCardDialog(
            title: title,
            description: description,
            category: category,
            imageUrl: imageUrl,
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
            meta: meta,
            onClose: () => Navigator.of(context).pop(),
          ),
        );
      },
      transitionBuilder: (dialogContext, anim, secondaryAnimation, child) {
        final curved = Curves.easeOutBack.transform(anim.value);
        return Transform.scale(
          scale: 0.85 + 0.15 * curved,
          child: Opacity(opacity: anim.value, child: child),
        );
      },
    );
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

  void _cycleLanguage() {
    final langService = Get.find<LanguageService>();
    final langs = ['fr', 'en', 'es'];
    final current = langService.currentLanguageCode;
    final idx = langs.indexOf(current);
    final next = langs[(idx + 1) % langs.length];
    langService.changeLanguage(next);
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
      service: _marketMapService,
      initial: _marketPoiSelection.enabled ? _marketPoiSelection : null,
    );
    if (selection == null || !mounted) return;

    setState(() {
      _marketPoiSelection = selection;
    });

    await _applyMarketPoiSelection(selection);
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
                          right: 0,
                          top: _actionsMenuTopOffset,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.40),
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
                                label: l10n.AppLocalizations.of(context)!.visit,
                                icon: Icons.map_outlined,
                                selected: _selectedAction == _MapAction.visiter,
                                onTap: () {
                                  _selectAction(_MapAction.visiter, 'Visiter');
                                  _closeNavWithDelay();
                                },
                              ),
                              const SizedBox(height: 8),
                              _ActionItem(
                                label: l10n.AppLocalizations.of(context)!.food,
                                icon: Icons.fastfood_rounded,
                                selected: _selectedAction == _MapAction.food,
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
                                    _selectedAction == _MapAction.assistance,
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
                                selected: _selectedAction == _MapAction.parking,
                                onTap: () {
                                  _selectAction(_MapAction.parking, 'Parking');
                                  _closeNavWithDelay();
                                },
                              ),
                              const SizedBox(height: 8),
                              _ActionItem(
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
                        _toggleActionsMenu();
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
  final IconData? icon;
  final Widget? iconWidget;
  final bool selected;
  final VoidCallback onTap;
  final bool fullBleed;
  final bool tintOnSelected;
  final bool showBorder;

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
        width: 60,
        height: 60,
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
                    if (iconWidget != null) iconWidget!,
                    if (icon != null)
                      Center(
                        child: Icon(
                          icon,
                          size: 28,
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
                        size: label.isEmpty ? 32 : 28,
                        color: selected && tintOnSelected
                            ? MasliveTheme.pink
                            : MasliveTheme.textPrimary,
                      ),
                      child: iconWidget!,
                    )
                  else
                    Icon(
                      icon,
                      size: label.isEmpty ? 32 : 28,
                      color: selected && tintOnSelected
                          ? MasliveTheme.pink
                          : MasliveTheme.textPrimary,
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

class _PolaroidCardDialog extends StatelessWidget {
  final String title;
  final String description;
  final String category;
  final String? imageUrl;
  final double? lng;
  final double? lat;

  final String address;
  final String openingHours;
  final String phone;
  final String website;
  final String instagram;
  final String facebook;
  final String whatsapp;
  final String email;
  final String mapsUrl;
  final Map<String, dynamic> meta;
  final VoidCallback onClose;

  const _PolaroidCardDialog({
    required this.title,
    required this.description,
    required this.category,
    required this.onClose,
    this.imageUrl,
    this.lng,
    this.lat,
    this.address = '',
    this.openingHours = '',
    this.phone = '',
    this.website = '',
    this.instagram = '',
    this.facebook = '',
    this.whatsapp = '',
    this.email = '',
    this.mapsUrl = '',
    this.meta = const <String, dynamic>{},
  });

  Future<void> _openUrl(String raw) async {
    final s = raw.trim();
    if (s.isEmpty) return;

    // Normalise si user met "www..."
    final uri = Uri.tryParse(s.startsWith('http') ? s : 'https://$s');
    if (uri == null) return;

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _callPhone(String raw) async {
    final s = raw.trim();
    if (s.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: s);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openEmail(String raw) async {
    final s = raw.trim();
    if (s.isEmpty) return;
    final uri = Uri(scheme: 'mailto', path: s);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openWhatsApp(String raw) async {
    final s = raw.trim();
    if (s.isEmpty) return;

    // accepte numéro ou lien direct
    final uri = Uri.tryParse(
      s.startsWith('http')
          ? s
          : 'https://wa.me/${s.replaceAll(RegExp(r"[^0-9]"), "")}',
    );
    if (uri == null) return;

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openMaps() async {
    // priorité mapsUrl, sinon construit si coords
    if (mapsUrl.trim().isNotEmpty) return _openUrl(mapsUrl);

    if (lat != null && lng != null) {
      final uri = Uri.parse(
        'https://www.google.com/maps?q=${lat!.toStringAsFixed(6)},${lng!.toStringAsFixed(6)}',
      );
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget infoRow(
      IconData icon,
      String label,
      String value, {
      VoidCallback? onTap,
    }) {
      if (value.trim().isEmpty) return const SizedBox.shrink();
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: const Color(0xFF3A3A3A)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF2B2B2B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF1F1F1F),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 10),
                const Icon(
                  Icons.open_in_new,
                  size: 16,
                  color: Color(0xFF6A6A6A),
                ),
              ],
            ],
          ),
        ),
      );
    }

    Widget actionChip(String text, IconData icon, VoidCallback onTap) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F2),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: const Color(0xFF2E2E2E)),
              const SizedBox(width: 8),
              Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: Transform.rotate(
        angle: -0.03,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Carte Polaroid papier
            Container(
              width: 340,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F6EF), // papier chaud
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 26,
                    spreadRadius: 2,
                    offset: const Offset(0, 14),
                    color: Colors.black.withValues(alpha: 0.30),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Texture papier + vignette légère
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: CustomPaint(
                        painter: _PaperGrainPainter(seed: title.hashCode),
                      ),
                    ),
                  ),

                  // Contenu
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Photo
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: AspectRatio(
                          aspectRatio: 1.0,
                          child: _PhotoOrPlaceholder(imageUrl: imageUrl),
                        ),
                      ),

                      // Bande “signature” (effet polaroid)
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF1C1C1C),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (category.trim().isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFFFFFFF,
                                  ).withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: const Color(0xFFE3DDCF),
                                  ),
                                ),
                                child: Text(
                                  category,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF444444),
                                  ),
                                ),
                              ),
                            if (lat != null && lng != null)
                              actionChip(
                                'Maps',
                                Icons.map_outlined,
                                () => _openMaps(),
                              ),
                            if (phone.trim().isNotEmpty)
                              actionChip(
                                'Appeler',
                                Icons.call,
                                () => _callPhone(phone),
                              ),
                            if (website.trim().isNotEmpty)
                              actionChip(
                                'Site',
                                Icons.public,
                                () => _openUrl(website),
                              ),
                          ],
                        ),
                      ),

                      if (description.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            description,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF303030),
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Color(0xFFE3DDCF)),
                      const SizedBox(height: 8),

                      // Fiche complète
                      infoRow(
                        Icons.location_on_outlined,
                        'Adresse',
                        address,
                        onTap: () => _openMaps(),
                      ),
                      infoRow(
                        Icons.schedule_outlined,
                        'Horaires',
                        openingHours,
                      ),
                      infoRow(
                        Icons.call_outlined,
                        'Téléphone',
                        phone,
                        onTap: () => _callPhone(phone),
                      ),
                      infoRow(
                        Icons.mail_outline,
                        'Email',
                        email,
                        onTap: () => _openEmail(email),
                      ),
                      infoRow(
                        Icons.public,
                        'Site web',
                        website,
                        onTap: () => _openUrl(website),
                      ),
                      infoRow(
                        Icons.camera_alt_outlined,
                        'Instagram',
                        instagram,
                        onTap: () => _openUrl(instagram),
                      ),
                      infoRow(
                        Icons.facebook_outlined,
                        'Facebook',
                        facebook,
                        onTap: () => _openUrl(facebook),
                      ),
                      infoRow(
                        Icons.chat_outlined,
                        'WhatsApp',
                        whatsapp,
                        onTap: () => _openWhatsApp(whatsapp),
                      ),

                      // Bonus: afficher 1–2 infos meta utiles
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Infos',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF2B2B2B),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _prettyMeta(meta),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Bouton X en haut à droite
            Positioned(
              top: -10,
              right: -10,
              child: Material(
                color: const Color(0xFFF9F6EF),
                shape: const CircleBorder(),
                elevation: 6,
                child: IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                  tooltip: 'Fermer',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _prettyMeta(Map<String, dynamic> meta) {
    // On évite d’afficher des gros blobs : seulement des paires simples
    final keys = meta.keys.take(6).toList();
    final parts = <String>[];
    for (final k in keys) {
      final v = meta[k];
      if (v == null) continue;
      final s = v.toString();
      if (s.length > 60) continue;
      parts.add('$k: $s');
    }
    return parts.join(' • ');
  }
}

class _PhotoOrPlaceholder extends StatelessWidget {
  final String? imageUrl;
  const _PhotoOrPlaceholder({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _placeholder(),
        loadingBuilder: (ctx, child, loading) {
          if (loading == null) return child;
          return Container(
            color: const Color(0xFFEFE9DD),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFEFE9DD),
      alignment: Alignment.center,
      child: const Icon(Icons.photo, size: 54, color: Color(0xFF9E9E9E)),
    );
  }
}

/// Texture papier + vignette légère + grains
class _PaperGrainPainter extends CustomPainter {
  final int seed;
  _PaperGrainPainter({required this.seed});

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    // Vignette très légère
    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.06)],
        stops: const [0.70, 1.0],
      ).createShader(ui.Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(ui.Offset.zero & size, vignette);

    // Grain papier (petits points)
    final rnd = Random(seed);
    final p = Paint()..color = Colors.black.withValues(alpha: 0.035);
    final count = (size.width * size.height / 220).clamp(350, 900).toInt();

    for (int i = 0; i < count; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final r = (rnd.nextDouble() * 0.9) + 0.2;
      canvas.drawCircle(ui.Offset(x, y), r, p);
    }

    // Fibres (traits très fins)
    final f = Paint()
      ..color = Colors.black.withValues(alpha: 0.025)
      ..strokeWidth = 0.6;

    for (int i = 0; i < 110; i++) {
      final x1 = rnd.nextDouble() * size.width;
      final y1 = rnd.nextDouble() * size.height;
      final dx = (rnd.nextDouble() - 0.5) * 34;
      final dy = (rnd.nextDouble() - 0.5) * 10;
      canvas.drawLine(ui.Offset(x1, y1), ui.Offset(x1 + dx, y1 + dy), f);
    }
  }

  @override
  bool shouldRepaint(covariant _PaperGrainPainter oldDelegate) =>
      oldDelegate.seed != seed;
}
