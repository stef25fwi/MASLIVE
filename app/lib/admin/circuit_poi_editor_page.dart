import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../models/market_circuit_models.dart';
import '../services/circuit_repository.dart';
import '../ui/map/maslive_map.dart';
import '../ui/snack/top_snack_bar.dart';

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

  final CircuitRepository _repository = CircuitRepository();

  bool _isLoading = true;
  String? _errorMessage;

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

  Map<String, dynamic> _draftData = {};

  @override
  void initState() {
    super.initState();

    _poiMapController.onPoiTap = (poiId) {
      final idx = _pois.indexWhere((p) => p.id == poiId);
      if (idx < 0) return;
      unawaited(_editPoi(_pois[idx]));
    };
    _poiMapController.onMapTap = (lat, lng) {
      unawaited(_onMapTapForPoi(lng, lat));
    };

    unawaited(_load());
  }

  @override
  void dispose() {
    _poiMapController.dispose();
    _nameController.dispose();
    _countryController.dispose();
    _eventController.dispose();
    _descriptionController.dispose();
    _styleUrlController.dispose();
    super.dispose();
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

  void _refreshPoiMarkers() async {
    await _poiMapController.clearAll();

    if (_selectedLayer == null) {
      await _poiMapController.clearPoisGeoJson();
      return;
    }

    final layer = _selectedLayer!;
    final poisForLayer = _pois.where((p) => _poiMatchesSelectedLayer(p, layer)).toList();
    await _poiMapController.setPoisGeoJson(_buildPoisFeatureCollection(poisForLayer));
  }

  Map<String, dynamic> _buildPoisFeatureCollection(List<MarketMapPOI> pois) {
    return <String, dynamic>{
      'type': 'FeatureCollection',
      'features': <Map<String, dynamic>>[
        for (final poi in pois)
          <String, dynamic>{
            'type': 'Feature',
            'id': poi.id,
            'properties': <String, dynamic>{
              'poiId': poi.id,
              'layerId': poi.layerType,
              'title': poi.name,
            },
            'geometry': <String, dynamic>{
              'type': 'Point',
              'coordinates': <double>[poi.lng, poi.lat],
            },
          },
      ],
    };
  }

  Future<void> _onMapTapForPoi(double lng, double lat) async {
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

    final nameController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouveau point d\'intérêt'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Nom du POI',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final name = nameController.text.trim().isEmpty
        ? '${_selectedLayer!.label} (${lng.toStringAsFixed(4)}, ${lat.toStringAsFixed(4)})'
        : nameController.text.trim();

    final poi = MarketMapPOI(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      layerType: _selectedLayer!.type,
      lng: lng,
      lat: lat,
      description: null,
      imageUrl: null,
      metadata: null,
    );

    setState(() {
      _pois.add(poi);
    });
    _refreshPoiMarkers();
  }

  Future<void> _editPoi(MarketMapPOI poi) async {
    final nameController = TextEditingController(text: poi.name);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier le POI'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Nom du POI',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final nextName = nameController.text.trim();
    if (nextName.isEmpty) return;

    setState(() {
      final idx = _pois.indexWhere((p) => p.id == poi.id);
      if (idx >= 0) {
        _pois[idx] = MarketMapPOI(
          id: poi.id,
          name: nextName,
          layerType: poi.layerType,
          lng: poi.lng,
          lat: poi.lat,
          description: poi.description,
          imageUrl: poi.imageUrl,
          instagram: poi.instagram,
          facebook: poi.facebook,
          metadata: poi.metadata,
        );
      }
    });
    _refreshPoiMarkers();
  }

  void _deletePoi(MarketMapPOI poi) {
    setState(() {
      _pois.removeWhere((p) => p.id == poi.id);
    });
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

  IconData _getLayerIcon(String type) {
    switch (type.trim().toLowerCase()) {
      case 'parking':
        return Icons.local_parking;
      case 'wc':
        return Icons.wc;
      case 'food':
        return Icons.restaurant;
      case 'assistance':
        return Icons.medical_services_outlined;
      case 'visit':
      case 'tour':
      case 'visiter':
        return Icons.location_city;
      default:
        return Icons.layers_outlined;
    }
  }

  Widget _buildPoiEditor() {
    Widget interceptPointersIfNeeded(Widget child) {
      if (!kIsWeb) return child;
      return PointerInterceptor(child: child);
    }

    final poiLayers = _layers.where((l) => l.type != 'route').toList();

    return Stack(
      children: [
        MasLiveMap(
          controller: _poiMapController,
          initialLng: _routePoints.isNotEmpty
              ? _routePoints.first.lng
              : (_perimeterPoints.isNotEmpty ? _perimeterPoints.first.lng : -61.533),
          initialLat: _routePoints.isNotEmpty
              ? _routePoints.first.lat
              : (_perimeterPoints.isNotEmpty ? _perimeterPoints.first.lat : 16.241),
          initialZoom: _routePoints.isNotEmpty || _perimeterPoints.isNotEmpty ? 14.0 : 12.0,
          styleUrl: _styleUrlController.text.trim().isEmpty ? null : _styleUrlController.text.trim(),
          onMapReady: (ctrl) async {
            _refreshPoiMarkers();
          },
        ),
        Positioned(
          left: 12,
          right: 78,
          top: 12,
          child: interceptPointersIfNeeded(
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.place_outlined, color: Colors.blueGrey),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Points d\'intérêt (POI)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.my_location),
                          tooltip: 'Ajouter un POI à la position actuelle',
                          onPressed: (_selectedLayer == null || _pois.length >= _poiLimit)
                              ? null
                              : _addPoiAtCurrentCenter,
                        ),
                        IconButton(
                          icon: const Icon(Icons.save_alt),
                          tooltip: 'Enregistrer les POI',
                          onPressed: _isLoading ? null : _saveDraft,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
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
                                    : Colors.black87),
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
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${_pois.where((p) => _poiMatchesSelectedLayer(p, _selectedLayer!)).length} POI',
                          style: const TextStyle(fontSize: 12),
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
                                    title: Text(
                                      poi.name,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text(
                                      '${poi.lng.toStringAsFixed(5)}, ${poi.lat.toStringAsFixed(5)}',
                                      style: const TextStyle(fontSize: 11),
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
              ),
            ),
          ),
        ),
        if (poiLayers.isNotEmpty)
          Positioned(
            right: 12,
            top: 12,
            child: interceptPointersIfNeeded(
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final layer in poiLayers) ...[
                        Tooltip(
                          message: layer.label,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setState(() {
                                _selectedLayer = layer;
                              });
                              _refreshPoiMarkers();
                            },
                            child: Container(
                              width: 52,
                              height: 44,
                              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: (_selectedLayer?.type == layer.type)
                                    ? Colors.blue.withValues(alpha: 0.12)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getLayerIcon(layer.type),
                                color: (_selectedLayer?.type == layer.type) ? Colors.blueGrey : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
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
