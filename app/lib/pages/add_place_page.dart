import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/mapbox_token_service.dart';
import '../ui/widgets/mapbox_token_dialog.dart';
import '../ui/widgets/mapbox_web_view_platform.dart';

/// AddPlacePage (Mapbox-only)
/// Page pour ajouter un POI en tapant sur la carte
/// - Web : Mapbox GL JS (tap via JS interop - TODO)
/// - Mobile : MapWidget avec tap gesture
class AddPlacePage extends StatefulWidget {
  const AddPlacePage({super.key});

  @override
  State<AddPlacePage> createState() => _AddPlacePageState();
}

class _AddPlacePageState extends State<AddPlacePage> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  
  ({double lat, double lng})? _selectedPoint;
  String _selectedType = 'ville';
  bool _saving = false;

  // Mapbox token
  String _runtimeMapboxToken = '';
  String get _effectiveMapboxToken =>
      _runtimeMapboxToken.isNotEmpty
          ? _runtimeMapboxToken
          : MapboxTokenService.getTokenSync();

  // Web: rebuild pour recentrer après sélection
  final int _webRebuildTick = 0;

  // Mobile
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointManager;

  final List<Map<String, dynamic>> _types = [
    {'id': 'ville', 'label': 'Ville', 'icon': Icons.location_city, 'color': Colors.blue},
    {'id': 'visiter', 'label': 'À Visiter', 'icon': Icons.attractions, 'color': Colors.purple},
    {'id': 'food', 'label': 'Food', 'icon': Icons.restaurant, 'color': Colors.orange},
    {'id': 'shopping', 'label': 'Shopping', 'icon': Icons.shopping_bag, 'color': Colors.pink},
    {'id': 'hotel', 'label': 'Hébergement', 'icon': Icons.hotel, 'color': Colors.teal},
    {'id': 'plage', 'label': 'Plage', 'icon': Icons.beach_access, 'color': Colors.cyan},
    {'id': 'culture', 'label': 'Culture', 'icon': Icons.museum, 'color': Colors.amber},
    {'id': 'sport', 'label': 'Sport', 'icon': Icons.sports_soccer, 'color': Colors.green},
  ];

  @override
  void initState() {
    super.initState();
    _loadRuntimeMapboxToken();
    if (!kIsWeb && _effectiveMapboxToken.isNotEmpty) {
      MapboxOptions.setAccessToken(_effectiveMapboxToken);
    }
  }

  Future<void> _loadRuntimeMapboxToken() async {
    try {
      final info = await MapboxTokenService.getTokenInfo();
      if (!mounted) return;
      setState(() {
        _runtimeMapboxToken = info.token;
      });
      if (!kIsWeb && _runtimeMapboxToken.isNotEmpty) {
        MapboxOptions.setAccessToken(_runtimeMapboxToken);
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _configureMapboxToken() async {
    final newToken = await MapboxTokenDialog.show(
      context,
      initialValue: _effectiveMapboxToken,
    );
    if (!mounted || newToken == null) return;
    setState(() {
      _runtimeMapboxToken = newToken.trim();
    });
    if (!kIsWeb && _runtimeMapboxToken.isNotEmpty) {
      MapboxOptions.setAccessToken(_runtimeMapboxToken);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _onMapTapNative(ScreenCoordinate screenCoord) async {
    final map = _mapboxMap;
    if (map == null) return;

    try {
      final geoCoord = await map.coordinateForPixel(screenCoord);
      if (!mounted) return;
      setState(() {
        _selectedPoint = (
          lat: geoCoord.coordinates.lat.toDouble(),
          lng: geoCoord.coordinates.lng.toDouble(),
        );
      });
      _scheduleNativeAnnotationsSync();
    } catch (_) {
      // ignore
    }
  }

  void _scheduleNativeAnnotationsSync() {
    if (kIsWeb) return;
    if (_mapboxMap == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ensurePointManager();
      await _syncNativeAnnotations();
    });
  }

  Future<void> _ensurePointManager() async {
    if (_mapboxMap == null) return;
    _pointManager ??= await _mapboxMap!.annotations.createPointAnnotationManager();
  }

  Future<void> _syncNativeAnnotations() async {
    final pm = _pointManager;
    if (pm == null) return;

    try {
      await pm.deleteAll();
    } catch (_) {
      // ignore
    }

    final point = _selectedPoint;
    if (point == null) return;

    // Afficher le marker
    final opt = PointAnnotationOptions(
      geometry: Point(coordinates: Position(point.lng, point.lat)),
      iconImage: 'marker-15',
      iconSize: 2.0,
      textField: _nameController.text.isNotEmpty ? _nameController.text : 'Nouveau lieu',
      textOffset: const [0.0, 1.2],
      textSize: 12.0,
      textColor: 0xFF111111,
      textHaloColor: 0xFFFFFFFF,
      textHaloWidth: 1.0,
    );
    await pm.create(opt);
  }

  Future<void> _savePlace() async {
    if (_selectedPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une position sur la carte')),
      );
      return;
    }

    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nom du lieu requis')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final placeData = {
        'name': _nameController.text,
        'description': _descriptionController.text,
        'address': _addressController.text,
        'type': _selectedType,
        'lat': _selectedPoint!.lat,
        'lng': _selectedPoint!.lng,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('places')
          .add(placeData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Lieu enregistré')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erreur: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter un lieu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.key_rounded),
            onPressed: _configureMapboxToken,
            tooltip: 'Configurer Mapbox Token',
          ),
        ],
      ),
      body: Column(
        children: [
          // Carte
          Expanded(
            flex: 2,
            child: _buildMap(),
          ),

          // Formulaire
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ListView(
                children: [
                  if (_selectedPoint != null) ...[
                    Text(
                      'Position: ${_selectedPoint!.lat.toStringAsFixed(5)}, ${_selectedPoint!.lng.toStringAsFixed(5)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    const Text(
                      '📍 Tapez sur la carte pour sélectionner une position',
                      style: TextStyle(fontSize: 14, color: Colors.orange),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Type de lieu
                  const Text(
                    'Catégorie',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _types.map((type) {
                      final selected = _selectedType == type['id'];
                      return ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              type['icon'] as IconData,
                              size: 16,
                              color: selected ? Colors.white : type['color'] as Color,
                            ),
                            const SizedBox(width: 4),
                            Text(type['label'] as String),
                          ],
                        ),
                        selected: selected,
                        selectedColor: type['color'] as Color,
                        onSelected: (val) {
                          if (val) {
                            setState(() => _selectedType = type['id'] as String);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Nom
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom du lieu *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.label),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Adresse
                  TextField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Adresse',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Description
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.notes),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  // Bouton Enregistrer
                  FilledButton.icon(
                    onPressed: _saving ? null : _savePlace,
                    icon: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(_saving ? 'Enregistrement...' : 'Enregistrer le lieu'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final token = _effectiveMapboxToken.trim();
    if (token.isEmpty) {
      return _TokenMissingOverlay(onConfigure: _configureMapboxToken);
    }

    final center = _selectedPoint ?? (lat: 16.241, lng: -61.533);

    if (kIsWeb) {
      return MapboxWebView(
        key: ValueKey('add-place-web-$_webRebuildTick'),
        accessToken: token,
        initialLat: center.lat,
        initialLng: center.lng,
        initialZoom: 13.0,
        initialPitch: 0.0,
        initialBearing: 0.0,
        styleUrl: 'mapbox://styles/mapbox/streets-v12',
        showUserLocation: false,
        onMapReady: () {
          // TODO: implémenter click handler via JS interop
          // Pour l'instant, utiliser mobile pour sélectionner des points
        },
      );
    }

    // Mobile natif
    final initialCamera = CameraOptions(
      center: Point(coordinates: Position(center.lng, center.lat)),
      zoom: 13.0,
      pitch: 0.0,
      bearing: 0.0,
    );

    return GestureDetector(
      onTapUp: (details) {
        final screenCoord = ScreenCoordinate(
          x: details.localPosition.dx,
          y: details.localPosition.dy,
        );
        _onMapTapNative(screenCoord);
      },
      child: MapWidget(
        key: const ValueKey('add-place-native'),
        cameraOptions: initialCamera,
        styleUri: 'mapbox://styles/mapbox/streets-v12',
        onMapCreated: (map) async {
          _mapboxMap = map;
          await _ensurePointManager();
          await _syncNativeAnnotations();
        },
      ),
    );
  }
}

class _TokenMissingOverlay extends StatelessWidget {
  final VoidCallback onConfigure;
  const _TokenMissingOverlay({required this.onConfigure});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.map_rounded, size: 42),
                  const SizedBox(height: 12),
                  const Text(
                    'Mapbox inactif: token manquant',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Configure MAPBOX_ACCESS_TOKEN pour afficher la carte.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: onConfigure,
                    icon: const Icon(Icons.key_rounded),
                    label: const Text('Configurer'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
