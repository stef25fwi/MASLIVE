import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb;
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/mapbox_token_service.dart';
import '../services/auth_service.dart';
import '../services/geolocation_service.dart';
import '../services/home_controls_theme_service.dart';
import '../services/language_service.dart';
import '../ui/theme/maslive_theme.dart';
import '../ui/widgets/maslive_card.dart';
import '../ui/widgets/active_circuit_header_banner.dart';
import '../ui/widgets/maslive_standard_bottom_bar.dart';
import '../ui/widgets/mapbox_token_dialog.dart';
import '../ui/widgets/marketmap_poi_selector_sheet.dart';
import '../ui/widgets/polaroid_poi_sheet.dart';
import '../route_style_pro/services/route_style_pro_projection.dart';
import '../route_style_pro/models/route_style_config.dart' as rsp;
import '../ui/map/maslive_map.dart';
import '../ui/map/maslive_map_controller.dart' show MapMarker, MapPoint;
import 'splash_wrapper_page.dart' show mapReadyNotifier;
import '../l10n/app_localizations.dart' as l10n;
import '../services/market_map_service.dart';
import '../services/poi_popup_service.dart';
import '../models/market_poi.dart';
import '../models/group_circuit_public_position.dart';
import '../services/group/marketmap_group_public_position_service.dart';
import '../utils/mapbox_style_url.dart';
import '../utils/startup_trace.dart';
import '../utils/web_viewport_resize.dart';
import 'storex_shop_page.dart';
import 'home_vertical_nav.dart';

// Menu vertical: modes/actions (pour refléter la sélection UI)
// Note: seul le tracking et les projets sont pleinement câblés ici.
enum _MapAction { visiter, food, assistance, parking, wc, parkingWc }

/// Page de carte par défaut avec Mapbox en plein écran
class DefaultMapPage extends StatefulWidget {
  const DefaultMapPage({
    super.key,
    this.showBottomBar = true,
    this.openActionsMenuOnLoad = false,
    this.actionsMenuOpenSignal,
    this.actionsMenuCloseSignal,
  });

  final bool showBottomBar;
  final bool openActionsMenuOnLoad;
  final ValueListenable<int>? actionsMenuOpenSignal;
  final ValueListenable<int>? actionsMenuCloseSignal;

  @override
  State<DefaultMapPage> createState() => _DefaultMapPageState();
}

class _DefaultMapPageState extends State<DefaultMapPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  static const String _prefsKeyDidAutoOpenActionsMenuOnce =
      'default_map_page.did_auto_open_actions_menu_once';
  static const String _prefsKeyLastHomeStyleUrl =
      'default_map_page.last_home_style_url';

  // Constantes
  static const Duration _resizeDebounceDelay = Duration(milliseconds: 80);
  static const Duration _gpsTimeout = Duration(seconds: 8);
  static const int _gpsDistanceFilter = 8;
  static const Duration _menuAnimationDuration = Duration(milliseconds: 300);
  static const Duration _navCloseDelay = Duration(milliseconds: 1500);
  static const Duration _deferredHomeInitDelay = Duration(milliseconds: 850);
  static const int _trackingIntervalSeconds = 15;
  static const double _homeBottomBarHeight = 58;
  static const Duration _poiPopupDebounce = Duration(milliseconds: 650);

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
  bool _showOnboardingTooltip = false;
  bool _isResolvingMapboxToken = MapboxTokenService.getTokenSync().isEmpty;
  bool _didStartDeferredHomeInit = false;
  bool _didStartPostSplashUiWarmups = false;
  String _currentLanguageFlag = '';
  int? _selectedBottomBarIndex;
  HomeControlsThemeMode _homeControlsTheme = HomeControlsThemeMode.classic;
  late AnimationController _menuAnimController;
  late Animation<Offset> _menuSlideAnimation;
  _MapAction? _selectedAction;

  // Tracking
  final GeolocationService _geo = GeolocationService.instance;
  final HomeControlsThemeService _homeControlsThemeService =
      HomeControlsThemeService();
  bool _isTracking = false;
  String? _userGroupId;

  // Affichage position groupe (publiée par l'admin sur un circuit)
  StreamSubscription<List<GroupCircuitPublicPosition>>? _groupPublicPosSub;
  StreamSubscription<HomeControlsThemeMode>? _homeControlsThemeSub;
  List<MapMarker> _groupPublicMarkers = const <MapMarker>[];

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
  final MasLiveMapControllerPoi _mapController = MasLiveMapControllerPoi();

  bool _isMasLiveMapReady = false;
  List<MapPoint> _marketRoutePoints = const <MapPoint>[];
  Map<String, dynamic> _marketRouteStyle = const <String, dynamic>{};
  rsp.RouteStyleConfig? _marketRouteStylePro;
  ({double west, double south, double east, double north})? _marketRouteBounds;
  bool _isPoiPopupShowing = false;
  DateTime? _lastPoiPopupAt;
  String? _lastPoiPopupId;

  Timer? _marketRouteStyleProTimer;
  int _marketRouteStyleProAnimTick = 0;
  bool _isApplyingMarketRoute = false;
  ValueListenable<int>? _boundActionsMenuSignal;
  ValueListenable<int>? _boundActionsMenuCloseSignal;

  MarketMapService _getMarketMapService() {
    return _marketMapService ??= MarketMapService();
  }

  int? get _activeBottomBarIndex =>
      _showActionsMenu ? 4 : (_selectedBottomBarIndex ?? 2);

  String? get _activeCircuitName {
    final circuitName = _marketPoiSelection.circuit?.name.trim();
    if (!_marketPoiSelection.enabled ||
        circuitName == null ||
        circuitName.isEmpty) {
      return null;
    }
    return circuitName;
  }

  List<MapMarker> _composeMarkers() {
    final markers = <MapMarker>[];

    // Position moyenne du/des groupe(s) (visible uniquement quand l'utilisateur active Tracking)
    if (_isTracking && _groupPublicMarkers.isNotEmpty) {
      markers.addAll(_groupPublicMarkers);
    }

    final lat = _userLat;
    final lng = _userLng;
    if (lat != null && lng != null) {
      markers.add(
        MapMarker(id: 'user-location', lng: lng, lat: lat, size: 1.2),
      );
    }
    return markers;
  }

  void _restartGroupPublicPositionStream() {
    _groupPublicPosSub?.cancel();
    _groupPublicPosSub = null;
    _groupPublicMarkers = const <MapMarker>[];

    if (!_isTracking) {
      if (_isMasLiveMapReady) {
        unawaited(_syncMarkersToMap());
      }
      return;
    }

    final selection = _marketPoiSelection;
    final country = selection.country;
    final event = selection.event;
    final circuit = selection.circuit;
    if (!selection.enabled ||
        country == null ||
        event == null ||
        circuit == null) {
      if (_isMasLiveMapReady) {
        unawaited(_syncMarkersToMap());
      }
      return;
    }

    _groupPublicPosSub = MarketMapGroupPublicPositionService.instance
        .streamCircuitGroupPositions(
          countryId: country.id,
          eventId: event.id,
          circuitId: circuit.id,
        )
        .listen((positions) {
          if (!mounted) return;

          final markers = <MapMarker>[];
          for (final p in positions) {
            markers.add(
              MapMarker(
                id: 'group-${p.adminGroupId}',
                lng: p.lng,
                lat: p.lat,
                label:
                    (p.displayName != null && p.displayName!.trim().isNotEmpty)
                    ? p.displayName!.trim()
                    : 'Groupe',
                size: 1.4,
              ),
            );
          }

          setState(() => _groupPublicMarkers = markers);
          if (_isMasLiveMapReady) {
            unawaited(_syncMarkersToMap());
          }
        });
  }

  Future<void> _syncMarkersToMap() async {
    await _mapController.setMarkers(_composeMarkers());
  }

  Future<void> _syncMarketPoisToMap() async {
    if (!_isMasLiveMapReady) return;

    final pois = _visibleMarketPoisForCurrentAction();
    if (pois.isEmpty) {
      await _mapController.clearPoisGeoJson();
      return;
    }

    await _mapController.setPoisGeoJson(
      _buildMarketPoisFeatureCollection(pois),
    );
  }

  List<MarketPoi> _visibleMarketPoisForCurrentAction() {
    final action = _selectedAction;
    final filterType = _actionToPoiType(action);

    Iterable<MarketPoi> pois = _marketPois.where(
      (poi) => poi.lat != 0.0 && poi.lng != 0.0,
    );

    if (action == _MapAction.parkingWc) {
      pois = pois.where((poi) => poi.type == 'parking' || poi.type == 'wc');
    } else if (filterType == null) {
      return const <MarketPoi>[];
    } else {
      pois = pois.where((poi) => poi.type == filterType);
    }

    return pois.toList();
  }

  Map<String, dynamic> _buildMarketPoisFeatureCollection(List<MarketPoi> pois) {
    return <String, dynamic>{
      'type': 'FeatureCollection',
      'features': pois
          .map(
            (poi) => <String, dynamic>{
              'type': 'Feature',
              'id': poi.id,
              'properties': <String, dynamic>{
                'poiId': poi.id,
                'layerId': poi.layerId.trim().isNotEmpty
                    ? poi.layerId.trim()
                    : ((poi.type ?? 'market').trim().isEmpty
                          ? 'market'
                          : poi.type!.trim()),
                'type': poi.type ?? poi.layerId,
                'title': poi.name,
                'name': poi.name,
              },
              'geometry': <String, dynamic>{
                'type': 'Point',
                'coordinates': <double>[poi.lng, poi.lat],
              },
            },
          )
          .toList(),
    };
  }

  String _marketPoiOpeningHoursText(Object? raw) {
    if (raw == null) return '';
    if (raw is String) return raw.trim();
    try {
      return jsonEncode(raw);
    } catch (_) {
      return raw.toString();
    }
  }

  String _marketPoiImageUrl(MarketPoi poi) {
    final direct = (poi.imageUrl ?? '').trim();
    if (direct.isNotEmpty) return direct;
    final imageMeta = poi.metadata?['image'];
    if (imageMeta is Map) {
      final url = (imageMeta['url'] ?? imageMeta['downloadUrl'] ?? '')
          .toString()
          .trim();
      if (url.isNotEmpty) return url;
    }
    return '';
  }

  bool _marketPoiHasImageInMetadata(MarketPoi poi) {
    final imageMeta = poi.metadata?['image'];
    if (imageMeta is! Map) return false;
    final url = (imageMeta['url'] ?? imageMeta['downloadUrl'] ?? '')
        .toString()
        .trim();
    return url.isNotEmpty;
  }

  Future<void> _handleMarketPoiTap(String poiId) async {
    MarketPoi? poi;
    for (final candidate in _visibleMarketPoisForCurrentAction()) {
      if (candidate.id == poiId) {
        poi = candidate;
        break;
      }
    }
    if (poi == null || !mounted) return;

    final type = (poi.type ?? poi.layerId).trim();
    final title = poi.name.trim().isEmpty
        ? 'Point d\'intérêt'
        : poi.name.trim();
    final description = (poi.description ?? '').trim();
    final imageUrl = _marketPoiImageUrl(poi);
    final hasImage = imageUrl.isNotEmpty || _marketPoiHasImageInMetadata(poi);
    final popupEnabled = PoiPopupService.isPopupEnabled(
      type: type,
      meta: poi.metadata,
      requireImage: false,
      hasImage: hasImage,
    );

    final hasCardData =
        title.isNotEmpty ||
        description.isNotEmpty ||
        imageUrl.isNotEmpty ||
        (poi.address ?? '').trim().isNotEmpty ||
        _marketPoiOpeningHoursText(poi.openingHours).isNotEmpty ||
        (poi.phone ?? '').trim().isNotEmpty ||
        (poi.website ?? '').trim().isNotEmpty ||
        (poi.instagram ?? '').trim().isNotEmpty ||
        (poi.facebook ?? '').trim().isNotEmpty ||
        (poi.whatsapp ?? '').trim().isNotEmpty ||
        (poi.email ?? '').trim().isNotEmpty ||
        (poi.mapsUrl ?? '').trim().isNotEmpty;

    if (!popupEnabled || !hasCardData) {
      return;
    }

    final now = DateTime.now();
    final lastAt = _lastPoiPopupAt;
    if (_isPoiPopupShowing) return;
    if (lastAt != null &&
        now.difference(lastAt) < _poiPopupDebounce &&
        _lastPoiPopupId == poiId) {
      return;
    }

    _lastPoiPopupAt = now;
    _lastPoiPopupId = poiId;
    _isPoiPopupShowing = true;

    try {
      await showPolaroidPoiSheet(
        context: context,
        title: title,
        description: description.isEmpty
            ? 'Aucune description disponible'
            : description,
        imageUrl: imageUrl.isEmpty ? null : imageUrl,
        meta: poi.metadata,
        hours: _marketPoiOpeningHoursText(poi.openingHours),
        phone: poi.phone,
        website: poi.website,
        whatsapp: poi.whatsapp,
        email: poi.email,
        address: poi.address,
        mapsUrl: poi.mapsUrl,
        lat: poi.lat,
        lng: poi.lng,
        countryId: _marketPoiSelection.country?.id,
        eventId: _marketPoiSelection.event?.id,
        circuitId: _marketPoiSelection.circuit?.id,
        poiId: poi.id,
      );
    } finally {
      _isPoiPopupShowing = false;
    }
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
      _isResolvingMapboxToken = false;
      // Le token est déjà stocké dans SharedPreferences via MapboxTokenDialog.
      // Un rebuild suffit pour que la page re-tente l'initialisation.
    });
  }

  Future<void> _resolveStartupMapboxToken() async {
    StartupTrace.log('MAPBOX_WEB', '_resolveStartupMapboxToken start');
    final info = await MapboxTokenService.getTokenInfo();
    if (!mounted) return;

    setState(() {
      _isResolvingMapboxToken = false;
    });

    StartupTrace.log(
      'MAPBOX_WEB',
      '_resolveStartupMapboxToken done source=${info.source} len=${info.token.length}',
    );

    if (info.token.isEmpty) {
      _notifyMapReady();
    }
  }

  Future<void> _restoreLastHomeStyleUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKeyLastHomeStyleUrl);
    final resolved = tryNormalizeMapboxStyleUrl(stored);
    if (!mounted || resolved == null || resolved == _styleUrl) {
      return;
    }

    setState(() {
      _styleUrl = resolved;
    });
  }

  Future<void> _persistLastHomeStyleUrl(String styleUrl) async {
    final normalized = tryNormalizeMapboxStyleUrl(styleUrl);
    if (normalized == null || normalized.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyLastHomeStyleUrl, normalized);
  }

  Future<void> _clearPersistedLastHomeStyleUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeyLastHomeStyleUrl);
  }

  void _handleMapStyleFallback() {
    unawaited(_clearPersistedLastHomeStyleUrl());
    if (!mounted) return;

    final defaultStyleUrl = normalizeMapboxStyleUrl(
      kDefaultMapboxStyleUrl,
      fallback: kDefaultMapboxStyleUrl,
    );
    if (_styleUrl == defaultStyleUrl) return;

    setState(() {
      _styleUrl = defaultStyleUrl;
    });
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

  void _startPostSplashUiWarmups() {
    if (_didStartPostSplashUiWarmups) return;
    _didStartPostSplashUiWarmups = true;

    Future<void>.delayed(const Duration(milliseconds: 700), () async {
      if (!mounted) return;
      if (widget.openActionsMenuOnLoad) {
        _showActionsMenuImmediately();
      } else {
        unawaited(_autoOpenActionsMenuOnceIfNeeded());
      }
      try {
        await precacheImage(
          const AssetImage('assets/images/icon wc parking.png'),
          context,
        );
      } catch (_) {
        // Optionnel: ne jamais bloquer l'affichage initial.
      }
    });
  }

  void _showActionsMenuImmediately({bool showTooltip = false}) {
    if (!mounted) return;
    setState(() {
      _showActionsMenu = true;
      _showOnboardingTooltip = showTooltip;
    });
    _menuAnimController.value = 1.0;
  }

  void _bindActionsMenuSignal(ValueListenable<int>? signal) {
    if (identical(_boundActionsMenuSignal, signal)) return;
    _boundActionsMenuSignal?.removeListener(_handleExternalActionsMenuOpen);
    _boundActionsMenuSignal = signal;
    _boundActionsMenuSignal?.addListener(_handleExternalActionsMenuOpen);
  }

  void _bindActionsMenuCloseSignal(ValueListenable<int>? signal) {
    if (identical(_boundActionsMenuCloseSignal, signal)) return;
    _boundActionsMenuCloseSignal?.removeListener(
      _handleExternalActionsMenuClose,
    );
    _boundActionsMenuCloseSignal = signal;
    _boundActionsMenuCloseSignal?.addListener(_handleExternalActionsMenuClose);
  }

  void _handleExternalActionsMenuOpen() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showActionsMenuImmediately();
    });
  }

  void _handleExternalActionsMenuClose() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_showActionsMenu) return;
      _dismissActionsMenu();
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bindActionsMenuSignal(widget.actionsMenuOpenSignal);
    _bindActionsMenuCloseSignal(widget.actionsMenuCloseSignal);
    unawaited(_restoreLastHomeStyleUrl());

    _isTracking = _geo.isTracking;
    _listenHomeControlsThemeConfig();
    _mapController.onPoiTap = _handleMarketPoiTap;

    // Initialiser le drapeau de langue dès initState (pas de délai)
    _updateLanguageFlag();

    // Sur Web, l'emoji drapeau peut arriver après l'init du service/langue.
    // On retente après le premier frame pour éviter tout placeholder.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final before = _currentLanguageFlag;
      _updateLanguageFlag();
      if (!mounted) return;
      if (_currentLanguageFlag != before) {
        setState(() {});
      }
    });

    _menuAnimController = AnimationController(
      duration: _menuAnimationDuration,
      vsync: this,
    );
    final CurvedAnimation menuMotion = CurvedAnimation(
      parent: _menuAnimController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _menuSlideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(menuMotion);

    unawaited(_resolveStartupMapboxToken());
  }

  @override
  void didUpdateWidget(covariant DefaultMapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(
      oldWidget.actionsMenuOpenSignal,
      widget.actionsMenuOpenSignal,
    )) {
      _bindActionsMenuSignal(widget.actionsMenuOpenSignal);
    }
    if (!identical(
      oldWidget.actionsMenuCloseSignal,
      widget.actionsMenuCloseSignal,
    )) {
      _bindActionsMenuCloseSignal(widget.actionsMenuCloseSignal);
    }
  }

  Future<void> _autoOpenActionsMenuOnceIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final didAutoOpen =
        prefs.getBool(_prefsKeyDidAutoOpenActionsMenuOnce) ?? false;
    if (!mounted) return;

    // Ouvrir le menu et afficher la tooltip à chaque lancement
    final showTooltip = true;

    if (!didAutoOpen) {
      // Marquer le premier lancement automatique si jamais
      await prefs.setBool(_prefsKeyDidAutoOpenActionsMenuOnce, true);
      if (!mounted) return;
    }

    _showActionsMenuImmediately(showTooltip: showTooltip);
  }

  void _notifyMapReady() {
    if (_didNotifyMapReady) return;
    _didNotifyMapReady = true;
    StartupTrace.log('MAPBOX_WEB', '_notifyMapReady');
    if (!mapReadyNotifier.value) {
      mapReadyNotifier.value = true;
    }
  }

  void _handleMapInitError(String message) {
    StartupTrace.log('MAPBOX_WEB', 'map init error: $message');
    debugPrint('⚠️ DefaultMapPage: map init error: $message');
    _notifyMapReady();
  }

  @override
  void dispose() {
    _boundActionsMenuSignal?.removeListener(_handleExternalActionsMenuOpen);
    _boundActionsMenuCloseSignal?.removeListener(
      _handleExternalActionsMenuClose,
    );
    _groupPublicPosSub?.cancel();
    _homeControlsThemeSub?.cancel();
    _marketPoisSub?.cancel();
    _resizeDebounce?.cancel();
    _positionSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _menuAnimController.dispose();
    super.dispose();
  }

  Future<void> _applyMarketPoiSelection(
    MarketMapPoiSelection selection, {
    bool resetPoiFilter = false,
  }) async {
    await _marketPoisSub?.cancel();
    _marketPoisSub = null;

    // Changement de carte/circuit => ne pas afficher de POIs par défaut.
    // Les POIs apparaissent uniquement après clic sur une icône de la barre verticale.
    if (resetPoiFilter && mounted) {
      setState(() => _selectedAction = null);
    }

    if (!selection.enabled ||
        selection.country == null ||
        selection.event == null ||
        selection.circuit == null) {
      _marketRouteStyleProTimer?.cancel();
      _marketRouteStyleProTimer = null;
      if (!mounted) return;
      setState(() {
        _marketPois = const <MarketPoi>[];
        _marketRoutePoints = const <MapPoint>[];
        _marketRouteStyle = const <String, dynamic>{};
        _marketRouteStylePro = null;
        _marketRouteBounds = null;
      });

      // Masquer le tracé sans effacer les marqueurs.
      if (_isMasLiveMapReady) {
        unawaited(_mapController.clearPoisGeoJson());
        unawaited(
          _mapController.setPolyline(points: const <MapPoint>[], show: false),
        );
      }
      return;
    }

    final circuit = selection.circuit!;
    final center = circuit.center;
    final resolvedStyleUrl = normalizeMapboxStyleUrl(circuit.styleUrl);

    StartupTrace.log(
      'MAPBOX_WEB',
      'market circuit selected id=${circuit.id} rawStyle=${circuit.styleUrl} resolvedStyle=$resolvedStyleUrl',
    );

    // Recentrer la carte sur le circuit choisi (via rebuild key)
    setState(() {
      _projectCenterLat = center['lat'];
      _projectCenterLng = center['lng'];
      _projectZoom = circuit.initialZoom;
      _styleUrl = resolvedStyleUrl;

      // Nouveau circuit => reset affichage POIs.
      // Nouveau widget Map -> on attend son onMapReady pour appliquer le tracé.
      _isMasLiveMapReady = false;
      _marketRoutePoints = const <MapPoint>[];
      _marketRouteStyle = const <String, dynamic>{};
      _marketRouteStylePro = null;
      _marketRouteBounds = null;
      _mapRebuildTick++;
    });

    unawaited(_persistLastHomeStyleUrl(resolvedStyleUrl));

    _marketRouteStyleProTimer?.cancel();
    _marketRouteStyleProTimer = null;

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
        _marketRouteStylePro = proCfg;
        _marketRouteBounds = bounds;
      });

      _syncMarketRouteStyleProTimer();

      await _applyCachedMarketRouteToMap();
    } catch (e) {
      debugPrint('⚠️ Erreur chargement tracé MarketMap: $e');
    }
  }

  void _syncMarketRouteStyleProTimer() {
    final cfg = _marketRouteStylePro;
    final needsAnim =
        cfg != null &&
        _marketPoiSelection.enabled &&
        _marketPoiSelection.circuit != null &&
        cfg.rainbowEnabled;

    if (!needsAnim) {
      _marketRouteStyleProTimer?.cancel();
      _marketRouteStyleProTimer = null;
      return;
    }

    final validated = cfg.validated();
    final periodMs = (110 - (validated.rainbowSpeed * 0.8))
        .clamp(25, 110)
        .round();

    _marketRouteStyleProTimer?.cancel();
    _marketRouteStyleProTimer = Timer.periodic(
      Duration(milliseconds: periodMs),
      (_) {
        if (!mounted) return;
        if (!_marketPoiSelection.enabled ||
            _marketPoiSelection.circuit == null) {
          _syncMarketRouteStyleProTimer();
          return;
        }
        _marketRouteStyleProAnimTick++;
        unawaited(_applyCachedMarketRouteToMap(fitToBounds: false));
      },
    );
  }

  Future<void> _applyCachedMarketRouteToMap({bool fitToBounds = true}) async {
    if (!mounted) return;
    if (!_isMasLiveMapReady) return;
    if (!_marketPoiSelection.enabled || _marketPoiSelection.circuit == null) {
      return;
    }

    if (_isApplyingMarketRoute) return;
    _isApplyingMarketRoute = true;

    try {
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
            if (west != null &&
                south != null &&
                east != null &&
                north != null) {
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

      final pro = _marketRouteStylePro;
      if (pro != null) {
        final cfg = pro.validated();

        final mainWidth = cfg.effectiveRenderedMainWidth;
        final casingWidth = cfg.effectiveRenderedCasingWidth;
        final glowWidth = cfg.glowWidth * cfg.effectiveWidthScale3d;

        final segmentsForMain =
            cfg.rainbowEnabled ||
            cfg.trafficDemoEnabled ||
            cfg.vanishingEnabled;
        final needSegmentsSource =
            segmentsForMain || cfg.effectiveCasingRainbowEnabled;
        final segmentsGeoJson = needSegmentsSource
            ? _buildRouteStyleProSegmentsGeoJson(
                pts,
                cfg,
                animTick: _marketRouteStyleProAnimTick,
              )
            : null;

        final shouldRoadLike = cfg.shouldRenderRoadLike;

        await _mapController.setPolyline(
          points: pts,
          color: cfg.mainColor,
          width: mainWidth,
          show: true,
          roadLike: shouldRoadLike,
          shadow3d: cfg.effectiveShadowEnabled,
          shadowOpacity: cfg.shadowOpacity,
          shadowBlur: cfg.shadowBlur,
          showDirection: false,
          animateDirection: cfg.pulseEnabled,
          animationSpeed: (cfg.pulseSpeed / 25.0).clamp(0.5, 5.0),

          opacity: cfg.opacity,
          casingColor: cfg.casingColor,
          casingWidth: cfg.effectiveCasingWidth > 0 ? casingWidth : null,
          casingRainbowEnabled: cfg.effectiveCasingRainbowEnabled,

          glowEnabled: cfg.effectiveGlowEnabled,
          glowColor: cfg.mainColor,
          glowWidth: glowWidth,
          glowOpacity: cfg.effectiveGlowEnabled ? cfg.glowOpacity : 0.0,
          glowBlur: cfg.glowBlur,

          thickness3d: cfg.thickness3d,
          elevationPx: cfg.effectiveElevationPx,
          sidesEnabled: cfg.effectiveSidesEnabled,
          sidesIntensity: cfg.sidesIntensity,

          dashArray: cfg.dashEnabled
              ? <double>[cfg.dashLength, cfg.dashGap]
              : null,
          lineCap: cfg.lineCap.name,
          lineJoin: cfg.lineJoin.name,
          segmentsGeoJson: segmentsGeoJson,
          segmentsForMain: segmentsForMain,
        );
      } else {
        final style = _marketRouteStyle;
        final color =
            _parseHexColor(style['color']?.toString()) ??
            const Color(0xFF0A84FF);
        final width = (style['width'] as num?)?.toDouble() ?? 6.0;
        final roadLike = (style['roadLike'] as bool?) ?? true;
        final shadow3d = (style['shadow3d'] as bool?) ?? true;
        final showDirection = (style['showDirection'] as bool?) ?? false;
        final animateDirection = (style['animateDirection'] as bool?) ?? false;
        final animationSpeed =
            (style['animationSpeed'] as num?)?.toDouble() ?? 1.0;

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
      }

      if (fitToBounds) {
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
    } finally {
      _isApplyingMarketRoute = false;
    }
  }

  String _buildRouteStyleProSegmentsGeoJson(
    List<MapPoint> pts,
    rsp.RouteStyleConfig cfg, {
    required int animTick,
  }) {
    if (pts.length < 2) {
      return jsonEncode({'type': 'FeatureCollection', 'features': []});
    }

    final width = cfg.effectiveRenderedMainWidth;

    // Limite le nombre de segments (perf)
    const maxSeg = 60;
    final step = math.max(1, ((pts.length - 1) / maxSeg).ceil());

    final features = <Map<String, dynamic>>[];
    int segIndex = 0;

    for (int i = 0; i < pts.length - 1; i += step) {
      final a = pts[i];
      final b = pts[math.min(i + step, pts.length - 1)];

      final denom = math.max(1, ((pts.length - 1) / step).floor());
      final t = segIndex / denom;

      final baseOpacity = cfg.opacity;
      final opacity = cfg.vanishingEnabled
          ? (t <= cfg.vanishingProgress ? 0.25 : baseOpacity)
          : baseOpacity;

      final color = _routeStyleProSegmentColor(cfg, segIndex, animTick);
      final casingColor = _routeStyleProSegmentCasingColor(
        cfg,
        segIndex,
        animTick,
      );

      features.add({
        'type': 'Feature',
        'properties': {
          'color': _toRgba(color, opacity: opacity),
          'casingColor': _toHexRgb(casingColor),
          'width': width,
          'opacity': opacity,
        },
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            [a.lng, a.lat],
            [b.lng, b.lat],
          ],
        },
      });
      segIndex++;
    }

    return jsonEncode({'type': 'FeatureCollection', 'features': features});
  }

  Color _routeStyleProSegmentColor(
    rsp.RouteStyleConfig cfg,
    int index,
    int animTick,
  ) {
    if (cfg.trafficDemoEnabled) {
      const traffic = [Color(0xFF22C55E), Color(0xFFF59E0B), Color(0xFFEF4444)];
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

  Color _routeStyleProSegmentCasingColor(
    rsp.RouteStyleConfig cfg,
    int index,
    int animTick,
  ) {
    if (!cfg.effectiveCasingRainbowEnabled) return cfg.casingColor;
    final shift = (animTick % 360);
    final dir = cfg.rainbowReverse ? -1 : 1;
    final hue = (shift + dir * index * 14) % 360;
    return _hsvToColor(hue.toDouble(), cfg.rainbowSaturation, 1.0);
  }

  Color _hsvToColor(double h, double s, double v) {
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

  String _toRgba(Color c, {required double opacity}) {
    // Mapbox GL JS accepte bien rgba() (plus robuste que #RRGGBBAA selon environnements).
    final a = opacity.clamp(0.0, 1.0);
    final r = ((c.r * 255).round()).clamp(0, 255);
    final g = ((c.g * 255).round()).clamp(0, 255);
    final b = ((c.b * 255).round()).clamp(0, 255);
    return 'rgba($r,$g,$b,${a.toStringAsFixed(3)})';
  }

  String _toHexRgb(Color c) {
    final v = c.toARGB32().toRadixString(16).padLeft(8, '0');
    return '#${v.substring(2, 8)}';
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
      case _MapAction.parkingWc:
        return null;
      case null:
        return null;
    }
  }

  void _refreshMarketPoiMarkers() {
    if (!mounted) return;
    final action = _selectedAction;
    final filterType = _actionToPoiType(action);

    // Action fusionnée: afficher parking + wc.
    if (action == _MapAction.parkingWc) {
      unawaited(_syncMarketPoisToMap());
      unawaited(_syncMarkersToMap());
      return;
    }

    // Par défaut (aucune action sélectionnée), on n'affiche aucun POI.
    // Les POIs apparaissent uniquement après clic sur une icône de la barre verticale.
    if (filterType == null) {
      unawaited(_syncMarketPoisToMap());
      unawaited(_syncMarkersToMap());
      return;
    }

    unawaited(_syncMarketPoisToMap());
    unawaited(_syncMarkersToMap());
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
      if (!doc.exists || !mounted) return;
      final groupId = doc.data()?['groupId'] as String?;
      setState(() => _userGroupId = groupId);
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

  void _listenHomeControlsThemeConfig() {
    _homeControlsThemeSub?.cancel();
    _homeControlsThemeSub = _homeControlsThemeService.watchTheme().listen(
      (theme) {
        if (!mounted || _homeControlsTheme == theme) return;
        setState(() => _homeControlsTheme = theme);
      },
      onError: (Object error, StackTrace stackTrace) {
        StartupTrace.log(
          'MAPBOX_WEB',
          'home theme config listen failed: $error',
        );
      },
    );
  }

  void _dismissActionsMenu() {
    _menuAnimController.reverse();
    Future.delayed(_menuAnimationDuration, () {
      if (mounted && _showActionsMenu) {
        setState(() {
          _showActionsMenu = false;
          _showOnboardingTooltip = false;
          if (_selectedBottomBarIndex == 4) {
            _selectedBottomBarIndex = 2;
          }
        });
      }
    });
  }

  void _toggleActionsMenu() {
    if (_showActionsMenu) {
      _dismissActionsMenu();
      return;
    }

    setState(() => _showActionsMenu = true);
    _menuAnimController.forward(from: 0.0);
  }

  void _selectBottomBarIndex(int index) {
    if (!mounted) return;
    setState(() => _selectedBottomBarIndex = index);
  }

  void _closeNavWithDelay() {
    Future.delayed(_navCloseDelay, () {
      if (mounted && _showActionsMenu) {
        _dismissActionsMenu();
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

  List<HomeVerticalNavItem> _buildClassicVerticalNavItems(
    BuildContext context,
  ) {
    final localizations = l10n.AppLocalizations.of(context)!;

    return [
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
        label: localizations.tracking,
        icon: Icons.track_changes_rounded,
        selected: _isTracking,
        onTap: () {
          _toggleTracking();
          _closeNavWithDelay();
        },
      ),
      HomeVerticalNavItem(
        label: localizations.visit,
        icon: Icons.map_outlined,
        selected: _selectedAction == _MapAction.visiter,
        onTap: () {
          _selectAction(_MapAction.visiter, 'Visiter');
          _closeNavWithDelay();
        },
      ),
      HomeVerticalNavItem(
        label: localizations.food,
        icon: Icons.fastfood_rounded,
        selected: _selectedAction == _MapAction.food,
        onTap: () {
          _selectAction(_MapAction.food, 'Food');
          _closeNavWithDelay();
        },
      ),
      HomeVerticalNavItem(
        label: localizations.assistance,
        icon: Icons.shield_outlined,
        selected: _selectedAction == _MapAction.assistance,
        onTap: () {
          _selectAction(_MapAction.assistance, 'Assistance');
          _closeNavWithDelay();
        },
      ),
      HomeVerticalNavItem(
        label: '',
        fullBleed: true,
        iconWidget: Row(
          children: [
            Expanded(
              child: ColoredBox(
                color: const Color(0xFF005BBB),
                child: const Center(
                  child: Text(
                    'P',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: Colors.black,
                child: const Center(
                  child: Icon(Icons.wc_rounded, size: 22, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        selected: _selectedAction == _MapAction.parkingWc,
        tintOnSelected: false,
        highlightBackgroundOnSelected: false,
        onTap: () {
          _selectAction(_MapAction.parkingWc, 'P/WC');
          _closeNavWithDelay();
        },
      ),
      HomeVerticalNavItem(
        label: '',
        iconWidget: Center(
          child: _currentLanguageFlag.isEmpty
              ? const SizedBox.shrink()
              : Text(
                  _currentLanguageFlag,
                  style: const TextStyle(fontSize: 32, height: 1),
                ),
        ),
        fullBleed: true,
        tintOnSelected: false,
        highlightBackgroundOnSelected: false,
        showBorder: false,
        selected: false,
        onTap: () {
          _cycleLanguage();
          _closeNavWithDelay();
        },
      ),
    ];
  }

  Widget _buildActionsMenuOverlay(
    BuildContext context, {
    required double menuTopOffset,
    required double navMenuRightOffset,
    required double navHorizontalPadding,
  }) {
    final Widget menu = Transform.translate(
      offset: Offset(navMenuRightOffset, 0),
      child: HomeVerticalNavMenu(
        margin: EdgeInsets.only(top: menuTopOffset),
        horizontalPadding: navHorizontalPadding,
        verticalPadding: 10,
        backgroundAlpha: 0.88,
        blurSigma: HomeVerticalNavMenu.boutiqueBlurSigma,
        boxShadow: HomeVerticalNavMenu.boutiqueShadow,
        borderColor: HomeVerticalNavMenu.boutiqueBorderColor,
        items: _buildClassicVerticalNavItems(context),
      ),
    );

    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _dismissActionsMenu,
              child: const SizedBox.expand(),
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: SlideTransition(position: _menuSlideAnimation, child: menu),
          ),
        ],
      ),
    );
  }

  List<MasliveStandardBottomBarItem> _buildBottomBarItems(
    BuildContext context,
    User? user,
  ) {
    final localizations = l10n.AppLocalizations.of(context)!;
    final pseudo = (user?.displayName ?? user?.email ?? localizations.profile)
        .trim();

    return [
      MasliveStandardBottomBarItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Profil',
        tooltip: pseudo.isEmpty ? localizations.profile : pseudo,
        onTap: () {
          _selectBottomBarIndex(0);
          if (user != null) {
            Navigator.pushNamed(context, '/account-ui');
          } else {
            Navigator.pushNamed(context, '/login');
          }
        },
      ),
      MasliveStandardBottomBarItem(
        icon: Icons.storefront_outlined,
        activeIcon: Icons.storefront,
        label: 'Boutique',
        tooltip: localizations.shop,
        onTap: () {
          _selectBottomBarIndex(1);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  const StorexShopPage(shopId: 'global', groupId: 'MASLIVE'),
            ),
          );
        },
      ),
      MasliveStandardBottomBarItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: 'Home',
        tooltip: 'Home',
        onTap: () {
          _selectBottomBarIndex(2);
          if (_showActionsMenu) {
            _dismissActionsMenu();
          }
        },
      ),
      MasliveStandardBottomBarItem(
        icon: Icons.photo_library_outlined,
        activeIcon: Icons.photo_library,
        label: 'Media',
        tooltip: 'Media',
        onTap: () {
          _selectBottomBarIndex(3);
          Navigator.pushNamed(context, '/media-marketplace');
        },
      ),
      MasliveStandardBottomBarItem(
        icon: Icons.search_rounded,
        activeIcon: Icons.search,
        label: 'Explorer',
        tooltip: 'Explorer',
        onTap: () {
          _selectBottomBarIndex(4);
          _toggleActionsMenu();
        },
      ),
    ];
  }

  Widget _buildBottomBar(BuildContext context, {required User? user}) {
    final items = _buildBottomBarItems(context, user);

    return MasliveStandardBottomBar(
      items: items,
      selectedIndex: _activeBottomBarIndex,
      height: _homeBottomBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      inactiveColor: const Color(0xFF101828),
      includeBottomSafeArea: true,
    );
  }

  Future<void> _toggleTracking() async {
    if (_isTracking) {
      _geo.stopTracking();
      if (mounted) setState(() => _isTracking = false);
      _restartGroupPublicPositionStream();
      return;
    }

    // Activer l'UI Tracking (affichage position groupe)
    if (mounted) setState(() => _isTracking = true);
    _restartGroupPublicPositionStream();

    // Partage GPS (si l'utilisateur appartient à un groupe)
    final uid = AuthService.instance.currentUser?.uid;
    final groupId = _userGroupId;
    if (uid == null || groupId == null || groupId.isEmpty) {
      return;
    }

    final ok = await _geo.startTracking(
      groupId: groupId,
      intervalSeconds: _trackingIntervalSeconds,
    );
    if (!mounted) return;
    if (!ok) {
      // On garde l'affichage Tracking actif (view-only), mais le partage GPS a échoué.
      debugPrint('⚠️ startTracking échoué (view-only actif)');
    }
  }

  Future<void> _showMapProjectsSelector() async {
    final selection = await showMarketMapCircuitSelectorSheet(
      context,
      service: _getMarketMapService(),
      initial: _marketPoiSelection.enabled ? _marketPoiSelection : null,
      disableKeyboardInput: true,
    );
    if (selection == null || !mounted) return;

    setState(() {
      _marketPoiSelection = selection;
    });

    // Changement de circuit => relancer le stream de position groupe si Tracking est actif.
    _restartGroupPublicPositionStream();

    await _applyMarketPoiSelection(selection, resetPoiFilter: true);
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Sur web, MasLiveMap / Mapbox GL JS gère le resize via
    // triggerWebViewportResize dans _scheduleResize.
    // Un setState vide suffit à forcer le LayoutBuilder à
    // capturer les nouvelles contraintes — pas besoin de recréer
    // le widget carte (coûteux, perd l'état WebGL).
    if (mounted) {
      try {
        setState(() {});
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

    if (_isResolvingMapboxToken && token.isEmpty) {
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
        bottomNavigationBar: widget.showBottomBar
            ? StreamBuilder<User?>(
                stream: AuthService.instance.authStateChanges,
                builder: (context, snap) {
                  return _buildBottomBar(context, user: snap.data);
                },
              )
            : null,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final size = ui.Size(constraints.maxWidth, constraints.maxHeight);
            final mediaQuery = MediaQuery.of(context);
            final topInset = mediaQuery.padding.top;
            final bottomInset = mediaQuery.padding.bottom;
            final menuTopOffset = topInset + 104;
            const navMenuRightOffset = -6.0;

            const bottomBarHeight = _homeBottomBarHeight;

            // Géométrie de la barre verticale (doit rester cohérente avec
            // `HomeVerticalNavMenu` et `HomeVerticalNavActionItem`).
            const navItemSize = 56.0;
            const navVerticalPadding = 10.0;
            const navHorizontalPadding = 6.0;
            const tooltipGapToMenu = 12.0;
            final navMenuWidth = navItemSize + (navHorizontalPadding * 2);
            final tooltipRight = navMenuWidth + tooltipGapToMenu;
            final carteIconCenterY =
                menuTopOffset + navVerticalPadding + (navItemSize / 2);
            final activeCircuitName = _activeCircuitName;

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
                          controlsPosition: 'top-left',
                          forceCompactAttribution: true,
                          showAttributionControl: false,
                          showMapboxLogo: false,
                          prioritizeFirstFrame: true,
                          onTap: (_) {
                            // Fermer la tooltip au premier clic
                            if (_showOnboardingTooltip) {
                              setState(() => _showOnboardingTooltip = false);
                            }
                          },
                          onMapReady: (_) {
                            _isMasLiveMapReady = true;
                            _notifyMapReady();
                            _startDeferredHomeInit();
                            _startPostSplashUiWarmups();
                            unawaited(_syncMarkersToMap());
                            unawaited(_syncMarketPoisToMap());
                            unawaited(_applyCachedMarketRouteToMap());
                          },
                          onInitError: _handleMapInitError,
                          onStyleFallback: _handleMapStyleFallback,
                        ),
                      ),
                    ),
                  ),
                ),

                // Overlay actions menu (vertical) + backdrop
                if (_showActionsMenu)
                  _buildActionsMenuOverlay(
                    context,
                    menuTopOffset: menuTopOffset,
                    navMenuRightOffset: navMenuRightOffset,
                    navHorizontalPadding: navHorizontalPadding,
                  ),

                // Onboarding tooltip (sélectionner votre carte)
                if (_showOnboardingTooltip && _showActionsMenu)
                  _OnboardingTooltip(
                    message: 'Sélectionnez votre carte ici',
                    anchorCenterY: carteIconCenterY,
                    right: tooltipRight,
                    onDismiss: () {
                      setState(() => _showOnboardingTooltip = false);
                    },
                  ),

                if (activeCircuitName != null)
                  Positioned(
                    top: topInset + 10,
                    left: 88,
                    right: 88,
                    child: IgnorePointer(
                      child: Center(
                        child: ActiveCircuitHeaderBanner(
                          circuitName: activeCircuitName,
                        ),
                      ),
                    ),
                  ),

                // Tracking pill
                if (_isTracking)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: bottomInset + bottomBarHeight + 12,
                    child: _TrackingPill(
                      isTracking: _isTracking,
                      onToggle: _toggleTracking,
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

class _OnboardingTooltip extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  final double anchorCenterY;
  final double right;

  const _OnboardingTooltip({
    required this.message,
    required this.onDismiss,
    required this.anchorCenterY,
    required this.right,
  });

  @override
  Widget build(BuildContext context) {
    const borderRadius = 16.0;
    const arrowWidth = 18.0;
    const arrowHeight = 24.0;

    return Positioned(
      top: anchorCenterY,
      right: right,
      child: GestureDetector(
        onTap: onDismiss,
        child: FractionalTranslation(
          translation: const Offset(0.0, -0.5),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerRight,
            children: [
              CustomPaint(
                painter: const _DashedTooltipBorderPainter(
                  borderRadius: borderRadius,
                ),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 230),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(borderRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -(arrowWidth - 3),
                top: 0,
                bottom: 0,
                child: SizedBox(
                  width: arrowWidth,
                  height: arrowHeight,
                  child: Center(
                    child: CustomPaint(
                      size: const Size(arrowWidth, arrowHeight),
                      painter: const _TooltipArrowPainter(),
                    ),
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

class _DashedTooltipBorderPainter extends CustomPainter {
  const _DashedTooltipBorderPainter({required this.borderRadius});

  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 1.8;
    const inset = 2.2;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset,
        inset,
        size.width - (inset * 2),
        size.height - (inset * 2),
      ),
      Radius.circular(borderRadius - inset),
    );
    final path = Path()..addRRect(rect);
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const dashWidth = 8.0;
    const dashGap = 4.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedTooltipBorderPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius;
  }
}

class _TooltipArrowPainter extends CustomPainter {
  const _TooltipArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, size.height / 2);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
