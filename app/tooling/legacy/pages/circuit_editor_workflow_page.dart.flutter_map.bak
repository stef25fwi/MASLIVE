import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

enum _EditorMode {
  perimeter,
  circuit,
  poi,
}

class _LayerRow extends StatelessWidget {
  const _LayerRow({
    required this.id,
    required this.label,
    required this.icon,
    required this.activeId,
    required this.visible,
    required this.onSetActive,
    required this.onToggleVisible,
  });

  final String id;
  final String label;
  final IconData icon;
  final String activeId;
  final bool visible;
  final VoidCallback onSetActive;
  final VoidCallback onToggleVisible;

  @override
  Widget build(BuildContext context) {
    final isActive = id == activeId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: onSetActive,
            child: Text(isActive ? 'Actif' : 'Activer'),
          ),
          IconButton(
            tooltip: visible ? 'Masquer' : 'Afficher',
            onPressed: onToggleVisible,
            icon: Icon(visible ? Icons.visibility : Icons.visibility_off),
          ),
        ],
      ),
    );
  }
}

class CircuitEditorWorkflowPage extends StatefulWidget {
  const CircuitEditorWorkflowPage({super.key, this.projectId});

  final String? projectId;

  @override
  State<CircuitEditorWorkflowPage> createState() => _CircuitEditorWorkflowPageState();
}

class _CircuitEditorWorkflowPageState extends State<CircuitEditorWorkflowPage> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();

  final _map = MapController();

  int _step = 0;
  _EditorMode _mode = _EditorMode.perimeter;

  final _yearCtrl = TextEditingController(text: DateTime.now().year.toString());
  final _communeCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();

  String _country = 'guadeloupe';

  // Périmètre (rectangle via 2 taps)
  LatLng? _perimeterCornerA;
  LatLng? _perimeterCornerB;
  bool _perimeterLocked = false;

  // Circuit
  final List<LatLng> _circuitPoints = [];
  bool _circuitLocked = false;
  Color _circuitColor = const Color(0xFFE11D48); // rouge
  double _circuitWidth = 6;
  Color _circuitBorderColor = const Color(0xFF111827);
  double _circuitBorderWidth = 2;

  // POI
  String _layerId = 'visiter';
  bool _showAllPois = false;
  final Set<String> _visiblePoiLayers = {'visiter', 'food', 'assistance', 'parking', 'wc'};
  bool _showCircuit = true;
  bool _showPerimeter = true;

  String? _projectId;
  bool _saving = false;

  static const LatLng _centerGuadeloupe = LatLng(16.241, -61.533);
  static const LatLng _centerMartinique = LatLng(14.6415, -61.0242);

  @override
  void initState() {
    super.initState();
    if (widget.projectId != null && widget.projectId!.isNotEmpty) {
      _projectId = widget.projectId;
      _loadExistingProject(widget.projectId!);
    }
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    _communeCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingProject(String projectId) async {
    setState(() => _saving = true);
    try {
      final snap = await _db.collection('map_projects').doc(projectId).get();
      final data = snap.data();
      if (data == null) return;

      final year = data['year'];
      final country = data['country'];
      final commune = data['commune'];
      final title = data['title'];

      final perimeter = data['perimeter'] as Map<String, dynamic>?;
      final circuit = data['circuit'] as Map<String, dynamic>?;

      final sw = perimeter?['sw'] as Map<String, dynamic>?;
      final ne = perimeter?['ne'] as Map<String, dynamic>?;

      final points = (circuit?['points'] as List?) ?? const [];
      final style = circuit?['style'] as Map<String, dynamic>?;

      setState(() {
        if (year != null) _yearCtrl.text = year.toString();
        if (country is String && (country == 'guadeloupe' || country == 'martinique')) {
          _country = country;
        }
        if (commune is String) _communeCtrl.text = commune;
        if (title is String) _titleCtrl.text = title;

        if (sw != null && ne != null) {
          _perimeterCornerA = LatLng((sw['lat'] as num).toDouble(), (sw['lng'] as num).toDouble());
          _perimeterCornerB = LatLng((ne['lat'] as num).toDouble(), (ne['lng'] as num).toDouble());
          _perimeterLocked = perimeter?['locked'] == true;
        }

        _circuitPoints
          ..clear()
          ..addAll(
            points.map((p) {
              final m = p as Map;
              return LatLng((m['lat'] as num).toDouble(), (m['lng'] as num).toDouble());
            }),
          );
        _circuitLocked = circuit?['locked'] == true;

        if (style != null) {
          final colorValue = style['color'];
          final width = style['width'];
          final borderColorValue = style['borderColor'];
          final borderWidth = style['borderWidth'];
          if (colorValue is int) _circuitColor = Color(colorValue);
          if (width is num) _circuitWidth = width.toDouble();
          if (borderColorValue is int) _circuitBorderColor = Color(borderColorValue);
          if (borderWidth is num) _circuitBorderWidth = borderWidth.toDouble();
        }

        // Ouvre directement l'étape POI si on édite un projet existant
        _step = 3;
        _mode = _EditorMode.poi;
      });

      _map.move(_countryCenter, 11.5);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  LatLng get _countryCenter => _country == 'martinique' ? _centerMartinique : _centerGuadeloupe;

  LatLngBounds? get _bounds {
    final a = _perimeterCornerA;
    final b = _perimeterCornerB;
    if (a == null || b == null) return null;

    final south = a.latitude < b.latitude ? a.latitude : b.latitude;
    final north = a.latitude > b.latitude ? a.latitude : b.latitude;
    final west = a.longitude < b.longitude ? a.longitude : b.longitude;
    final east = a.longitude > b.longitude ? a.longitude : b.longitude;

    return LatLngBounds(LatLng(south, west), LatLng(north, east));
  }

  List<LatLng> _boundsPolygon(LatLngBounds b) {
    final sw = b.southWest;
    final ne = b.northEast;
    final nw = LatLng(ne.latitude, sw.longitude);
    final se = LatLng(sw.latitude, ne.longitude);
    return [sw, nw, ne, se, sw];
  }

  Future<String> _uploadBytes({
    required String path,
    required Uint8List bytes,
  }) async {
    final ref = _storage.ref(path);
    final meta = SettableMetadata(contentType: 'image/jpeg');
    await ref.putData(bytes, meta);
    return ref.getDownloadURL();
  }

  Future<void> _ensureProject() async {
    if (_projectId != null) return;

    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Utilisateur non connecté');
    }

    final year = int.tryParse(_yearCtrl.text.trim());
    if (year == null) {
      throw StateError('Année invalide');
    }

    final commune = _communeCtrl.text.trim();
    if (commune.isEmpty) {
      throw StateError('Commune requise');
    }

    final title = _titleCtrl.text.trim().isEmpty
        ? 'Circuit ${DateTime.now().toIso8601String().substring(0, 10)}'
        : _titleCtrl.text.trim();

    final ref = _db.collection('map_projects').doc();
    _projectId = ref.id;

    await ref.set({
      'title': title,
      'year': year,
      'country': _country,
      'commune': commune,
      'status': 'draft',
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _saveDraft({required bool validate}) async {
    setState(() => _saving = true);
    try {
      await _ensureProject();

      final id = _projectId!;
      final ref = _db.collection('map_projects').doc(id);
      final b = _bounds;

      await ref.set({
        'updatedAt': FieldValue.serverTimestamp(),
        'status': validate ? 'validated' : 'draft',
        'perimeter': b == null
            ? null
            : {
                'sw': {'lat': b.southWest.latitude, 'lng': b.southWest.longitude},
                'ne': {'lat': b.northEast.latitude, 'lng': b.northEast.longitude},
                'locked': _perimeterLocked,
              },
        'circuit': {
          'points': _circuitPoints.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
          'locked': _circuitLocked,
          'style': {
            'color': _circuitColor.value,
            'width': _circuitWidth,
            'borderColor': _circuitBorderColor.value,
            'borderWidth': _circuitBorderWidth,
          },
        },
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validate ? '✅ Circuit validé' : '✅ Brouillon sauvegardé')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _onMapTap(LatLng p) {
    switch (_mode) {
      case _EditorMode.perimeter:
        if (!_showPerimeter) return;
        if (_perimeterLocked) return;
        setState(() {
          if (_perimeterCornerA == null || (_perimeterCornerA != null && _perimeterCornerB != null)) {
            _perimeterCornerA = p;
            _perimeterCornerB = null;
          } else {
            _perimeterCornerB = p;
          }
        });
        return;

      case _EditorMode.circuit:
        if (!_showCircuit) return;
        if (_circuitLocked) return;
        setState(() => _circuitPoints.add(p));
        return;

      case _EditorMode.poi:
        // Si la couche est masquée, on évite d’ajouter “dans le vide”
        if (!_visiblePoiLayers.contains(_layerId)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Couche masquée: active-la pour ajouter des points')),
          );
          return;
        }
        _openPoiEditor(p);
        return;
    }
  }

  Future<void> _openLayersManager() async {
    var tmpShowAll = _showAllPois;
    var tmpActive = _layerId;
    final tmpVisible = Set<String>.from(_visiblePoiLayers);
    var tmpShowCircuit = _showCircuit;
    var tmpShowPerimeter = _showPerimeter;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Couches', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Afficher toutes les couches visibles'),
                    subtitle: const Text('Sinon: affiche uniquement la couche active'),
                    value: tmpShowAll,
                    onChanged: (v) => setModal(() => tmpShowAll = v),
                  ),
                  const Divider(height: 18),
                  const Text('Affichage', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Circuit'),
                    value: tmpShowCircuit,
                    onChanged: (v) => setModal(() => tmpShowCircuit = v),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Périmètre'),
                    value: tmpShowPerimeter,
                    onChanged: (v) => setModal(() => tmpShowPerimeter = v),
                  ),
                  const Divider(height: 18),
                  const Text('POI', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  _LayerRow(
                    id: 'visiter',
                    label: 'Visiter',
                    icon: Icons.attractions,
                    activeId: tmpActive,
                    visible: tmpVisible.contains('visiter'),
                    onSetActive: () => setModal(() => tmpActive = 'visiter'),
                    onToggleVisible: () => setModal(() {
                      if (!tmpVisible.remove('visiter')) tmpVisible.add('visiter');
                    }),
                  ),
                  _LayerRow(
                    id: 'food',
                    label: 'Food',
                    icon: Icons.restaurant,
                    activeId: tmpActive,
                    visible: tmpVisible.contains('food'),
                    onSetActive: () => setModal(() => tmpActive = 'food'),
                    onToggleVisible: () => setModal(() {
                      if (!tmpVisible.remove('food')) tmpVisible.add('food');
                    }),
                  ),
                  _LayerRow(
                    id: 'assistance',
                    label: 'Assistance',
                    icon: Icons.support_agent,
                    activeId: tmpActive,
                    visible: tmpVisible.contains('assistance'),
                    onSetActive: () => setModal(() => tmpActive = 'assistance'),
                    onToggleVisible: () => setModal(() {
                      if (!tmpVisible.remove('assistance')) tmpVisible.add('assistance');
                    }),
                  ),
                  _LayerRow(
                    id: 'parking',
                    label: 'Parking',
                    icon: Icons.local_parking,
                    activeId: tmpActive,
                    visible: tmpVisible.contains('parking'),
                    onSetActive: () => setModal(() => tmpActive = 'parking'),
                    onToggleVisible: () => setModal(() {
                      if (!tmpVisible.remove('parking')) tmpVisible.add('parking');
                    }),
                  ),
                  _LayerRow(
                    id: 'wc',
                    label: 'WC',
                    icon: Icons.wc,
                    activeId: tmpActive,
                    visible: tmpVisible.contains('wc'),
                    onSetActive: () => setModal(() => tmpActive = 'wc'),
                    onToggleVisible: () => setModal(() {
                      if (!tmpVisible.remove('wc')) tmpVisible.add('wc');
                    }),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Fermer'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            setState(() {
                              _showAllPois = tmpShowAll;
                              _layerId = tmpActive;
                              _visiblePoiLayers
                                ..clear()
                                ..addAll(tmpVisible);
                              _showCircuit = tmpShowCircuit;
                              _showPerimeter = tmpShowPerimeter;
                            });
                            Navigator.pop(ctx);
                          },
                          child: const Text('Appliquer'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openPoiList() async {
    final projectId = _projectId;
    if (projectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoute un premier POI ou sauvegarde le projet pour voir la liste.')),
      );
      return;
    }

    String q = '';

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _showAllPois ? 'POI (toutes couches visibles)' : 'POI (${_layerId.toUpperCase()})',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Rechercher',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setModal(() => q = v.trim().toLowerCase()),
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _db.collection('map_projects').doc(projectId).collection('pois').snapshots(),
                    builder: (context, snap) {
                      final docs = snap.data?.docs ?? const [];
                      final filtered = docs.where((d) {
                        final data = d.data();
                        final layerId = (data['layerId'] as String?) ?? '';
                        if (!_visiblePoiLayers.contains(layerId)) return false;
                        if (!_showAllPois && layerId != _layerId) return false;
                        if (q.isEmpty) return true;
                        final name = ((data['name'] as String?) ?? '').toLowerCase();
                        final desc = ((data['description'] as String?) ?? '').toLowerCase();
                        return name.contains(q) || desc.contains(q) || layerId.contains(q);
                      }).toList();

                      filtered.sort((a, b) {
                        final an = ((a.data()['name'] as String?) ?? '').toLowerCase();
                        final bn = ((b.data()['name'] as String?) ?? '').toLowerCase();
                        return an.compareTo(bn);
                      });

                      if (filtered.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Center(child: Text('Aucun POI.')),
                        );
                      }

                      return ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 420),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final d = filtered[i];
                            final data = d.data();
                            final name = (data['name'] as String?) ?? 'Point';
                            final layerId = (data['layerId'] as String?) ?? '';
                            final lat = (data['lat'] as num?)?.toDouble();
                            final lng = (data['lng'] as num?)?.toDouble();

                            IconData icon = Icons.place;
                            if (layerId == 'food') icon = Icons.restaurant;
                            if (layerId == 'visiter') icon = Icons.attractions;
                            if (layerId == 'assistance') icon = Icons.support_agent;
                            if (layerId == 'wc') icon = Icons.wc;
                            if (layerId == 'parking') icon = Icons.local_parking;

                            return ListTile(
                              leading: Icon(icon),
                              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(layerId, maxLines: 1, overflow: TextOverflow.ellipsis),
                              trailing: const Icon(Icons.edit_outlined),
                              onTap: () async {
                                Navigator.pop(ctx);
                                if (lat != null && lng != null) {
                                  _map.move(LatLng(lat, lng), 15.5);
                                }
                                await _openPoiEditorExisting(poiId: d.id, data: data);
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openCircuitStyle() async {
    Color tmpColor = _circuitColor;
    double tmpWidth = _circuitWidth;
    Color tmpBorderColor = _circuitBorderColor;
    double tmpBorderWidth = _circuitBorderWidth;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Habillage circuit', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 12),
                  const Text('Couleur', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      const Color(0xFFE11D48),
                      const Color(0xFF1A73E8),
                      const Color(0xFF34A853),
                      const Color(0xFF111827),
                      const Color(0xFFF59E0B),
                    ].map((c) {
                      final selected = tmpColor.value == c.value;
                      return InkWell(
                        onTap: () => setModal(() => tmpColor = c),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(color: selected ? Colors.white : Colors.black12, width: selected ? 3 : 1),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 4)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  const Text('Épaisseur', style: TextStyle(fontWeight: FontWeight.w800)),
                  Slider(
                    value: tmpWidth,
                    min: 3,
                    max: 14,
                    divisions: 11,
                    label: tmpWidth.toStringAsFixed(0),
                    onChanged: (v) => setModal(() => tmpWidth = v),
                  ),
                  const SizedBox(height: 10),
                  const Text('Bordure (lisibilité)', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      const Color(0xFF111827),
                      Colors.white,
                      const Color(0xFF000000),
                      const Color(0xFF1A73E8),
                    ].map((c) {
                      final selected = tmpBorderColor.value == c.value;
                      return InkWell(
                        onTap: () => setModal(() => tmpBorderColor = c),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected ? Colors.white : Colors.black12,
                              width: selected ? 3 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  Slider(
                    value: tmpBorderWidth,
                    min: 0,
                    max: 6,
                    divisions: 12,
                    label: tmpBorderWidth.toStringAsFixed(1),
                    onChanged: (v) => setModal(() => tmpBorderWidth = v),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Annuler'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            setState(() {
                              _circuitColor = tmpColor;
                              _circuitWidth = tmpWidth;
                              _circuitBorderColor = tmpBorderColor;
                              _circuitBorderWidth = tmpBorderWidth;
                            });
                            Navigator.pop(ctx);
                          },
                          child: const Text('Appliquer'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openPoiEditorExisting({
    required String poiId,
    required Map<String, dynamic> data,
  }) async {
    final nameCtrl = TextEditingController(text: (data['name'] as String?) ?? '');
    final descCtrl = TextEditingController(text: (data['description'] as String?) ?? '');

    final initialLayerId = (data['layerId'] as String?) ?? _layerId;
    String tmpLayerId = initialLayerId;
    Uint8List? newPhoto;

    Future<void> pick(ImageSource source) async {
      final x = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 1800);
      if (x == null) return;
      newPhoto = await x.readAsBytes();
    }

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Éditer point', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: tmpLayerId,
                    decoration: const InputDecoration(labelText: 'Couche', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'visiter', child: Text('Visiter')),
                      DropdownMenuItem(value: 'food', child: Text('Food')),
                      DropdownMenuItem(value: 'assistance', child: Text('Assistance')),
                      DropdownMenuItem(value: 'parking', child: Text('Parking')),
                      DropdownMenuItem(value: 'wc', child: Text('WC')),
                    ],
                    onChanged: (v) => setModal(() => tmpLayerId = v ?? tmpLayerId),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nom *', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descCtrl,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await pick(ImageSource.camera);
                            setModal(() {});
                          },
                          icon: const Icon(Icons.photo_camera),
                          label: const Text('Caméra'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await pick(ImageSource.gallery);
                            setModal(() {});
                          },
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Galerie'),
                        ),
                      ),
                    ],
                  ),
                  if (newPhoto != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(newPhoto!, height: 140, width: double.infinity, fit: BoxFit.cover),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(ctx, 'delete'),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Supprimer'),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx, 'save'),
                          child: const Text('Enregistrer'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (action == null) return;
    if (_projectId == null) return;

    final name = nameCtrl.text.trim();
    if (action == 'save' && name.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nom requis')));
      return;
    }

    setState(() => _saving = true);
    try {
      final projectId = _projectId!;
      final poiRef = _db.collection('map_projects').doc(projectId).collection('pois').doc(poiId);

      if (action == 'delete') {
        await poiRef.delete();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🗑️ Point supprimé')));
        return;
      }

      String? imageUrl = data['imageUrl'] as String?;
      if (newPhoto != null) {
        imageUrl = await _uploadBytes(
          path: 'map_projects/$projectId/pois/$poiId.jpg',
          bytes: newPhoto!,
        );
      }

      await poiRef.set({
        'name': name,
        'description': descCtrl.text.trim(),
        'layerId': tmpLayerId,
        'imageUrl': imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Point mis à jour')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openPoiEditor(LatLng p) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    Uint8List? photo;

    Future<void> pick(ImageSource source) async {
      final x = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 1800);
      if (x == null) return;
      photo = await x.readAsBytes();
    }

    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Créer un point (${_layerId.toUpperCase()})', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _layerId,
                    decoration: const InputDecoration(labelText: 'Couche', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'visiter', child: Text('Visiter')),
                      DropdownMenuItem(value: 'food', child: Text('Food')),
                      DropdownMenuItem(value: 'assistance', child: Text('Assistance')),
                      DropdownMenuItem(value: 'parking', child: Text('Parking')),
                      DropdownMenuItem(value: 'wc', child: Text('WC')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _layerId = v);
                      setModal(() {});
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nom *', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descCtrl,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await pick(ImageSource.camera);
                            setModal(() {});
                          },
                          icon: const Icon(Icons.photo_camera),
                          label: const Text('Caméra'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await pick(ImageSource.gallery);
                            setModal(() {});
                          },
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Galerie'),
                        ),
                      ),
                    ],
                  ),
                  if (photo != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(photo!, height: 140, width: double.infinity, fit: BoxFit.cover),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Annuler'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Valider'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (ok != true) return;

    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nom requis')));
      return;
    }

    setState(() => _saving = true);
    try {
      await _ensureProject();
      final projectId = _projectId!;

      final poiRef = _db.collection('map_projects').doc(projectId).collection('pois').doc();

      String? imageUrl;
      if (photo != null) {
        final url = await _uploadBytes(path: 'map_projects/$projectId/pois/${poiRef.id}.jpg', bytes: photo!);
        imageUrl = url;
      }

      await poiRef.set({
        'name': name,
        'description': descCtrl.text.trim(),
        'layerId': _layerId,
        'lat': p.latitude,
        'lng': p.longitude,
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Point enregistré')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _topStep0() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Paramètres', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _country,
                  decoration: const InputDecoration(labelText: 'Pays', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'guadeloupe', child: Text('Guadeloupe')),
                    DropdownMenuItem(value: 'martinique', child: Text('Martinique')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _country = v;
                      _perimeterCornerA = null;
                      _perimeterCornerB = null;
                      _perimeterLocked = false;
                      _circuitPoints.clear();
                      _circuitLocked = false;
                      _map.move(_countryCenter, 11.5);
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _yearCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Année', border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _communeCtrl,
            decoration: const InputDecoration(labelText: 'Commune *', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Nom du circuit', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          Text(
            'Classement: année / pays / commune',
            style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _toolbar() {
    final b = _bounds;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 18, offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Périmètre',
              onPressed: () => setState(() => _mode = _EditorMode.perimeter),
              icon: Icon(Icons.crop_free, color: _mode == _EditorMode.perimeter ? _circuitColor : Colors.black54),
            ),
            IconButton(
              tooltip: _perimeterLocked ? 'Déverrouiller périmètre' : 'Verrouiller périmètre',
              onPressed: b == null
                  ? null
                  : () => setState(() {
                        _perimeterLocked = !_perimeterLocked;
                      }),
              icon: Icon(_perimeterLocked ? Icons.lock : Icons.lock_open, color: Colors.black87),
            ),
            const VerticalDivider(width: 12),
            IconButton(
              tooltip: 'Créer circuit (tap)',
              onPressed: () => setState(() => _mode = _EditorMode.circuit),
              icon: Icon(Icons.alt_route, color: _mode == _EditorMode.circuit ? _circuitColor : Colors.black54),
            ),
            IconButton(
              tooltip: _circuitLocked ? 'Déverrouiller circuit' : 'Verrouiller circuit',
              onPressed: () => setState(() => _circuitLocked = !_circuitLocked),
              icon: Icon(_circuitLocked ? Icons.lock : Icons.lock_open, color: Colors.black87),
            ),
            IconButton(
              tooltip: 'Habillage circuit',
              onPressed: _openCircuitStyle,
              icon: const Icon(Icons.palette_outlined),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Annuler dernier point',
              onPressed: _circuitPoints.isEmpty ? null : () => setState(() => _circuitPoints.removeLast()),
              icon: const Icon(Icons.undo),
            ),
            IconButton(
              tooltip: 'Vider circuit',
              onPressed: _circuitPoints.isEmpty ? null : () => setState(() => _circuitPoints.clear()),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _layersBar() {
    final layers = const [
      {'id': 'visiter', 'icon': Icons.attractions, 'label': 'Visiter'},
      {'id': 'food', 'icon': Icons.restaurant, 'label': 'Food'},
      {'id': 'assistance', 'icon': Icons.support_agent, 'label': 'Assistance'},
      {'id': 'wc', 'icon': Icons.wc, 'label': 'WC'},
      {'id': 'parking', 'icon': Icons.local_parking, 'label': 'Parking'},
    ];

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 76),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 18, offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Mode POI (tap)',
              onPressed: () => setState(() => _mode = _EditorMode.poi),
              icon: Icon(Icons.add_location_alt, color: _mode == _EditorMode.poi ? _circuitColor : Colors.black54),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: layers.map((l) {
                    final selected = _layerId == l['id'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: selected,
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(l['icon'] as IconData, size: 16),
                            const SizedBox(width: 6),
                            Text(l['label'] as String),
                          ],
                        ),
                        onSelected: (_) => setState(() {
                          _layerId = l['id'] as String;
                          _mode = _EditorMode.poi;
                        }),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Liste des POI',
              onPressed: _openPoiList,
              icon: const Icon(Icons.list_alt),
            ),
            IconButton(
              tooltip: 'Gérer couches',
              onPressed: _openLayersManager,
              icon: const Icon(Icons.tune),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapView() {
    final b = _bounds;
    final polygons = <Polygon>[];
    if (_showPerimeter && b != null) {
      polygons.add(
        Polygon(
          points: _boundsPolygon(b),
          isFilled: true,
          color: (_perimeterLocked ? Colors.red : Colors.redAccent).withValues(alpha: 0.15),
          borderColor: _perimeterLocked ? Colors.red : Colors.redAccent,
          borderStrokeWidth: 3,
        ),
      );
    }

    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: _countryCenter,
        initialZoom: 11.5,
        onTap: (tapPos, latlng) => _onMapTap(latlng),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.maslive.app',
        ),
        if (polygons.isNotEmpty) PolygonLayer(polygons: polygons),
        if (_showCircuit && _circuitPoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _circuitPoints,
                color: _circuitColor,
                strokeWidth: _circuitWidth,
                borderColor: _circuitBorderColor,
                borderStrokeWidth: _circuitBorderWidth,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (_perimeterCornerA != null)
              Marker(
                point: _perimeterCornerA!,
                width: 42,
                height: 42,
                child: const Icon(Icons.crop_square, color: Colors.red),
              ),
            if (_perimeterCornerB != null)
              Marker(
                point: _perimeterCornerB!,
                width: 42,
                height: 42,
                child: const Icon(Icons.crop_square, color: Colors.red),
              ),
            if (_showCircuit && _circuitPoints.isNotEmpty)
              Marker(
                point: _circuitPoints.first,
                width: 46,
                height: 46,
                child: const Icon(Icons.flag, color: Colors.green),
              ),
            if (_showCircuit && _circuitPoints.length >= 2)
              Marker(
                point: _circuitPoints.last,
                width: 46,
                height: 46,
                child: const Icon(Icons.flag, color: Colors.red),
              ),
          ],
        ),
        if (_projectId != null)
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _db.collection('map_projects').doc(_projectId).collection('pois').snapshots(),
            builder: (context, snap) {
              final rawDocs = snap.data?.docs ?? const [];
              final docs = rawDocs.where((d) {
                final layerId = (d.data()['layerId'] as String?) ?? '';
                if (!_visiblePoiLayers.contains(layerId)) return false;
                if (_showAllPois) return true;
                return layerId == _layerId;
              }).toList();
              if (docs.isEmpty) return const SizedBox.shrink();
              return MarkerLayer(
                markers: docs.map((d) {
                  final data = d.data();
                  final lat = (data['lat'] as num).toDouble();
                  final lng = (data['lng'] as num).toDouble();
                  final layerId = data['layerId'] as String? ?? '';
                  final label = data['name'] as String? ?? 'Point';

                  IconData icon = Icons.place;
                  if (layerId == 'food') icon = Icons.restaurant;
                  if (layerId == 'visiter') icon = Icons.attractions;
                  if (layerId == 'assistance') icon = Icons.support_agent;
                  if (layerId == 'wc') icon = Icons.wc;
                  if (layerId == 'parking') icon = Icons.local_parking;

                  return Marker(
                    point: LatLng(lat, lng),
                    width: 48,
                    height: 48,
                    child: GestureDetector(
                      onTap: () => _openPoiEditorExisting(poiId: d.id, data: data),
                      child: Tooltip(
                        message: label,
                        child: Icon(icon, color: const Color(0xFF1A73E8), size: 30),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _helpCard() {
    String txt;
    if (_mode == _EditorMode.perimeter) {
      txt = _perimeterLocked
          ? 'Périmètre verrouillé (zone rouge).'
          : 'Définis le périmètre: tape 2 coins opposés, puis verrouille.';
    } else if (_mode == _EditorMode.circuit) {
      txt = _circuitLocked
          ? 'Circuit verrouillé (protège contre les ajouts involontaires).'
          : 'Créer circuit: tape pour poser les marqueurs (départ → ... → arrivée).';
    } else {
      txt = 'Ajouter un point: choisis une couche puis tape sur la carte.';
    }

    return Positioned(
      left: 12,
      right: 12,
      top: 12,
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.92),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.info_outline),
              const SizedBox(width: 10),
              Expanded(child: Text(txt, style: const TextStyle(fontWeight: FontWeight.w700))),
              if (_saving) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _step == 0
        ? _communeCtrl.text.trim().isNotEmpty
        : _step == 1
            ? _bounds != null
            : _step == 2
                ? _circuitPoints.length >= 2
                : true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Track Editor'),
        actions: [
          IconButton(
            tooltip: 'Sauvegarder',
            onPressed: _saving ? null : () => _saveDraft(validate: false),
            icon: const Icon(Icons.save_outlined),
          ),
          IconButton(
            tooltip: 'Valider',
            onPressed: _saving
                ? null
                : () async {
                    if (_circuitPoints.length < 2) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Le circuit doit avoir au moins 2 points')),
                      );
                      return;
                    }
                    await _saveDraft(validate: true);
                  },
            icon: const Icon(Icons.verified_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Stepper(
            currentStep: _step,
            onStepTapped: (i) => setState(() => _step = i),
            controlsBuilder: (ctx, details) {
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    FilledButton(
                      onPressed: (!canContinue || _saving)
                          ? null
                          : () {
                              if (_step < 3) {
                                setState(() {
                                  _step++;
                                  if (_step == 1) _mode = _EditorMode.perimeter;
                                  if (_step == 2) _mode = _EditorMode.circuit;
                                  if (_step == 3) _mode = _EditorMode.poi;
                                });
                              }
                            },
                      child: const Text('Continuer'),
                    ),
                    const SizedBox(width: 10),
                    if (_step > 0)
                      OutlinedButton(
                        onPressed: _saving ? null : () => setState(() => _step--),
                        child: const Text('Retour'),
                      ),
                  ],
                ),
              );
            },
            steps: const [
              Step(title: Text('Pays'), content: SizedBox.shrink(), isActive: true),
              Step(title: Text('Périmètre'), content: SizedBox.shrink(), isActive: true),
              Step(title: Text('Circuit'), content: SizedBox.shrink(), isActive: true),
              Step(title: Text('Couches/POI'), content: SizedBox.shrink(), isActive: true),
            ],
          ),
          if (_step == 0) _topStep0(),
          Expanded(
            child: Stack(
              children: [
                _mapView(),
                _helpCard(),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_step >= 3) _layersBar(),
                      _toolbar(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
