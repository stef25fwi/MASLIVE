import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/market_circuit_models.dart';
import '../services/circuit_repository.dart';
import '../services/circuit_versioning_service.dart';
import '../services/market_map_service.dart';
import '../services/publish_quality_service.dart';
import '../ui/map/maslive_map.dart';
import '../ui/map/maslive_map_controller.dart';
import '../ui/map/maslive_poi_style.dart';
import '../ui/widgets/country_autocomplete_field.dart';
import '../ui/widgets/glass_scrollbar.dart';
import '../ui/snack/top_snack_bar.dart';
import '../models/market_country.dart';
import '../ui_kit/glass/glass_app_bar.dart';
import '../ui_kit/glass/glass_panel.dart';
import '../ui_kit/layout/soft_background.dart';
import '../ui_kit/tokens/maslive_tokens.dart';
import '../ui_kit/wizard/wizard_bottom_bar.dart';
import '../ui_kit/wizard/wizard_stepper_pills.dart';
import 'circuit_map_editor.dart';
import '../route_style_pro/models/route_style_config.dart' as rsp;
import '../route_style_pro/services/route_snap_service.dart' as snap;
import '../route_style_pro/ui/route_style_wizard_pro_page.dart';
import '../pages/home_vertical_nav.dart';
import 'poi_bottom_popup.dart';
import 'poi_edit_popup.dart';

typedef LngLat = ({double lng, double lat});

enum _PoiInlineEditorMode { none, createPoint, createZone, edit }

class CircuitWizardProPage extends StatefulWidget {
  final String? projectId;
  final String? countryId;
  final String? eventId;
  final String? circuitId;
  final int? initialStep;
  final bool poiOnly;

  const CircuitWizardProPage({
    super.key,
    this.projectId,
    this.countryId,
    this.eventId,
    this.circuitId,
    this.initialStep,
    this.poiOnly = false,
  });

  @override
  State<CircuitWizardProPage> createState() => _CircuitWizardProPageState();
}

class _CircuitWizardProPageState extends State<CircuitWizardProPage>
    with SingleTickerProviderStateMixin {
  static const int _poiPageSize = 100;
  static const int _poiLimit = 2000;
  static const int _poiStepIndex = 5;

  final CircuitRepository _repository = CircuitRepository();
  final CircuitVersioningService _versioning = CircuitVersioningService();
  final PublishQualityService _qualityService = PublishQualityService();
  final MarketMapService _marketMapService = MarketMapService();

  String? _projectId;
  late PageController _pageController;
  int _currentStep = 0;
  bool _didAutoOpenStyleProForCurrentVisit = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentUserRole;
  String? _currentGroupId;

  bool _canWriteMapProjects = false;

  List<CircuitTemplate> _templates = [];
  CircuitTemplate? _selectedTemplate;

  final _perimeterEditorController = CircuitMapEditorController();
  final _routeEditorController = CircuitMapEditorController();

  // Formulaire Step 1: Infos
  final _nameController = TextEditingController();
  final _countryController = TextEditingController();
  final _eventController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _styleUrlController = TextEditingController();

  Timer? _styleUrlDebounce;

  // Données Steps 2-4: Cartes
  List<LngLat> _perimeterPoints = [];
  List<LngLat> _routePoints = [];

  // Step 2: Option périmètre cercle (centre + diamètre)
  bool _perimeterCircleMode = false;
  LngLat? _perimeterCircleCenter;
  double _perimeterCircleDiameterMeters = 1200.0;

  // Step 2 (périmètre): contraintes caméra
  double _perimeterCameraInitialZoom = 15.0;
  double _perimeterCameraPitchZoomThreshold = 16.0;
  double _perimeterCameraPitchDegrees = 45.0;
  double _perimeterCameraMaxZoom = 18.0;

  // Style du tracé (Step 3 + Step 4)
  String _routeColorHex = '#1A73E8';
  double _routeWidth = 6.0;
  bool _routeRoadLike = true;
  bool _routeShadow3d = true;
  bool _routeShowDirection = true;
  bool _routeAnimateDirection = false;
  double _routeAnimationSpeed = 1.0;

  // Style Pro (RouteStyleConfig) chargé depuis Firestore (map_projects.routeStylePro)
  rsp.RouteStyleConfig? _routeStyleProConfig;

  // Animation (rainbow) sur la carte POI
  Timer? _poiRouteStyleProTimer;
  int _poiRouteStyleProAnimTick = 0;
  bool _isRenderingPoiRoute = false;
  String? _lastPoiBuildingsKey;

  // Step 4: Layers/POI
  List<MarketMapLayer> _layers = [];
  List<MarketMapPOI> _pois = [];
  DocumentSnapshot<Map<String, dynamic>>? _poisLastDoc;
  bool _hasMorePois = false;
  bool _isLoadingMorePois = false;
  MarketMapLayer? _selectedLayer;
  final MasLiveMapControllerPoi _poiMapController = MasLiveMapControllerPoi();
  final PoiSelectionController _poiSelection = PoiSelectionController();
  final ScrollController _poiStepScrollController = ScrollController();

  String _defaultPoiAppearanceId = kMasLivePoiAppearancePresets.first.id;
  String _poiInlineAppearanceId = kMasLivePoiAppearancePresets.first.id;

  // Empêche le scroll vertical de certaines pages quand l'utilisateur interagit
  // avec une carte intégrée dans un scroll (drag/pan/zoom).
  int _wizardMapPointerCount = 0;
  bool get _isWizardMapInteracting => _wizardMapPointerCount > 0;

  Widget _wrapWizardMapToBlockScroll(Widget child) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        if (!mounted) return;
        setState(() => _wizardMapPointerCount++);
      },
      onPointerUp: (_) {
        if (!mounted) return;
        setState(() {
          _wizardMapPointerCount = math.max(0, _wizardMapPointerCount - 1);
        });
      },
      onPointerCancel: (_) {
        if (!mounted) return;
        setState(() {
          _wizardMapPointerCount = math.max(0, _wizardMapPointerCount - 1);
        });
      },
      child: child,
    );
  }

  _PoiInlineEditorMode _poiInlineEditorMode = _PoiInlineEditorMode.none;
  MarketMapPOI? _poiEditingPoi;

  final TextEditingController _poiInlineNameController =
      TextEditingController();
  final TextEditingController _poiInlineLatController = TextEditingController();
  final TextEditingController _poiInlineLngController = TextEditingController();
  String? _poiInlineError;

  // Parking: création de zone (polygone)
  bool _isDrawingParkingZone = false;
  List<LngLat> _parkingZonePoints = <LngLat>[];

  // Parking: style de zone (fond/couleur/texture)
  static const String _parkingZoneStyleKey = 'perimeterStyle';
  static const double _parkingZoneDefaultFillOpacity = 0.20;
  static const double _parkingZoneDefaultStrokeWidth = 2.0;
  static const double _parkingZoneDefaultPatternOpacity = 0.55;
  String _parkingZoneFillColorHex = '#FBBF24';
  String _parkingZoneStrokeColorHex = '#FBBF24';
  bool _parkingZoneStrokeFollowsFill = true;
  double _parkingZoneFillOpacity = _parkingZoneDefaultFillOpacity;
  double _parkingZoneStrokeWidth = _parkingZoneDefaultStrokeWidth;
  String _parkingZoneStrokeDash = 'solid'; // solid|dashed|dotted
  String _parkingZonePattern = 'none'; // none|diag|cross|dots
  double _parkingZonePatternOpacity = _parkingZoneDefaultPatternOpacity;
  final TextEditingController _parkingZoneColorController =
      TextEditingController(text: '#FBBF24');

  void _applyParkingZonePresetWhiteBlue() {
    // Preset demandé: contour blanc, intérieur bleu.
    const fillHex = '#0A84FF';
    const strokeHex = '#FFFFFF';
    setState(() {
      _parkingZoneFillColorHex = fillHex;
      _parkingZoneStrokeColorHex = strokeHex;
      _parkingZoneStrokeFollowsFill = false;
      _parkingZoneFillOpacity = 0.30;
      _parkingZoneStrokeWidth = _parkingZoneDefaultStrokeWidth;
      _parkingZoneStrokeDash = 'solid';
      _parkingZonePattern = 'none';
      _parkingZonePatternOpacity = _parkingZoneDefaultPatternOpacity;
      _parkingZoneColorController.text = fillHex;
      _poiInlineError = null;
    });
    _refreshPoiMarkers();
  }

  double? _poiInitialLng;
  double? _poiInitialLat;
  double? _poiInitialZoom;

  bool _isSnappingRoute = false;

  bool _isRefreshingMarketImport = false;
  bool _isEnsuringAllPoisLoaded = false;

  // Snap en continu (debounce + ignore résultats obsolètes)
  Timer? _routeSnapDebounce;
  int _routeSnapSeq = 0;

  // Brouillon
  Map<String, dynamic> _draftData = {};

  void _showTopSnackBar(
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!mounted) return;

    TopSnackBar.showMessage(
      context,
      message,
      isError: isError,
      duration: duration,
    );
  }

  Future<void> _ensureAllPoisLoadedForPublish() async {
    if (_isEnsuringAllPoisLoaded) return;
    if (_projectId == null) return;
    if (!_hasMorePois) return;

    setState(() => _isEnsuringAllPoisLoaded = true);
    try {
      // Sécurité: évite une boucle infinie si l'état Firestore est instable.
      int pageGuard = 0;
      while (mounted && _hasMorePois) {
        pageGuard += 1;
        if (pageGuard > 60) {
          throw StateError('Trop de pages POI à charger (guard).');
        }
        await _loadMorePoisPage();
      }
    } finally {
      if (mounted) {
        setState(() => _isEnsuringAllPoisLoaded = false);
      } else {
        _isEnsuringAllPoisLoaded = false;
      }
    }
  }

  Future<void> _refreshImportFromMarketMap() async {
    if (_isRefreshingMarketImport) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _ensureActorContext();
      if (!_canWriteMapProjects) {
        if (!mounted) return;
        _showTopSnackBar('⛔ Import réservé aux admins master.', isError: true);
        return;
      }

      // Assure un projectId existant (on importe dans un brouillon).
      if (_projectId == null) {
        await _saveDraft();
      }

      final projectId = _projectId;
      if (projectId == null || projectId.trim().isEmpty) {
        throw StateError('Projet non initialisé');
      }

      final countryId = _countryController.text.trim();
      final eventId = _eventController.text.trim();
      final circuitId = (widget.circuitId?.trim().isNotEmpty ?? false)
          ? widget.circuitId!.trim()
          : (_draftData['circuitId']?.toString().trim() ?? '');

      if (countryId.isEmpty || eventId.isEmpty || circuitId.isEmpty) {
        throw StateError('Pays / événement / circuit requis pour importer.');
      }

      if (!mounted) return;

      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Réimporter depuis MarketMap ?'),
            content: const Text(
              'Cette action remplace les couches et POI du brouillon par la version publiée (MarketMap).\n'
              'Les modifications locales non publiées sur les POI/couches seront perdues.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Importer'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;
      if (ok != true) return;

      setState(() => _isRefreshingMarketImport = true);
      await _repository.refreshDraftFromMarketMap(
        projectId: projectId,
        actorUid: user.uid,
        actorRole: _currentUserRole ?? 'creator',
        groupId: _currentGroupId ?? 'default',
        countryId: countryId,
        eventId: eventId,
        circuitId: circuitId,
      );

      // Recharge l'état (doc courant + sous-collections layers/pois).
      await _loadDraftOrInitialize();

      if (mounted) {
        _showTopSnackBar('✅ Import MarketMap terminé');
      }
    } catch (e) {
      debugPrint('WizardPro _refreshImportFromMarketMap error: $e');
      if (mounted) {
        final msg = e is FirebaseException
            ? '❌ Import Firestore (${e.code}): ${e.message ?? e.toString()}'
            : '❌ Erreur import: $e';
        _showTopSnackBar(
          msg,
          isError: true,
          duration: const Duration(seconds: 6),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshingMarketImport = false);
      } else {
        _isRefreshingMarketImport = false;
      }
    }
  }

  PublishQualityReport get _qualityReport => _qualityService.evaluate(
    perimeter: _perimeterPoints,
    route: _routePoints,
    routeColorHex: _routeColorHex,
    routeWidth: _routeWidth,
    layers: _layers,
    pois: _pois,
  );

  String _formatMeters(double meters) {
    if (meters >= 1000) {
      final km = meters / 1000.0;
      return '${km.toStringAsFixed(km >= 10 ? 0 : 1)} km';
    }
    return '${meters.round()} m';
  }

  List<LngLat> _circlePerimeter({
    required LngLat center,
    required double diameterMeters,
    int steps = 36,
  }) {
    final radiusMeters = (diameterMeters / 2).clamp(50.0, 50000.0);
    final lat1 = _toRad(center.lat);
    final lng1 = _toRad(center.lng);
    const earthRadius = 6371000.0;
    final d = radiusMeters / earthRadius;

    double wrapLngDeg(double lngDeg) {
      var x = lngDeg;
      while (x > 180) {
        x -= 360;
      }
      while (x < -180) {
        x += 360;
      }
      return x;
    }

    final pts = <LngLat>[];
    for (var i = 0; i < steps; i++) {
      final bearing = 2 * 3.141592653589793 * (i / steps);
      final lat2 = math.asin(
        math.sin(lat1) * math.cos(d) +
            math.cos(lat1) * math.sin(d) * math.cos(bearing),
      );
      final lng2 =
          lng1 +
          math.atan2(
            math.sin(bearing) * math.sin(d) * math.cos(lat1),
            math.cos(d) - math.sin(lat1) * math.sin(lat2),
          );

      pts.add((lng: wrapLngDeg(_toDeg(lng2)), lat: _toDeg(lat2)));
    }

    if (pts.isNotEmpty) pts.add(pts.first);
    return pts;
  }

  double _toRad(double deg) => deg * (3.141592653589793 / 180.0);
  double _toDeg(double rad) => rad * (180.0 / 3.141592653589793);

  void _applyPerimeterCircle({LngLat? center, double? diameterMeters}) {
    final nextCenter = center ?? _perimeterCircleCenter;
    if (nextCenter == null) return;

    final nextDiameter = (diameterMeters ?? _perimeterCircleDiameterMeters)
        .clamp(200.0, 20000.0);

    setState(() {
      _perimeterCircleMode = true;
      _perimeterCircleCenter = nextCenter;
      _perimeterCircleDiameterMeters = nextDiameter;
      _perimeterPoints = _circlePerimeter(
        center: nextCenter,
        diameterMeters: nextDiameter,
      );
    });
  }

  Future<void> _openRouteStylePro() async {
    await _ensureActorContext();
    if (!_canWriteMapProjects) {
      if (!mounted) return;
      _showTopSnackBar(
        '⛔ Accès en écriture réservé aux admins master.',
        isError: true,
      );
      if (!widget.poiOnly) {
        unawaited(_continueToStep(3));
      }
      return;
    }
    // Assure un projectId existant avant d'ouvrir le wizard Pro.
    await _saveDraft();

    final projectId = _projectId;
    if (!mounted) return;
    if (projectId == null || projectId.trim().isEmpty) {
      _showTopSnackBar('❌ Impossible: projet non sauvegardé', isError: true);
      if (!widget.poiOnly) {
        unawaited(_continueToStep(3));
      }
      return;
    }

    final result = await Navigator.of(context).pushNamed(
      '/admin/route-style-pro',
      arguments: RouteStyleProArgs(
        projectId: projectId,
        circuitId: widget.circuitId,
        initialStyleUrl:
            _normalizeMapboxStyleUrl(_styleUrlController.text).trim().isEmpty
            ? null
            : _normalizeMapboxStyleUrl(_styleUrlController.text).trim(),
        initialRoute: _routePoints.isNotEmpty
            ? <rsp.LatLng>[
                for (final p in _routePoints) (lat: p.lat, lng: p.lng),
              ]
            : null,
      ),
    );

    await _reloadRouteAndStyleFromFirestore(projectId);

    // Si l'utilisateur revient sur l'étape POI, on veut voir immédiatement
    // la version “Style Pro” du tracé sur la carte.
    unawaited(_refreshPoiRouteOverlay());
    _syncPoiRouteStyleProTimer();

    // UX: pas d'écran intermédiaire "Style Pro".
    // Au retour, on navigue immédiatement vers l'étape demandée.
    if (!mounted) return;
    if (widget.poiOnly) return;
    if (result is String && result == 'previous') {
      unawaited(_continueToStep(3));
    } else {
      unawaited(_continueToStep(_poiStepIndex));
    }
  }

  Future<void> _reloadRouteAndStyleFromFirestore(String projectId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('map_projects')
          .doc(projectId)
          .get();

      if (!doc.exists) return;
      final data = doc.data() ?? <String, dynamic>{};

      void applyRouteStyle(Map<String, dynamic> m) {
        final color = (m['color'] as String?)?.trim();
        if (color != null && color.isNotEmpty) {
          _routeColorHex = color;
        }
        final w = m['width'];
        if (w is num) _routeWidth = w.toDouble();
        final rl = m['roadLike'];
        if (rl is bool) _routeRoadLike = rl;
        final sh = m['shadow3d'];
        if (sh is bool) _routeShadow3d = sh;
        final sd = m['showDirection'];
        if (sd is bool) _routeShowDirection = sd;
        final ad = m['animateDirection'];
        if (ad is bool) _routeAnimateDirection = ad;
        final sp = m['animationSpeed'];
        if (sp is num) _routeAnimationSpeed = sp.toDouble();
      }

      final routeStyle = data['routeStyle'];
      if (routeStyle is Map) {
        applyRouteStyle(Map<String, dynamic>.from(routeStyle));
      }

      // Charger la config Style Pro (si elle existe)
      final routeStylePro = data['routeStylePro'];
      if (routeStylePro is Map) {
        try {
          _routeStyleProConfig = rsp.RouteStyleConfig.fromJson(
            Map<String, dynamic>.from(routeStylePro),
          ).validated();
        } catch (_) {
          _routeStyleProConfig = null;
        }
      } else {
        _routeStyleProConfig = null;
      }

      final routeData = data['route'] as List<dynamic>?;
      if (routeData != null) {
        double asDouble(dynamic v) => v is num ? v.toDouble() : 0.0;
        _routePoints = routeData.map((p) {
          final m = Map<String, dynamic>.from(p as Map);
          return (lng: asDouble(m['lng']), lat: asDouble(m['lat']));
        }).toList();
      }

      _draftData = data;

      if (mounted) {
        setState(() {});
      }

      // Applique le rendu sur la carte POI si besoin.
      unawaited(_refreshPoiRouteOverlay());
      _syncPoiRouteStyleProTimer();
    } catch (e) {
      debugPrint('WizardPro _reloadRouteAndStyleFromFirestore error: $e');
      if (mounted) {
        _showTopSnackBar(
          '❌ Erreur recharge style: $e',
          isError: true,
          duration: const Duration(seconds: 6),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _projectId = widget.projectId;
    _currentStep = widget.poiOnly
        ? _poiStepIndex
        : (widget.initialStep ?? 0).clamp(0, 7);
    _pageController = PageController(initialPage: _currentStep);

    // Si on arrive directement sur l'étape Style Pro, on ouvre le wizard pro
    // immédiatement (pas besoin d'appuyer sur le bouton).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_currentStep == 4 && !_didAutoOpenStyleProForCurrentVisit) {
        _didAutoOpenStyleProForCurrentVisit = true;
        unawaited(_openRouteStylePro());
      }
    });

    // Step POI: hit-testing GeoJSON (tap POI => édition, tap carte => ajout)
    _poiMapController.onPoiTap = (poiId) {
      final idx = _pois.indexWhere((p) => p.id == poiId);
      if (idx < 0) return;
      _poiSelection.select(_pois[idx]);
    };
    _poiMapController.onMapTap = (lat, lng) {
      // Note: signature controller = (lat, lng), handler = (lng, lat)
      if (_isDrawingParkingZone) {
        unawaited(_onMapTapForPoi(lng, lat));
        return;
      }
      if (_poiSelection.hasSelection) {
        _poiSelection.clear();
        return;
      }
      unawaited(_onMapTapForPoi(lng, lat));
    };

    _poiSelection.addListener(_onPoiSelectionChanged);

    _loadDraftOrInitialize();
  }

  void _onPoiSelectionChanged() {
    if (!_poiSelection.hasSelection) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_poiStepScrollController.hasClients) return;
      _poiStepScrollController.animateTo(
        _poiStepScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _ensureActorContext() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = userDoc.data() ?? const <String, dynamic>{};

    final role = ((data['role'] as String?) ?? 'creator').trim();
    final groupId = ((data['groupId'] as String?) ?? 'default').trim();
    final isAdmin = (data['isAdmin'] as bool?) ?? false;

    final canWrite =
        isAdmin ||
        role == 'admin' ||
        role == 'admin_master' ||
        role == 'superAdmin' ||
        role == 'super-admin' ||
        role == 'superadmin';

    _currentUserRole = role;
    _currentGroupId = groupId;

    if (mounted && canWrite != _canWriteMapProjects) {
      setState(() => _canWriteMapProjects = canWrite);
    } else {
      _canWriteMapProjects = canWrite;
    }
  }

  Map<String, dynamic> _buildCurrentData() {
    final proCfg = _routeStyleProConfig?.validated();

    final routeStyle = <String, dynamic>{
      'color': _routeColorHex,
      'width': _routeWidth,
      'roadLike': _routeRoadLike,
      'shadow3d': _routeShadow3d,
      'showDirection': _routeShowDirection,
      'animateDirection': _routeAnimateDirection,
      'animationSpeed': _routeAnimationSpeed,
    };

    // Si un Style Pro existe, il devient la source de vérité du design publié.
    // On publie:
    // - `routeStylePro` complet (future-proof)
    // - une projection `routeStyle` compatible avec les consommateurs legacy
    //   (ex: Home/Default map qui lit `style.color/width/...`).
    if (proCfg != null) {
      routeStyle['color'] = _toHexRgb(proCfg.mainColor);
      routeStyle['width'] = proCfg.mainWidth * proCfg.widthScale3d;
      routeStyle['shadow3d'] = proCfg.shadowEnabled;
      routeStyle['animateDirection'] = proCfg.pulseEnabled;
      routeStyle['animationSpeed'] = (proCfg.pulseSpeed / 25.0).clamp(0.5, 5.0);
    }

    return {
      'circuitId': (widget.circuitId ?? _projectId ?? '').trim(),
      'name': _nameController.text.trim(),
      'countryId': _countryController.text.trim(),
      'eventId': _eventController.text.trim(),
      'description': _descriptionController.text.trim(),
      'styleUrl': _styleUrlController.text.trim(),
      'perimeter': _perimeterPoints
          .map((p) => {'lng': p.lng, 'lat': p.lat})
          .toList(),
      'perimeterCircle': {
        'enabled': _perimeterCircleMode,
        'center': _perimeterCircleCenter == null
            ? null
            : {
                'lng': _perimeterCircleCenter!.lng,
                'lat': _perimeterCircleCenter!.lat,
              },
        'diameterMeters': _perimeterCircleDiameterMeters,
      },
      'perimeterMapCamera': {
        'initialZoom': _perimeterCameraInitialZoom,
        'pitchZoomThreshold': _perimeterCameraPitchZoomThreshold,
        'pitchDegrees': _perimeterCameraPitchDegrees,
        'maxZoom': _perimeterCameraMaxZoom,
      },
      'route': _routePoints.map((p) => {'lng': p.lng, 'lat': p.lat}).toList(),
      'routeStyle': routeStyle,
      if (proCfg != null) 'routeStylePro': proCfg.toJson(),
    };
  }

  Future<void> _loadTemplates() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _templates = await _repository.listTemplates(actorUid: user.uid);
  }

  Future<void> _applyTemplate(CircuitTemplate template) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _ensureActorContext();
    if (!_canWriteMapProjects) {
      if (!mounted) return;
      _showTopSnackBar(
        '⛔ Accès en écriture réservé aux admins master.',
        isError: true,
      );
      return;
    }
    final result = await _repository.createProjectFromTemplate(
      template: template,
      groupId: _currentGroupId ?? 'default',
      actorUid: user.uid,
      projectId: _projectId,
    );
    _projectId = result['projectId'] as String;
    final current = Map<String, dynamic>.from(
      (result['current'] as Map?) ?? const <String, dynamic>{},
    );
    _nameController.text = (current['name'] as String?) ?? _nameController.text;
    _descriptionController.text =
        (current['description'] as String?) ?? _descriptionController.text;
    _selectedTemplate = template;
    await _loadDraftOrInitialize();
    if (!mounted) return;
    _showTopSnackBar('✅ Modèle appliqué: ${template.name}');
  }

  Future<void> _showDraftHistory() async {
    if (_projectId == null) {
      if (!mounted) return;
      _showTopSnackBar('ℹ️ Sauvegarde d’abord le projet.');
      return;
    }

    final drafts = await _versioning.listDrafts(
      projectId: _projectId!,
      pageSize: 30,
    );
    if (!mounted) return;

    final selected = await showDialog<CircuitDraftVersion>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Historique des versions'),
        content: SizedBox(
          width: 520,
          child: drafts.isEmpty
              ? const Text('Aucune version disponible')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: drafts.length,
                  itemBuilder: (_, index) {
                    final d = drafts[index];
                    return ListTile(
                      title: Text('Version ${d.version}'),
                      subtitle: Text(
                        d.createdAt?.toLocal().toString() ?? 'Date inconnue',
                      ),
                      onTap: () => Navigator.pop(ctx, d),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );

    if (selected == null) return;

    if (!_canWriteMapProjects) {
      if (!mounted) return;
      _showTopSnackBar(
        '⛔ Restauration réservée aux admins master.',
        isError: true,
      );
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _ensureActorContext();
    await _versioning.restoreDraft(
      projectId: _projectId!,
      draftId: selected.id,
      actorUid: user.uid,
      actorRole: _currentUserRole ?? 'creator',
      groupId: _currentGroupId ?? 'default',
    );
    await _loadDraftOrInitialize();
    if (!mounted) return;
    _showTopSnackBar('✅ Version ${selected.version} restaurée');
  }

  @override
  void dispose() {
    _poiRouteStyleProTimer?.cancel();
    _poiRouteStyleProTimer = null;
    _routeSnapDebounce?.cancel();
    _pageController.dispose();
    _perimeterEditorController.dispose();
    _routeEditorController.dispose();
    _poiMapController.dispose();
    _poiSelection.removeListener(_onPoiSelectionChanged);
    _poiSelection.dispose();
    _poiStepScrollController.dispose();
    _poiInlineNameController.dispose();
    _poiInlineLatController.dispose();
    _poiInlineLngController.dispose();
    _parkingZoneColorController.dispose();
    _nameController.dispose();
    _countryController.dispose();
    _eventController.dispose();
    _descriptionController.dispose();
    _styleUrlController.dispose();
    _styleUrlDebounce?.cancel();
    super.dispose();
  }

  void _onStyleUrlChanged(String _) {
    // Évite de recharger le style à chaque frappe.
    _styleUrlDebounce?.cancel();
    _styleUrlDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;

      final current = _styleUrlController.text;
      final normalized = _normalizeMapboxStyleUrl(current);
      if (normalized != current) {
        _styleUrlController.text = normalized;
        _styleUrlController.selection = TextSelection.collapsed(
          offset: normalized.length,
        );
      }

      setState(() {
        // La valeur source-of-truth reste _styleUrlController.text.
        // Le rebuild suffit pour propager le nouveau styleUrl aux MasLiveMap.
      });
    });
  }

  String _normalizeMapboxStyleUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';

    Uri uri;
    try {
      uri = Uri.parse(value);
    } catch (_) {
      return value;
    }

    final host = uri.host.toLowerCase();

    // Cas fréquent: URL Mapbox Studio (page HTML) copiée depuis l'UI.
    // Ex: https://studio.mapbox.com/styles/{user}/{styleId}/edit
    // => mapbox://styles/{user}/{styleId}
    if (host == 'studio.mapbox.com') {
      final seg = uri.pathSegments;
      final stylesIndex = seg.indexOf('styles');
      if (stylesIndex != -1 && seg.length >= stylesIndex + 3) {
        final user = seg[stylesIndex + 1];
        final styleId = seg[stylesIndex + 2];
        if (user.isNotEmpty && styleId.isNotEmpty) {
          return 'mapbox://styles/$user/$styleId';
        }
      }
    }

    // Certains liens finissent par ".html" (HTML, non JSON). On tente d'enlever le suffixe.
    if (value.toLowerCase().endsWith('.html')) {
      return value.substring(0, value.length - 5);
    }

    return value;
  }

  void _applyStylePreset(String styleUrl) {
    _styleUrlDebounce?.cancel();
    final normalized = _normalizeMapboxStyleUrl(styleUrl);
    _styleUrlController.text = normalized;
    _styleUrlController.selection = TextSelection.collapsed(
      offset: normalized.length,
    );
    if (!mounted) return;
    setState(() {
      // Rebuild immédiat pour que la preview réagisse au clic.
    });
  }

  void _ensurePoiInitialCamera() {
    if (_poiInitialLng != null &&
        _poiInitialLat != null &&
        _poiInitialZoom != null) {
      return;
    }

    final lng = _routePoints.isNotEmpty
        ? _routePoints.first.lng
        : (_perimeterPoints.isNotEmpty ? _perimeterPoints.first.lng : -61.533);
    final lat = _routePoints.isNotEmpty
        ? _routePoints.first.lat
        : (_perimeterPoints.isNotEmpty ? _perimeterPoints.first.lat : 16.241);
    final zoom = (_routePoints.isNotEmpty || _perimeterPoints.isNotEmpty)
        ? _perimeterCameraInitialZoom
        : 12.0;

    _poiInitialLng = lng;
    _poiInitialLat = lat;
    _poiInitialZoom = zoom;
  }

  Future<void> _loadDraftOrInitialize() async {
    try {
      setState(() => _isLoading = true);

      await _ensureActorContext();
      await _loadTemplates();

      // Si un projectId est fouirni, le charger
      if (_projectId != null) {
        final data = await _repository.loadProjectCurrent(
          projectId: _projectId!,
          fallbackCountryId: widget.countryId,
          fallbackEventId: widget.eventId,
          fallbackCircuitId: widget.circuitId,
        );

        if (data != null) {
          _draftData = data;
          _nameController.text = _draftData['name'] ?? '';
          _countryController.text = _draftData['countryId'] ?? '';
          _eventController.text = _draftData['eventId'] ?? '';
          _descriptionController.text = _draftData['description'] ?? '';
          _styleUrlController.text = _draftData['styleUrl'] ?? '';

          // Style tracé
          final routeStyle = _draftData['routeStyle'];
          if (routeStyle is Map) {
            final m = Map<String, dynamic>.from(routeStyle);
            _routeColorHex = (m['color'] as String?)?.trim().isNotEmpty == true
                ? (m['color'] as String).trim()
                : _routeColorHex;
            final w = m['width'];
            if (w is num) _routeWidth = w.toDouble();
            final rl = m['roadLike'];
            if (rl is bool) _routeRoadLike = rl;
            final sh = m['shadow3d'];
            if (sh is bool) _routeShadow3d = sh;
            final sd = m['showDirection'];
            if (sd is bool) _routeShowDirection = sd;
            final ad = m['animateDirection'];
            if (ad is bool) _routeAnimateDirection = ad;
            final sp = m['animationSpeed'];
            if (sp is num) _routeAnimationSpeed = sp.toDouble();
          }

          // Style Pro (si présent) : utilisé ensuite pour le rendu des étapes suivantes
          final routeStylePro = _draftData['routeStylePro'];
          if (routeStylePro is Map) {
            try {
              _routeStyleProConfig = rsp.RouteStyleConfig.fromJson(
                Map<String, dynamic>.from(routeStylePro),
              ).validated();
            } catch (_) {
              _routeStyleProConfig = null;
            }
          } else {
            _routeStyleProConfig = null;
          }

          // Charger points
          final perimData = _draftData['perimeter'] as List<dynamic>?;
          if (perimData != null) {
            _perimeterPoints = perimData.map((p) {
              final m = p as Map<String, dynamic>;
              return (lng: m['lng'] as double, lat: m['lat'] as double);
            }).toList();
          }

          // Optionnel: restauration du mode cercle (centre + diamètre)
          final circleData = _draftData['perimeterCircle'];
          if (circleData is Map) {
            final m = Map<String, dynamic>.from(circleData);
            final enabled = (m['enabled'] as bool?) ?? false;
            if (enabled) {
              _perimeterCircleMode = true;

              final center = m['center'];
              if (center is Map) {
                final cm = Map<String, dynamic>.from(center);
                final lng = cm['lng'];
                final lat = cm['lat'];
                if (lng is num && lat is num) {
                  _perimeterCircleCenter = (
                    lng: lng.toDouble(),
                    lat: lat.toDouble(),
                  );
                }
              }

              final diam = m['diameterMeters'];
              if (diam is num) {
                _perimeterCircleDiameterMeters = diam.toDouble();
              }

              // Si on a le centre mais pas (ou peu) de points, régénère.
              if (_perimeterCircleCenter != null &&
                  _perimeterPoints.length < 3) {
                _perimeterPoints = _circlePerimeter(
                  center: _perimeterCircleCenter!,
                  diameterMeters: _perimeterCircleDiameterMeters,
                );
              }
            }
          }

          // Caméra (étape périmètre)
          final camData = _draftData['perimeterMapCamera'];
          if (camData is Map) {
            final m = Map<String, dynamic>.from(camData);
            final iz = m['initialZoom'];
            final th = m['pitchZoomThreshold'];
            final pd = m['pitchDegrees'];
            final mz = m['maxZoom'];
            if (iz is num) _perimeterCameraInitialZoom = iz.toDouble();
            if (th is num) _perimeterCameraPitchZoomThreshold = th.toDouble();
            if (pd is num) _perimeterCameraPitchDegrees = pd.toDouble();
            if (mz is num) _perimeterCameraMaxZoom = mz.toDouble();

            _perimeterCameraInitialZoom = _perimeterCameraInitialZoom.clamp(
              0.0,
              22.0,
            );
            _perimeterCameraMaxZoom = _perimeterCameraMaxZoom.clamp(
              _perimeterCameraInitialZoom,
              22.0,
            );
            _perimeterCameraPitchZoomThreshold =
                _perimeterCameraPitchZoomThreshold.clamp(
                  0.0,
                  _perimeterCameraMaxZoom,
                );
            _perimeterCameraPitchDegrees = _perimeterCameraPitchDegrees.clamp(
              0.0,
              60.0,
            );
          }

          final routeData = _draftData['route'] as List<dynamic>?;
          if (routeData != null) {
            _routePoints = routeData.map((p) {
              final m = p as Map<String, dynamic>;
              return (lng: m['lng'] as double, lat: m['lat'] as double);
            }).toList();
          }

          // Charger layers
          _layers = await _loadLayers();

          // Assure les couches POI attendues (visit/food/assistance/parking/wc)
          // et migre les anciens types (tour/visiter -> visit).
          await _ensureDefaultPoiLayers();

          // Charger POI (paginé)
          await _loadPoisFirstPage();

          // Couche sélectionnée par défaut
          if (_layers.isNotEmpty) {
            _selectedLayer = _layers.firstWhere(
              (l) => l.type != 'route',
              orElse: () => _layers.first,
            );
          }
        }
      } else {
        // Nouveau brouillon
        _countryController.text = widget.countryId ?? '';
        _eventController.text = widget.eventId ?? '';

        // Pas de Style Pro au démarrage d'un nouveau projet
        _routeStyleProConfig = null;

        // Initialiser les couches standard en local
        _layers = await _loadLayers();
        _pois = [];
        _poisLastDoc = null;
        _hasMorePois = false;
        _isLoadingMorePois = false;
        if (_layers.isNotEmpty) {
          _selectedLayer = _layers.firstWhere(
            (l) => l.type != 'route',
            orElse: () => _layers.first,
          );
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        if (e is FirebaseException) {
          _errorMessage =
              'Erreur chargement (${e.code}): ${e.message ?? e.toString()}';
        } else {
          _errorMessage = 'Erreur chargement: $e';
        }
        _isLoading = false;
      });
    }
  }

  Future<List<MarketMapLayer>> _loadLayers() async {
    if (_projectId == null) {
      // Initialiser les 6 couches standard
      return [
        MarketMapLayer(
          id: '1',
          label: 'Tracé Route',
          type: 'route',
          isVisible: true,
          zIndex: 1,
          color: '#1A73E8',
        ),
        MarketMapLayer(
          id: '2',
          label: 'Parkings',
          type: 'parking',
          isVisible: true,
          zIndex: 2,
          color: '#FBBf24',
        ),
        MarketMapLayer(
          id: '3',
          label: 'Toilettes',
          type: 'wc',
          isVisible: true,
          zIndex: 3,
          color: '#9333EA',
        ),
        MarketMapLayer(
          id: '4',
          label: 'Food',
          type: 'food',
          isVisible: true,
          zIndex: 4,
          color: '#EF4444',
        ),
        MarketMapLayer(
          id: '5',
          label: 'Assistance',
          type: 'assistance',
          isVisible: true,
          zIndex: 5,
          color: '#34A853',
        ),
        MarketMapLayer(
          id: '6',
          label: 'Lieux à visiter',
          type: 'visit',
          isVisible: true,
          zIndex: 6,
          color: '#F59E0B',
        ),
      ];
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('map_projects')
        .doc(_projectId)
        .collection('layers')
        .orderBy('zIndex')
        .get();

    return snapshot.docs
        .map((doc) => MarketMapLayer.fromFirestore(doc))
        .toList();
  }

  String _normalizePoiLayerType(String raw) {
    final norm = raw.trim().toLowerCase();
    if (norm == 'tour' || norm == 'visiter') return 'visit';
    if (norm == 'toilet' || norm == 'toilets') return 'wc';
    return norm;
  }

  bool _poiMatchesSelectedLayer(MarketMapPOI poi, MarketMapLayer layer) {
    return _normalizePoiLayerType(poi.layerType) ==
        _normalizePoiLayerType(layer.type);
  }

  Future<void> _migrateLegacyPoiTypesToVisit({
    required String projectId,
  }) async {
    if (!_canWriteMapProjects) return;

    final db = FirebaseFirestore.instance;
    final col = db.collection('map_projects').doc(projectId).collection('pois');

    // Migration ciblée (pas de scan complet): tour/visiter -> visit
    final snap = await col
        .where('layerType', whereIn: const ['tour', 'visiter'])
        .get();
    if (snap.docs.isEmpty) return;

    WriteBatch batch = db.batch();
    int ops = 0;

    Future<void> commitIfNeeded({bool force = false}) async {
      if (ops == 0) return;
      if (!force && ops < 450) return;
      await batch.commit();
      batch = db.batch();
      ops = 0;
    }

    for (final doc in snap.docs) {
      batch.update(doc.reference, {
        'layerType': 'visit',
        'layerId': 'visit',
        // Compat: certains écrans lisent `type`
        'type': 'visit',
      });
      ops++;
      await commitIfNeeded();
    }

    await commitIfNeeded(force: true);
  }

  Future<void> _ensureDefaultPoiLayers() async {
    final projectId = _projectId;
    if (projectId == null || projectId.trim().isEmpty) return;

    // 1) Migration POI legacy (pour cohérence avec Home: visit)
    try {
      await _migrateLegacyPoiTypesToVisit(projectId: projectId);
    } catch (e) {
      debugPrint('WizardPro migrate POI types error: $e');
    }

    // 2) Assurer les couches attendues côté wizard/Home
    const defaults =
        <({String type, String label, String color, int preferredZ})>[
          (
            type: 'route',
            label: 'Tracé Route',
            color: '#1A73E8',
            preferredZ: 1,
          ),
          (type: 'parking', label: 'Parkings', color: '#FBBF24', preferredZ: 2),
          (type: 'wc', label: 'Toilettes', color: '#9333EA', preferredZ: 3),
          (type: 'food', label: 'Food', color: '#EF4444', preferredZ: 4),
          (
            type: 'assistance',
            label: 'Assistance',
            color: '#34A853',
            preferredZ: 5,
          ),
          (
            type: 'visit',
            label: 'Lieux à visiter',
            color: '#F59E0B',
            preferredZ: 6,
          ),
        ];

    bool hasExactLayerType(String t) {
      final norm = t.trim().toLowerCase();
      return _layers.any((l) => l.type.trim().toLowerCase() == norm);
    }

    final usedZ = _layers.map((l) => l.zIndex).toSet();
    int maxZ = 0;
    for (final z in usedZ) {
      if (z > maxZ) maxZ = z;
    }

    int allocZ(int preferred) {
      if (!usedZ.contains(preferred)) {
        usedZ.add(preferred);
        if (preferred > maxZ) maxZ = preferred;
        return preferred;
      }
      maxZ += 1;
      usedZ.add(maxZ);
      return maxZ;
    }

    // Si pas de couche `visit` mais une legacy `tour/visiter` existe,
    // on la convertit en `visit` pour éviter des doublons.
    final hasVisit = hasExactLayerType('visit');
    if (!hasVisit) {
      final idx = _layers.indexWhere(
        (l) => ['tour', 'visiter'].contains(l.type.trim().toLowerCase()),
      );
      if (idx >= 0 && _canWriteMapProjects) {
        final legacy = _layers[idx];
        try {
          await FirebaseFirestore.instance
              .collection('map_projects')
              .doc(projectId)
              .collection('layers')
              .doc(legacy.id)
              .set({'type': 'visit'}, SetOptions(merge: true));
          final migrated = legacy.copyWith(type: 'visit');
          _layers[idx] = migrated;
          if (_selectedLayer?.id == legacy.id) {
            _selectedLayer = migrated;
          }
        } catch (e) {
          debugPrint('WizardPro migrate layer tour->visit error: $e');
        }
      }
    }

    final db = FirebaseFirestore.instance;
    final layersCol = db
        .collection('map_projects')
        .doc(projectId)
        .collection('layers');
    WriteBatch? batch;
    int writes = 0;

    void queueWrite(DocumentReference ref, Map<String, dynamic> data) {
      batch ??= db.batch();
      batch!.set(ref, data, SetOptions(merge: true));
      writes += 1;
    }

    for (final d in defaults) {
      if (hasExactLayerType(d.type)) continue;

      final layer = MarketMapLayer(
        id: d.type,
        label: d.label,
        type: d.type,
        isVisible: true,
        zIndex: allocZ(d.preferredZ),
        color: d.color,
      );
      _layers.add(layer);
      if (_canWriteMapProjects) {
        queueWrite(layersCol.doc(layer.id), layer.toFirestore());
      }
    }

    if (batch != null && writes > 0) {
      try {
        await batch!.commit();
      } catch (e) {
        debugPrint('WizardPro ensure POI layers commit error: $e');
      }
    }

    _layers.sort((a, b) => a.zIndex.compareTo(b.zIndex));

    // Si la couche sélectionnée a disparu ou est nulle, on en choisit une valide.
    if (_selectedLayer == null && _layers.isNotEmpty) {
      _selectedLayer = _layers.firstWhere(
        (l) => _normalizePoiLayerType(l.type) != 'route',
        orElse: () => _layers.first,
      );
    }
  }

  Future<void> _loadPoisFirstPage() async {
    if (_projectId == null) {
      _pois = [];
      _poisLastDoc = null;
      _hasMorePois = false;
      _isLoadingMorePois = false;
      return;
    }

    final page = await _repository.listPoisPage(
      projectId: _projectId!,
      pageSize: _poiPageSize,
    );

    _pois = page.docs.map((doc) => MarketMapPOI.fromFirestore(doc)).toList();
    _poisLastDoc = page.docs.isNotEmpty ? page.docs.last : null;
    _hasMorePois = page.docs.length == _poiPageSize;
  }

  Future<void> _loadMorePoisPage() async {
    if (_projectId == null || _isLoadingMorePois || !_hasMorePois) return;

    setState(() => _isLoadingMorePois = true);
    try {
      final page = await _repository.listPoisPage(
        projectId: _projectId!,
        pageSize: _poiPageSize,
        startAfter: _poisLastDoc,
      );

      final incoming = page.docs
          .map((doc) => MarketMapPOI.fromFirestore(doc))
          .toList();
      final existingIds = _pois.map((p) => p.id).toSet();
      _pois.addAll(incoming.where((p) => !existingIds.contains(p.id)));

      _poisLastDoc = page.docs.isNotEmpty ? page.docs.last : _poisLastDoc;
      _hasMorePois = page.docs.length == _poiPageSize;
    } finally {
      if (mounted) {
        setState(() => _isLoadingMorePois = false);
      } else {
        _isLoadingMorePois = false;
      }
    }

    // Si l'utilisateur est déjà sur une couche, on rafraîchit l'affichage.
    if (mounted && _selectedLayer != null) {
      _refreshPoiMarkers();
    }
  }

  Future<void> _saveDraft({
    bool createSnapshot = false,
    bool ensureRouteSnapped = true,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Garantit que le tracé est bien "au milieu de la voie" au moment
      // de la persistance (si l'utilisateur clique vite après avoir posé des points).
      // On ne persiste pas ici: on laisse `_repository.saveDraft` écrire `currentData`.
      if (ensureRouteSnapped && _currentStep == 3) {
        await _ensureRouteSnappedBeforePersist();
      }

      await _ensureActorContext();
      if (!_canWriteMapProjects) {
        if (!mounted) return;
        _showTopSnackBar(
          '⛔ Sauvegarde réservée aux admins master.',
          isError: true,
        );
        return;
      }

      final isNew = _projectId == null;
      final projectId = _projectId ?? _repository.createProjectId();
      _projectId = projectId;

      final previousRouteCount = (_draftData['route'] as List?)?.length ?? 0;
      final previousPoiCount = _pois.length;
      final currentData = _buildCurrentData();

      await _repository.saveDraft(
        projectId: projectId,
        actorUid: user.uid,
        actorRole: _currentUserRole ?? 'creator',
        groupId: _currentGroupId ?? 'default',
        currentData: currentData,
        layers: _layers,
        pois: _pois,
        previousRouteCount: previousRouteCount,
        previousPoiCount: previousPoiCount,
        isNew: isNew,
      );

      _draftData = currentData;

      // Alimente l'historique des versions uniquement sur action explicite.
      // Important: ne pas créer de versions sur les autosaves silencieux (ex: snap route)
      // pour éviter de spammer la sous-collection `drafts`.
      if (createSnapshot) {
        try {
          await _versioning.saveDraftVersion(
            projectId: projectId,
            actorUid: user.uid,
            actorRole: _currentUserRole ?? 'creator',
            groupId: _currentGroupId ?? 'default',
            currentData: currentData,
            layers: _layers,
            pois: _pois,
          );
        } catch (e) {
          debugPrint('WizardPro _saveDraft snapshot error: $e');
        }
      }

      if (mounted) {
        _showTopSnackBar('✅ Brouillon sauvegardé');
      }
    } catch (e) {
      debugPrint('WizardPro _saveDraft error: $e');
      if (mounted) {
        final msg = e is FirebaseException
            ? '❌ Firestore (${e.code}): ${e.message ?? e.toString()}'
            : '❌ Erreur: $e';
        _showTopSnackBar(
          msg,
          isError: true,
          duration: const Duration(seconds: 6),
        );
      }
    }
  }

  Future<void> _continueToStep(int step) async {
    if (widget.poiOnly && step != _poiStepIndex) return;
    // Valider l'étape courante
    if (_currentStep == 1) {
      if (_nameController.text.trim().isEmpty) {
        _showTopSnackBar('❌ Nom requis', isError: true);
        return;
      }
    }

    // En quittant l'étape Tracé + Style, on force un snap immédiat et on attend.
    // Objectif: le tracé reste toujours centré sur la route, même si l'utilisateur
    // a posé les points "à la main" et enchaîne rapidement sur l'étape suivante.
    final leavingRouteStep = _currentStep == 3 && step != 3;
    if (leavingRouteStep) {
      await _ensureRouteSnappedBeforePersist();
    }

    if (_canWriteMapProjects) {
      await _saveDraft(
        createSnapshot: true,
        ensureRouteSnapped: !leavingRouteStep,
      );
    }
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _ensureRouteSnappedBeforePersist() async {
    if (_routePoints.length < 2) return;

    // Si un snap est déjà en cours, on attend un peu qu'il se termine.
    // (Evite un early-return de `_snapRouteToRoadsInternal`.)
    final startedAt = DateTime.now();
    while (mounted &&
        _isSnappingRoute &&
        DateTime.now().difference(startedAt) < const Duration(seconds: 8)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    if (!mounted) return;

    // Snap silencieux (sans snack) et sans persistance Firestore.
    // La persistance est faite ensuite via `_saveDraft`/`_repository.saveDraft`.
    await _snapRouteToRoadsInternal(
      persist: false,
      showSnackBar: false,
      expectedSeq: null,
    );
  }

  @override
  Widget build(BuildContext context) {
    const stepLabels = <String>[
      'Template',
      'Infos',
      'Périmètre',
      'Tracé + Style',
      'Style Pro',
      'POI',
      'Pré-pub',
      'Publication',
    ];

    if (_isLoading) {
      return Scaffold(
        body: SoftBackground(
          child: Column(
            children: [
              const GlassAppBar(title: 'Chargement…', padding: EdgeInsets.zero),
              const SizedBox(height: MasliveTokens.s),
              WizardStepperPills(
                currentStep: _currentStep,
                labels: stepLabels,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: MasliveTokens.s),
              const Expanded(child: Center(child: CircularProgressIndicator())),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: SoftBackground(
          child: Column(
            children: [
              const GlassAppBar(title: 'Erreur', padding: EdgeInsets.zero),
              const SizedBox(height: MasliveTokens.s),
              WizardStepperPills(
                currentStep: _currentStep,
                labels: stepLabels,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: MasliveTokens.s),
              Expanded(
                child: Center(
                  child: GlassPanel(
                    padding: const EdgeInsets.all(MasliveTokens.l),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error, size: 48, color: Colors.red),
                        const SizedBox(height: MasliveTokens.m),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: MasliveTokens.text,
                          ),
                        ),
                        const SizedBox(height: MasliveTokens.m),
                        FilledButton(
                          onPressed: () => Navigator.pop(context),
                          style: FilledButton.styleFrom(
                            backgroundColor: MasliveTokens.primary,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          child: const Text('Retour'),
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

    bool isStepEnabled(int index) {
      // UX existante: en mode POI-only, on verrouille sur l'étape POI.
      return widget.poiOnly ? index == _poiStepIndex : true;
    }

    bool isStepCompleted(int index) {
      // UX existante: en mode POI-only, on n'affiche pas de complétion.
      return widget.poiOnly ? false : index < _currentStep;
    }

    return Scaffold(
      body: SoftBackground(
        child: Column(
          children: [
            const GlassAppBar(title: 'Wizard Circuit Pro', padding: EdgeInsets.zero),
            const SizedBox(height: MasliveTokens.s),
            WizardStepperPills(
              currentStep: _currentStep,
              labels: stepLabels,
              padding: EdgeInsets.zero,
              onStepTap: (index) => unawaited(_continueToStep(index)),
              isStepEnabled: isStepEnabled,
              isStepCompleted: isStepCompleted,
            ),
            const SizedBox(height: MasliveTokens.s),
            Expanded(
              child: Stack(
                children: [
                  PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (page) {
                      setState(() => _currentStep = page);

                      // Auto-ouvrir Style Pro quand on arrive sur l'étape Style Pro (index 4)
                      // pour éviter le clic sur "Ouvrir Style Pro".
                      if (_currentStep != 4) {
                        _didAutoOpenStyleProForCurrentVisit = false;
                      }

                      // Quand on arrive sur l'étape POI, on veut afficher le circuit
                      // (Style Pro si présent) sur la carte immédiatement.
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        if (_currentStep == _poiStepIndex) {
                          unawaited(_refreshPoiRouteOverlay());
                        }

                        if (_currentStep == 4 &&
                            !_didAutoOpenStyleProForCurrentVisit) {
                          _didAutoOpenStyleProForCurrentVisit = true;
                          unawaited(_openRouteStylePro());
                        }

                        _syncPoiRouteStyleProTimer();
                      });
                    },
                    children: [
                      _buildStep0Template(),
                      _buildStep1Infos(),
                      _buildStep2Perimeter(),
                      _buildStep3RouteAndStyleTabbed(),
                      _buildStep6StylePro(),
                      _buildStep5POI(),
                      _buildStep7Validation(),
                      _buildStep8Publish(),
                    ],
                  ),

                  // Map controls (Apple Maps style): overlay right.
                  if (_currentStep == 2 || _currentStep == 3)
                    Positioned(
                      right: MasliveTokens.m,
                      top: MasliveTokens.m,
                      child: _buildCentralMapToolsBar(),
                    ),
                ],
              ),
            ),
            WizardBottomBar(
              outerPadding: EdgeInsets.zero,
              panelPadding: EdgeInsets.zero,
              showPrevious: (!widget.poiOnly && _currentStep > 0),
              onPrevious: (!widget.poiOnly && _currentStep > 0)
                  ? () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      )
                  : null,
              onSave: () => _saveDraft(createSnapshot: true),
              showNext: (!widget.poiOnly && _currentStep < 7),
              onNext: (!widget.poiOnly && _currentStep < 7)
                  ? () => _continueToStep(_currentStep + 1)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3RouteAndStyleTabbed() {
    // UX: fusion Tracé + Style (un seul affichage).
    // Tous les outils sont réunis dans la barre centrale.
    return _buildStep3RouteAndStyleUnified();
  }

  Widget _buildStep3RouteAndStyleUnified() {
    final proCfg = _routeStyleProConfig?.validated();
    return CircuitMapEditor(
      title: 'Tracé + Style',
      subtitle: 'Tracez l\'itinéraire et réglez son apparence',
      points: _routePoints,
      controller: _routeEditorController,
      perimeterOverlay: _perimeterPoints,
      lockMapToPerimeter: true,
      cameraInitialZoom: _perimeterCameraInitialZoom,
      cameraMaxZoom: _perimeterCameraMaxZoom,
      cameraPitchZoomThreshold: _perimeterCameraPitchZoomThreshold,
      cameraPitchDegrees: _perimeterCameraPitchDegrees,
      styleUrl: _normalizeMapboxStyleUrl(_styleUrlController.text).isEmpty
          ? null
          : _normalizeMapboxStyleUrl(_styleUrlController.text),
      buildings3dEnabled: proCfg?.buildings3dEnabled,
      buildingsOpacity: proCfg?.buildingOpacity,
      showToolbar: false,
      allowVerticalScroll: true,
      mapHeight: 720,
      onPointsChanged: (points) {
        final previousCount = _routePoints.length;
        setState(() {
          _routePoints = points;
        });

        // Waze-like: après ajout de point, on aligne automatiquement sur route.
        // Important: on ne spam pas pendant les glisser-déposer.
        if (_currentStep == 3 &&
            points.length >= 2 &&
            points.length > previousCount) {
          _scheduleContinuousRouteSnap();
        }
      },
      onSave: _saveDraft,
      mode: 'polyline',

      // Style itinéraire routier
      polylineColor: _parseHexColor(_routeColorHex, fallback: Colors.blue),
      polylineWidth: _routeWidth,
      polylineRoadLike: _routeRoadLike,
      polylineShadow3d: _routeShadow3d,
      polylineShowDirection: _routeShowDirection,
      polylineAnimateDirection: _routeAnimateDirection,
      polylineAnimationSpeed: _routeAnimationSpeed,
      polylineOpacity: proCfg?.opacity,
    );
  }

  Widget _buildStep0Template() {
    return GlassScrollbar(
      child: SingleChildScrollView(
        physics: _isWizardMapInteracting
            ? const NeverScrollableScrollPhysics()
            : null,
        padding: const EdgeInsets.fromLTRB(
          MasliveTokens.m,
          0,
          MasliveTokens.m,
          MasliveTokens.xl,
        ),
        child: GlassPanel(
          padding: const EdgeInsets.all(MasliveTokens.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Choisir un modèle (optionnel)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: MasliveTokens.text,
                ),
              ),
              const SizedBox(height: MasliveTokens.s),
              Text(
                'Tu peux démarrer depuis un template global ou passer cette étape.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: MasliveTokens.textSoft,
                ),
              ),
              const SizedBox(height: MasliveTokens.l),
              DropdownButtonFormField<CircuitTemplate>(
                initialValue: _selectedTemplate,
                items: _templates
                    .map(
                      (t) => DropdownMenuItem<CircuitTemplate>(
                        value: t,
                        child: Text('${t.name} (${t.category})'),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedTemplate = value),
                decoration: const InputDecoration(
                  labelText: 'Template',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: MasliveTokens.s),
              Row(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.auto_awesome),
                    onPressed: _selectedTemplate == null
                        ? null
                        : () => _applyTemplate(_selectedTemplate!),
                    label: const Text('Appliquer le modèle'),
                  ),
                  const SizedBox(width: MasliveTokens.s),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.history),
                    onPressed: _showDraftHistory,
                    label: const Text('Historique'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1Infos() {
    return GlassScrollbar(
      child: SingleChildScrollView(
        physics: _isWizardMapInteracting
            ? const NeverScrollableScrollPhysics()
            : null,
        padding: const EdgeInsets.fromLTRB(
          MasliveTokens.m,
          0,
          MasliveTokens.m,
          MasliveTokens.xl,
        ),
        child: GlassPanel(
          padding: const EdgeInsets.all(MasliveTokens.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Informations de base',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: MasliveTokens.text,
                ),
              ),
              const SizedBox(height: MasliveTokens.l),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom du circuit *',
                  hintText: 'Ex: Circuit Côte Nord',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: MasliveTokens.m),
              StreamBuilder<List<MarketCountry>>(
                stream: _marketMapService.watchCountries(),
                builder: (context, snap) {
                  final items = snap.data ?? const <MarketCountry>[];

                  // Fallback: champ texte si la liste n'est pas dispo.
                  if (snap.hasError || items.isEmpty) {
                    return TextField(
                      controller: _countryController,
                      decoration: const InputDecoration(
                        labelText: 'Pays *',
                        hintText: 'Ex: guadeloupe',
                        border: OutlineInputBorder(),
                      ),
                    );
                  }

                  return MarketCountryAutocompleteField(
                    items: items,
                    controller: _countryController,
                    labelText: 'Pays *',
                    hintText: 'Rechercher un pays…',
                    valueForOption: (c) => c.id,
                    onSelected: (_) {},
                  );
                },
              ),
              const SizedBox(height: MasliveTokens.m),
              TextField(
                controller: _eventController,
                decoration: const InputDecoration(
                  labelText: 'Événement *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: MasliveTokens.m),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: MasliveTokens.m),
              TextField(
                controller: _styleUrlController,
                onChanged: _onStyleUrlChanged,
                decoration: const InputDecoration(
                  labelText: 'Style URL Mapbox (optionnel)',
                  hintText: 'mapbox://styles/username/style-id',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: MasliveTokens.s),
              Builder(
                builder: (context) {
                  final current = _normalizeMapboxStyleUrl(
                    _styleUrlController.text,
                  );
                  final presets = <({String label, String url})>[
                    (label: 'Effacer', url: ''),
                    (
                      label: 'Streets',
                      url: 'mapbox://styles/mapbox/streets-v12',
                    ),
                    (
                      label: 'Outdoors',
                      url: 'mapbox://styles/mapbox/outdoors-v12',
                    ),
                    (
                      label: 'Satellite',
                      url: 'mapbox://styles/mapbox/satellite-streets-v12',
                    ),
                    (label: 'Light', url: 'mapbox://styles/mapbox/light-v11'),
                    (label: 'Dark', url: 'mapbox://styles/mapbox/dark-v11'),
                    (
                      label: 'Perso (stef971fwi)',
                      url:
                          'mapbox://styles/stef971fwi/cmm3zyr4q00fn01s12idvb2oe',
                    ),
                  ];

                  Widget pill({required String label, required String url}) {
                    final normalized = _normalizeMapboxStyleUrl(url);
                    final selected =
                        (normalized.isEmpty && current.isEmpty) ||
                        (normalized.isNotEmpty && normalized == current);

                    final bg = selected
                        ? MasliveTokens.primary.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.74);
                    final fg = selected ? MasliveTokens.primary : MasliveTokens.text;

                    return InkWell(
                      onTap: () => _applyStylePreset(url),
                      borderRadius: BorderRadius.circular(MasliveTokens.rPill),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(
                          horizontal: MasliveTokens.m,
                          vertical: MasliveTokens.s,
                        ),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(MasliveTokens.rPill),
                          border: Border.all(
                            color: selected
                                ? MasliveTokens.primary.withValues(alpha: 0.22)
                                : MasliveTokens.borderSoft,
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: fg,
                          ),
                        ),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Presets rapides',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: MasliveTokens.text,
                        ),
                      ),
                      const SizedBox(height: MasliveTokens.xs),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final p in presets) ...[
                              pill(label: p.label, url: p.url),
                              const SizedBox(width: MasliveTokens.xs),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: MasliveTokens.m),
              ClipRRect(
                borderRadius: BorderRadius.circular(MasliveTokens.rL),
                child: SizedBox(
                  height: 440,
                  child: _wrapWizardMapToBlockScroll(
                    MasLiveMap(
                      initialLng: _routePoints.isNotEmpty
                          ? _routePoints.first.lng
                          : (_perimeterPoints.isNotEmpty
                                ? _perimeterPoints.first.lng
                                : -61.533),
                      initialLat: _routePoints.isNotEmpty
                          ? _routePoints.first.lat
                          : (_perimeterPoints.isNotEmpty
                                ? _perimeterPoints.first.lat
                                : 16.241),
                      initialZoom: (_routePoints.isNotEmpty ||
                              _perimeterPoints.isNotEmpty)
                          ? 13.5
                          : 12.0,
                      styleUrl: _normalizeMapboxStyleUrl(
                                _styleUrlController.text,
                              ).isEmpty
                          ? null
                          : _normalizeMapboxStyleUrl(_styleUrlController.text),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: MasliveTokens.xl),
              GlassPanel(
                radius: MasliveTokens.rM,
                opacity: 0.74,
                padding: const EdgeInsets.all(MasliveTokens.m),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: MasliveTokens.textSoft,
                    ),
                    const SizedBox(width: MasliveTokens.s),
                    Expanded(
                      child: Text(
                        'Complétez les informations de base, puis définissez le périmètre et le tracé sur les étapes suivantes.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: MasliveTokens.textSoft,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep2Perimeter() {
    final proCfg = _routeStyleProConfig?.validated();
    return CircuitMapEditor(
      title: 'Définir le périmètre',
      subtitle: 'Tracez la zone de couverture (polygon fermé)',
      points: _perimeterPoints,
      controller: _perimeterEditorController,
      styleUrl: _normalizeMapboxStyleUrl(_styleUrlController.text).isEmpty
          ? null
          : _normalizeMapboxStyleUrl(_styleUrlController.text),
      buildings3dEnabled: proCfg?.buildings3dEnabled,
      buildingsOpacity: proCfg?.buildingOpacity,

      // Verrouillage + caméra (périmètre)
      lockMapToPerimeter: true,
      cameraInitialZoom: _perimeterCameraInitialZoom,
      cameraMaxZoom: _perimeterCameraMaxZoom,
      cameraPitchZoomThreshold: _perimeterCameraPitchZoomThreshold,
      cameraPitchDegrees: _perimeterCameraPitchDegrees,

      editingEnabled: true,
      onPointAddedOverride: _perimeterCircleMode
          ? (p) {
              _applyPerimeterCircle(center: p);
            }
          : null,
      centerMarker: _perimeterCircleMode ? _perimeterCircleCenter : null,
      showPointMarkers: !_perimeterCircleMode,
      showPointsList: !_perimeterCircleMode,
      showToolbar: false,
      showHeader: false,
      allowVerticalScroll: true,
      mapHeight: 720,
      pointsListMaxHeight: 120,
      onPointsChanged: (points) {
        setState(() {
          _perimeterPoints = points;
        });
      },
      onSave: _saveDraft,
    );
  }

  Widget _buildCentralMapToolsBar() {
    final isPerimeter = _currentStep == 2;
    final controller = isPerimeter
        ? _perimeterEditorController
        : _routeEditorController;

    final isRouteAndStyleStep = !isPerimeter && _currentStep == 3;

    Widget content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: GlassPanel(
        radius: MasliveTokens.rM,
        opacity: 0.76,
        padding: const EdgeInsets.symmetric(
          horizontal: MasliveTokens.s,
          vertical: MasliveTokens.xs,
        ),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final routeIsLooped =
                !isPerimeter &&
                _routePoints.length >= 2 &&
                _routePoints.first == _routePoints.last;

            final perimeterIsLooped =
                isPerimeter &&
                _perimeterPoints.length >= 2 &&
                _perimeterPoints.first == _perimeterPoints.last;

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.undo),
                    onPressed: controller.canUndo ? controller.undo : null,
                    tooltip: 'Annuler',
                  ),
                  IconButton(
                    icon: const Icon(Icons.redo),
                    onPressed: controller.canRedo ? controller.redo : null,
                    tooltip: 'Rétablir',
                  ),
                  const VerticalDivider(),

                  if (isPerimeter && !_perimeterCircleMode)
                    IconButton(
                      icon: const Icon(Icons.loop_rounded),
                      onPressed: controller.pointCount >= 2
                          ? controller.closePath
                          : null,
                      tooltip: 'Fermer le polygone',
                    ),
                  if (isPerimeter) ...[
                    const SizedBox(width: 4),
                    FilterChip(
                      label: const Text('Boucle fermée'),
                      selected: perimeterIsLooped,
                      shape: StadiumBorder(
                        side: BorderSide(color: MasliveTokens.borderSoft),
                      ),
                      side: BorderSide(color: MasliveTokens.borderSoft),
                      selectedColor:
                          MasliveTokens.primary.withValues(alpha: 0.15),
                      onSelected:
                          (_perimeterCircleMode || controller.pointCount < 2)
                          ? null
                          : (v) {
                              if (v) {
                                controller.closePath();
                              } else {
                                controller.openPath();
                              }
                            },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Cercle'),
                      selected: _perimeterCircleMode,
                      shape: StadiumBorder(
                        side: BorderSide(color: MasliveTokens.borderSoft),
                      ),
                      side: BorderSide(color: MasliveTokens.borderSoft),
                      selectedColor:
                          MasliveTokens.primary.withValues(alpha: 0.15),
                      onSelected: (v) {
                        if (v) {
                          if (_perimeterCircleCenter != null) {
                            _applyPerimeterCircle();
                            return;
                          }
                          if (_perimeterPoints.isNotEmpty) {
                            _applyPerimeterCircle(
                              center: _perimeterPoints.first,
                            );
                            return;
                          }
                          setState(() {
                            _perimeterCircleMode = true;
                            _perimeterPoints = [];
                          });
                          _showTopSnackBar(
                            '🧭 Tape sur la carte pour poser le centre du cercle.',
                          );
                        } else {
                          setState(() {
                            _perimeterCircleMode = false;
                          });
                        }
                      },
                    ),
                    if (_perimeterCircleMode) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Réduire diamètre',
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () {
                          final next = (_perimeterCircleDiameterMeters - 200.0)
                              .clamp(200.0, 20000.0);
                          if (_perimeterCircleCenter != null) {
                            _applyPerimeterCircle(diameterMeters: next);
                          } else {
                            setState(
                              () => _perimeterCircleDiameterMeters = next,
                            );
                          }
                        },
                      ),
                      Text(
                        'Ø ${_formatMeters(_perimeterCircleDiameterMeters)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      IconButton(
                        tooltip: 'Augmenter diamètre',
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () {
                          final next = (_perimeterCircleDiameterMeters + 200.0)
                              .clamp(200.0, 20000.0);
                          if (_perimeterCircleCenter != null) {
                            _applyPerimeterCircle(diameterMeters: next);
                          } else {
                            setState(
                              () => _perimeterCircleDiameterMeters = next,
                            );
                          }
                        },
                      ),
                    ],
                  ],

                  if (isPerimeter) ...[
                    const VerticalDivider(),
                    const Text(
                      'Caméra',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),

                    IconButton(
                      tooltip: 'Zoom initial -',
                      icon: const Icon(Icons.zoom_out),
                      onPressed: () {
                        setState(() {
                          _perimeterCameraInitialZoom =
                              (_perimeterCameraInitialZoom - 0.5).clamp(
                                0.0,
                                22.0,
                              );
                          _perimeterCameraMaxZoom = _perimeterCameraMaxZoom
                              .clamp(_perimeterCameraInitialZoom, 22.0);
                          _perimeterCameraPitchZoomThreshold =
                              _perimeterCameraPitchZoomThreshold.clamp(
                                0.0,
                                _perimeterCameraMaxZoom,
                              );
                        });
                      },
                    ),
                    Text(
                      'Init ${_perimeterCameraInitialZoom.toStringAsFixed(1)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    IconButton(
                      tooltip: 'Zoom initial +',
                      icon: const Icon(Icons.zoom_in),
                      onPressed: () {
                        setState(() {
                          _perimeterCameraInitialZoom =
                              (_perimeterCameraInitialZoom + 0.5).clamp(
                                0.0,
                                22.0,
                              );
                          _perimeterCameraMaxZoom = _perimeterCameraMaxZoom
                              .clamp(_perimeterCameraInitialZoom, 22.0);
                          _perimeterCameraPitchZoomThreshold =
                              _perimeterCameraPitchZoomThreshold.clamp(
                                0.0,
                                _perimeterCameraMaxZoom,
                              );
                        });
                      },
                    ),
                    const SizedBox(width: 10),

                    IconButton(
                      tooltip: 'Seuil tilt -',
                      icon: const Icon(Icons.expand_more),
                      onPressed: () {
                        setState(() {
                          _perimeterCameraPitchZoomThreshold =
                              (_perimeterCameraPitchZoomThreshold - 0.5).clamp(
                                0.0,
                                _perimeterCameraMaxZoom,
                              );
                        });
                      },
                    ),
                    Text(
                      'Seuil ${_perimeterCameraPitchZoomThreshold.toStringAsFixed(1)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    IconButton(
                      tooltip: 'Seuil tilt +',
                      icon: const Icon(Icons.expand_less),
                      onPressed: () {
                        setState(() {
                          _perimeterCameraPitchZoomThreshold =
                              (_perimeterCameraPitchZoomThreshold + 0.5).clamp(
                                0.0,
                                _perimeterCameraMaxZoom,
                              );
                        });
                      },
                    ),
                    const SizedBox(width: 10),

                    IconButton(
                      tooltip: 'Pitch -',
                      icon: const Icon(Icons.threed_rotation),
                      onPressed: () {
                        setState(() {
                          _perimeterCameraPitchDegrees =
                              (_perimeterCameraPitchDegrees - 5.0).clamp(
                                0.0,
                                60.0,
                              );
                        });
                      },
                    ),
                    Text(
                      'Pitch ${_perimeterCameraPitchDegrees.toStringAsFixed(0)}°',
                      style: const TextStyle(fontSize: 12),
                    ),
                    IconButton(
                      tooltip: 'Pitch +',
                      icon: const Icon(Icons.rotate_right),
                      onPressed: () {
                        setState(() {
                          _perimeterCameraPitchDegrees =
                              (_perimeterCameraPitchDegrees + 5.0).clamp(
                                0.0,
                                60.0,
                              );
                        });
                      },
                    ),
                    const SizedBox(width: 10),

                    IconButton(
                      tooltip: 'Zoom max -',
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        setState(() {
                          _perimeterCameraMaxZoom =
                              (_perimeterCameraMaxZoom - 0.5).clamp(
                                _perimeterCameraInitialZoom,
                                22.0,
                              );
                          _perimeterCameraPitchZoomThreshold =
                              _perimeterCameraPitchZoomThreshold.clamp(
                                0.0,
                                _perimeterCameraMaxZoom,
                              );
                        });
                      },
                    ),
                    Text(
                      'Max ${_perimeterCameraMaxZoom.toStringAsFixed(1)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    IconButton(
                      tooltip: 'Zoom max +',
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () {
                        setState(() {
                          _perimeterCameraMaxZoom =
                              (_perimeterCameraMaxZoom + 0.5).clamp(
                                _perimeterCameraInitialZoom,
                                22.0,
                              );
                          _perimeterCameraPitchZoomThreshold =
                              _perimeterCameraPitchZoomThreshold.clamp(
                                0.0,
                                _perimeterCameraMaxZoom,
                              );
                        });
                      },
                    ),
                  ],

                  IconButton(
                    icon: const Icon(Icons.flip_to_back),
                    onPressed: controller.pointCount >= 2
                        ? controller.reversePath
                        : null,
                    tooltip: 'Inverser sens',
                  ),
                  IconButton(
                    icon: const Icon(Icons.compress_rounded),
                    onPressed: controller.pointCount >= 3
                        ? controller.simplifyTrack
                        : null,
                    tooltip: 'Simplifier tracé',
                  ),

                  if (isRouteAndStyleStep) ...[
                    IconButton(
                      icon: _isSnappingRoute
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.alt_route_rounded),
                      onPressed:
                          (!_isSnappingRoute && controller.pointCount >= 2)
                          ? _snapRouteToRoads
                          : null,
                      tooltip: 'Snap sur route (Waze)',
                    ),

                    const SizedBox(width: 4),
                    ToggleButtons(
                      isSelected: [routeIsLooped, !routeIsLooped],
                      borderRadius: BorderRadius.circular(10),
                      constraints: const BoxConstraints(minHeight: 36),
                      onPressed: controller.pointCount >= 2
                          ? (index) {
                              if (index == 0) {
                                controller.closePath();
                              } else {
                                controller.openPath();
                              }
                            }
                          : null,
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            children: [
                              Icon(Icons.loop_rounded, size: 18),
                              SizedBox(width: 6),
                              Text('Boucler', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            children: [
                              Icon(Icons.flag_rounded, size: 18),
                              SizedBox(width: 6),
                              Text('Arrivée', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.delete_sweep),
                    onPressed: controller.pointCount > 0
                        ? controller.clearAll
                        : null,
                    tooltip: 'Effacer tous',
                  ),
                  const VerticalDivider(),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${controller.pointCount} points',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${controller.distanceKm.toStringAsFixed(2)} km',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (!isPerimeter && _currentStep == 3) ...[
                    const VerticalDivider(),
                    _buildRouteStyleControls(),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );

    if (kIsWeb) {
      content = PointerInterceptor(child: content);
    }
    return content;
  }

  Future<void> _snapRouteToRoads() async {
    await _snapRouteToRoadsInternal(
      persist: true,
      showSnackBar: true,
      expectedSeq: null,
    );
  }

  void _scheduleContinuousRouteSnap() {
    if (_routePoints.length < 2) return;

    _routeSnapDebounce?.cancel();
    final seq = ++_routeSnapSeq;
    _routeSnapDebounce = Timer(const Duration(milliseconds: 650), () {
      _attemptContinuousRouteSnap(seq);
    });
  }

  void _attemptContinuousRouteSnap(int seq) {
    if (!mounted) return;
    if (seq != _routeSnapSeq) return;

    // Si un snap est en cours, on retente un peu plus tard.
    if (_isSnappingRoute) {
      _routeSnapDebounce?.cancel();
      _routeSnapDebounce = Timer(const Duration(milliseconds: 350), () {
        _attemptContinuousRouteSnap(seq);
      });
      return;
    }

    // Mode silencieux + sans persistance: évite de spammer Firestore.
    _snapRouteToRoadsInternal(
      persist: false,
      showSnackBar: false,
      expectedSeq: seq,
    );
  }

  Future<void> _snapRouteToRoadsInternal({
    required bool persist,
    required bool showSnackBar,
    required int? expectedSeq,
  }) async {
    if (_routePoints.length < 2) return;
    if (_isSnappingRoute) return;

    // Anti-stale: on invalide les snaps en cours si une nouvelle édition arrive.
    final seq = expectedSeq ?? ++_routeSnapSeq;

    setState(() => _isSnappingRoute = true);
    try {
      final service = snap.RouteSnapService();
      final input = <rsp.LatLng>[
        for (final p in _routePoints) (lat: p.lat, lng: p.lng),
      ];

      final snapped = await service.snapToRoad(
        input,
        options: const snap.SnapOptions(
          toleranceMeters: 35.0,
          simplifyPercent: 0.0,
        ),
      );

      if (!mounted) return;
      if (seq != _routeSnapSeq) return;

      final output = <LngLat>[
        for (final p in snapped.points) (lng: p.lng, lat: p.lat),
      ];

      setState(() {
        _routePoints = output;
      });

      if (showSnackBar) {
        _showTopSnackBar(
          '✅ Tracé aligné sur la route (${output.length} points)',
        );
      }

      if (persist && _projectId != null) {
        await _saveDraft(ensureRouteSnapped: false);
      }
    } catch (e) {
      debugPrint('WizardPro _snapRouteToRoadsInternal error: $e');
      if (!mounted) return;
      if (seq != _routeSnapSeq) return;
      if (showSnackBar) {
        _showTopSnackBar(
          '❌ Snap impossible: $e',
          isError: true,
          duration: const Duration(seconds: 6),
        );
      }
    } finally {
      if (mounted) setState(() => _isSnappingRoute = false);
    }
  }

  Widget _buildRouteStyleControls() {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = <String, String>{
      '#1A73E8': 'Bleu',
      '#34A853': 'Vert',
      '#EF4444': 'Rouge',
      '#F59E0B': 'Orange',
    };
    const proBlue = Color(0xFF1A73E8);

    return Row(
      children: [
        PopupMenuButton<String>(
          tooltip: 'Couleur du tracé',
          initialValue: _routeColorHex,
          onSelected: (hex) {
            setState(() => _routeColorHex = hex);
          },
          itemBuilder: (context) => [
            for (final e in colors.entries)
              PopupMenuItem<String>(
                value: e.key,
                child: Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: _parseHexColor(e.key, fallback: Colors.blue),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(e.value),
                  ],
                ),
              ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.color_lens, color: colorScheme.onSurface),
                const SizedBox(width: 6),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _parseHexColor(
                      _routeColorHex,
                      fallback: colorScheme.primary,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: colorScheme.outline, width: 1),
                  ),
                ),
              ],
            ),
          ),
        ),

        SizedBox(
          width: 140,
          child: Row(
            children: [
              const Text(
                'L',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: Slider(
                  value: _routeWidth.clamp(2.0, 18.0),
                  min: 2.0,
                  max: 18.0,
                  divisions: 16,
                  label: _routeWidth.toStringAsFixed(0),
                  onChanged: (v) {
                    setState(() => _routeWidth = v);
                  },
                ),
              ),
            ],
          ),
        ),

        IconButton(
          tooltip: 'Itinéraire routier',
          onPressed: () => setState(() => _routeRoadLike = !_routeRoadLike),
          icon: Icon(
            Icons.route,
            color: _routeRoadLike ? proBlue : colorScheme.onSurfaceVariant,
          ),
        ),
        IconButton(
          tooltip: 'Ombre 3D',
          onPressed: _routeRoadLike
              ? () => setState(() => _routeShadow3d = !_routeShadow3d)
              : null,
          icon: Icon(
            Icons.layers,
            color: (_routeRoadLike && _routeShadow3d)
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant,
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: _routeShowDirection
                ? proBlue.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _routeShowDirection
                  ? proBlue.withValues(alpha: 0.35)
                  : colorScheme.outline.withValues(alpha: 0.50),
            ),
          ),
          child: IconButton(
            tooltip: 'Sens (flèches)',
            onPressed: () {
              setState(() {
                _routeShowDirection = !_routeShowDirection;
                // Si on coupe l'affichage des flèches, on coupe aussi l'animation.
                if (!_routeShowDirection) {
                  _routeAnimateDirection = false;
                }
              });
            },
            icon: Icon(
              Icons.navigation,
              color: _routeShowDirection
                  ? proBlue
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Animation sens de marche',
          onPressed: _routeShowDirection
              ? () => setState(
                  () => _routeAnimateDirection = !_routeAnimateDirection,
                )
              : null,
          icon: Icon(
            _routeAnimateDirection
                ? Icons.pause_circle_filled
                : Icons.play_circle_filled,
            color: _routeAnimateDirection
                ? proBlue
                : colorScheme.onSurfaceVariant,
          ),
        ),

        if (_routeAnimateDirection)
          SizedBox(
            width: 160,
            child: Row(
              children: [
                const Text(
                  'V',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: Slider(
                    value: _routeAnimationSpeed.clamp(0.5, 5.0),
                    min: 0.5,
                    max: 5.0,
                    divisions: 9,
                    label: _routeAnimationSpeed.toStringAsFixed(1),
                    onChanged: (v) {
                      setState(() => _routeAnimationSpeed = v);
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStep6StylePro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          MasliveTokens.m,
          0,
          MasliveTokens.m,
          MasliveTokens.m,
        ),
        child: GlassPanel(
          radius: MasliveTokens.rL,
          opacity: 0.76,
          padding: const EdgeInsets.all(MasliveTokens.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(height: 12),
              Text(
                'Ouverture du Style Pro…',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MasliveTokens.textSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _parseHexColor(String hex, {required Color fallback}) {
    final h = hex.trim();
    final m = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(h);
    if (m == null) return fallback;
    final rgb = int.parse(m.group(1)!, radix: 16);
    return Color(0xFF000000 | rgb);
  }

  Widget _buildStep5POI() {
    _ensurePoiInitialCamera();

    Widget buildPoiToolsPanel({required List<MarketMapLayer> poiLayers}) {
      IconButton toolButton({
        required Widget icon,
        required String tooltip,
        required VoidCallback? onPressed,
      }) {
        return IconButton.filledTonal(
          onPressed: onPressed,
          tooltip: tooltip,
          icon: icon,
        );
      }

      return GlassPanel(
        radius: MasliveTokens.rL,
        opacity: 0.78,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.place_outlined, color: MasliveTokens.textSoft),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Points d\'intérêt (POI)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: MasliveTokens.text,
                    ),
                  ),
                ),
                toolButton(
                  icon: const Icon(Icons.edit_location_alt_rounded),
                  tooltip: 'Ajouter un POI (coordonnées manuelles)',
                  onPressed: (_selectedLayer == null || _pois.length >= _poiLimit)
                      ? null
                      : () {
                          // Pré-remplissage simple (l'utilisateur peut ajuster).
                          double lng;
                          double lat;
                          if (_routePoints.isNotEmpty) {
                            lng = _routePoints.first.lng;
                            lat = _routePoints.first.lat;
                          } else if (_perimeterPoints.isNotEmpty) {
                            lng = _perimeterPoints.first.lng;
                            lat = _perimeterPoints.first.lat;
                          } else {
                            lng = -61.533;
                            lat = 16.241;
                          }

                          unawaited(_createPoiAt(lng: lng, lat: lat));
                        },
                ),
                toolButton(
                  icon: const Icon(Icons.my_location),
                  tooltip: 'Ajouter un POI à la position actuelle',
                  onPressed: (_selectedLayer == null || _pois.length >= _poiLimit)
                      ? null
                      : _addPoiAtCurrentCenter,
                ),
                if (_selectedLayer?.type == 'parking')
                  toolButton(
                    icon: Icon(
                      _isDrawingParkingZone
                          ? Icons.crop_square
                          : Icons.crop_square_rounded,
                    ),
                    tooltip: _isDrawingParkingZone
                        ? 'Mode zone parking (en cours)'
                        : 'Créer une zone parking (périmètre)',
                    onPressed: (_pois.length >= _poiLimit)
                        ? null
                        : () {
                            if (_isDrawingParkingZone) {
                              _cancelParkingZoneDrawing();
                            } else {
                              _startParkingZoneDrawing();
                            }
                          },
                  ),
                toolButton(
                  icon: const Icon(Icons.save_alt),
                  tooltip: 'Enregistrer les POI',
                  onPressed: _isLoading ? null : _saveDraft,
                ),
                toolButton(
                  icon: const Icon(Icons.sync),
                  tooltip: 'Réimporter POI/couches depuis MarketMap',
                  onPressed: (_isLoading || _isRefreshingMarketImport)
                      ? null
                      : _refreshImportFromMarketMap,
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (_selectedLayer?.type == 'parking' && _isDrawingParkingZone)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Zone parking: ${_parkingZonePoints.length} points (tap sur la carte)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: MasliveTokens.text,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _cancelParkingZoneDrawing,
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 6),
                    FilledButton.tonal(
                      onPressed: _parkingZonePoints.length < 3
                          ? null
                          : _finishParkingZoneDrawing,
                      child: const Text('Créer la zone'),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Text(
                  'POI: ${_pois.length}/$_poiLimit',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _pois.length >= _poiLimit
                        ? Colors.redAccent
                        : (_pois.length >= (_poiLimit * 0.9)
                            ? Colors.orange
                            : MasliveTokens.text),
                  ),
                ),
                const SizedBox(width: 8),
                if (_hasMorePois || _isLoadingMorePois)
                  TextButton.icon(
                    onPressed: _isLoadingMorePois ? null : _loadMorePoisPage,
                    icon: _isLoadingMorePois
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.expand_more, size: 16),
                    label: const Text('Charger +100'),
                  ),
              ],
            ),
            if (_pois.length >= _poiLimit)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Limite atteinte: supprime des POI pour continuer.',
                  style: TextStyle(fontSize: 12, color: Colors.redAccent),
                ),
              ),
            const SizedBox(height: 10),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Apparence (nouveau POI)',
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _defaultPoiAppearanceId,
                  isExpanded: true,
                  items: [
                    for (final p in kMasLivePoiAppearancePresets)
                      DropdownMenuItem(value: p.id, child: Text(p.label)),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _defaultPoiAppearanceId = v);
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (poiLayers.isNotEmpty)
              Row(
                children: [
                  const Text(
                    'Catégorie: ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _selectedLayer?.label ?? 'Choisissez une catégorie',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              )
            else
              const Text(
                'Aucune couche trouvée. Vérifiez la configuration du projet.',
                style: TextStyle(fontSize: 12, color: Colors.redAccent),
              ),
            if (_selectedLayer != null) ...[
              const SizedBox(height: 10),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                initiallyExpanded: true,
                title: Text(
                  'POI de la couche: ${_selectedLayer!.label}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MasliveTokens.text,
                  ),
                ),
                subtitle: Text(
                  '${_pois.where((p) => _poiMatchesSelectedLayer(p, _selectedLayer!)).length} POI',
                  style: TextStyle(
                    fontSize: 12,
                    color: MasliveTokens.textSoft,
                  ),
                ),
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final poi in _pois.where(
                          (p) => _poiMatchesSelectedLayer(p, _selectedLayer!),
                        ))
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.place_outlined, size: 18),
                            onTap: () => _poiSelection.select(poi),
                            title: Text(
                              poi.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: MasliveTokens.text,
                              ),
                            ),
                            subtitle: Text(
                              '${poi.lng.toStringAsFixed(5)}, ${poi.lat.toStringAsFixed(5)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: MasliveTokens.textSoft,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Modifier',
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () => _editPoi(poi),
                                ),
                                IconButton(
                                  tooltip: 'Supprimer',
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                  ),
                                  onPressed: () => _deletePoi(poi),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_hasMorePois || _isLoadingMorePois)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _isLoadingMorePois ? null : _loadMorePoisPage,
                        icon: _isLoadingMorePois
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.more_horiz),
                        label: const Text('Voir plus'),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    Widget interceptPointersIfNeeded(Widget child) {
      // Sur Flutter web + HtmlElementView (Mapbox), des clics peuvent traverser
      // certains overlays et déclencher le onTap de la carte en arrière-plan.
      if (!kIsWeb) return child;
      return PointerInterceptor(child: child);
    }

    final poiLayers = _layers.where((l) => l.type != 'route').toList();

    final viewportHeight = MediaQuery.sizeOf(context).height;

    return ChangeNotifierProvider<PoiSelectionController>.value(
      value: _poiSelection,
      child: SingleChildScrollView(
        controller: _poiStepScrollController,
        physics: _isWizardMapInteracting
            ? const NeverScrollableScrollPhysics()
            : null,
        child: Column(
          children: [
            SizedBox(
              height: viewportHeight,
              child: Stack(
                children: [
                  _wrapWizardMapToBlockScroll(
                    MasLiveMap(
                      controller: _poiMapController,
                      initialLng: _poiInitialLng ?? -61.533,
                      initialLat: _poiInitialLat ?? 16.241,
                      initialZoom: _poiInitialZoom ?? 12.0,
                      styleUrl:
                          _normalizeMapboxStyleUrl(
                            _styleUrlController.text,
                          ).isEmpty
                          ? null
                          : _normalizeMapboxStyleUrl(_styleUrlController.text),
                      onMapReady: (ctrl) async {
                        final cfg = _routeStyleProConfig?.validated();
                        if (cfg != null) {
                          await ctrl.setBuildings3d(
                            enabled: cfg.buildings3dEnabled,
                            opacity: cfg.buildingOpacity,
                          );
                        }

                        // Restrictions périmètre (après l'étape "Périmètre")
                        // - empêche de pan en dehors du périmètre
                        // - applique le zoom max configuré
                        final perim = _perimeterPoints;
                        final isClosed =
                            perim.length >= 3 && perim.first == perim.last;
                        if (isClosed) {
                          var west = perim.first.lng;
                          var east = perim.first.lng;
                          var south = perim.first.lat;
                          var north = perim.first.lat;
                          for (final p in perim) {
                            if (p.lng < west) west = p.lng;
                            if (p.lng > east) east = p.lng;
                            if (p.lat < south) south = p.lat;
                            if (p.lat > north) north = p.lat;
                          }
                          await ctrl.setZoomRange(
                            maxZoom: _perimeterCameraMaxZoom,
                          );
                          await ctrl.setMaxBounds(
                            west: west,
                            south: south,
                            east: east,
                            north: north,
                          );
                        } else {
                          await ctrl.setZoomRange(
                            maxZoom: _perimeterCameraMaxZoom,
                          );
                          await ctrl.setMaxBounds();
                        }

                        await _refreshPoiMarkers();
                        await _refreshPoiRouteOverlay();
                        _syncPoiRouteStyleProTimer();
                      },
                    ),
                  ),

                  if (poiLayers.isNotEmpty)
                    Align(
                      alignment: Alignment.topRight,
                      child: interceptPointersIfNeeded(
                        HomeVerticalNavMenu(
                          margin: const EdgeInsets.only(right: 0, top: 12),
                          horizontalPadding: 6,
                          verticalPadding: 10,
                          items: [
                            for (final layer in poiLayers)
                              (() {
                                final v = _poiNavVisualForLayerType(layer.type);
                                return HomeVerticalNavItem(
                                  label: layer.label,
                                  icon: v.icon,
                                  iconWidget: v.iconWidget,
                                  fullBleed: v.fullBleed,
                                  tintOnSelected: v.tintOnSelected,
                                  showBorder: v.showBorder,
                                  selected: _selectedLayer?.type == layer.type,
                                  onTap: () {
                                    _poiSelection.clear();
                                    setState(() {
                                      _isDrawingParkingZone = false;
                                      _parkingZonePoints = <LngLat>[];
                                      _poiInlineEditorMode =
                                          _PoiInlineEditorMode.none;
                                      _poiEditingPoi = null;
                                      _poiInlineError = null;
                                      _selectedLayer = layer;
                                    });
                                    _refreshPoiMarkers();
                                  },
                                );
                              })(),
                          ],
                        ),
                      ),
                    ),

                  // Fin Stack carte
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: buildPoiToolsPanel(poiLayers: poiLayers),
            ),

            Consumer<PoiSelectionController>(
              builder: (context, selection, _) {
                final selected = selection.selectedPoi;
                if (_poiInlineEditorMode != _PoiInlineEditorMode.none) {
                  return _buildPoiInlineEditorSection();
                }

                return PoiInlinePopup(
                  selectedPoi: selected,
                  onClose: selection.clear,
                  onEdit: selected == null ? () {} : () => _editPoi(selected),
                  onDelete: selected == null
                      ? () {}
                      : () => _deletePoi(selected),
                  categoryLabel: (poi) {
                    final match = _layers
                        .where((l) => l.type == poi.layerType)
                        .toList();
                    return match.isNotEmpty ? match.first.label : poi.layerType;
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ====== Gestion POI (étape 4) ======

  double? _tryParseCoord(String raw) {
    final norm = raw.trim().replaceAll(',', '.');
    return double.tryParse(norm);
  }

  void _scrollPoiBottomSectionIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_poiStepScrollController.hasClients) return;
      _poiStepScrollController.animateTo(
        _poiStepScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _openPoiCreatePointSection({
    required double initialLng,
    required double initialLat,
  }) {
    _poiSelection.clear();
    setState(() {
      _poiInlineEditorMode = _PoiInlineEditorMode.createPoint;
      _poiEditingPoi = null;
      _poiInlineError = null;
      _poiInlineAppearanceId = _defaultPoiAppearanceId;
      _poiInlineNameController.text = '';
      _poiInlineLatController.text = initialLat.toStringAsFixed(6);
      _poiInlineLngController.text = initialLng.toStringAsFixed(6);
    });
    _scrollPoiBottomSectionIntoView();
  }

  void _openPoiCreateZoneSection({required List<LngLat> perimeterPoints}) {
    _poiSelection.clear();

    final defaultHex =
        _normalizeColorHex(_selectedLayer?.color) ??
        _defaultLayerColorHex('parking') ??
        _parkingZoneFillColorHex;

    setState(() {
      _poiInlineEditorMode = _PoiInlineEditorMode.createZone;
      _poiEditingPoi = null;
      _poiInlineError = null;
      _poiInlineNameController.text = '';

      _parkingZoneFillColorHex = defaultHex;
      _parkingZoneStrokeColorHex = defaultHex;
      _parkingZoneStrokeFollowsFill = true;
      _parkingZoneFillOpacity = _parkingZoneDefaultFillOpacity;
      _parkingZoneStrokeWidth = _parkingZoneDefaultStrokeWidth;
      _parkingZoneStrokeDash = 'solid';
      _parkingZonePattern = 'none';
      _parkingZonePatternOpacity = _parkingZoneDefaultPatternOpacity;
      _parkingZoneColorController.text = defaultHex;

      // Pour une zone, lat/lng servent de centre (centroid approx.)
      final centroid = _centroidOf(perimeterPoints);
      _poiInlineLatController.text = centroid.lat.toStringAsFixed(6);
      _poiInlineLngController.text = centroid.lng.toStringAsFixed(6);
    });
    _scrollPoiBottomSectionIntoView();
  }

  void _openPoiEditSection(MarketMapPOI poi) {
    _poiSelection.select(poi);

    final perimeter = _poiPerimeterFromMetadata(poi);
    final isZone = perimeter != null;
    final style = isZone ? _parkingZoneStyleFromMetadata(poi) : null;

    setState(() {
      _poiInlineEditorMode = _PoiInlineEditorMode.edit;
      _poiEditingPoi = poi;
      _poiInlineError = null;
      _poiInlineAppearanceId =
        (poi.metadata?[kMasLivePoiAppearanceKey] as String?)
              ?.trim()
              .isNotEmpty ==
            true
          ? (poi.metadata![kMasLivePoiAppearanceKey] as String)
          : _defaultPoiAppearanceId;
      _poiInlineNameController.text = poi.name;
      _poiInlineLatController.text = poi.lat.toStringAsFixed(6);
      _poiInlineLngController.text = poi.lng.toStringAsFixed(6);

      if (style != null) {
        _parkingZoneFillColorHex =
            style['fillColor'] as String? ??
            _normalizeColorHex(_selectedLayer?.color) ??
            _defaultLayerColorHex(poi.layerType) ??
            _parkingZoneFillColorHex;
          _parkingZoneStrokeColorHex =
            style['strokeColor'] as String? ?? _parkingZoneFillColorHex;
          _parkingZoneStrokeFollowsFill =
            _parkingZoneStrokeColorHex.toUpperCase() ==
            _parkingZoneFillColorHex.toUpperCase();
        _parkingZoneFillOpacity =
            (style['fillOpacity'] as num?)?.toDouble() ??
            _parkingZoneFillOpacity;
        _parkingZoneStrokeWidth =
            (style['strokeWidth'] as num?)?.toDouble() ??
            _parkingZoneStrokeWidth;
        _parkingZoneStrokeDash =
            (style['strokeDash'] as String?)?.trim().isNotEmpty == true
            ? (style['strokeDash'] as String).trim()
            : _parkingZoneStrokeDash;
        _parkingZonePattern =
            (style['pattern'] as String?)?.trim().isNotEmpty == true
            ? (style['pattern'] as String).trim()
            : _parkingZonePattern;
        _parkingZonePatternOpacity =
            (style['patternOpacity'] as num?)?.toDouble() ??
            _parkingZonePatternOpacity;
        _parkingZoneColorController.text = _parkingZoneFillColorHex;
      }
    });
    _scrollPoiBottomSectionIntoView();
  }

  void _closePoiInlineEditor({bool keepSelection = true}) {
    setState(() {
      _poiInlineEditorMode = _PoiInlineEditorMode.none;
      _poiEditingPoi = null;
      _poiInlineError = null;
    });
    if (!keepSelection) {
      _poiSelection.clear();
    }
  }

  Future<void> _createPoiAt({required double lng, required double lat}) async {
    if (_selectedLayer == null) return;
    if (_pois.length >= _poiLimit) {
      if (mounted) {
        _showTopSnackBar(
          '❌ Limite atteinte: 2000 POI maximum par projet',
          isError: true,
        );
      }
      return;
    }

    _openPoiCreatePointSection(initialLng: lng, initialLat: lat);
  }

  Future<void> _refreshPoiMarkers() async {
    if (_selectedLayer == null) {
      await _poiMapController.clearPoisGeoJson();
      return;
    }

    final layer = _selectedLayer!;
    final poisForLayer = _pois
        .where((p) => _poiMatchesSelectedLayer(p, layer))
        .toList();

    final previewParkingZonePoints =
        (_isDrawingParkingZone &&
            layer.type == 'parking' &&
            _parkingZonePoints.isNotEmpty)
        ? _parkingZonePoints
        : null;

    await _poiMapController.setPoisGeoJson(
      _buildPoisFeatureCollection(
        poisForLayer,
        previewParkingZonePoints: previewParkingZonePoints,
      ),
    );
  }

  void _syncPoiRouteStyleProTimer() {
    final cfg = _routeStyleProConfig;
    final needsAnim =
        mounted &&
        _currentStep == _poiStepIndex &&
        cfg != null &&
        (cfg.rainbowEnabled || cfg.casingRainbowEnabled);

    if (!needsAnim) {
      _poiRouteStyleProTimer?.cancel();
      _poiRouteStyleProTimer = null;
      return;
    }

    // Période similaire à la preview map (throttlée)
    final periodMs = (110 - (cfg.rainbowSpeed * 0.8)).clamp(25, 110).round();

    _poiRouteStyleProTimer?.cancel();
    _poiRouteStyleProTimer = Timer.periodic(Duration(milliseconds: periodMs), (
      _,
    ) {
      if (!mounted) return;
      if (_currentStep != _poiStepIndex) {
        _syncPoiRouteStyleProTimer();
        return;
      }
      _poiRouteStyleProAnimTick++;
      unawaited(_refreshPoiRouteOverlay(animTick: _poiRouteStyleProAnimTick));
    });
  }

  Future<void> _refreshPoiRouteOverlay({int? animTick}) async {
    if (!mounted) return;
    if (_currentStep != _poiStepIndex) return;
    if (_isRenderingPoiRoute) return;
    _isRenderingPoiRoute = true;

    try {
      final route = _routePoints;
      if (route.length < 2) {
        await _poiMapController.setPolyline(points: const [], show: false);
        return;
      }

      final mapPoints = <MapPoint>[
        for (final p in route) MapPoint(p.lng, p.lat),
      ];

      final pro = _routeStyleProConfig;
      if (pro != null) {
        final cfg = pro.validated();

        final buildingsKey =
            '${cfg.buildings3dEnabled ? 1 : 0}:${cfg.buildingOpacity.toStringAsFixed(3)}';
        if (_lastPoiBuildingsKey != buildingsKey) {
          _lastPoiBuildingsKey = buildingsKey;
          unawaited(
            _poiMapController.setBuildings3d(
              enabled: cfg.buildings3dEnabled,
              opacity: cfg.buildingOpacity,
            ),
          );
        }

        final widthScale = cfg.widthScale3d;
        final mainWidth = cfg.mainWidth * widthScale;
        final casingWidth = cfg.casingWidth * widthScale;
        final glowWidth = cfg.glowWidth * widthScale;

        final segmentsForMain =
            cfg.rainbowEnabled ||
            cfg.trafficDemoEnabled ||
            cfg.vanishingEnabled;
        final needSegmentsSource = segmentsForMain || cfg.casingRainbowEnabled;
        final segmentsGeoJson = needSegmentsSource
            ? _buildRouteStyleProSegmentsGeoJson(
                route,
                cfg,
                animTick: animTick ?? _poiRouteStyleProAnimTick,
              )
            : null;

        final shouldRoadLike =
            (cfg.casingWidth > 0) || cfg.shadowEnabled || cfg.glowEnabled;

        await _poiMapController.setPolyline(
          points: mapPoints,
          color: cfg.mainColor,
          width: mainWidth,
          show: true,
          roadLike: shouldRoadLike,
          shadow3d: cfg.shadowEnabled,
          shadowOpacity: cfg.shadowOpacity,
          shadowBlur: cfg.shadowBlur,
          showDirection: false,
          animateDirection: cfg.pulseEnabled,
          animationSpeed: (cfg.pulseSpeed / 25.0).clamp(0.5, 5.0),

          opacity: cfg.opacity,
          casingColor: cfg.casingColor,
          casingWidth: cfg.casingWidth > 0 ? casingWidth : null,
          casingRainbowEnabled: cfg.casingRainbowEnabled,

          glowEnabled: cfg.glowEnabled,
          glowColor: cfg.mainColor,
          glowWidth: glowWidth,
          glowOpacity: cfg.glowOpacity,
          glowBlur: cfg.glowBlur,

          thickness3d: cfg.thickness3d,
          elevationPx: cfg.elevationPx,
          sidesEnabled: cfg.sidesEnabled,
          sidesIntensity: cfg.sidesIntensity,

          dashArray: cfg.dashEnabled
              ? <double>[cfg.dashLength, cfg.dashGap]
              : null,
          lineCap: cfg.lineCap.name,
          lineJoin: cfg.lineJoin.name,
          segmentsGeoJson: segmentsGeoJson,
          segmentsForMain: segmentsForMain,
        );
        return;
      }

      // Fallback: style legacy (Waze-like)
      await _poiMapController.setPolyline(
        points: mapPoints,
        color: _parseHexColor(_routeColorHex, fallback: Colors.blue),
        width: _routeWidth,
        show: true,
        roadLike: _routeRoadLike,
        shadow3d: _routeShadow3d,
        showDirection: _routeShowDirection,
        animateDirection: _routeAnimateDirection,
        animationSpeed: _routeAnimationSpeed,
      );
    } catch (_) {
      // Garder l'étape POI stable même si interop map KO.
    } finally {
      _isRenderingPoiRoute = false;
    }
  }

  String _emptyFeatureCollection() =>
      jsonEncode({'type': 'FeatureCollection', 'features': []});

  String _featureCollection(List<Map<String, dynamic>> features) =>
      jsonEncode({'type': 'FeatureCollection', 'features': features});

  String _buildRouteStyleProSegmentsGeoJson(
    List<LngLat> pts,
    rsp.RouteStyleConfig cfg, {
    required int animTick,
  }) {
    if (pts.length < 2) return _emptyFeatureCollection();

    final width = cfg.mainWidth * cfg.widthScale3d;

    // Limite le nombre de segments (perf)
    const maxSeg = 60;
    final step = math.max(1, ((pts.length - 1) / maxSeg).ceil());

    final features = <Map<String, dynamic>>[];
    int segIndex = 0;

    for (int i = 0; i < pts.length - 1; i += step) {
      final a = pts[i];
      final b = pts[math.min(i + step, pts.length - 1)];

      final t = segIndex / math.max(1, ((pts.length - 1) / step).floor());

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
          'color': _toHexRgba(color, opacity: opacity),
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

    return _featureCollection(features);
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
    if (!cfg.casingRainbowEnabled) return cfg.casingColor;
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

  String _toHexRgba(Color c, {required double opacity}) {
    // Mapbox accepte bien rgba() (plus robuste que #RRGGBBAA selon environnements).
    final a = opacity.clamp(0.0, 1.0);
    final r = ((c.r * 255).round()).clamp(0, 255);
    final g = ((c.g * 255).round()).clamp(0, 255);
    final b = ((c.b * 255).round()).clamp(0, 255);
    return 'rgba($r,$g,$b,${a.toStringAsFixed(3)})';
  }

  String _toHexRgb(Color c) {
    final r = ((c.r * 255).round())
        .clamp(0, 255)
        .toRadixString(16)
        .padLeft(2, '0');
    final g = ((c.g * 255).round())
        .clamp(0, 255)
        .toRadixString(16)
        .padLeft(2, '0');
    final b = ((c.b * 255).round())
        .clamp(0, 255)
        .toRadixString(16)
        .padLeft(2, '0');
    return '#${r.toUpperCase()}${g.toUpperCase()}${b.toUpperCase()}';
  }

  List<LngLat>? _poiPerimeterFromMetadata(MarketMapPOI poi) {
    final meta = poi.metadata;
    if (meta == null) return null;
    final raw = meta['perimeter'];
    if (raw is! List) return null;
    final pts = <LngLat>[];
    for (final item in raw) {
      if (item is Map) {
        final lng = (item['lng'] as num?)?.toDouble();
        final lat = (item['lat'] as num?)?.toDouble();
        if (lng != null && lat != null) {
          pts.add((lng: lng, lat: lat));
        }
      }
    }
    return pts.length >= 3 ? pts : null;
  }

  String? _defaultLayerColorHex(String layerType) {
    for (final l in _layers) {
      if (l.type == layerType) {
        final hex = _normalizeColorHex(l.color);
        if (hex != null) return hex;
      }
    }
    return null;
  }

  String? _normalizeColorHex(String? raw) {
    final v = raw?.trim();
    if (v == null || v.isEmpty) return null;
    final hex6 = RegExp(r'^#?[0-9a-fA-F]{6}$');
    if (hex6.hasMatch(v)) {
      final s = v.startsWith('#') ? v : '#$v';
      return s.toUpperCase();
    }
    final hex8 = RegExp(r'^0x[0-9a-fA-F]{8}$');
    if (hex8.hasMatch(v)) {
      // 0xAARRGGBB -> #RRGGBB
      final rgb = v.substring(v.length - 6);
      return '#${rgb.toUpperCase()}';
    }
    return null;
  }

  Map<String, dynamic> _parkingZoneStyleFromMetadata(MarketMapPOI poi) {
    final meta = poi.metadata;
    final styleRaw = meta?[_parkingZoneStyleKey];
    final style = (styleRaw is Map) ? styleRaw.cast<String, dynamic>() : null;

    final layerHex = _defaultLayerColorHex(poi.layerType) ?? '#FBBF24';
    final fillColor =
        _normalizeColorHex(style?['fillColor']?.toString()) ?? layerHex;
    final strokeColor =
        _normalizeColorHex(style?['strokeColor']?.toString()) ?? fillColor;
    final fillOpacity =
        (style?['fillOpacity'] as num?)?.toDouble() ??
        _parkingZoneDefaultFillOpacity;
    final strokeWidth =
        (style?['strokeWidth'] as num?)?.toDouble() ??
        _parkingZoneDefaultStrokeWidth;
    final dashRaw = style?['strokeDash'];
    final dash = (dashRaw is String && dashRaw.trim().isNotEmpty)
        ? dashRaw.trim()
        : 'solid';

    final pattern =
        (style?['pattern'] is String &&
            (style?['pattern'] as String).trim().isNotEmpty)
        ? (style?['pattern'] as String).trim()
        : 'none';
    final patternOpacity =
        (style?['patternOpacity'] as num?)?.toDouble() ??
        _parkingZoneDefaultPatternOpacity;

    return <String, dynamic>{
      'fillColor': fillColor,
      'fillOpacity': fillOpacity.clamp(0.0, 1.0),
      'strokeColor': strokeColor,
      'strokeWidth': strokeWidth,
      'strokeDash': dash,
      'pattern': pattern,
      'patternOpacity': patternOpacity.clamp(0.0, 1.0),
    };
  }

  String? _mapboxFillPatternIdFromStylePattern(String? pattern) {
    switch ((pattern ?? '').trim()) {
      case 'diag':
        return 'maslive_pat_diag';
      case 'cross':
        return 'maslive_pat_cross';
      case 'dots':
        return 'maslive_pat_dots';
      default:
        return null;
    }
  }

  LngLat _centroidOf(List<LngLat> points) {
    if (points.isEmpty) return (lng: -61.533, lat: 16.241);
    var sumLng = 0.0;
    var sumLat = 0.0;
    for (final p in points) {
      sumLng += p.lng;
      sumLat += p.lat;
    }
    return (lng: sumLng / points.length, lat: sumLat / points.length);
  }

  Map<String, dynamic> _buildPoisFeatureCollection(
    List<MarketMapPOI> pois, {
    List<LngLat>? previewParkingZonePoints,
  }) {
    final features = <Map<String, dynamic>>[];

    for (final poi in pois) {
      final perimeter = _poiPerimeterFromMetadata(poi);

      if (perimeter != null) {
        final style = _parkingZoneStyleFromMetadata(poi);
        final fillPattern = _mapboxFillPatternIdFromStylePattern(
          style['pattern'] as String?,
        );
        final ring = <List<double>>[
          for (final p in perimeter) <double>[p.lng, p.lat],
          <double>[perimeter.first.lng, perimeter.first.lat],
        ];
        features.add(<String, dynamic>{
          'type': 'Feature',
          'id': poi.id,
          'properties': <String, dynamic>{
            'poiId': poi.id,
            'layerId': poi.layerType,
            'title': poi.name,
            'isZone': true,
            'fillColor': style['fillColor'],
            'fillOpacity': style['fillOpacity'],
            'strokeColor': style['strokeColor'],
            'strokeWidth': style['strokeWidth'],
            'strokeDash': style['strokeDash'],
            if (fillPattern != null) 'fillPattern': fillPattern,
            'patternOpacity': style['patternOpacity'],
          },
          'geometry': <String, dynamic>{
            'type': 'Polygon',
            'coordinates': <List<List<double>>>[ring],
          },
        });

        // Label “P” au centre pour les zones parking.
        if (poi.layerType == 'parking') {
          final c = _centroidOf(perimeter);
          features.add(<String, dynamic>{
            'type': 'Feature',
            'id': '${poi.id}__zone_label',
            'properties': <String, dynamic>{
              'poiId': poi.id,
              'layerId': poi.layerType,
              'title': poi.name,
              'isZoneLabel': true,
              'labelText': 'P',
            },
            'geometry': <String, dynamic>{
              'type': 'Point',
              'coordinates': <double>[c.lng, c.lat],
            },
          });
        }
      } else {
        features.add(<String, dynamic>{
          'type': 'Feature',
          'id': poi.id,
          'properties': <String, dynamic>{
            'poiId': poi.id,
            'layerId': poi.layerType,
            'title': poi.name,
            if (poi.metadata?[kMasLivePoiAppearanceKey] is String)
              kMasLivePoiAppearanceKey: poi.metadata![kMasLivePoiAppearanceKey],
          },
          'geometry': <String, dynamic>{
            'type': 'Point',
            'coordinates': <double>[poi.lng, poi.lat],
          },
        });
      }
    }

    if (previewParkingZonePoints != null &&
        previewParkingZonePoints.isNotEmpty) {
      final previewFill =
          _normalizeColorHex(_parkingZoneFillColorHex) ??
          _normalizeColorHex(_selectedLayer?.color) ??
          _defaultLayerColorHex('parking') ??
          '#FBBF24';

      // Points de prévisualisation: un point visible à chaque tap.
      for (var i = 0; i < previewParkingZonePoints.length; i++) {
        final p = previewParkingZonePoints[i];
        features.add(<String, dynamic>{
          'type': 'Feature',
          'id': '__preview_parking_vertex__$i',
          'properties': <String, dynamic>{
            'layerId': 'parking',
            'title': 'Point zone parking',
            'isPreview': true,
            'isPreviewVertex': true,
            'strokeColor': previewFill,
          },
          'geometry': <String, dynamic>{
            'type': 'Point',
            'coordinates': <double>[p.lng, p.lat],
          },
        });
      }
    }

    if (previewParkingZonePoints != null &&
        previewParkingZonePoints.length >= 3) {
      final ring = <List<double>>[
        for (final p in previewParkingZonePoints) <double>[p.lng, p.lat],
        <double>[
          previewParkingZonePoints.first.lng,
          previewParkingZonePoints.first.lat,
        ],
      ];

      final previewFill =
          _normalizeColorHex(_parkingZoneFillColorHex) ??
          _normalizeColorHex(_selectedLayer?.color) ??
          _defaultLayerColorHex('parking') ??
          '#FBBF24';

          final previewStroke =
            (_parkingZoneStrokeFollowsFill
              ? previewFill
              : (_normalizeColorHex(_parkingZoneStrokeColorHex) ?? previewFill));

      final previewPattern = _mapboxFillPatternIdFromStylePattern(
        _parkingZonePattern,
      );

      features.add(<String, dynamic>{
        'type': 'Feature',
        'id': '__preview_parking_zone__',
        'properties': <String, dynamic>{
          'poiId': '__preview_parking_zone__',
          'layerId': 'parking',
          'title': 'Zone parking (aperçu)',
          'isPreview': true,
          'isZone': true,
          'fillColor': previewFill,
          'fillOpacity': _parkingZoneFillOpacity.clamp(0.0, 1.0),
          'strokeColor': previewStroke,
          'strokeWidth': _parkingZoneStrokeWidth,
          'strokeDash': _parkingZoneStrokeDash,
          if (previewPattern != null) 'fillPattern': previewPattern,
          'patternOpacity': _parkingZonePatternOpacity.clamp(0.0, 1.0),
        },
        'geometry': <String, dynamic>{
          'type': 'Polygon',
          'coordinates': <List<List<double>>>[ring],
        },
      });

      // Label “P” preview au centre.
      final c = _centroidOf(previewParkingZonePoints);
      features.add(<String, dynamic>{
        'type': 'Feature',
        'id': '__preview_parking_zone_label__',
        'properties': <String, dynamic>{
          'poiId': '__preview_parking_zone__',
          'layerId': 'parking',
          'title': 'Zone parking (aperçu)',
          'isPreview': true,
          'isZoneLabel': true,
          'labelText': 'P',
        },
        'geometry': <String, dynamic>{
          'type': 'Point',
          'coordinates': <double>[c.lng, c.lat],
        },
      });
    }

    return <String, dynamic>{'type': 'FeatureCollection', 'features': features};
  }

  Future<void> _onMapTapForPoi(double lng, double lat) async {
    if (_isDrawingParkingZone && _selectedLayer?.type == 'parking') {
      setState(() {
        _parkingZonePoints = <LngLat>[
          ..._parkingZonePoints,
          (lng: lng, lat: lat),
        ];
      });
      try {
        await _refreshPoiMarkers();
      } catch (e) {
        debugPrint('Erreur lors de l\'ajout du point parking: $e');
        if (mounted) {
          _showTopSnackBar('⚠️ Erreur lors de l\'ajout du point', isError: true);
        }
      }
      return;
    }

    await _createPoiAt(lng: lng, lat: lat);
  }

  Future<void> _editPoi(MarketMapPOI poi) async {
    final perimeter = _poiPerimeterFromMetadata(poi);
    if (perimeter != null) {
      // Garder l'éditeur inline pour les zones parking (style, etc.).
      _openPoiEditSection(poi);
      return;
    }

    final updated = await showModalBottomSheet<MarketMapPOI>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => PoiEditPopup(poi: poi, projectId: _projectId),
    );

    if (updated == null) return;

    setState(() {
      final idx = _pois.indexWhere((p) => p.id == poi.id);
      if (idx >= 0) {
        _pois[idx] = updated;
      }
    });
    _poiSelection.select(updated);
    _refreshPoiMarkers();

    await _persistPoiDraftUpdate(updated);
  }

  String _draftPoiDocId(MarketMapPOI poi) {
    final trimmed = poi.id.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return 'poi_${poi.layerType}_${poi.lng.toStringAsFixed(5)}_${poi.lat.toStringAsFixed(5)}';
  }

  Future<void> _persistPoiDraftUpdate(MarketMapPOI poi) async {
    final projectId = _projectId;
    if (projectId == null || projectId.trim().isEmpty) return;

    try {
      final docId = _draftPoiDocId(poi);
      await FirebaseFirestore.instance
          .collection('map_projects')
          .doc(projectId)
          .collection('pois')
          .doc(docId)
          .set({
            ...poi.toFirestore(),
            'layerId': poi.layerType,
            'isVisible': true,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      if (!mounted) return;
      _showTopSnackBar(
        '⚠️ POI sauvegardé localement mais Firestore a refusé: $e',
        isError: true,
        duration: const Duration(seconds: 6),
      );
    }
  }

  void _startParkingZoneDrawing() {
    if (_selectedLayer?.type != 'parking') return;
    _poiSelection.clear();
    _closePoiInlineEditor(keepSelection: false);

    final defaultHex =
        _normalizeColorHex(_selectedLayer?.color) ??
        _defaultLayerColorHex('parking') ??
        _parkingZoneFillColorHex;
    setState(() {
      _isDrawingParkingZone = true;
      _parkingZonePoints = <LngLat>[];

      _parkingZoneFillColorHex = defaultHex;
      _parkingZoneFillOpacity = _parkingZoneDefaultFillOpacity;
      _parkingZoneStrokeWidth = _parkingZoneDefaultStrokeWidth;
      _parkingZoneStrokeDash = 'solid';
      _parkingZonePattern = 'none';
      _parkingZonePatternOpacity = _parkingZoneDefaultPatternOpacity;
      _parkingZoneColorController.text = defaultHex;
    });
    _refreshPoiMarkers();
  }

  void _cancelParkingZoneDrawing() {
    setState(() {
      _isDrawingParkingZone = false;
      _parkingZonePoints = <LngLat>[];
    });
    _refreshPoiMarkers();
  }

  void _finishParkingZoneDrawing() {
    if (_selectedLayer?.type != 'parking') return;
    if (_parkingZonePoints.length < 3) return;
    _openPoiCreateZoneSection(perimeterPoints: _parkingZonePoints);
  }

  void _commitPoiInlineEditor() {
    if (_selectedLayer == null) return;

    if (_poiInlineEditorMode == _PoiInlineEditorMode.createPoint) {
      final lat = _tryParseCoord(_poiInlineLatController.text);
      final lng = _tryParseCoord(_poiInlineLngController.text);
      if (lat == null || lng == null) {
        setState(() => _poiInlineError = 'Coordonnées invalides (lat/lng).');
        return;
      }
      if (lat < -90 || lat > 90) {
        setState(
          () => _poiInlineError =
              'Latitude invalide (doit être entre -90 et 90).',
        );
        return;
      }
      if (lng < -180 || lng > 180) {
        setState(
          () => _poiInlineError =
              'Longitude invalide (doit être entre -180 et 180).',
        );
        return;
      }

      final name = _poiInlineNameController.text.trim().isEmpty
          ? '${_selectedLayer?.label ?? 'POI'} (${lng.toStringAsFixed(4)}, ${lat.toStringAsFixed(4)})'
          : _poiInlineNameController.text.trim();

      final poi = MarketMapPOI(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        layerType: _selectedLayer!.type,
        lng: lng,
        lat: lat,
        description: null,
        imageUrl: null,
        metadata: <String, dynamic>{
          kMasLivePoiAppearanceKey: _poiInlineAppearanceId,
        },
      );

      setState(() {
        _pois.add(poi);
        _poiInlineEditorMode = _PoiInlineEditorMode.none;
        _poiInlineError = null;
      });
      _refreshPoiMarkers();
      _poiSelection.select(poi);
      return;
    }

    if (_poiInlineEditorMode == _PoiInlineEditorMode.createZone) {
      if (_selectedLayer?.type != 'parking') {
        setState(
          () => _poiInlineError = 'Zone disponible uniquement en parking.',
        );
        return;
      }
      if (_parkingZonePoints.length < 3) {
        setState(
          () => _poiInlineError = 'Périmètre incomplet (min. 3 points).',
        );
        return;
      }

      final name = _poiInlineNameController.text.trim().isEmpty
          ? 'Zone parking'
          : _poiInlineNameController.text.trim();

      final fillHex =
          _normalizeColorHex(_parkingZoneColorController.text) ??
          _normalizeColorHex(_parkingZoneFillColorHex);
      if (fillHex == null) {
        setState(
          () => _poiInlineError =
              'Couleur invalide (attendu: #RRGGBB, ex: #FBBF24).',
        );
        return;
      }

      final strokeHex =
          _parkingZoneStrokeFollowsFill
              ? fillHex
              : (_normalizeColorHex(_parkingZoneStrokeColorHex) ?? fillHex);

      final centroid = _centroidOf(_parkingZonePoints);
      final poi = MarketMapPOI(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        layerType: 'parking',
        lng: centroid.lng,
        lat: centroid.lat,
        description: null,
        imageUrl: null,
        metadata: <String, dynamic>{
          'perimeter': [
            for (final p in _parkingZonePoints) {'lng': p.lng, 'lat': p.lat},
          ],
          _parkingZoneStyleKey: <String, dynamic>{
            'fillColor': fillHex,
            'fillOpacity': _parkingZoneFillOpacity.clamp(0.0, 1.0),
            'strokeColor': strokeHex,
            'strokeWidth': _parkingZoneStrokeWidth,
            'strokeDash': _parkingZoneStrokeDash,
            'pattern': _parkingZonePattern,
            'patternOpacity': _parkingZonePatternOpacity.clamp(0.0, 1.0),
          },
        },
      );

      setState(() {
        _pois.add(poi);
        _poiInlineEditorMode = _PoiInlineEditorMode.none;
        _poiInlineError = null;
        _isDrawingParkingZone = false;
        _parkingZonePoints = <LngLat>[];
      });
      _refreshPoiMarkers();
      _poiSelection.select(poi);
      return;
    }

    if (_poiInlineEditorMode == _PoiInlineEditorMode.edit) {
      final poi = _poiEditingPoi;
      if (poi == null) return;
      final nextName = _poiInlineNameController.text.trim();
      if (nextName.isEmpty) {
        setState(() => _poiInlineError = 'Le nom ne peut pas être vide.');
        return;
      }

      final perimeter = _poiPerimeterFromMetadata(poi);
      final isZone = perimeter != null;

      Map<String, dynamic>? nextMetadata = poi.metadata;
      if (isZone) {
        final fillHex =
            _normalizeColorHex(_parkingZoneColorController.text) ??
            _normalizeColorHex(_parkingZoneFillColorHex);
        if (fillHex == null) {
          setState(
            () => _poiInlineError =
                'Couleur invalide (attendu: #RRGGBB, ex: #FBBF24).',
          );
          return;
        }

        final strokeHex =
            _parkingZoneStrokeFollowsFill
                ? fillHex
                : (_normalizeColorHex(_parkingZoneStrokeColorHex) ?? fillHex);
        nextMetadata = <String, dynamic>{
          ...(poi.metadata ?? const <String, dynamic>{}),
          _parkingZoneStyleKey: <String, dynamic>{
            'fillColor': fillHex,
            'fillOpacity': _parkingZoneFillOpacity.clamp(0.0, 1.0),
            'strokeColor': strokeHex,
            'strokeWidth': _parkingZoneStrokeWidth,
            'strokeDash': _parkingZoneStrokeDash,
            'pattern': _parkingZonePattern,
            'patternOpacity': _parkingZonePatternOpacity.clamp(0.0, 1.0),
          },
        };
      } else {
        nextMetadata = <String, dynamic>{
          ...(poi.metadata ?? const <String, dynamic>{}),
          kMasLivePoiAppearanceKey: _poiInlineAppearanceId,
        };
      }

      setState(() {
        final idx = _pois.indexWhere((p) => p.id == poi.id);
        if (idx >= 0) {
          final updated = MarketMapPOI(
            id: poi.id,
            name: nextName,
            layerType: poi.layerType,
            lng: poi.lng,
            lat: poi.lat,
            description: poi.description,
            imageUrl: poi.imageUrl,
            metadata: nextMetadata,
          );
          _pois[idx] = updated;
          _poiSelection.select(updated);
        }
        _poiInlineEditorMode = _PoiInlineEditorMode.none;
        _poiEditingPoi = null;
        _poiInlineError = null;
      });
      _refreshPoiMarkers();
    }
  }

  Widget _buildPoiInlineEditorSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = colorScheme.surface;

    final isCreatePoint =
        _poiInlineEditorMode == _PoiInlineEditorMode.createPoint;
    final isCreateZone =
        _poiInlineEditorMode == _PoiInlineEditorMode.createZone;
    final isEdit = _poiInlineEditorMode == _PoiInlineEditorMode.edit;

    final editingPoi = _poiEditingPoi;
    final isEditZone =
        isEdit &&
        editingPoi != null &&
        _poiPerimeterFromMetadata(editingPoi) != null;

    final title = isEdit
        ? 'Modifier le POI'
        : (isCreateZone ? 'Nouvelle zone parking' : 'Nouveau point d\'intérêt');

    final primaryLabel = isEdit
        ? 'Enregistrer'
        : (isCreateZone ? 'Ajouter la zone' : 'Ajouter');

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
      child: Material(
        color: bg,
        elevation: 0,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
          bottom: Radius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: () {
                      if (isCreateZone) {
                        _cancelParkingZoneDrawing();
                      }
                      _closePoiInlineEditor();
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _poiInlineNameController,
                decoration: const InputDecoration(
                  labelText: 'Nom',
                  border: OutlineInputBorder(),
                ),
              ),
              if (!isCreateZone && !isEditZone) ...[
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Apparence',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _poiInlineAppearanceId,
                      isExpanded: true,
                      items: [
                        for (final p in kMasLivePoiAppearancePresets)
                          DropdownMenuItem(value: p.id, child: Text(p.label)),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _poiInlineAppearanceId = v;
                          _poiInlineError = null;
                        });
                        _refreshPoiMarkers();
                      },
                    ),
                  ),
                ),
              ],
              if (isCreatePoint) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _poiInlineLatController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Latitude (GPS)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _poiInlineLngController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Longitude (GPS)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              if (isCreateZone) ...[
                const SizedBox(height: 12),
                Text(
                  'Périmètre: ${_parkingZonePoints.length} points',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],

              if (isCreateZone || isEditZone) ...[
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: _applyParkingZonePresetWhiteBlue,
                  child: const Text('Preset parking (contour blanc / fond bleu)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _parkingZoneColorController,
                  onChanged: (v) {
                    setState(() {
                      _parkingZoneFillColorHex = v;
                      if (_parkingZoneStrokeFollowsFill) {
                        _parkingZoneStrokeColorHex = v;
                      }
                      _poiInlineError = null;
                    });
                    _refreshPoiMarkers();
                  },
                  decoration: const InputDecoration(
                    labelText: 'Couleur (hex, ex: #FBBF24)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Fond (opacité): ${(100 * _parkingZoneFillOpacity).round()}%',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Slider(
                  value: _parkingZoneFillOpacity.clamp(0.0, 1.0),
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  onChanged: (v) {
                    setState(() {
                      _parkingZoneFillOpacity = v;
                      _poiInlineError = null;
                    });
                    _refreshPoiMarkers();
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'Contour (largeur): ${_parkingZoneStrokeWidth.toStringAsFixed(1)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Slider(
                  value: _parkingZoneStrokeWidth.clamp(1.0, 10.0),
                  min: 1.0,
                  max: 10.0,
                  divisions: 18,
                  onChanged: (v) {
                    setState(() {
                      _parkingZoneStrokeWidth = v;
                      _poiInlineError = null;
                    });
                    _refreshPoiMarkers();
                  },
                ),
                const SizedBox(height: 4),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Texture (contour)',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _parkingZoneStrokeDash,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'solid', child: Text('Plein')),
                        DropdownMenuItem(
                          value: 'dashed',
                          child: Text('Pointillé'),
                        ),
                        DropdownMenuItem(
                          value: 'dotted',
                          child: Text('Pointillé fin'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _parkingZoneStrokeDash = v;
                          _poiInlineError = null;
                        });
                        _refreshPoiMarkers();
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Texture intérieure (pattern)',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _parkingZonePattern,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'none', child: Text('Aucune')),
                        DropdownMenuItem(
                          value: 'diag',
                          child: Text('Diagonale'),
                        ),
                        DropdownMenuItem(
                          value: 'cross',
                          child: Text('Croisillons'),
                        ),
                        DropdownMenuItem(value: 'dots', child: Text('Points')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _parkingZonePattern = v;
                          _poiInlineError = null;
                        });
                        _refreshPoiMarkers();
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Texture intérieure (opacité): ${(100 * _parkingZonePatternOpacity.clamp(0.0, 1.0)).round()}%',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Slider(
                  value: _parkingZonePatternOpacity.clamp(0.0, 1.0),
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  onChanged: _parkingZonePattern == 'none'
                      ? null
                      : (v) {
                          setState(() {
                            _parkingZonePatternOpacity = v;
                            _poiInlineError = null;
                          });
                          _refreshPoiMarkers();
                        },
                ),
              ],
              if (_poiInlineError != null) ...[
                const SizedBox(height: 10),
                Text(
                  _poiInlineError!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        if (isCreateZone) {
                          _cancelParkingZoneDrawing();
                        }
                        _closePoiInlineEditor();
                      },
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: _commitPoiInlineEditor,
                      child: Text(primaryLabel),
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

  void _deletePoi(MarketMapPOI poi) {
    setState(() {
      _pois.removeWhere((p) => p.id == poi.id);
    });
    if (_poiSelection.selectedPoi?.id == poi.id) {
      _poiSelection.clear();
    }
    _refreshPoiMarkers();
  }

  Future<void> _addPoiAtCurrentCenter() async {
    // Version simple : on réutilise le premier point du tracé ou du périmètre
    double lng;
    double lat;

    if (_routePoints.isNotEmpty) {
      lng = _routePoints.first.lng;
      lat = _routePoints.first.lat;
    } else if (_perimeterPoints.isNotEmpty) {
      lng = _perimeterPoints.first.lng;
      lat = _perimeterPoints.first.lat;
    } else {
      // Fallback: centre par défaut
      lng = -61.533;
      lat = 16.241;
    }

    await _createPoiAt(lng: lng, lat: lat);
  }

  Widget _buildStep7Validation() {
    final report = _qualityReport;
    return GlassScrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          MasliveTokens.l,
          MasliveTokens.m,
          MasliveTokens.l,
          MasliveTokens.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassPanel(
              radius: MasliveTokens.rL,
              opacity: 0.78,
              padding: const EdgeInsets.all(MasliveTokens.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Pré-publication',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: MasliveTokens.text,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Score qualité: ${report.score}/100',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: report.canPublish ? Colors.green : Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: report.score / 100,
                      minHeight: 8,
                      color: report.canPublish ? Colors.green : Colors.orange,
                      backgroundColor: MasliveTokens.borderSoft,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: MasliveTokens.m),
            GlassPanel(
              radius: MasliveTokens.rL,
              opacity: 0.76,
              padding: const EdgeInsets.fromLTRB(
                MasliveTokens.s,
                MasliveTokens.s,
                MasliveTokens.s,
                MasliveTokens.s,
              ),
              child: Column(
                children: [
                  for (final item in report.items)
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: MasliveTokens.s,
                        vertical: 2,
                      ),
                      leading: Icon(
                        item.ok ? Icons.check_circle : Icons.error_outline,
                        color: item.ok ? Colors.green : Colors.redAccent,
                      ),
                      title: Text(
                        item.label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: MasliveTokens.text,
                        ),
                      ),
                      subtitle: (!item.ok && item.hint != null)
                          ? Text(
                              item.hint!,
                              style: TextStyle(
                                fontSize: 12,
                                color: MasliveTokens.textSoft,
                              ),
                            )
                          : null,
                      trailing: item.required
                          ? const Chip(label: Text('Requis'))
                          : const Chip(label: Text('Optionnel')),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep8Publish() {
    final report = _qualityReport;
    return GlassScrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          MasliveTokens.l,
          MasliveTokens.m,
          MasliveTokens.l,
          MasliveTokens.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassPanel(
              radius: MasliveTokens.rL,
              opacity: 0.78,
              padding: const EdgeInsets.all(MasliveTokens.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Publication',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: MasliveTokens.text,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          report.canPublish
                              ? 'Votre circuit est prêt !'
                              : 'Circuit presque prêt',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color:
                                report.canPublish ? Colors.green : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Nom: ${_nameController.text.trim()}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: MasliveTokens.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Points périmètre: ${_perimeterPoints.length}',
                    style: TextStyle(
                      fontSize: 13,
                      color: MasliveTokens.textSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Points tracé: ${_routePoints.length}',
                    style: TextStyle(
                      fontSize: 13,
                      color: MasliveTokens.textSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Score qualité: ${report.score}/100',
                    style: TextStyle(
                      fontSize: 13,
                      color: MasliveTokens.textSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!report.canPublish) ...[
                    const SizedBox(height: 12),
                    const Text(
                      '❌ Publication bloquée: corrige les points requis de l’étape Pré-publication.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: MasliveTokens.m),
            GlassPanel(
              radius: MasliveTokens.rL,
              opacity: 0.76,
              padding: const EdgeInsets.all(MasliveTokens.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Options de publication',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: MasliveTokens.text,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.cloud_upload),
                    onPressed: (report.canPublish && !_isEnsuringAllPoisLoaded)
                        ? _publishCircuit
                        : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green,
                    ),
                    label: const Text(
                      'PUBLIER LE CIRCUIT',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_isEnsuringAllPoisLoaded) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Chargement de tous les POIs avant publication…',
                            style: TextStyle(
                              fontSize: 12,
                              color: MasliveTokens.textSoft,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.save_alt),
                    onPressed: () => _saveDraft(createSnapshot: true),
                    label: const Text('Rester en brouillon'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _publishCircuit() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _ensureActorContext();
      if (!_canWriteMapProjects) {
        if (!mounted) return;
        _showTopSnackBar(
          '⛔ Publication réservée aux admins master.',
          isError: true,
        );
        return;
      }

      // Garde-fou: si on n'a pas chargé tous les POIs (pagination), publier
      // supprimerait les POIs non chargés côté MarketMap (sync par différence).
      if (_hasMorePois || _isLoadingMorePois) {
        if (!mounted) return;
        final action = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('POIs non chargés'),
            content: const Text(
              'Tous les POIs du brouillon ne sont pas chargés (pagination).\n'
              'Publier maintenant risquerait de supprimer des POIs existants dans MarketMap.\n\n'
              'Charge tous les POIs avant de publier.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop('cancel'),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop('load'),
                child: const Text('Charger tout'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop('goto'),
                child: const Text('Aller aux POIs'),
              ),
            ],
          ),
        );

        if (!mounted) return;
        if (action == 'goto') {
          _pageController.animateToPage(
            5,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          return;
        }
        if (action != 'load') return;

        await _ensureAllPoisLoadedForPublish();

        if (_hasMorePois) {
          // Toujours incomplet: on bloque la publication.
          if (!mounted) return;
          _showTopSnackBar(
            '❌ Impossible de charger tous les POIs.',
            isError: true,
          );
          return;
        }
      }

      setState(() => _isLoading = true);

      final report = _qualityReport;
      if (!report.canPublish) {
        throw StateError(
          'Pré-publication non conforme: corrige les points bloquants.',
        );
      }

      if (_projectId == null) {
        await _saveDraft();
      }

      final projectId = _projectId;
      if (projectId == null) {
        throw Exception('Project not initialized');
      }

      final countryId = _countryController.text.trim();
      final eventId = _eventController.text.trim();
      final marketCircuitId = (widget.circuitId?.trim().isNotEmpty ?? false)
          ? widget.circuitId!.trim()
          : projectId;

      if (countryId.isEmpty || eventId.isEmpty) {
        throw StateError('Pays et événement requis pour publier.');
      }

      await _versioning.lockProject(projectId: projectId, uid: user.uid);
      try {
        await _repository.publishToMarketMap(
          projectId: projectId,
          actorUid: user.uid,
          actorRole: _currentUserRole ?? 'creator',
          groupId: _currentGroupId ?? 'default',
          countryId: countryId,
          eventId: eventId,
          marketCircuitId: marketCircuitId,
          currentData: _buildCurrentData(),
          layers: _layers,
          pois: _pois,
        );
      } finally {
        await _versioning.unlockProject(projectId: projectId);
      }

      if (mounted) {
        _showTopSnackBar('✅ Circuit publié avec succès !');
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('WizardPro _publishCircuit error: $e');
      if (mounted) {
        final msg = e is FirebaseException
            ? '❌ Publication Firestore (${e.code}): ${e.message ?? e.toString()}'
            : '❌ Erreur publication: $e';
        _showTopSnackBar(
          msg,
          isError: true,
          duration: const Duration(seconds: 7),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  ({
    IconData? icon,
    Widget? iconWidget,
    bool fullBleed,
    bool tintOnSelected,
    bool showBorder,
  })
  _poiNavVisualForLayerType(String type) {
    final norm = type.trim().toLowerCase();

    // Aligné avec les icônes utilisées sur la Home (barre nav verticale).
    // - visit: map_outlined
    // - food: fastfood_rounded
    // - assistance: shield_outlined
    // - parking: asset icon wc/parking
    switch (norm) {
      case 'visit':
      case 'tour':
        return (
          icon: Icons.map_outlined,
          iconWidget: null,
          fullBleed: false,
          tintOnSelected: true,
          showBorder: true,
        );
      case 'food':
        return (
          icon: Icons.fastfood_rounded,
          iconWidget: null,
          fullBleed: false,
          tintOnSelected: true,
          showBorder: true,
        );
      case 'assistance':
        return (
          icon: Icons.shield_outlined,
          iconWidget: null,
          fullBleed: false,
          tintOnSelected: true,
          showBorder: true,
        );
      case 'parking':
        return (
          icon: null,
          iconWidget: Image.asset(
            'assets/images/icon wc parking.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
          fullBleed: false,
          tintOnSelected: false,
          showBorder: true,
        );
      case 'wc':
        // La Home utilise ce slot pour la langue, donc on garde une icône WC.
        return (
          icon: Icons.wc_rounded,
          iconWidget: null,
          fullBleed: false,
          tintOnSelected: true,
          showBorder: true,
        );
      default:
        return (
          icon: Icons.place_outlined,
          iconWidget: null,
          fullBleed: false,
          tintOnSelected: true,
          showBorder: true,
        );
    }
  }
}
