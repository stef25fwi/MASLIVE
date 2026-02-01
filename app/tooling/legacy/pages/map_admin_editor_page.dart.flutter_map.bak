import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/route_validator.dart';

enum AdminEditMode { none, addPoi, setStart, setEnd, addCircuitPoint }

class MapAdminEditorPage extends StatefulWidget {
  const MapAdminEditorPage({super.key, this.groupId});

  final String? groupId;

  @override
  State<MapAdminEditorPage> createState() => _MapAdminEditorPageState();
}

class _MapAdminEditorPageState extends State<MapAdminEditorPage> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final MapController _mapController = MapController();

  // Mode édition
  AdminEditMode _mode = AdminEditMode.none;

  // Points édités
  LatLng? _start;
  LatLng? _end;
  LatLng? _poiDraft;
  final List<LatLng> _circuitPoints = [];

  // Calques visibles
  bool _showPoisLayer = true;
  bool _showCircuitsLayer = true;

  // UI helpers
  String _hint = "Mode normal";

  bool get _isAdmin {
    // Ici tu peux brancher ton check réel via users/{uid}.isAdmin
    // Pour demo, on laisse true si connecté
    return _auth.currentUser != null;
  }

  @override
  Widget build(BuildContext context) {
    final center = _start ?? const LatLng(16.245, -61.551); // Guadeloupe approx

    return Scaffold(
      appBar: AppBar(
        title: const Text("Carte (OSM)"),
        actions: [
          if (_isAdmin)
            PopupMenuButton<AdminEditMode>(
              tooltip: "Mode admin",
              onSelected: _setMode,
              itemBuilder: (_) => const [
                PopupMenuItem(value: AdminEditMode.none, child: Text("Mode normal")),
                PopupMenuItem(value: AdminEditMode.addPoi, child: Text("Ajouter POI (tap sur carte)")),
                PopupMenuItem(value: AdminEditMode.setStart, child: Text("Définir Départ (tap sur carte)")),
                PopupMenuItem(value: AdminEditMode.setEnd, child: Text("Définir Arrivée (tap sur carte)")),
                PopupMenuItem(value: AdminEditMode.addCircuitPoint, child: Text("Ajouter points Circuit (tap)")),
              ],
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 12,
              onTap: (tapPosition, latlng) => _handleTap(latlng),
            ),
            children: [
              // Fond OSM
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: "com.example.maslive",
              ),

              // Calque circuits existants
              if (_showCircuitsLayer)
                StreamBuilder<List<_CircuitOverlay>>( // circuits Firestore
                  stream: _circuitsStream(),
                  builder: (context, snap) {
                    final circuits = snap.data ?? const [];
                    if (circuits.isEmpty) return const SizedBox.shrink();
                    return PolylineLayer(
                      polylines: circuits
                          .where((c) => c.points.length >= 2)
                          .map(
                            (c) => Polyline(
                              points: c.points,
                              color: Colors.black.withValues(alpha: 0.5),
                              strokeWidth: 4,
                            ),
                          )
                          .toList(),
                    );
                  },
                ),

              // Calque POI existants
              if (_showPoisLayer)
                StreamBuilder<List<_PoiOverlay>>( // POIs Firestore
                  stream: _poisStream(),
                  builder: (context, snap) {
                    final pois = snap.data ?? const [];
                    if (pois.isEmpty) return const SizedBox.shrink();
                    return MarkerLayer(
                      markers: pois
                          .map(
                            (p) => Marker(
                              point: p.point,
                              width: 46,
                              height: 46,
                              child: Tooltip(
                                message: p.name,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.deepPurple.withValues(alpha: 0.75),
                                  ),
                                  child: const Icon(Icons.place, color: Colors.white),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),

              // Brouillon circuit
              if (_circuitPoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _circuitPoints,
                      strokeWidth: 5,
                    ),
                  ],
                ),

              // Brouillon markers
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),

          // Barre modes / calques
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: _ModeAndLayerBar(
              mode: _mode,
              showPois: _showPoisLayer,
              showCircuits: _showCircuitsLayer,
              onModeChanged: _setMode,
              onTogglePois: (v) => setState(() => _showPoisLayer = v),
              onToggleCircuits: (v) => setState(() => _showCircuitsLayer = v),
            ),
          ),

          // Bandeau stats circuit
          if (_mode == AdminEditMode.addCircuitPoint && _circuitPoints.isNotEmpty)
            Positioned(
              left: 12,
              right: 12,
              bottom: 90,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withValues(alpha: 0.92),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatChip(
                      label: '${_circuitPoints.length} pts',
                      icon: Icons.pin_drop,
                    ),
                    _StatChip(
                      label: _formatDist(RouteValidator.totalDistance(_circuitPoints)),
                      icon: Icons.route,
                    ),
                    _StatChip(
                      label: _formatTime(RouteValidator.estimatedTime(_circuitPoints)),
                      icon: Icons.timer,
                    ),
                  ],
                ),
              ),
            ),

          // Bandeau d'info
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _HintBar(
              hint: _hint,
              mode: _mode,
              onClear: _clearDraft,
              onSavePoi: (_poiDraft != null) ? _savePoi : null,
              onSaveCircuit: (_circuitPoints.isNotEmpty && _start != null && _end != null) ? _saveCircuit : null,
              hasStart: _start != null,
              hasEnd: _end != null,
              pointsCount: _circuitPoints.length,
            ),
          ),
        ],
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: () {
                // recentre
                _mapController.move((_poiDraft ?? _start ?? center), 13);
              },
              icon: const Icon(Icons.my_location),
              label: const Text("Recentrer"),
            )
          : null,
    );
  }

  void _setMode(AdminEditMode m) {
    setState(() {
      _mode = m;
      _hint = switch (m) {
        AdminEditMode.none => "Mode normal",
        AdminEditMode.addPoi => "Ajouter POI : tape sur la carte",
        AdminEditMode.setStart => "Définir Départ : tape sur la carte",
        AdminEditMode.setEnd => "Définir Arrivée : tape sur la carte",
        AdminEditMode.addCircuitPoint => "Circuit : tape pour ajouter des points",
      };
    });
  }

  void _handleTap(LatLng p) {
    if (!_isAdmin) return;

    setState(() {
      switch (_mode) {
        case AdminEditMode.none:
          // rien
          break;

        case AdminEditMode.addPoi:
          _poiDraft = p;
          _hint = "POI prêt: (${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}) → Enregistrer";
          break;

        case AdminEditMode.setStart:
          _start = p;
          _hint = "Départ: (${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)})";
          break;

        case AdminEditMode.setEnd:
          _end = p;
          _hint = "Arrivée: (${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)})";
          break;

        case AdminEditMode.addCircuitPoint:
          _circuitPoints.add(p);
          _hint = "Point circuit ajouté (#${_circuitPoints.length})";
          break;
      }
    });
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    if (_start != null) {
      markers.add(_marker(_start!, Icons.play_arrow, "Départ"));
    }
    if (_end != null) {
      markers.add(_marker(_end!, Icons.flag, "Arrivée"));
    }
    if (_poiDraft != null) {
      markers.add(_marker(_poiDraft!, Icons.place, "POI"));
    }

    for (int i = 0; i < _circuitPoints.length; i++) {
      markers.add(
        Marker(
          point: _circuitPoints[i],
          width: 44,
          height: 44,
          child: _SmallIndexBadge(index: i + 1),
        ),
      );
    }

    return markers;
  }

  Stream<List<_PoiOverlay>> _poisStream() {
    return _db
        .collection('pois')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) {
        final data = doc.data();
        final lat = (data['lat'] as num?)?.toDouble();
        final lng = (data['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) return null;
        return _PoiOverlay(
          id: doc.id,
          name: (data['name'] ?? 'POI').toString(),
          point: LatLng(lat, lng),
        );
      }).whereType<_PoiOverlay>().toList();
    });
  }

  Stream<List<_CircuitOverlay>> _circuitsStream() {
    return _db
        .collection('circuits')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) {
        final data = doc.data();
        final points = (data['points'] as List?)
                ?.map((e) => _latLngFrom(e as Map<String, dynamic>?))
                .whereType<LatLng>()
                .toList() ??
            const <LatLng>[];
        if (points.length < 2) return null;
        return _CircuitOverlay(id: doc.id, points: points);
      }).whereType<_CircuitOverlay>().toList();
    });
  }

  Marker _marker(LatLng p, IconData icon, String label) {
    return Marker(
      point: p,
      width: 52,
      height: 52,
      child: Tooltip(
        message: label,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.65),
          ),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }

  LatLng? _latLngFrom(Map<String, dynamic>? data) {
    if (data == null) return null;
    final lat = (data['lat'] as num?)?.toDouble();
    final lng = (data['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  void _clearDraft() {
    setState(() {
      _poiDraft = null;
      _circuitPoints.clear();
      _hint = "Brouillon effacé";
    });
  }

  Future<void> _savePoi() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || _poiDraft == null) return;

    // mini formulaire rapide
    final result = await showDialog<_PoiFormResult>(
      context: context,
      builder: (_) => const _PoiFormDialog(),
    );
    if (result == null) return;

    final p = _poiDraft!;
    await _db.collection('pois').add({
      'name': result.name,
      'category': result.category,
      'description': result.description,
      'lat': p.latitude,
      'lng': p.longitude,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': uid,
      'isActive': true,
    });

    setState(() {
      _poiDraft = null;
      _hint = "POI enregistré ✅";
    });
  }

  Future<void> _saveCircuit() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || _start == null || _end == null || _circuitPoints.isEmpty) return;

    // Validation
    if (_circuitPoints.length < 2) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Au moins 2 points pour un circuit')),
      );
      return;
    }

    final dist = RouteValidator.totalDistance(_circuitPoints);
    if (dist < 0.2) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Distance minimale: 0.2 km (actuellement: ${dist.toStringAsFixed(2)} km)')),
      );
      return;
    }

    final title = await _askText("Titre du circuit", hint: "Ex: Circuit Basse-Terre");
    if (title == null || title.trim().isEmpty) return;

    final desc = await _askText("Description", hint: "Optionnel", optional: true);

    await _db.collection('circuits').add({
      'title': title.trim(),
      'description': (desc ?? "").trim(),
      'groupId': widget.groupId,
      'start': {'lat': _start!.latitude, 'lng': _start!.longitude, 'label': 'Départ'},
      'end': {'lat': _end!.latitude, 'lng': _end!.longitude, 'label': 'Arrivée'},
      'points': _circuitPoints
          .map((p) => {'lat': p.latitude, 'lng': p.longitude, 'label': 'Stop'})
          .toList(),
      'distanceKm': dist,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': uid,
      'isPublished': false,
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ Circuit enregistré (${dist.toStringAsFixed(2)} km)')),
    );

    setState(() {
      _circuitPoints.clear();
      _start = null;
      _end = null;
      _hint = "Circuit enregistré ✅ (draft)";
    });
  }

  Future<String?> _askText(String title, {String? hint, bool optional = false}) async {
    final ctrl = TextEditingController();
    return showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(hintText: hint),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          FilledButton(
            onPressed: () {
              final v = ctrl.text;
              if (!optional && v.trim().isEmpty) return;
              Navigator.pop(context, v);
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  String _formatDist(double km) => '${km.toStringAsFixed(2)} km';
  String _formatTime(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes}m';
  }
}

class _ModeAndLayerBar extends StatelessWidget {
  final AdminEditMode mode;
  final bool showPois;
  final bool showCircuits;
  final ValueChanged<AdminEditMode> onModeChanged;
  final ValueChanged<bool> onTogglePois;
  final ValueChanged<bool> onToggleCircuits;

  const _ModeAndLayerBar({
    required this.mode,
    required this.showPois,
    required this.showCircuits,
    required this.onModeChanged,
    required this.onTogglePois,
    required this.onToggleCircuits,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          alignment: WrapAlignment.start,
          children: [
            _modeChip('Normal', AdminEditMode.none, Icons.pan_tool_alt),
            _modeChip('POI', AdminEditMode.addPoi, Icons.add_location_alt),
            _modeChip('Départ', AdminEditMode.setStart, Icons.play_arrow_rounded),
            _modeChip('Arrivée', AdminEditMode.setEnd, Icons.flag_rounded),
            _modeChip('Circuit', AdminEditMode.addCircuitPoint, Icons.alt_route_rounded),
            FilterChip(
              label: const Text('POIs'),
              selected: showPois,
              onSelected: (v) => onTogglePois(v),
              avatar: const Icon(Icons.layers),
            ),
            FilterChip(
              label: const Text('Circuits'),
              selected: showCircuits,
              onSelected: (v) => onToggleCircuits(v),
              avatar: const Icon(Icons.polyline_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeChip(String label, AdminEditMode value, IconData icon) {
    final isSelected = mode == value;
    return ChoiceChip(
      label: Text(label),
      avatar: Icon(icon, size: 18),
      selected: isSelected,
      onSelected: (_) => onModeChanged(value),
    );
  }
}

class _HintBar extends StatelessWidget {
  final String hint;
  final AdminEditMode mode;
  final VoidCallback onClear;
  final VoidCallback? onSavePoi;
  final VoidCallback? onSaveCircuit;
  final bool hasStart;
  final bool hasEnd;
  final int pointsCount;

  const _HintBar({
    required this.hint,
    required this.mode,
    required this.onClear,
    required this.onSavePoi,
    required this.onSaveCircuit,
    required this.hasStart,
    required this.hasEnd,
    required this.pointsCount,
  });

  @override
  Widget build(BuildContext context) {
    final canSavePoi = onSavePoi != null;
    final canSaveCircuit = onSaveCircuit != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.92),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(hint, maxLines: 2, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              IconButton(
                tooltip: "Effacer brouillon",
                onPressed: onClear,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          if (mode == AdminEditMode.addCircuitPoint)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _StatusChip(label: "Départ", ok: hasStart),
                  _StatusChip(label: "Arrivée", ok: hasEnd),
                  _StatusChip(label: "Points: $pointsCount", ok: pointsCount >= 2),
                ],
              ),
            ),
          Row(
            children: [
              if (mode == AdminEditMode.addPoi)
                FilledButton(
                  onPressed: canSavePoi ? onSavePoi : null,
                  child: const Text("Enregistrer POI"),
                ),
              if (mode == AdminEditMode.addCircuitPoint)
                FilledButton(
                  onPressed: canSaveCircuit ? onSaveCircuit : null,
                  child: const Text("Enregistrer circuit"),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallIndexBadge extends StatelessWidget {
  final int index;
  const _SmallIndexBadge({required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.75),
      ),
      child: Text(
        "$index",
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool ok;
  const _StatusChip({required this.label, required this.ok});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      avatar: Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked, color: ok ? Colors.green : Colors.grey),
      side: BorderSide(color: ok ? Colors.green : Colors.grey.shade300),
      backgroundColor: ok ? Colors.green.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.08),
    );
  }
}

class _PoiOverlay {
  final String id;
  final String name;
  final LatLng point;
  const _PoiOverlay({required this.id, required this.name, required this.point});
}

class _CircuitOverlay {
  final String id;
  final List<LatLng> points;
  const _CircuitOverlay({required this.id, required this.points});
}

class _StatChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _StatChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.blue),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// ---------- POI Form ----------

class _PoiFormResult {
  final String name;
  final String category;
  final String description;
  _PoiFormResult({required this.name, required this.category, required this.description});
}

class _PoiFormDialog extends StatefulWidget {
  const _PoiFormDialog();

  @override
  State<_PoiFormDialog> createState() => _PoiFormDialogState();
}

class _PoiFormDialogState extends State<_PoiFormDialog> {
  final nameCtrl = TextEditingController();
  final catCtrl = TextEditingController(text: "nature");
  final descCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Nouveau POI"),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Nom")),
            TextField(controller: catCtrl, decoration: const InputDecoration(labelText: "Catégorie")),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: "Description (optionnel)")),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
        FilledButton(
          onPressed: () {
            if (nameCtrl.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              _PoiFormResult(
                name: nameCtrl.text.trim(),
                category: catCtrl.text.trim().isEmpty ? "other" : catCtrl.text.trim(),
                description: descCtrl.text.trim(),
              ),
            );
          },
          child: const Text("OK"),
        ),
      ],
    );
  }
}
