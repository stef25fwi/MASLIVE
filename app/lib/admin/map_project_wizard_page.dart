import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../ui/map/maslive_map.dart';
import '../ui/map/maslive_map_controller.dart';
import '../models/market_circuit.dart';
import '../services/market_map_service.dart';

class MapProjectWizardPage extends StatefulWidget {
  final String projectId;

  const MapProjectWizardPage({super.key, required this.projectId});

  @override
  State<MapProjectWizardPage> createState() => _MapProjectWizardPageState();
}

class _MapProjectWizardPageState extends State<MapProjectWizardPage> {
  int _currentStep = 0;
  bool _loading = true;

  final _nameController = TextEditingController();
  final _countryController = TextEditingController();
  final _eventController = TextEditingController();
  final _styleUrlController = TextEditingController();

  final MasLiveMapController _mapController = MasLiveMapController();
  List<Map<String, double>> _perimeterPoints = [];
  List<Map<String, double>> _routePoints = [];
  bool _isEditingPerimeter = false;
  bool _isEditingRoute = false;

  final MarketMapService _marketMapService = MarketMapService();

  @override
  void initState() {
    super.initState();
    _loadProject();
  }

  Future<void> _loadProject() async {
    final doc = await FirebaseFirestore.instance
        .collection('map_projects')
        .doc(widget.projectId)
        .get();

    if (!doc.exists) {
      setState(() => _loading = false);
      return;
    }

    setState(() {
      _nameController.text = doc.get('name') ?? '';
      _countryController.text = doc.get('countryId') ?? '';
      _eventController.text = doc.get('eventId') ?? '';
      _styleUrlController.text = doc.get('styleUrl') ?? '';

      final perimeter = doc.get('perimeter') as List<dynamic>?;
      if (perimeter != null) {
        _perimeterPoints = perimeter
            .map((p) => {
                  'lng': (p as Map<String, dynamic>)['lng'] as double,
                  'lat': p['lat'] as double,
                })
            .toList();
      }

      final route = doc.get('route') as List<dynamic>?;
      if (route != null) {
        _routePoints = route
            .map((p) => {
                  'lng': (p as Map<String, dynamic>)['lng'] as double,
                  'lat': p['lat'] as double,
                })
            .toList();
      }

      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _countryController.dispose();
    _eventController.dispose();
    _styleUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveBasicInfo() async {
    await FirebaseFirestore.instance
        .collection('map_projects')
        .doc(widget.projectId)
        .update({
      'name': _nameController.text.trim(),
      'countryId': _countryController.text.trim(),
      'eventId': _eventController.text.trim(),
      'styleUrl': _styleUrlController.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informations sauvegardées')),
      );
    }
  }

  Future<void> _savePerimeter() async {
    await FirebaseFirestore.instance
        .collection('map_projects')
        .doc(widget.projectId)
        .update({
      'perimeter': _perimeterPoints,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Périmètre sauvegardé')),
      );
    }
  }

  Future<void> _saveRoute() async {
    await FirebaseFirestore.instance
        .collection('map_projects')
        .doc(widget.projectId)
        .update({
      'route': _routePoints,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Circuit sauvegardé')),
      );
    }
  }

  void _togglePerimeterEditing() {
    setState(() {
      _isEditingPerimeter = !_isEditingPerimeter;
      _mapController.setEditingEnabled(enabled: _isEditingPerimeter);
    });
  }

  void _toggleRouteEditing() {
    setState(() {
      _isEditingRoute = !_isEditingRoute;
      _mapController.setEditingEnabled(enabled: _isEditingRoute);
    });
  }

  void _addPerimeterPoint(double lng, double lat) {
    setState(() {
      _perimeterPoints.add({'lng': lng, 'lat': lat});
      _updatePerimeterDisplay();
    });
  }

  void _addRoutePoint(double lng, double lat) {
    setState(() {
      _routePoints.add({'lng': lng, 'lat': lat});
      _updateRouteDisplay();
    });
  }

  void _updatePerimeterDisplay() {
    if (_perimeterPoints.length >= 3) {
      final points = _perimeterPoints
          .map((p) => MapPoint(p['lng']!, p['lat']!))
          .toList();
      _mapController.setPolygon(
        points: points,
        fillColor: const Color(0x409B6BFF),
        strokeColor: const Color(0xFF9B6BFF),
        strokeWidth: 2.0,
        show: true,
      );
    }
  }

  void _updateRouteDisplay() {
    if (_routePoints.length >= 2) {
      final points = _routePoints
          .map((p) => MapPoint(p['lng']!, p['lat']!))
          .toList();
      _mapController.setPolyline(
        points: points,
        color: const Color(0xFFFF7AAE),
        width: 3.0,
        show: true,
      );
    }
  }

  void _clearPerimeter() {
    setState(() {
      _perimeterPoints.clear();
      _mapController.clearAll();
    });
  }

  void _clearRoute() {
    setState(() {
      _routePoints.clear();
      _mapController.clearAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chargement...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Wizard: ${_nameController.text.isNotEmpty ? _nameController.text : widget.projectId}'),
        backgroundColor: const Color(0xFF1A1A2E),
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepTapped: (step) => setState(() => _currentStep = step),
        onStepContinue: () {
          if (_currentStep < 4) {
            setState(() => _currentStep += 1);
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep -= 1);
          }
        },
        steps: [
          _buildBasicInfoStep(),
          _buildPerimeterStep(),
          _buildRouteStep(),
          _buildLayersStep(),
          _buildPublishStep(),
        ],
      ),
    );
  }

  Step _buildBasicInfoStep() {
    return Step(
      title: const Text('Informations de base'),
      isActive: _currentStep >= 0,
      state: _currentStep > 0 ? StepState.complete : StepState.indexed,
      content: Column(
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nom du projet',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _countryController,
            decoration: const InputDecoration(
              labelText: 'Country ID',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _eventController,
            decoration: const InputDecoration(
              labelText: 'Event ID',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _styleUrlController,
            decoration: const InputDecoration(
              labelText: 'Style URL (Mapbox)',
              border: OutlineInputBorder(),
              hintText: 'mapbox://styles/username/style-id',
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saveBasicInfo,
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }

  Step _buildPerimeterStep() {
    return Step(
      title: const Text('Périmètre (Polygon)'),
      isActive: _currentStep >= 1,
      state: _currentStep > 1 ? StepState.complete : StepState.indexed,
      content: Column(
        children: [
          SizedBox(
            height: 400,
            child: Stack(
              children: [
                MasLiveMap(
                  controller: _mapController,
                  initialLng: _perimeterPoints.isNotEmpty
                      ? _perimeterPoints.first['lng']!
                      : -61.533,
                  initialLat: _perimeterPoints.isNotEmpty
                      ? _perimeterPoints.first['lat']!
                      : 16.241,
                  initialZoom: 12.0,
                  onMapReady: (ctrl) {
                    if (_perimeterPoints.isNotEmpty) {
                      _updatePerimeterDisplay();
                    }
                  },
                  onTap: (point) {
                    if (_isEditingPerimeter) {
                      _addPerimeterPoint(point.lng, point.lat);
                    }
                  },
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Column(
                    children: [
                      FloatingActionButton(
                        heroTag: 'edit_perimeter',
                        mini: true,
                        backgroundColor: _isEditingPerimeter
                            ? Colors.red
                            : const Color(0xFF9B6BFF),
                        onPressed: _togglePerimeterEditing,
                        child: Icon(_isEditingPerimeter ? Icons.close : Icons.edit),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        heroTag: 'clear_perimeter',
                        mini: true,
                        backgroundColor: Colors.orange,
                        onPressed: _clearPerimeter,
                        child: const Icon(Icons.delete),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Points: ${_perimeterPoints.length}'),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _savePerimeter,
            child: const Text('Sauvegarder le périmètre'),
          ),
        ],
      ),
    );
  }

  Step _buildRouteStep() {
    return Step(
      title: const Text('Circuit / Route (Polyline)'),
      isActive: _currentStep >= 2,
      state: _currentStep > 2 ? StepState.complete : StepState.indexed,
      content: Column(
        children: [
          SizedBox(
            height: 400,
            child: Stack(
              children: [
                MasLiveMap(
                  controller: _mapController,
                  initialLng: _routePoints.isNotEmpty
                      ? _routePoints.first['lng']!
                      : -61.533,
                  initialLat: _routePoints.isNotEmpty
                      ? _routePoints.first['lat']!
                      : 16.241,
                  initialZoom: 12.0,
                  onMapReady: (ctrl) {
                    if (_routePoints.isNotEmpty) {
                      _updateRouteDisplay();
                    }
                  },
                  onTap: (point) {
                    if (_isEditingRoute) {
                      _addRoutePoint(point.lng, point.lat);
                    }
                  },
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Column(
                    children: [
                      FloatingActionButton(
                        heroTag: 'edit_route',
                        mini: true,
                        backgroundColor: _isEditingRoute
                            ? Colors.red
                            : const Color(0xFF9B6BFF),
                        onPressed: _toggleRouteEditing,
                        child: Icon(_isEditingRoute ? Icons.close : Icons.edit),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        heroTag: 'clear_route',
                        mini: true,
                        backgroundColor: Colors.orange,
                        onPressed: _clearRoute,
                        child: const Icon(Icons.delete),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Points: ${_routePoints.length}'),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _saveRoute,
            child: const Text('Sauvegarder le circuit'),
          ),
        ],
      ),
    );
  }

  Step _buildLayersStep() {
    return Step(
      title: const Text('Gestion des Layers'),
      isActive: _currentStep >= 3,
      state: _currentStep > 3 ? StepState.complete : StepState.indexed,
      content: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('map_projects')
            .doc(widget.projectId)
            .collection('layers')
            .orderBy('zIndex')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final layers = snapshot.data!.docs;

          return Column(
            children: [
              const Text(
                'Les 6 layers ont été créés automatiquement lors de la création du projet.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 16),
              ...layers.map((doc) {
                final type = doc.get('type') as String;
                final label = doc.get('label') as String;
                final isVisible = doc.get('isVisible') as bool? ?? true;

                return Card(
                  child: ListTile(
                    leading: Icon(
                      _getLayerIcon(type),
                      color: isVisible ? const Color(0xFF9B6BFF) : Colors.grey,
                    ),
                    title: Text(label),
                    subtitle: Text('Type: $type'),
                    trailing: Switch(
                      value: isVisible,
                      onChanged: (value) async {
                        await doc.reference.update({'isVisible': value});
                      },
                    ),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Edition points: TODO prochaine phase'),
                        ),
                      );
                    },
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Step _buildPublishStep() {
    return Step(
      title: const Text('Publication'),
      isActive: _currentStep >= 4,
      state: _currentStep == 4 ? StepState.indexed : StepState.complete,
      content: Column(
        children: [
          const Text(
            'Prêt à publier votre projet ?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('map_projects')
                .doc(widget.projectId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const CircularProgressIndicator();
              }

              final data = snapshot.data!;
              final status = data.get('status') as String? ?? 'draft';
              final isVisible = data.get('isVisible') as bool? ?? false;
              final countryId = data.get('countryId') as String? ?? '';
              final eventId = data.get('eventId') as String? ?? '';
              final linkedCircuitId = data.data() is Map<String, dynamic>
                  ? ((data.data() as Map<String, dynamic>)['linkedCircuitId']
                          as String?) ??
                      ''
                  : '';

              return Column(
                children: [
                  Text('Statut actuel: $status'),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Circuit MarketMap lié (menu "Carte")',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildLinkedCircuitSelector(
                    countryId: countryId,
                    eventId: eventId,
                    linkedCircuitId: linkedCircuitId,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Visible publiquement'),
                    value: isVisible,
                    onChanged: (value) async {
                      await FirebaseFirestore.instance
                          .collection('map_projects')
                          .doc(widget.projectId)
                          .update({'isVisible': value});

                      await _syncLinkedCircuitVisibility(
                        countryId: countryId,
                        eventId: eventId,
                        linkedCircuitId: linkedCircuitId,
                        isVisible: value,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9B6BFF),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                    ),
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('map_projects')
                          .doc(widget.projectId)
                          .update({
                        'status': 'published',
                        'isVisible': true,
                        'publishedAt': FieldValue.serverTimestamp(),
                        'publishAt': FieldValue.serverTimestamp(),
                        'updatedAt': FieldValue.serverTimestamp(),
                      });

                      await _syncLinkedCircuitVisibility(
                        countryId: countryId,
                        eventId: eventId,
                        linkedCircuitId: linkedCircuitId,
                        isVisible: true,
                      );

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Projet publié avec succès !')),
                        );
                        Navigator.pop(context);
                      }
                    },
                    child: const Text(
                      'PUBLIER LE PROJET',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedCircuitSelector({
    required String countryId,
    required String eventId,
    required String linkedCircuitId,
  }) {
    if (countryId.isEmpty || eventId.isEmpty) {
      return const Text(
        'Renseigne d\'abord Country ID et Event ID pour lier un circuit MarketMap.',
        style: TextStyle(fontSize: 12),
      );
    }

    return StreamBuilder<List<MarketCircuit>>(
      stream: _marketMapService.watchCircuits(
        countryId: countryId,
        eventId: eventId,
      ),
      builder: (context, snap) {
        if (snap.hasError) {
          return Text('Erreur circuits MarketMap: ${snap.error}');
        }
        if (!snap.hasData) {
          return const SizedBox(
            height: 40,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final circuits = snap.data!;
        if (circuits.isEmpty) {
          return const Text(
            'Aucun circuit MarketMap pour ce countryId/eventId.',
            style: TextStyle(fontSize: 12),
          );
        }

        final value =
            circuits.any((c) => c.id == linkedCircuitId) ? linkedCircuitId : null;

        return DropdownButtonFormField<String>(
          value: value,
          decoration: const InputDecoration(
            labelText: 'Circuit MarketMap associé',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final c in circuits)
              DropdownMenuItem(
                value: c.id,
                child: Text('${c.name} (${c.status})'),
              ),
          ],
          onChanged: (id) async {
            await FirebaseFirestore.instance
                .collection('map_projects')
                .doc(widget.projectId)
                .update({
              'linkedCircuitId': id,
              'linkedCircuitCountryId': countryId,
              'linkedCircuitEventId': eventId,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          },
        );
      },
    );
  }

  Future<void> _syncLinkedCircuitVisibility({
    required String countryId,
    required String eventId,
    required String linkedCircuitId,
    required bool isVisible,
  }) async {
    if (countryId.isEmpty || eventId.isEmpty || linkedCircuitId.isEmpty) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('marketMap')
          .doc(countryId)
          .collection('events')
          .doc(eventId)
          .collection('circuits')
          .doc(linkedCircuitId)
          .update({'isVisible': isVisible});
    } catch (e) {
      debugPrint('Erreur synchro isVisible circuit MarketMap: $e');
    }
  }

  IconData _getLayerIcon(String type) {
    switch (type) {
      case 'tracking':
        return Icons.my_location;
      case 'visited':
        return Icons.check_circle;
      case 'full':
        return Icons.layers;
      case 'assistance':
        return Icons.help;
      case 'parking':
        return Icons.local_parking;
      case 'wc':
        return Icons.wc;
      default:
        return Icons.map;
    }
  }
}
