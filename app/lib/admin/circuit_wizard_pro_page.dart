import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/market_circuit_models.dart';
import '../ui/map/maslive_map.dart';
import '../ui/map/maslive_map_controller.dart';
import 'circuit_map_editor.dart';
import 'circuit_validation_checklist_page.dart';

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

  // Données Steps 2-3: Cartes
  List<LngLat> _perimeterPoints = [];
  List<LngLat> _routePoints = [];

  // Step 4: Layers/POI
  List<MarketMapLayer> _layers = [];
  List<MarketMapPOI> _pois = [];
  MarketMapLayer? _selectedLayer;
  final MasLiveMapController _poiMapController = MasLiveMapController();

  // Brouillon
  Map<String, dynamic> _draftData = {};

  @override
  void initState() {
    super.initState();
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
      if (widget.projectId != null) {
        final doc = await FirebaseFirestore.instance
            .collection('map_projects')
            .doc(widget.projectId)
            .get();

        if (doc.exists) {
          _draftData = doc.data() ?? {};
          _nameController.text = _draftData['name'] ?? '';
          _countryController.text = _draftData['countryId'] ?? '';
          _eventController.text = _draftData['eventId'] ?? '';
          _descriptionController.text = _draftData['description'] ?? '';
          _styleUrlController.text = _draftData['styleUrl'] ?? '';

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
        _errorMessage = 'Erreur chargement: $e';
        _isLoading = false;
      });
    }
  }

  Future<List<MarketMapLayer>> _loadLayers() async {
    if (widget.projectId == null) {
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
          label: 'Restauration',
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
        .doc(widget.projectId)
        .collection('layers')
        .orderBy('zIndex')
        .get();

    return snapshot.docs
        .map((doc) => MarketMapLayer.fromFirestore(doc))
        .toList();
  }

  Future<List<MarketMapPOI>> _loadPois() async {
    if (widget.projectId == null) {
      return [];
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('map_projects')
        .doc(widget.projectId)
        .collection('pois')
        .get();

    return snapshot.docs
        .map((doc) => MarketMapPOI.fromFirestore(doc))
        .toList();
  }

  Future<void> _saveDraft() async {
    try {
      final projectId = widget.projectId ??
          FirebaseFirestore.instance.collection('map_projects').doc().id;
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

      await FirebaseFirestore.instance
          .collection('map_projects')
          .doc(projectId)
          .set({
        'name': _nameController.text.trim(),
        'countryId': _countryController.text.trim(),
        'eventId': _eventController.text.trim(),
        'description': _descriptionController.text.trim(),
        'styleUrl': _styleUrlController.text.trim(),
        'perimeter': _perimeterPoints
            .map((p) => {'lng': p.lng, 'lat': p.lat})
            .toList(),
        'route': _routePoints.map((p) => {'lng': p.lng, 'lat': p.lat}).toList(),
        'status': 'draft',
        'uid': uid,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': _draftData.isEmpty ? FieldValue.serverTimestamp() : null,
      }, SetOptions(merge: true));

      // Sauvegarder les POI si un projet est défini
      if (widget.projectId != null) {
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
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Brouillon sauvegardé')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e')),
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
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 6,
              itemBuilder: (context, index) {
                return Expanded(
                  child: GestureDetector(
                    onTap: index <= _currentStep ? () => _pageController.jumpToPage(index) : null,
                    child: _StepIndicator(
                      step: index,
                      label: _getStepLabel(index),
                      isActive: index == _currentStep,
                      isCompleted: index < _currentStep,
                      isEnabled: index <= _currentStep,
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),

          if (_currentStep == 1 || _currentStep == 2) _buildCentralMapToolsBar(),

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
                _buildStep4POI(),
                _buildStep5Validation(),
                _buildStep6Publish(),
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
                if (_currentStep < 5)
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
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStep4POI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header + sélection de couche
        Container(
          color: Colors.grey.shade100,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.place_outlined, color: Colors.blueGrey),
              const SizedBox(width: 8),
              const Text(
                'Points d\'intérêt (POI)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 16),
              if (_layers.isNotEmpty)
                Expanded(
                  child: DropdownButton<MarketMapLayer>(
                    isExpanded: true,
                    value: _selectedLayer,
                    hint: const Text('Sélectionnez une couche'),
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
                  ),
                )
              else
                const Expanded(
                  child: Text(
                    'Aucune couche trouvée. Vérifiez la configuration du projet.',
                    style: TextStyle(fontSize: 12, color: Colors.redAccent),
                  ),
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.my_location),
                tooltip: 'Ajouter un POI à la position actuelle',
                onPressed: _selectedLayer == null ? null : _addPoiAtCurrentCenter,
              ),
              IconButton(
                icon: const Icon(Icons.save_alt),
                tooltip: 'Enregistrer les POI',
                onPressed: widget.projectId == null ? null : _saveDraft,
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Carte pleine largeur/hauteur disponible
        Expanded(
          child: MasLiveMap(
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
              // Afficher les POI existants
              _refreshPoiMarkers();
            },
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

  Widget _buildStep5Validation() {
    return CircuitValidationChecklistPage(
      perimeterPoints: _perimeterPoints,
      routePoints: _routePoints,
      name: _nameController.text.trim(),
      country: _countryController.text.trim(),
    );
  }

  Widget _buildStep6Publish() {
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

      final projectId = widget.projectId ??
          FirebaseFirestore.instance.collection('map_projects').doc().id;

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur publication: $e')),
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
