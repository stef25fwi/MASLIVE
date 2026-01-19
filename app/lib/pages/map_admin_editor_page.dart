import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum AdminEditMode { none, addPoi, setStart, setEnd, addCircuitPoint }

class MapAdminEditorPage extends StatefulWidget {
  const MapAdminEditorPage({super.key});

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
              // OSM tiles
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: "com.example.maslive",
                // Note: Respecter l'attribution OSM
              ),

              // Ligne du circuit (polyline)
              if (_circuitPoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _circuitPoints,
                      strokeWidth: 5,
                    ),
                  ],
                ),

              // Markers
              MarkerLayer(markers: _buildMarkers()),
            ],
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

    final title = await _askText("Titre du circuit", hint: "Ex: Circuit Basse-Terre");
    if (title == null || title.trim().isEmpty) return;

    final desc = await _askText("Description", hint: "Optionnel", optional: true);

    await _db.collection('circuits').add({
      'title': title.trim(),
      'description': (desc ?? "").trim(),
      'start': {'lat': _start!.latitude, 'lng': _start!.longitude, 'label': 'Départ'},
      'end': {'lat': _end!.latitude, 'lng': _end!.longitude, 'label': 'Arrivée'},
      'points': _circuitPoints
          .map((p) => {'lat': p.latitude, 'lng': p.longitude, 'label': 'Stop'})
          .toList(),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': uid,
      'isPublished': false,
    });

    setState(() {
      _circuitPoints.clear();
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
}

class _HintBar extends StatelessWidget {
  final String hint;
  final AdminEditMode mode;
  final VoidCallback onClear;
  final VoidCallback? onSavePoi;
  final VoidCallback? onSaveCircuit;

  const _HintBar({
    required this.hint,
    required this.mode,
    required this.onClear,
    required this.onSavePoi,
    required this.onSaveCircuit,
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
      child: Row(
        children: [
          Expanded(child: Text(hint, maxLines: 2, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          IconButton(
            tooltip: "Effacer brouillon",
            onPressed: onClear,
            icon: const Icon(Icons.delete_outline),
          ),
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
