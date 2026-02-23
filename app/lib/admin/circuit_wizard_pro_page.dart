import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/market_circuit_models.dart';
import '../services/circuit_repository.dart';
import '../services/circuit_versioning_service.dart';
import '../services/market_map_service.dart';
import '../services/publish_quality_service.dart';
import '../ui/map/maslive_map.dart';
import '../ui/widgets/country_autocomplete_field.dart';
import '../models/market_country.dart';
import 'circuit_map_editor.dart';
import '../route_style_pro/models/route_style_config.dart' as rsp;
import '../route_style_pro/services/route_snap_service.dart' as snap;
import '../route_style_pro/ui/route_style_wizard_pro_page.dart';

typedef LngLat = ({double lng, double lat});

class CircuitWizardProPage extends StatefulWidget {
  final String? projectId;
  final String? countryId;
  final String? eventId;
  final String? circuitId;

  const CircuitWizardProPage({
    super.key,
    this.projectId,
    this.countryId,
    this.eventId,
    this.circuitId,
  });

  @override
  State<CircuitWizardProPage> createState() => _CircuitWizardProPageState();
}

class _CircuitWizardProPageState extends State<CircuitWizardProPage> {
  static const int _poiPageSize = 100;
  static const int _poiLimit = 2000;

  final CircuitRepository _repository = CircuitRepository();
  final CircuitVersioningService _versioning = CircuitVersioningService();
  final PublishQualityService _qualityService = PublishQualityService();
  final MarketMapService _marketMapService = MarketMapService();

  String? _projectId;
  late PageController _pageController;
  int _currentStep = 0;
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

  // Données Steps 2-4: Cartes
  List<LngLat> _perimeterPoints = [];
  List<LngLat> _routePoints = [];

  // Style du tracé (Step 3 + Step 4)
  String _routeColorHex = '#1A73E8';
  double _routeWidth = 6.0;
  bool _routeRoadLike = true;
  bool _routeShadow3d = true;
  bool _routeShowDirection = true;
  bool _routeAnimateDirection = false;
  double _routeAnimationSpeed = 1.0;

  // Step 4: Layers/POI
  List<MarketMapLayer> _layers = [];
  List<MarketMapPOI> _pois = [];
  DocumentSnapshot<Map<String, dynamic>>? _poisLastDoc;
  bool _hasMorePois = false;
  bool _isLoadingMorePois = false;
  MarketMapLayer? _selectedLayer;
  final MasLiveMapControllerPoi _poiMapController = MasLiveMapControllerPoi();

  bool _isSnappingRoute = false;

  // Snap en continu (debounce + ignore résultats obsolètes)
  Timer? _routeSnapDebounce;
  int _routeSnapSeq = 0;

  // Brouillon
  Map<String, dynamic> _draftData = {};

  PublishQualityReport get _qualityReport => _qualityService.evaluate(
        perimeter: _perimeterPoints,
        route: _routePoints,
        routeColorHex: _routeColorHex,
        routeWidth: _routeWidth,
        layers: _layers,
        pois: _pois,
      );

  Future<void> _openRouteStylePro() async {
    await _ensureActorContext();
    if (!_canWriteMapProjects) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⛔ Accès en écriture réservé aux admins master.'),
        ),
      );
      return;
    }
    // Assure un projectId existant avant d'ouvrir le wizard Pro.
    await _saveDraft();

    final projectId = _projectId;
    if (!mounted) return;
    if (projectId == null || projectId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Impossible: projet non sauvegardé')),
      );
      return;
    }

    await Navigator.of(context).pushNamed(
      '/admin/route-style-pro',
      arguments: RouteStyleProArgs(
        projectId: projectId,
        circuitId: widget.circuitId,
        initialRoute: _routePoints.isNotEmpty
            ? <rsp.LatLng>[for (final p in _routePoints) (lat: p.lat, lng: p.lng)]
            : null,
      ),
    );

    await _reloadRouteAndStyleFromFirestore(projectId);
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
    } catch (e) {
      debugPrint('WizardPro _reloadRouteAndStyleFromFirestore error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur recharge style: $e')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _projectId = widget.projectId;
    _pageController = PageController();

    // Step POI: hit-testing GeoJSON (tap POI => édition, tap carte => ajout)
    _poiMapController.onPoiTap = (poiId) {
      final idx = _pois.indexWhere((p) => p.id == poiId);
      if (idx < 0) return;
      unawaited(_editPoi(_pois[idx]));
    };
    _poiMapController.onMapTap = (lat, lng) {
      // Note: signature controller = (lat, lng), handler = (lng, lat)
      unawaited(_onMapTapForPoi(lng, lat));
    };

    _loadDraftOrInitialize();
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

  Map<String, dynamic> _buildCurrentData() {
    return {
      'name': _nameController.text.trim(),
      'countryId': _countryController.text.trim(),
      'eventId': _eventController.text.trim(),
      'description': _descriptionController.text.trim(),
      'styleUrl': _styleUrlController.text.trim(),
      'perimeter':
          _perimeterPoints.map((p) => {'lng': p.lng, 'lat': p.lat}).toList(),
      'route': _routePoints.map((p) => {'lng': p.lng, 'lat': p.lat}).toList(),
      'routeStyle': {
        'color': _routeColorHex,
        'width': _routeWidth,
        'roadLike': _routeRoadLike,
        'shadow3d': _routeShadow3d,
        'showDirection': _routeShowDirection,
        'animateDirection': _routeAnimateDirection,
        'animationSpeed': _routeAnimationSpeed,
      },
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⛔ Accès en écriture réservé aux admins master.'),
        ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ Modèle appliqué: ${template.name}')),
    );
  }

  Future<void> _showDraftHistory() async {
    if (_projectId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ℹ️ Sauvegarde d’abord le projet.')),
      );
      return;
    }

    final drafts = await _versioning.listDrafts(projectId: _projectId!, pageSize: 30);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⛔ Restauration réservée aux admins master.'),
        ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ Version ${selected.version} restaurée')),
    );
  }

  @override
  void dispose() {
    _routeSnapDebounce?.cancel();
    _pageController.dispose();
    _perimeterEditorController.dispose();
    _routeEditorController.dispose();
    _poiMapController.dispose();
    _nameController.dispose();
    _countryController.dispose();
    _eventController.dispose();
    _descriptionController.dispose();
    _styleUrlController.dispose();
    super.dispose();
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

          // Charger points
          final perimData = _draftData['perimeter'] as List<dynamic>?;
          if (perimData != null) {
            _perimeterPoints = perimData.map((p) {
              final m = p as Map<String, dynamic>;
              return (lng: m['lng'] as double, lat: m['lat'] as double);
            }).toList();
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
          type: 'tour',
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

    // Si l'utilisateur est déjà sur une couche, on rafraîchit l'affichage.
    if (mounted && _selectedLayer != null) {
      _refreshPoiMarkers();
    }
  }

  Future<void> _saveDraft({bool createSnapshot = false}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _ensureActorContext();
      if (!_canWriteMapProjects) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⛔ Sauvegarde réservée aux admins master.'),
          ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Brouillon sauvegardé')),
        );
      }
    } catch (e) {
      debugPrint('WizardPro _saveDraft error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is FirebaseException
                  ? '❌ Firestore (${e.code}): ${e.message ?? e.toString()}'
                  : '❌ Erreur: $e',
            ),
          ),
        );
      }
    }
  }

  Future<void> _continueToStep(int step) async {
    // Valider l'étape courante
    if (_currentStep == 1) {
      if (_nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Nom requis')),
        );
        return;
      }
    }

    if (_canWriteMapProjects) {
      await _saveDraft(createSnapshot: true);
    }
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chargement...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erreur')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_errorMessage!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Création de circuit'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Progress indicator
          SizedBox(
            height: 60,
            child: Row(
              children: List.generate(8, (index) {
                return Expanded(
                  child: GestureDetector(
                    onTap: index <= _currentStep
                        ? () => _pageController.jumpToPage(index)
                        : null,
                    child: _StepIndicator(
                      step: index,
                      label: _getStepLabel(index),
                      isActive: index == _currentStep,
                      isCompleted: index < _currentStep,
                      isEnabled: index <= _currentStep,
                    ),
                  ),
                );
              }),
            ),
          ),
          const Divider(height: 1),

          // Étape 3 (côté UI): Définir le périmètre.
          // On affiche le titre juste sous le header principal pour une meilleure lisibilité.
          if (_currentStep == 2)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              width: double.infinity,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Définir le périmètre',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tracez la zone de couverture (polygone fermé)',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),

          if (_currentStep == 2 || _currentStep == 3 || _currentStep == 4)
            _buildCentralMapToolsBar(),

          // Pages
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (page) {
                setState(() => _currentStep = page);
              },
              children: [
                _buildStep0Template(),
                _buildStep1Infos(),
                _buildStep2Perimeter(),
                _buildStep3Route(),
                _buildStep4Style(),
                _buildStep5POI(),
                _buildStep6Validation(),
                _buildStep7Publish(),
              ],
            ),
          ),

          // Navigation buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentStep > 0)
                  ElevatedButton(
                    onPressed: () => _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    ),
                    child: const Text('← Précédent'),
                  )
                else
                  const SizedBox(),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  onPressed: () => _saveDraft(createSnapshot: true),
                  label: const Text('Sauvegarder'),
                ),
                if (_currentStep < 7)
                  ElevatedButton(
                    onPressed: () => _continueToStep(_currentStep + 1),
                    child: const Text('Suivant →'),
                  )
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStepLabel(int step) {
    const labels = [
      'Template',
      'Infos',
      'Périmètre',
      'Tracé',
      'Style',
      'POI',
      'Pré-pub',
      'Publication'
    ];
    return labels[step];
  }

  Widget _buildStep0Template() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Choisir un modèle (optionnel)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tu peux démarrer depuis un template global ou passer cette étape.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 20),
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
            onChanged: (value) => setState(() => _selectedTemplate = value),
            decoration: const InputDecoration(
              labelText: 'Template',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.auto_awesome),
                onPressed: _selectedTemplate == null
                    ? null
                    : () => _applyTemplate(_selectedTemplate!),
                label: const Text('Appliquer le modèle'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.history),
                onPressed: _showDraftHistory,
                label: const Text('Historique'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep1Infos() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Informations de base',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nom du circuit *',
              hintText: 'Ex: Circuit Côte Nord',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
          TextField(
            controller: _eventController,
            decoration: const InputDecoration(
              labelText: 'Événement *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _styleUrlController,
            decoration: const InputDecoration(
              labelText: 'Style URL Mapbox (optionnel)',
              hintText: 'mapbox://styles/username/style-id',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 220,
              child: MasLiveMap(
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
                initialZoom:
                    (_routePoints.isNotEmpty || _perimeterPoints.isNotEmpty)
                        ? 13.5
                        : 12.0,
                styleUrl: _styleUrlController.text.trim().isEmpty
                    ? null
                    : _styleUrlController.text.trim(),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '💡 Complétez les informations de base, puis définissez le périmètre et le tracé sur les étapes suivantes.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Perimeter() {
    return CircuitMapEditor(
      title: 'Définir le périmètre',
      subtitle: 'Tracez la zone de couverture (polygon fermé)',
      points: _perimeterPoints,
      controller: _perimeterEditorController,
      styleUrl: _styleUrlController.text.trim().isEmpty
          ? null
          : _styleUrlController.text.trim(),
      showToolbar: false,
      showHeader: false,
      pointsListMaxHeight: 120,
      onPointsChanged: (points) {
        setState(() {
          _perimeterPoints = points;
        });
      },
      onSave: _saveDraft,
    );
  }

  Widget _buildStep3Route() {
    return CircuitMapEditor(
      title: 'Définir le tracé',
      subtitle: 'Tracez l\'itinéraire du circuit (polyline)',
      points: _routePoints,
      controller: _routeEditorController,
      perimeterOverlay: _perimeterPoints,
      styleUrl: _styleUrlController.text.trim().isEmpty
          ? null
          : _styleUrlController.text.trim(),
      showToolbar: false,
      onPointsChanged: (points) {
        final previousCount = _routePoints.length;
        setState(() {
          _routePoints = points;
        });

        // Waze-like: après ajout de point, on aligne automatiquement sur route.
        // Important: on ne spam pas pendant les glisser-déposer.
        if (_currentStep == 3 && points.length >= 2 && points.length > previousCount) {
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
    );
  }

  Widget _buildStep4Style() {
    return CircuitMapEditor(
      title: 'Style du tracé (Waze)',
      subtitle: 'Réglez l\'apparence de l\'itinéraire',
      points: _routePoints,
      controller: _routeEditorController,
      perimeterOverlay: _perimeterPoints,
      styleUrl: _styleUrlController.text.trim().isEmpty
          ? null
          : _styleUrlController.text.trim(),
      showToolbar: false,
      onPointsChanged: (points) {
        setState(() {
          _routePoints = points;
        });
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
    );
  }

  Widget _buildCentralMapToolsBar() {
    final isPerimeter = _currentStep == 2;
    final controller = isPerimeter ? _perimeterEditorController : _routeEditorController;

    return Material(
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final routeIsLooped = !isPerimeter &&
                _routePoints.length >= 2 &&
                _routePoints.first == _routePoints.last;

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

                  if (isPerimeter)
                    IconButton(
                      icon: const Icon(Icons.loop_rounded),
                      onPressed: controller.pointCount >= 2 ? controller.closePath : null,
                      tooltip: 'Fermer le polygone',
                    ),
                  IconButton(
                    icon: const Icon(Icons.flip_to_back),
                    onPressed: controller.pointCount >= 2 ? controller.reversePath : null,
                    tooltip: 'Inverser sens',
                  ),
                  IconButton(
                    icon: const Icon(Icons.compress_rounded),
                    onPressed: controller.pointCount >= 3 ? controller.simplifyTrack : null,
                    tooltip: 'Simplifier tracé',
                  ),

                  if (!isPerimeter && _currentStep == 3) ...[
                    IconButton(
                      icon: _isSnappingRoute
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.alt_route_rounded),
                      onPressed: (!_isSnappingRoute && controller.pointCount >= 2)
                          ? _snapRouteToRoads
                          : null,
                      tooltip: 'Snap sur route (Waze)',
                    ),

                    const SizedBox(width: 4),
                    ToggleButtons(
                      isSelected: [routeIsLooped, !routeIsLooped],
                      borderRadius: BorderRadius.circular(10),
                      constraints: const BoxConstraints(minHeight: 36),
                      onPressed: (index) {
                        if (controller.pointCount < 2) return;
                        if (index == 0) {
                          controller.closePath();
                        } else {
                          controller.openPath();
                        }
                      },
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
                    onPressed: controller.pointCount > 0 ? controller.clearAll : null,
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
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),

                  if (!isPerimeter && (_currentStep == 3 || _currentStep == 4)) ...[
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Tracé aligné sur la route (${output.length} points)',
            ),
          ),
        );
      }

      if (persist && _projectId != null) {
        await _saveDraft();
      }
    } catch (e) {
      debugPrint('WizardPro _snapRouteToRoadsInternal error: $e');
      if (!mounted) return;
      if (seq != _routeSnapSeq) return;
      if (showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Snap impossible: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSnappingRoute = false);
    }
  }

  Widget _buildRouteStyleControls() {
    final colors = <String, String>{
      '#1A73E8': 'Bleu',
      '#34A853': 'Vert',
      '#EF4444': 'Rouge',
      '#F59E0B': 'Orange',
      '#9333EA': 'Violet',
    };

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
            child: Icon(
              Icons.color_lens,
              color: _parseHexColor(_routeColorHex, fallback: Colors.blue),
            ),
          ),
        ),

        SizedBox(
          width: 140,
          child: Row(
            children: [
              const Text('L',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
            color: _routeRoadLike ? Colors.blue : Colors.grey,
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
                ? Colors.blueGrey
                : Colors.grey,
          ),
        ),
        IconButton(
          tooltip: 'Sens (flèches)',
          onPressed: () => setState(() => _routeShowDirection = !_routeShowDirection),
          icon: Icon(
            Icons.navigation,
            color: _routeShowDirection ? Colors.blueGrey : Colors.grey,
          ),
        ),
        IconButton(
          tooltip: 'Animation sens de marche',
          onPressed: () => setState(() => _routeAnimateDirection = !_routeAnimateDirection),
          icon: Icon(
            _routeAnimateDirection
                ? Icons.pause_circle_filled
                : Icons.play_circle_filled,
            color: _routeAnimateDirection ? Colors.green : Colors.grey,
          ),
        ),

        if (_routeAnimateDirection)
          SizedBox(
            width: 160,
            child: Row(
              children: [
                const Text('V',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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

        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _openRouteStylePro,
          icon: const Icon(Icons.tune, size: 18),
          label: const Text('Style Pro'),
        ),
      ],
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
    Widget interceptPointersIfNeeded(Widget child) {
      // Sur Flutter web + HtmlElementView (Mapbox), des clics peuvent traverser
      // certains overlays et déclencher le onTap de la carte en arrière-plan.
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
              : (_perimeterPoints.isNotEmpty
                  ? _perimeterPoints.first.lng
                  : -61.533),
          initialLat: _routePoints.isNotEmpty
              ? _routePoints.first.lat
              : (_perimeterPoints.isNotEmpty
                  ? _perimeterPoints.first.lat
                  : 16.241),
          initialZoom: _routePoints.isNotEmpty || _perimeterPoints.isNotEmpty
              ? 14.0
              : 12.0,
          styleUrl: _styleUrlController.text.trim().isEmpty
              ? null
              : _styleUrlController.text.trim(),
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
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
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
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          '${_pois.where((p) => p.layerType == _selectedLayer!.type).length} POI',
                          style: const TextStyle(fontSize: 12),
                        ),
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 220),
                            child: ListView(
                              shrinkWrap: true,
                              children: [
                                for (final poi in _pois.where(
                                  (p) => p.layerType == _selectedLayer!.type,
                                ))
                                  ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(
                                      Icons.place_outlined,
                                      size: 18,
                                    ),
                                    title: Text(
                                      poi.name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
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
                              margin: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: (_selectedLayer?.type == layer.type)
                                    ? Colors.blue.withValues(alpha: 0.12)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getLayerIcon(layer.type),
                                color: (_selectedLayer?.type == layer.type)
                                    ? Colors.blueGrey
                                    : Colors.grey,
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

  // ====== Gestion POI (étape 4) ======

  void _refreshPoiMarkers() async {
    await _poiMapController.clearAll();

    if (_selectedLayer == null) {
      await _poiMapController.clearPoisGeoJson();
      return;
    }

    final layerType = _selectedLayer!.type;
    final poisForLayer = _pois.where((p) => p.layerType == layerType).toList();
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Limite atteinte: 2000 POI maximum par projet'),
          ),
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

    await _onMapTapForPoi(lng, lat);
  }

  Widget _buildStep6Validation() {
    final report = _qualityReport;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Pré-publication',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Score qualité: ${report.score}/100',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: report.canPublish ? Colors.green : Colors.orange,
            ),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: report.score / 100,
            minHeight: 8,
            color: report.canPublish ? Colors.green : Colors.orange,
          ),
          const SizedBox(height: 20),
          for (final item in report.items)
            ListTile(
              dense: true,
              leading: Icon(
                item.ok ? Icons.check_circle : Icons.error_outline,
                color: item.ok ? Colors.green : Colors.redAccent,
              ),
              title: Text(item.label),
              subtitle: (!item.ok && item.hint != null)
                  ? Text(item.hint!)
                  : null,
              trailing: item.required
                  ? const Chip(label: Text('Requis'))
                  : const Chip(label: Text('Optionnel')),
            ),
        ],
      ),
    );
  }

  Widget _buildStep7Publish() {
    final report = _qualityReport;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Publication',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '✅ Votre circuit est prêt !',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Nom: ${_nameController.text.trim()}',
                  style: const TextStyle(fontSize: 13),
                ),
                Text(
                  'Points périmètre: ${_perimeterPoints.length}',
                  style: const TextStyle(fontSize: 13),
                ),
                Text(
                  'Points tracé: ${_routePoints.length}',
                  style: const TextStyle(fontSize: 13),
                ),
                Text(
                  'Score qualité: ${report.score}/100',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          if (!report.canPublish) ...[
            const SizedBox(height: 12),
            const Text(
              '❌ Publication bloquée: corrige les points requis de l’étape Pré-publication.',
              style: TextStyle(color: Colors.redAccent),
            ),
          ],
          const SizedBox(height: 32),
          const Text(
            'Options de publication',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.cloud_upload),
            onPressed: report.canPublish ? _publishCircuit : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.green,
            ),
            label: const Text(
              'PUBLIER LE CIRCUIT',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.save_alt),
            onPressed: () => _saveDraft(createSnapshot: true),
            label: const Text('Rester en brouillon'),
          ),
        ],
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⛔ Publication réservée aux admins master.'),
          ),
        );
        return;
      }

      setState(() => _isLoading = true);

      final report = _qualityReport;
      if (!report.canPublish) {
        throw StateError('Pré-publication non conforme: corrige les points bloquants.');
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Circuit publié avec succès !')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('WizardPro _publishCircuit error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is FirebaseException
                  ? '❌ Publication Firestore (${e.code}): ${e.message ?? e.toString()}'
                  : '❌ Erreur publication: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  IconData _getLayerIcon(String type) {
    const icons = {
      'parking': Icons.local_parking,
      'wc': Icons.wc,
      'food': Icons.restaurant,
      'assistance': Icons.support_agent,
      'tour': Icons.tour,
      'route': Icons.route,
    };
    return icons[type] ?? Icons.place_outlined;
  }
}

class _StepIndicator extends StatelessWidget {
  final int step;
  final String label;
  final bool isActive;
  final bool isCompleted;
  final bool isEnabled;

  const _StepIndicator({
    required this.step,
    required this.label,
    required this.isActive,
    required this.isCompleted,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isCompleted
                ? Colors.green
                : isActive
                    ? Colors.blue
                    : Colors.grey.shade300,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isActive || isCompleted ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
