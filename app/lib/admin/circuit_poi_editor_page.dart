import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';

import 'poi_bottom_popup.dart';
import 'poi_edit_popup.dart';
import '../models/market_circuit_models.dart';
import '../pages/home_vertical_nav.dart';
import '../services/circuit_repository.dart';
import '../ui/map/maslive_map.dart';
import '../ui/map/maslive_poi_style.dart';
import '../ui/snack/top_snack_bar.dart';
import '../ui_kit/glass/glass_panel.dart';
import '../ui_kit/tokens/maslive_tokens.dart';

typedef LngLat = ({double lng, double lat});

class CircuitPoiEditorPage extends StatefulWidget {
  const CircuitPoiEditorPage({
    super.key,
    required this.projectId,
    required this.countryId,
    required this.eventId,
    required this.circuitId,
    this.circuitName,
  });

  final String projectId;
  final String countryId;
  final String eventId;
  final String circuitId;
  final String? circuitName;

  @override
  State<CircuitPoiEditorPage> createState() => _CircuitPoiEditorPageState();
}

class _CircuitPoiEditorPageState extends State<CircuitPoiEditorPage> {
  static const int _poiPageSize = 100;
  static const int _poiLimit = 2000;

  // Parking: création de zone (polygone)
  bool _isDrawingParkingZone = false;
  List<LngLat> _parkingZonePoints = <LngLat>[];

  // Parking: style de zone (hérité du wizard)
  static const String _parkingZoneStyleKey = 'perimeterStyle';
  static const double _parkingZoneDefaultFillOpacity = 0.20;
  static const double _parkingZoneDefaultStrokeWidth = 2.0;
  static const double _parkingZoneDefaultPatternOpacity = 0.55;

  final CircuitRepository _repository = CircuitRepository();
  final PoiSelectionController _poiSelection = PoiSelectionController();

  bool _isLoading = true;
  String? _errorMessage;

  bool _isRefreshingMarketImport = false;

  String? _currentUserRole;
  String? _currentGroupId;
  bool _canWriteMapProjects = false;

  final _nameController = TextEditingController();
  final _countryController = TextEditingController();
  final _eventController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _styleUrlController = TextEditingController();

  List<LngLat> _perimeterPoints = [];
  List<LngLat> _routePoints = [];

  List<MarketMapLayer> _layers = [];
  List<MarketMapPOI> _pois = [];
  DocumentSnapshot<Map<String, dynamic>>? _poisLastDoc;
  bool _hasMorePois = false;
  bool _isLoadingMorePois = false;
  MarketMapLayer? _selectedLayer;

  final MasLiveMapControllerPoi _poiMapController = MasLiveMapControllerPoi();

  String _defaultPoiAppearanceId = kMasLivePoiAppearancePresets.first.id;

  Map<String, dynamic> _draftData = {};

  @override
  void initState() {
    super.initState();

    _poiMapController.onPoiTap = (poiId) {
      final idx = _pois.indexWhere((p) => p.id == poiId);
      if (idx < 0) return;
      _poiSelection.select(_pois[idx]);
    };
    _poiMapController.onMapTap = (lat, lng) {
      unawaited(_onMapTapForPoi(lng, lat));
    };

    unawaited(_load());
  }

  @override
  void dispose() {
    _poiMapController.dispose();
    _poiSelection.dispose();
    _nameController.dispose();
    _countryController.dispose();
    _eventController.dispose();
    _descriptionController.dispose();
    _styleUrlController.dispose();
    super.dispose();
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
        TopSnackBar.show(
          context,
          const SnackBar(content: Text('⛔ Import réservé aux admins master.')),
        );
        return;
      }

      final projectId = widget.projectId.trim();
      if (projectId.isEmpty) {
        throw StateError('Projet non initialisé');
      }

      final countryId = _countryController.text.trim();
      final eventId = _eventController.text.trim();
      final circuitId = widget.circuitId.trim();

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
      await _load();

      if (mounted) {
        TopSnackBar.show(
          context,
          const SnackBar(content: Text('✅ Import MarketMap terminé')),
        );
      }
    } catch (e) {
      debugPrint('PoiEditor _refreshImportFromMarketMap error: $e');
      if (mounted) {
        final msg = e is FirebaseException
            ? '❌ Import Firestore (${e.code}): ${e.message ?? e.toString()}'
            : '❌ Erreur import: $e';
        TopSnackBar.show(
          context,
          SnackBar(content: Text(msg)),
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

    final canWrite = isAdmin ||
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

  Future<void> _load() async {
    try {
      await _ensureActorContext();

      final current = await _repository.loadProjectCurrent(
        projectId: widget.projectId,
        fallbackCountryId: widget.countryId,
        fallbackEventId: widget.eventId,
        fallbackCircuitId: widget.circuitId,
      );

      if (current == null) {
        setState(() {
          _errorMessage = 'Projet introuvable.';
          _isLoading = false;
        });
        return;
      }

      _draftData = Map<String, dynamic>.from(current);

      _nameController.text = (current['name'] ?? widget.circuitName ?? '').toString();
      _countryController.text = (current['countryId'] ?? widget.countryId).toString();
      _eventController.text = (current['eventId'] ?? widget.eventId).toString();
      _descriptionController.text = (current['description'] ?? '').toString();
      _styleUrlController.text = (current['styleUrl'] ?? '').toString();

      final perimeterData = current['perimeter'] as List<dynamic>?;
      if (perimeterData != null) {
        _perimeterPoints = perimeterData.map((p) {
          final m = p as Map<String, dynamic>;
          return (lng: (m['lng'] as num).toDouble(), lat: (m['lat'] as num).toDouble());
        }).toList();
      }

      final routeData = current['route'] as List<dynamic>?;
      if (routeData != null) {
        _routePoints = routeData.map((p) {
          final m = p as Map<String, dynamic>;
          return (lng: (m['lng'] as num).toDouble(), lat: (m['lat'] as num).toDouble());
        }).toList();
      }

      _layers = await _loadLayers();
      await _ensureDefaultPoiLayers();
      await _loadPoisFirstPage();

      if (_layers.isNotEmpty) {
        _selectedLayer = _layers.firstWhere(
          (l) => l.type != 'route',
          orElse: () => _layers.first,
        );
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      _refreshPoiMarkers();
    } catch (e) {
      setState(() {
        if (e is FirebaseException) {
          _errorMessage = 'Erreur chargement (${e.code}): ${e.message ?? e.toString()}';
        } else {
          _errorMessage = 'Erreur chargement: $e';
        }
        _isLoading = false;
      });
    }
  }

  Future<List<MarketMapLayer>> _loadLayers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('map_projects')
        .doc(widget.projectId)
        .collection('layers')
        .orderBy('zIndex')
        .get();

    if (snapshot.docs.isEmpty) {
      return [
        MarketMapLayer(
          id: 'route',
          label: 'Tracé Route',
          type: 'route',
          isVisible: true,
          zIndex: 1,
          color: '#1A73E8',
        ),
        MarketMapLayer(
          id: 'parking',
          label: 'Parkings',
          type: 'parking',
          isVisible: true,
          zIndex: 2,
          color: '#FBBF24',
        ),
        MarketMapLayer(
          id: 'wc',
          label: 'Toilettes',
          type: 'wc',
          isVisible: true,
          zIndex: 3,
          color: '#9333EA',
        ),
        MarketMapLayer(
          id: 'food',
          label: 'Food',
          type: 'food',
          isVisible: true,
          zIndex: 4,
          color: '#EF4444',
        ),
        MarketMapLayer(
          id: 'assistance',
          label: 'Assistance',
          type: 'assistance',
          isVisible: true,
          zIndex: 5,
          color: '#34A853',
        ),
        MarketMapLayer(
          id: 'visit',
          label: 'Lieux à visiter',
          type: 'visit',
          isVisible: true,
          zIndex: 6,
          color: '#F59E0B',
        ),
      ];
    }

    return snapshot.docs.map((doc) => MarketMapLayer.fromFirestore(doc)).toList();
  }

  String _normalizePoiLayerType(String raw) {
    final norm = raw.trim().toLowerCase();
    if (norm == 'tour' || norm == 'visiter') return 'visit';
    if (norm == 'toilet' || norm == 'toilets') return 'wc';
    return norm;
  }

  bool _poiMatchesSelectedLayer(MarketMapPOI poi, MarketMapLayer layer) {
    return _normalizePoiLayerType(poi.layerType) == _normalizePoiLayerType(layer.type);
  }

  Future<void> _migrateLegacyPoiTypesToVisit({required String projectId}) async {
    if (!_canWriteMapProjects) return;

    final db = FirebaseFirestore.instance;
    final col = db.collection('map_projects').doc(projectId).collection('pois');

    final snap = await col.where('layerType', whereIn: const ['tour', 'visiter']).get();
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
        'type': 'visit',
      });
      ops++;
      await commitIfNeeded();
    }

    await commitIfNeeded(force: true);
  }

  Future<void> _ensureDefaultPoiLayers() async {
    final projectId = widget.projectId;
    if (projectId.trim().isEmpty) return;

    try {
      await _migrateLegacyPoiTypesToVisit(projectId: projectId);
    } catch (e) {
      debugPrint('PoiEditor migrate POI types error: $e');
    }

    const defaults = <({String type, String label, String color, int preferredZ})>[
      (type: 'route', label: 'Tracé Route', color: '#1A73E8', preferredZ: 1),
      (type: 'parking', label: 'Parkings', color: '#FBBF24', preferredZ: 2),
      (type: 'wc', label: 'Toilettes', color: '#9333EA', preferredZ: 3),
      (type: 'food', label: 'Food', color: '#EF4444', preferredZ: 4),
      (type: 'assistance', label: 'Assistance', color: '#34A853', preferredZ: 5),
      (type: 'visit', label: 'Lieux à visiter', color: '#F59E0B', preferredZ: 6),
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
          debugPrint('PoiEditor migrate layer tour->visit error: $e');
        }
      }
    }

    final db = FirebaseFirestore.instance;
    final layersCol = db.collection('map_projects').doc(projectId).collection('layers');
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
        debugPrint('PoiEditor ensure POI layers commit error: $e');
      }
    }

    _layers.sort((a, b) => a.zIndex.compareTo(b.zIndex));

    if (_selectedLayer == null && _layers.isNotEmpty) {
      _selectedLayer = _layers.firstWhere(
        (l) => _normalizePoiLayerType(l.type) != 'route',
        orElse: () => _layers.first,
      );
    }
  }

  Future<void> _loadPoisFirstPage() async {
    final page = await _repository.listPoisPage(
      projectId: widget.projectId,
      pageSize: _poiPageSize,
    );

    _pois = page.docs.map((doc) => MarketMapPOI.fromFirestore(doc)).toList();
    _poisLastDoc = page.docs.isNotEmpty ? page.docs.last : null;
    _hasMorePois = page.docs.length == _poiPageSize;
  }

  Future<void> _loadMorePoisPage() async {
    if (_isLoadingMorePois || !_hasMorePois) return;

    setState(() => _isLoadingMorePois = true);
    try {
      final page = await _repository.listPoisPage(
        projectId: widget.projectId,
        pageSize: _poiPageSize,
        startAfter: _poisLastDoc,
      );

      final incoming = page.docs.map((doc) => MarketMapPOI.fromFirestore(doc)).toList();
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

    if (mounted && _selectedLayer != null) {
      _refreshPoiMarkers();
    }
  }

  Future<void> _ensureAllPoisLoaded() async {
    while (_hasMorePois && !_isLoadingMorePois) {
      await _loadMorePoisPage();
    }
  }

  Map<String, dynamic> _buildCurrentData() {
    return {
      'circuitId': widget.circuitId.trim(),
      'name': _nameController.text.trim(),
      'countryId': _countryController.text.trim(),
      'eventId': _eventController.text.trim(),
      'description': _descriptionController.text.trim(),
      'styleUrl': _styleUrlController.text.trim(),
      'perimeter': _perimeterPoints.map((p) => {'lng': p.lng, 'lat': p.lat}).toList(),
      'route': _routePoints.map((p) => {'lng': p.lng, 'lat': p.lat}).toList(),
      'routeStyle': Map<String, dynamic>.from((_draftData['routeStyle'] as Map?) ?? const <String, dynamic>{}),
    };
  }

  Future<void> _saveDraft() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _ensureActorContext();
      if (!_canWriteMapProjects) {
        if (!mounted) return;
        TopSnackBar.show(
          context,

          const SnackBar(content: Text('⛔ Sauvegarde réservée aux admins.')),
        );
        return;
      }

      setState(() => _isLoading = true);

      // IMPORTANT: la sauvegarde sync les POIs et peut supprimer ceux non chargés.
      // On force donc le chargement complet avant de sauver.
      await _ensureAllPoisLoaded();

      final previousRouteCount = (_draftData['route'] as List?)?.length ?? 0;
      final previousPoiCount = _pois.length;
      final currentData = _buildCurrentData();

      await _repository.saveDraft(
        projectId: widget.projectId,
        actorUid: user.uid,
        actorRole: _currentUserRole ?? 'creator',
        groupId: _currentGroupId ?? 'default',
        currentData: currentData,
        layers: _layers,
        pois: _pois,
        previousRouteCount: previousRouteCount,
        previousPoiCount: previousPoiCount,
      );

      _draftData = {..._draftData, ...currentData};

      if (!mounted) return;
      TopSnackBar.show(
        context,

        const SnackBar(content: Text('✅ POIs enregistrés.')),
      );
    } catch (e) {
      if (!mounted) return;
      TopSnackBar.show(
        context,

        SnackBar(content: Text('❌ Erreur sauvegarde: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      } else {
        _isLoading = false;
      }
    }
  }

  // ====== UI POIs ======

  Future<void> _refreshPoiMarkers() async {
    await _poiMapController.clearAll();

    if (_selectedLayer == null) {
      await _poiMapController.clearPoisGeoJson();
      return;
    }

    final layer = _selectedLayer!;
    final poisForLayer = _pois.where((p) => _poiMatchesSelectedLayer(p, layer)).toList();

    final previewParkingZonePoints =
        (_isDrawingParkingZone && layer.type == 'parking' && _parkingZonePoints.isNotEmpty)
            ? _parkingZonePoints
            : null;

    await _poiMapController.setPoisGeoJson(
      _buildPoisFeatureCollection(
        poisForLayer,
        previewParkingZonePoints: previewParkingZonePoints,
      ),
    );
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

  String? _defaultLayerColorHex(String layerType) {
    for (final l in _layers) {
      if (l.type == layerType) {
        final hex = _normalizeColorHex(l.color);
        if (hex != null) return hex;
      }
    }
    return null;
  }

  Map<String, dynamic> _parkingZoneStyleFromMetadata(MarketMapPOI poi) {
    final meta = poi.metadata;
    final styleRaw = meta?[_parkingZoneStyleKey];
    final style = (styleRaw is Map) ? styleRaw.cast<String, dynamic>() : null;

    final layerHex = _defaultLayerColorHex(poi.layerType) ?? '#FBBF24';
    final fillColor = _normalizeColorHex(style?['fillColor']?.toString()) ?? layerHex;
    final strokeColor =
        _normalizeColorHex(style?['strokeColor']?.toString()) ?? fillColor;
    final fillOpacity = (style?['fillOpacity'] as num?)?.toDouble() ?? _parkingZoneDefaultFillOpacity;
    final strokeWidth = (style?['strokeWidth'] as num?)?.toDouble() ?? _parkingZoneDefaultStrokeWidth;
    final dashRaw = style?['strokeDash'];
    final dash = (dashRaw is String && dashRaw.trim().isNotEmpty) ? dashRaw.trim() : 'solid';

    final pattern =
        (style?['pattern'] is String && (style?['pattern'] as String).trim().isNotEmpty)
            ? (style?['pattern'] as String).trim()
            : 'none';
    final patternOpacity =
        (style?['patternOpacity'] as num?)?.toDouble() ?? _parkingZoneDefaultPatternOpacity;

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
        final fillPattern =
            _mapboxFillPatternIdFromStylePattern(style['pattern'] as String?);
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

    if (previewParkingZonePoints != null && previewParkingZonePoints.isNotEmpty) {
      final previewFill =
          _normalizeColorHex(_selectedLayer?.color) ?? _defaultLayerColorHex('parking') ?? '#FBBF24';

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

    if (previewParkingZonePoints != null && previewParkingZonePoints.length >= 3) {
      final ring = <List<double>>[
        for (final p in previewParkingZonePoints) <double>[p.lng, p.lat],
        <double>[previewParkingZonePoints.first.lng, previewParkingZonePoints.first.lat],
      ];

      final previewFill =
          _normalizeColorHex(_selectedLayer?.color) ?? _defaultLayerColorHex('parking') ?? '#FBBF24';

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
          'fillOpacity': _parkingZoneDefaultFillOpacity,
          'strokeColor': previewFill,
          'strokeWidth': _parkingZoneDefaultStrokeWidth,
          'strokeDash': 'solid',
          'patternOpacity': _parkingZoneDefaultPatternOpacity,
        },
        'geometry': <String, dynamic>{
          'type': 'Polygon',
          'coordinates': <List<List<double>>>[ring],
        },
      });

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

  void _startParkingZoneDrawing() {
    if (_selectedLayer?.type != 'parking') return;
    _poiSelection.clear();
    setState(() {
      _isDrawingParkingZone = true;
      _parkingZonePoints = <LngLat>[];
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

    final centroid = _centroidOf(_parkingZonePoints);
    final fillHex =
        _normalizeColorHex(_selectedLayer?.color) ?? _defaultLayerColorHex('parking') ?? '#FBBF24';
    final poi = MarketMapPOI(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'Zone parking',
      layerType: 'parking',
      layerId: 'parking',
      lng: centroid.lng,
      lat: centroid.lat,
      isVisible: true,
      metadata: <String, dynamic>{
        'perimeter': [for (final p in _parkingZonePoints) {'lng': p.lng, 'lat': p.lat}],
        _parkingZoneStyleKey: <String, dynamic>{
          'fillColor': fillHex,
          'fillOpacity': _parkingZoneDefaultFillOpacity,
          'strokeColor': fillHex,
          'strokeWidth': _parkingZoneDefaultStrokeWidth,
          'strokeDash': 'solid',
          'pattern': 'none',
          'patternOpacity': _parkingZoneDefaultPatternOpacity,
        },
      },
    );

    setState(() {
      _pois.add(poi);
      _isDrawingParkingZone = false;
      _parkingZonePoints = <LngLat>[];
    });
    _poiSelection.select(poi);
    _refreshPoiMarkers();
  }

  Future<void> _onMapTapForPoi(double lng, double lat) async {
    if (_selectedLayer == null) return;

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
          TopSnackBar.show(
            context,
            const SnackBar(content: Text('⚠️ Erreur lors de l\'ajout du point')),
          );
        }
      }
      return;
    }

    if (_pois.length >= _poiLimit) {
      if (mounted) {
        TopSnackBar.show(
          context,

          const SnackBar(content: Text('❌ Limite atteinte: 2000 POI maximum par projet')),
        );
      }
      return;
    }

    await _createPoiAt(lng: lng, lat: lat);
  }

  Future<void> _createPoiAt({required double lng, required double lat}) async {
    if (_selectedLayer == null) return;
    if (_pois.length >= _poiLimit) {
      if (mounted) {
        TopSnackBar.show(
          context,
          const SnackBar(content: Text('❌ Limite atteinte: 2000 POI maximum par projet')),
        );
      }
      return;
    }

    final layerType = _selectedLayer!.type;
    final provisional = MarketMapPOI(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '',
      layerType: layerType,
      layerId: layerType,
      lng: lng,
      lat: lat,
      metadata: <String, dynamic>{kMasLivePoiAppearanceKey: _defaultPoiAppearanceId},
    );

    final created = await showModalBottomSheet<MarketMapPOI>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => PoiEditPopup(
        poi: provisional,
        projectId: widget.projectId,
        appearancePresets: kMasLivePoiAppearancePresets,
      ),
    );
    if (created == null) return;

    setState(() {
      _pois.add(created);
    });
    _poiSelection.select(created);
    _refreshPoiMarkers();
  }

  Future<void> _editPoi(MarketMapPOI poi) async {
    final updated = await showModalBottomSheet<MarketMapPOI>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => PoiEditPopup(
        poi: poi,
        projectId: widget.projectId,
        appearancePresets: kMasLivePoiAppearancePresets,
      ),
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

    await _onMapTapForPoi(lng, lat);
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

  Widget _buildPoiEditor() {
    Widget interceptPointersIfNeeded(Widget child) {
      if (!kIsWeb) return child;
      return PointerInterceptor(child: child);
    }

    final poiLayers = _layers.where((l) => l.type != 'route').toList();

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
                      _isDrawingParkingZone ? Icons.crop_square : Icons.crop_square_rounded,
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
                      onPressed: _parkingZonePoints.length < 3 ? null : _finishParkingZoneDrawing,
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
                        : (_pois.length >= (_poiLimit * 0.9) ? Colors.orange : MasliveTokens.text),
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
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
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
                  style: TextStyle(fontSize: 12, color: MasliveTokens.textSoft),
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
                              style: TextStyle(fontSize: 11, color: MasliveTokens.textSoft),
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
                                  icon: const Icon(Icons.delete_outline, size: 18),
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

    final initialLng = _routePoints.isNotEmpty
        ? _routePoints.first.lng
        : (_perimeterPoints.isNotEmpty ? _perimeterPoints.first.lng : -61.533);
    final initialLat = _routePoints.isNotEmpty
        ? _routePoints.first.lat
        : (_perimeterPoints.isNotEmpty ? _perimeterPoints.first.lat : 16.241);
    final initialZoom = _routePoints.isNotEmpty || _perimeterPoints.isNotEmpty ? 14.0 : 12.0;

    return ChangeNotifierProvider<PoiSelectionController>.value(
      value: _poiSelection,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewportHeight = constraints.maxHeight;

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: MasliveTokens.xl),
            child: Column(
              children: [
                SizedBox(
                  height: viewportHeight,
                  child: Stack(
                    children: [
                      MasLiveMap(
                        controller: _poiMapController,
                        initialLng: initialLng,
                        initialLat: initialLat,
                        initialZoom: initialZoom,
                        styleUrl: _styleUrlController.text.trim().isEmpty
                            ? null
                            : _styleUrlController.text.trim(),
                        onMapReady: (ctrl) async {
                          _refreshPoiMarkers();
                        },
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
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: interceptPointersIfNeeded(
                    buildPoiToolsPanel(poiLayers: poiLayers),
                  ),
                ),
                Consumer<PoiSelectionController>(
                  builder: (context, selection, _) {
                    final selected = selection.selectedPoi;
                    return PoiInlinePopup(
                      selectedPoi: selected,
                      onClose: selection.clear,
                      onEdit: selected == null ? () {} : () => _editPoi(selected),
                      onDelete: selected == null ? () {} : () => _deletePoi(selected),
                      categoryLabel: (poi) {
                        final match = _layers.where((l) => l.type == poi.layerType).toList();
                        return match.isNotEmpty ? match.first.label : poi.layerType;
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.circuitName ?? _nameController.text).trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(title.isEmpty ? 'POIs' : 'POIs • $title'),
        actions: [
          IconButton(
            tooltip: 'Enregistrer',
            onPressed: _isLoading ? null : _saveDraft,
            icon: const Icon(Icons.save_alt),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_errorMessage != null)
              ? Center(child: Text(_errorMessage!))
              : _buildPoiEditor(),
    );
  }
}
