import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/market_circuit_models.dart';
import '../ui/map/maslive_map.dart';
import '../ui/map/maslive_map_controller.dart';
import 'circuit_map_editor.dart';
import 'circuit_validation_checklist_page.dart';
import '../route_style_pro/models/route_style_config.dart' as rsp;
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
  String? _projectId;
  late PageController _pageController;
  int _currentStep = 0;
  bool _isLoading = false;
  String? _errorMessage;

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
  MarketMapLayer? _selectedLayer;
  final MasLiveMapController _poiMapController = MasLiveMapController();

  // Brouillon
  Map<String, dynamic> _draftData = {};

  Future<void> _openRouteStylePro() async {
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
    _loadDraftOrInitialize();
  }

  @override
  void dispose() {
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

      // Si un projectId est fouirni, le charger
      if (_projectId != null) {
        final doc = await FirebaseFirestore.instance
            .collection('map_projects')
            .doc(_projectId)
            .get();

        if (doc.exists) {
          _draftData = doc.data() ?? {};
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

          // Charger POI
          _pois = await _loadPois();

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

  Future<List<MarketMapPOI>> _loadPois() async {
    if (_projectId == null) {
      return [];
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('map_projects')
        .doc(_projectId)
        .collection('pois')
        .get();

    return snapshot.docs
        .map((doc) => MarketMapPOI.fromFirestore(doc))
        .toList();
  }

  Future<void> _saveDraft() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final isNew = _projectId == null;
      final projectId = _projectId ?? FirebaseFirestore.instance.collection('map_projects').doc().id;
      _projectId = projectId;

      final data = <String, dynamic>{
        'name': _nameController.text.trim(),
        'countryId': _countryController.text.trim(),
        'eventId': _eventController.text.trim(),
        'description': _descriptionController.text.trim(),
        'styleUrl': _styleUrlController.text.trim(),
        'perimeter': _perimeterPoints.map((p) => {'lng': p.lng, 'lat': p.lat}).toList(),
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
        'status': 'draft',
        'uid': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (isNew) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }

      await FirebaseFirestore.instance
          .collection('map_projects')
          .doc(projectId)
          .set(data, SetOptions(merge: true));

      // Sauvegarder les POI
      final poisRef = FirebaseFirestore.instance
          .collection('map_projects')
          .doc(projectId)
          .collection('pois');

      // Pour simplifier: on efface et on réécrit tous les POI
      final existing = await poisRef.get();
      for (final doc in existing.docs) {
        await doc.reference.delete();
      }

      for (final poi in _pois) {
        await poisRef.add(poi.toFirestore());
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
    if (_currentStep == 0) {
      if (_nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Nom requis')),
        );
        return;
      }
    }

    await _saveDraft();
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
        title: const Text('Création de Circuit (Wizard Pro)'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Progress indicator
          SizedBox(
            height: 60,
            child: Row(
              children: List.generate(7, (index) {
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

          if (_currentStep == 1 || _currentStep == 2 || _currentStep == 3)
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
                  onPressed: _saveDraft,
                  label: const Text('Sauvegarder'),
                ),
                if (_currentStep < 6)
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
      'Infos',
      'Périmètre',
      'Tracé',
      'Style',
      'POI',
      'Validation',
      'Publication'
    ];
    return labels[step];
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
          TextField(
            controller: _countryController,
            decoration: const InputDecoration(
              labelText: 'Pays *',
              border: OutlineInputBorder(),
            ),
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
      showToolbar: false,
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

  Widget _buildStep4Style() {
    return CircuitMapEditor(
      title: 'Style du tracé (Waze)',
      subtitle: 'Réglez l\'apparence de l\'itinéraire',
      points: _routePoints,
      controller: _routeEditorController,
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
    final isPerimeter = _currentStep == 1;
    final controller = isPerimeter ? _perimeterEditorController : _routeEditorController;

    return Material(
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
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
          onTap: (p) => _onMapTapForPoi(p.lng, p.lat),
          onMapReady: (ctrl) async {
            _refreshPoiMarkers();
          },
        ),

        Positioned(
          left: 12,
          right: 12,
          top: 12,
          child: DecoratedBox(
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
                        onPressed: _selectedLayer == null
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
                  const SizedBox(height: 8),
                  if (_layers.isNotEmpty)
                    DropdownButton<MarketMapLayer>(
                      isExpanded: true,
                      value: _selectedLayer,
                      hint: const Text(
                          'Choisissez une couche pour placer des points'),
                      items: _layers
                          .where((l) => l.type != 'route')
                          .map(
                            (layer) => DropdownMenuItem<MarketMapLayer>(
                              value: layer,
                              child: Row(
                                children: [
                                  Icon(_getLayerIcon(layer.type), size: 18),
                                  const SizedBox(width: 8),
                                  Text(layer.label),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (layer) {
                        setState(() {
                          _selectedLayer = layer;
                        });
                        _refreshPoiMarkers();
                      },
                    )
                  else
                    const Text(
                      'Aucune couche trouvée. Vérifiez la configuration du projet.',
                      style: TextStyle(fontSize: 12, color: Colors.redAccent),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ====== Gestion POI (étape 4) ======

  void _refreshPoiMarkers() async {
    if (_selectedLayer == null) return;

    final layerType = _selectedLayer!.type;
    final poisForLayer = _pois.where((p) => p.layerType == layerType).toList();

    await _poiMapController.setMarkers(
      poisForLayer
          .map(
            (poi) => MapMarker(
              id: poi.id,
              lng: poi.lng,
              lat: poi.lat,
              label: poi.name,
            ),
          )
          .toList(),
    );
  }

  Future<void> _onMapTapForPoi(double lng, double lat) async {
    if (_selectedLayer == null) return;

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
    return CircuitValidationChecklistPage(
      perimeterPoints: _perimeterPoints,
      routePoints: _routePoints,
      name: _nameController.text.trim(),
      country: _countryController.text.trim(),
    );
  }

  Widget _buildStep7Publish() {
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
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Options de publication',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.cloud_upload),
            onPressed: _publishCircuit,
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
            onPressed: _saveDraft,
            label: const Text('Rester en brouillon'),
          ),
        ],
      ),
    );
  }

  Future<void> _publishCircuit() async {
    try {
      setState(() => _isLoading = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      if (_projectId == null) {
        await _saveDraft();
      }

      final projectId = _projectId;
      if (projectId == null) {
        throw Exception('Project not initialized');
      }

      await FirebaseFirestore.instance
          .collection('map_projects')
          .doc(projectId)
          .update({
        'status': 'published',
        'isVisible': true,
        'publishedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

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
