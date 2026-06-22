import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/market_circuit_models.dart';
import '../ui/map/maslive_map.dart';
import '../ui/map/maslive_map_controller.dart';
import '../ui_kit/tokens/maslive_tokens.dart';

typedef _LngLat = ({double lng, double lat});

// ─── Constants ──────────────────────────────────────────────────────────────

const _kDefaultFillHex = '#0A84FF';
const _kDefaultStrokeHex = '#FFFFFF';
const _kDefaultFillOpacity = 0.88;
const _kDefaultStrokeWidth = 4.0;
const _kDefaultPatternOpacity = 0.55;
const _kDefaultColorSaturation = 1.0;
const _kLabelPresetWideBlue = 'wide_blue_badge_white_outline';
const _kStyleKey = 'perimeterStyle';
const _kVehiclesKey = 'vehicleTypes';

// ─── Page ─────────────────────────────────────────────────────────────────

/// Standalone page for drawing a parking-zone polygon on a map.
///
/// Opens full-screen. The user taps the map to add vertices; when ≥ 3 points
/// are placed they can open the styling sheet and save.
///
/// Returns a [MarketMapPOI] when saved (via `Navigator.pop`), or `null` when
/// cancelled.
class ParkingZoneDrawerPage extends StatefulWidget {
  const ParkingZoneDrawerPage({
    super.key,
    required this.countryId,
    required this.eventId,
    required this.circuitId,
    this.initialLat = 16.2410,
    this.initialLng = -61.5340,
    this.initialZoom = 15.0,
    this.styleUrl,
  });

  final String countryId;
  final String eventId;
  final String circuitId;
  final double initialLat;
  final double initialLng;
  final double initialZoom;
  final String? styleUrl;

  @override
  State<ParkingZoneDrawerPage> createState() => _ParkingZoneDrawerPageState();
}

class _ParkingZoneDrawerPageState extends State<ParkingZoneDrawerPage> {
  final _mapController = MasLiveMapControllerPoi();

  // ── Vertices ──────────────────────────────────────────────────────────────
  List<_LngLat> _points = [];

  // ── Style state ───────────────────────────────────────────────────────────
  String _fillColorHex = _kDefaultFillHex;
  String _strokeColorHex = _kDefaultStrokeHex;
  bool _strokeFollowsFill = false;
  double _colorSaturation = _kDefaultColorSaturation;
  double _fillOpacity = _kDefaultFillOpacity;
  double _strokeWidth = _kDefaultStrokeWidth;
  String _strokeDash = 'solid';
  String _pattern = 'none';
  double _patternOpacity = _kDefaultPatternOpacity;
  String _labelPreset = _kLabelPresetWideBlue;
  Set<String> _vehicleTypes = {'car', 'moto'};

  final _nameCtrl = TextEditingController(text: 'Zone parking');
  final _fillColorCtrl = TextEditingController(text: _kDefaultFillHex);
  final _strokeColorCtrl = TextEditingController(text: _kDefaultStrokeHex);

  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _fillColorCtrl.dispose();
    _strokeColorCtrl.dispose();
    super.dispose();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String? _normalizeHex(String? raw) {
    final v = raw?.trim();
    if (v == null || v.isEmpty) return null;
    if (RegExp(r'^#?[0-9a-fA-F]{6}$').hasMatch(v)) {
      return (v.startsWith('#') ? v : '#$v').toUpperCase();
    }
    if (RegExp(r'^0x[0-9a-fA-F]{8}$').hasMatch(v)) {
      return '#${v.substring(v.length - 6).toUpperCase()}';
    }
    return null;
  }

  Color _parseHex(String hex) {
    final m = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(hex.trim());
    if (m == null) return Colors.black;
    return Color(0xFF000000 | int.parse(m.group(1)!, radix: 16));
  }

  String _colorToHex(Color c) {
    final r = c.r.round().toRadixString(16).padLeft(2, '0');
    final g = c.g.round().toRadixString(16).padLeft(2, '0');
    final b = c.b.round().toRadixString(16).padLeft(2, '0');
    return '#${(r + g + b).toUpperCase()}';
  }

  String _adjustSaturation(String hex, double factor) {
    final color = _parseHex(hex);
    final hsv = HSVColor.fromColor(color);
    final adjusted = hsv.withSaturation(
      (hsv.saturation * factor.clamp(0.0, 1.0)).clamp(0.0, 1.0),
    );
    return _colorToHex(adjusted.toColor());
  }

  _LngLat _centroid(List<_LngLat> pts) {
    if (pts.isEmpty) return (lng: widget.initialLng, lat: widget.initialLat);
    var sLng = 0.0, sLat = 0.0;
    for (final p in pts) {
      sLng += p.lng;
      sLat += p.lat;
    }
    return (lng: sLng / pts.length, lat: sLat / pts.length);
  }

  double _distMeters(_LngLat a, _LngLat b) {
    const r = 6371000.0;
    final lat1 = a.lat * math.pi / 180;
    final lat2 = b.lat * math.pi / 180;
    final dLat = (b.lat - a.lat) * math.pi / 180;
    final dLng = (b.lng - a.lng) * math.pi / 180;
    final sinLat = math.sin(dLat / 2);
    final sinLng = math.sin(dLng / 2);
    final h = sinLat * sinLat + math.cos(lat1) * math.cos(lat2) * sinLng * sinLng;
    return 2 * r * math.asin(math.min(1.0, math.sqrt(h)));
  }

  double _maxSpan(List<_LngLat> pts) {
    if (pts.length < 2) return 0;
    var w = pts.first.lng, e = pts.first.lng;
    var s = pts.first.lat, n = pts.first.lat;
    for (final p in pts.skip(1)) {
      w = math.min(w, p.lng);
      e = math.max(e, p.lng);
      s = math.min(s, p.lat);
      n = math.max(n, p.lat);
    }
    final cLat = (s + n) / 2, cLng = (w + e) / 2;
    return math.max(
      _distMeters((lng: w, lat: cLat), (lng: e, lat: cLat)),
      _distMeters((lng: cLng, lat: s), (lng: cLng, lat: n)),
    );
  }

  String? _badgeId(List<_LngLat> pts) {
    if (_labelPreset != _kLabelPresetWideBlue) return null;
    final span = _maxSpan(pts);
    if (span >= 120) return 'maslive_parking_badge_lg';
    if (span >= 60) return 'maslive_parking_badge_md';
    return 'maslive_parking_badge_sm';
  }

  double _labelSize(List<_LngLat> pts) {
    if (_labelPreset != _kLabelPresetWideBlue) return 16.0;
    final span = _maxSpan(pts);
    if (span >= 120) return 17.0;
    if (span >= 60) return 15.0;
    return 13.0;
  }

  double _iconScale(List<_LngLat> pts) {
    if (_labelPreset != _kLabelPresetWideBlue) return 1.0;
    final span = _maxSpan(pts);
    if (span >= 120) return 1.0;
    if (span >= 60) return 0.92;
    return 0.84;
  }

  String _symbolImageId() {
    final n = _vehicleTypes.where((t) => t == 'car' || t == 'moto').toSet();
    if (n.length == 2) return 'maslive_parking_both';
    if (n.contains('moto')) return 'maslive_parking_moto';
    return 'maslive_parking_car';
  }

  String? _mapboxPattern(String? p) {
    switch ((p ?? '').trim()) {
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

  // ─── GeoJSON preview ──────────────────────────────────────────────────────

  Map<String, dynamic> _buildFeatureCollection(List<_LngLat> pts) {
    final features = <Map<String, dynamic>>[];

    final baseFill = _normalizeHex(_fillColorCtrl.text) ?? _kDefaultFillHex;
    final baseStroke = _strokeFollowsFill
        ? baseFill
        : (_normalizeHex(_strokeColorCtrl.text) ?? baseFill);
    final fill = _adjustSaturation(baseFill, _colorSaturation);
    final stroke = _adjustSaturation(baseStroke, _colorSaturation);

    // Vertices
    for (var i = 0; i < pts.length; i++) {
      features.add({
        'type': 'Feature',
        'id': '__pv_vertex__$i',
        'properties': {
          'layerId': 'parking',
          'title': 'Point zone parking',
          'isPreview': true,
          'isPreviewVertex': true,
          'fillColor': '#FFFFFF',
          'strokeColor': stroke,
          'strokeWidth': _strokeWidth,
        },
        'geometry': {
          'type': 'Point',
          'coordinates': [pts[i].lng, pts[i].lat],
        },
      });
    }

    // Path (LineString)
    if (pts.length >= 2) {
      features.add({
        'type': 'Feature',
        'id': '__pv_path__',
        'properties': {
          'poiId': '__pv_path__',
          'layerId': 'parking',
          'isPreview': true,
          'isPreviewEdge': true,
          'strokeColor': stroke,
          'strokeWidth': _strokeWidth,
          'strokeDash': _strokeDash,
        },
        'geometry': {
          'type': 'LineString',
          'coordinates': [for (final p in pts) [p.lng, p.lat]],
        },
      });
    }

    // Polygon
    if (pts.length >= 3) {
      final ring = [
        for (final p in pts) [p.lng, p.lat],
        [pts.first.lng, pts.first.lat],
      ];
      final pat = _mapboxPattern(_pattern);
      features.add({
        'type': 'Feature',
        'id': '__pv_zone__',
        'properties': {
          'poiId': '__pv_zone__',
          'layerId': 'parking',
          'title': 'Zone parking (aperçu)',
          'isPreview': true,
          'isZone': true,
          'fillColor': fill,
          'fillOpacity': _fillOpacity.clamp(0.0, 1.0),
          'strokeColor': stroke,
          'strokeWidth': _strokeWidth,
          'strokeDash': _strokeDash,
          if (pat != null) 'fillPattern': pat,
          'patternOpacity': _patternOpacity.clamp(0.0, 1.0),
        },
        'geometry': {
          'type': 'Polygon',
          'coordinates': [ring],
        },
      });

      final c = _centroid(pts);
      final badge = _badgeId(pts);
      features.add({
        'type': 'Feature',
        'id': '__pv_zone_label__',
        'properties': {
          'poiId': '__pv_zone__',
          'layerId': 'parking',
          'isPreview': true,
          'isZoneLabel': true,
          'labelText': 'PARKING',
          'labelTextSize': _labelSize(pts),
          'parkingIconId': _symbolImageId(),
          'parkingIconScale': _iconScale(pts),
          if (badge != null) 'parkingBadgeId': badge,
        },
        'geometry': {
          'type': 'Point',
          'coordinates': [c.lng, c.lat],
        },
      });
    }

    return {'type': 'FeatureCollection', 'features': features};
  }

  void _refreshPreview() {
    _mapController.setPoisGeoJson(_buildFeatureCollection(_points));
  }

  // ─── Vertex management ────────────────────────────────────────────────────

  void _onMapTap(MapPoint pt) {
    setState(() {
      _points = [..._points, (lng: pt.lng, lat: pt.lat)];
      _error = null;
    });
    _refreshPreview();
  }

  void _undoLast() {
    if (_points.isEmpty) return;
    setState(() => _points = _points.sublist(0, _points.length - 1));
    _refreshPreview();
  }

  void _reset() {
    setState(() {
      _points = [];
      _error = null;
    });
    _mapController.clearPoisGeoJson();
  }

  // ─── Save ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_points.length < 3) {
      setState(() => _error = 'Périmètre incomplet (min. 3 points).');
      return;
    }

    final fillHex = _normalizeHex(_fillColorCtrl.text) ?? _normalizeHex(_fillColorHex);
    if (fillHex == null) {
      setState(() => _error = 'Couleur invalide (ex: $_kDefaultFillHex).');
      return;
    }

    final strokeHex = _strokeFollowsFill
        ? fillHex
        : (_normalizeHex(_strokeColorCtrl.text) ?? fillHex);

    final centroid = _centroid(_points);
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final name = _nameCtrl.text.trim().isEmpty ? 'Zone parking' : _nameCtrl.text.trim();

    final poi = MarketMapPOI(
      id: id,
      name: name,
      layerType: 'parking',
      layerId: 'parking',
      lng: centroid.lng,
      lat: centroid.lat,
      isVisible: true,
      metadata: {
        _kVehiclesKey: _vehicleTypes.toList()..sort(),
        'perimeter': [for (final p in _points) {'lng': p.lng, 'lat': p.lat}],
        _kStyleKey: {
          'fillColor': fillHex,
          'colorSaturation': _colorSaturation.clamp(0.0, 1.0),
          'fillOpacity': _fillOpacity.clamp(0.0, 1.0),
          'strokeColor': strokeHex,
          'strokeFollowsFill': _strokeFollowsFill,
          'strokeWidth': _strokeWidth,
          'labelPreset': _labelPreset,
          'strokeDash': _strokeDash,
          'pattern': _pattern,
          'patternOpacity': _patternOpacity.clamp(0.0, 1.0),
        },
      },
    );

    setState(() => _saving = true);
    try {
      final db = FirebaseFirestore.instance;
      final user = FirebaseAuth.instance.currentUser;
      final now = FieldValue.serverTimestamp();

      final data = <String, dynamic>{
        ...poi.toFirestore(),
        'layerType': 'parking',
        'layerId': 'parking',
        'type': 'parking',
        'createdAt': now,
        'updatedAt': now,
        if (user != null) 'createdByUid': user.uid,
      };

      await db
          .collection('marketMap')
          .doc(widget.countryId)
          .collection('events')
          .doc(widget.eventId)
          .collection('circuits')
          .doc(widget.circuitId)
          .collection('pois')
          .doc(id)
          .set(data);

      if (mounted) Navigator.of(context).pop(poi);
    } catch (e) {
      if (mounted) setState(() => _error = 'Erreur lors de la sauvegarde: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─── Styling bottom sheet ────────────────────────────────────────────────

  void _onStyleChanged({
    String? fillColorHex,
    String? strokeColorHex,
    bool? strokeFollowsFill,
    double? colorSaturation,
    double? fillOpacity,
    double? strokeWidth,
    String? strokeDash,
    String? pattern,
    double? patternOpacity,
    Set<String>? vehicleTypes,
  }) {
    setState(() {
      if (fillColorHex != null) _fillColorHex = fillColorHex;
      if (strokeColorHex != null) _strokeColorHex = strokeColorHex;
      if (strokeFollowsFill != null) _strokeFollowsFill = strokeFollowsFill;
      if (colorSaturation != null) _colorSaturation = colorSaturation;
      if (fillOpacity != null) _fillOpacity = fillOpacity;
      if (strokeWidth != null) _strokeWidth = strokeWidth;
      if (strokeDash != null) _strokeDash = strokeDash;
      if (pattern != null) _pattern = pattern;
      if (patternOpacity != null) _patternOpacity = patternOpacity;
      if (vehicleTypes != null) _vehicleTypes = vehicleTypes;
      _error = null;
    });
    _refreshPreview();
  }

  void _openStyleSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _StyleSheet(
        nameCtrl: _nameCtrl,
        fillColorCtrl: _fillColorCtrl,
        strokeColorCtrl: _strokeColorCtrl,
        vehicleTypes: _vehicleTypes,
        strokeFollowsFill: _strokeFollowsFill,
        colorSaturation: _colorSaturation,
        fillOpacity: _fillOpacity,
        strokeWidth: _strokeWidth,
        strokeDash: _strokeDash,
        pattern: _pattern,
        patternOpacity: _patternOpacity,
        pointCount: _points.length,
        error: _error,
        saving: _saving,
        onStyleChanged: _onStyleChanged,
        onSave: _save,
      ),
    ).then((_) => setState(() {}));
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final canFinish = _points.length >= 3;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dessiner une zone parking'),
        actions: [
          if (_points.isNotEmpty)
            TextButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Réinitialiser'),
            ),
        ],
      ),
      body: Stack(
        children: [
          MasLiveMap(
            controller: _mapController,
            initialLng: widget.initialLng,
            initialLat: widget.initialLat,
            initialZoom: widget.initialZoom,
            styleUrl: widget.styleUrl,
            onTap: _onMapTap,
            onMapReady: (_) => _refreshPreview(),
          ),
          // Instruction banner
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Material(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Text(
                  _points.isEmpty
                      ? 'Appuyez sur la carte pour placer les premiers points de la zone.'
                      : _points.length < 3
                      ? 'Ajoutez encore ${3 - _points.length} point(s) pour former un polygone.'
                      : '${_points.length} points • Appuyez sur "Styliser & Créer" pour finaliser.',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                        ),
                      ),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _points.isEmpty ? null : _undoLast,
                          icon: const Icon(Icons.undo_rounded, size: 18),
                          label: const Text('Annuler dernier'),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: canFinish ? _openStyleSheet : null,
                          icon: const Icon(Icons.tune_rounded, size: 18),
                          label: const Text('Styliser & Créer'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Styling sheet ────────────────────────────────────────────────────────────
//
// StatefulWidget so sliders/chips/dropdowns rebuild in place without closing
// the sheet. Style changes are propagated to the parent via [onStyleChanged]
// for live map preview.

typedef _StyleChangedCallback = void Function({
  String? fillColorHex,
  String? strokeColorHex,
  bool? strokeFollowsFill,
  double? colorSaturation,
  double? fillOpacity,
  double? strokeWidth,
  String? strokeDash,
  String? pattern,
  double? patternOpacity,
  Set<String>? vehicleTypes,
});

class _StyleSheet extends StatefulWidget {
  const _StyleSheet({
    required this.nameCtrl,
    required this.fillColorCtrl,
    required this.strokeColorCtrl,
    required this.vehicleTypes,
    required this.strokeFollowsFill,
    required this.colorSaturation,
    required this.fillOpacity,
    required this.strokeWidth,
    required this.strokeDash,
    required this.pattern,
    required this.patternOpacity,
    required this.pointCount,
    required this.error,
    required this.saving,
    required this.onStyleChanged,
    required this.onSave,
  });

  final TextEditingController nameCtrl;
  final TextEditingController fillColorCtrl;
  final TextEditingController strokeColorCtrl;
  final Set<String> vehicleTypes;
  final bool strokeFollowsFill;
  final double colorSaturation;
  final double fillOpacity;
  final double strokeWidth;
  final String strokeDash;
  final String pattern;
  final double patternOpacity;
  final int pointCount;
  final String? error;
  final bool saving;
  final _StyleChangedCallback onStyleChanged;
  final Future<void> Function() onSave;

  @override
  State<_StyleSheet> createState() => _StyleSheetState();
}

class _StyleSheetState extends State<_StyleSheet> {
  late Set<String> _vehicleTypes;
  late bool _strokeFollowsFill;
  late double _colorSaturation;
  late double _fillOpacity;
  late double _strokeWidth;
  late String _strokeDash;
  late String _pattern;
  late double _patternOpacity;

  @override
  void initState() {
    super.initState();
    _vehicleTypes = Set<String>.from(widget.vehicleTypes);
    _strokeFollowsFill = widget.strokeFollowsFill;
    _colorSaturation = widget.colorSaturation;
    _fillOpacity = widget.fillOpacity;
    _strokeWidth = widget.strokeWidth;
    _strokeDash = widget.strokeDash;
    _pattern = widget.pattern;
    _patternOpacity = widget.patternOpacity;
  }

  void _applyPreset() {
    setState(() {
      _strokeFollowsFill = false;
      _colorSaturation = _kDefaultColorSaturation;
      _fillOpacity = _kDefaultFillOpacity;
      _strokeWidth = _kDefaultStrokeWidth;
      _strokeDash = 'solid';
      _pattern = 'none';
      _patternOpacity = _kDefaultPatternOpacity;
    });
    widget.fillColorCtrl.text = _kDefaultFillHex;
    widget.strokeColorCtrl.text = _kDefaultStrokeHex;
    widget.onStyleChanged(
      fillColorHex: _kDefaultFillHex,
      strokeColorHex: _kDefaultStrokeHex,
      strokeFollowsFill: false,
      colorSaturation: _kDefaultColorSaturation,
      fillOpacity: _kDefaultFillOpacity,
      strokeWidth: _kDefaultStrokeWidth,
      strokeDash: 'solid',
      pattern: 'none',
      patternOpacity: _kDefaultPatternOpacity,
    );
  }

  void _toggleVehicle(String type) {
    final next = Set<String>.from(_vehicleTypes);
    if (next.contains(type)) {
      if (next.length == 1) return;
      next.remove(type);
    } else {
      next.add(type);
    }
    setState(() => _vehicleTypes = next);
    widget.onStyleChanged(vehicleTypes: next);
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String displayValue,
    required void Function(double) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
            Text(displayValue, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        Slider.adaptive(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),

              Text(
                'Nouvelle zone parking • ${widget.pointCount} points',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: widget.nameCtrl,
                decoration: const InputDecoration(labelText: 'Nom', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),

              FilledButton.tonal(
                onPressed: _applyPreset,
                child: const Text('Preset badge parking blanc/bleu'),
              ),
              const SizedBox(height: 16),

              Text('Types affichés sur la zone',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilterChip(
                    selected: _vehicleTypes.contains('car'),
                    onSelected: (_) => _toggleVehicle('car'),
                    avatar: Icon(Icons.directions_car_filled_rounded, size: 18,
                        color: _vehicleTypes.contains('car') ? Colors.white : MasliveTokens.textSoft),
                    label: Text('Voiture',
                        style: TextStyle(fontWeight: FontWeight.w700,
                            color: _vehicleTypes.contains('car') ? Colors.white : MasliveTokens.text)),
                    selectedColor: MasliveTokens.primary,
                    checkmarkColor: Colors.white,
                  ),
                  FilterChip(
                    selected: _vehicleTypes.contains('moto'),
                    onSelected: (_) => _toggleVehicle('moto'),
                    avatar: Icon(Icons.two_wheeler_rounded, size: 18,
                        color: _vehicleTypes.contains('moto') ? Colors.white : MasliveTokens.textSoft),
                    label: Text('Moto',
                        style: TextStyle(fontWeight: FontWeight.w700,
                            color: _vehicleTypes.contains('moto') ? Colors.white : MasliveTokens.text)),
                    selectedColor: MasliveTokens.primary,
                    checkmarkColor: Colors.white,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextField(
                controller: widget.fillColorCtrl,
                onChanged: (v) {
                  widget.onStyleChanged(fillColorHex: v);
                  if (_strokeFollowsFill) {
                    widget.strokeColorCtrl.text = v;
                    widget.onStyleChanged(strokeColorHex: v);
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Couleur fond (hex, ex: #0A84FF)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),

              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _strokeFollowsFill,
                onChanged: (v) {
                  setState(() => _strokeFollowsFill = v);
                  if (v) {
                    widget.strokeColorCtrl.text = widget.fillColorCtrl.text;
                    widget.onStyleChanged(strokeFollowsFill: true, strokeColorHex: widget.fillColorCtrl.text);
                  } else {
                    widget.onStyleChanged(strokeFollowsFill: false);
                  }
                },
                title: const Text('Contour suit le fond'),
                subtitle: const Text('Désactivez pour choisir une couleur de contour séparée.'),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: widget.strokeColorCtrl,
                enabled: !_strokeFollowsFill,
                onChanged: (v) => widget.onStyleChanged(strokeColorHex: v),
                decoration: InputDecoration(
                  labelText: 'Couleur contour (hex, ex: #FFFFFF)',
                  border: const OutlineInputBorder(),
                  helperText: _strokeFollowsFill ? 'Le contour reprend la couleur du fond.' : null,
                ),
              ),
              const SizedBox(height: 12),

              _slider(
                label: 'Couleurs (saturation)',
                value: _colorSaturation,
                min: 0, max: 1, divisions: 20,
                displayValue: '${(100 * _colorSaturation).round()}%',
                onChanged: (v) {
                  setState(() => _colorSaturation = v);
                  widget.onStyleChanged(colorSaturation: v);
                },
              ),
              const SizedBox(height: 4),

              _slider(
                label: 'Fond (opacité)',
                value: _fillOpacity,
                min: 0, max: 1, divisions: 20,
                displayValue: '${(100 * _fillOpacity).round()}%',
                onChanged: (v) {
                  setState(() => _fillOpacity = v);
                  widget.onStyleChanged(fillOpacity: v);
                },
              ),
              const SizedBox(height: 4),

              _slider(
                label: 'Contour (largeur)',
                value: _strokeWidth,
                min: 1, max: 10, divisions: 18,
                displayValue: _strokeWidth.toStringAsFixed(1),
                onChanged: (v) {
                  setState(() => _strokeWidth = v);
                  widget.onStyleChanged(strokeWidth: v);
                },
              ),
              const SizedBox(height: 12),

              InputDecorator(
                decoration: const InputDecoration(labelText: 'Texture (contour)', border: OutlineInputBorder()),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _strokeDash,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'solid', child: Text('Plein')),
                      DropdownMenuItem(value: 'dashed', child: Text('Pointillé')),
                      DropdownMenuItem(value: 'dotted', child: Text('Pointillé fin')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _strokeDash = v);
                      widget.onStyleChanged(strokeDash: v);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),

              InputDecorator(
                decoration: const InputDecoration(labelText: 'Texture intérieure (pattern)', border: OutlineInputBorder()),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _pattern,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('Aucune')),
                      DropdownMenuItem(value: 'diag', child: Text('Diagonale')),
                      DropdownMenuItem(value: 'cross', child: Text('Croisillons')),
                      DropdownMenuItem(value: 'dots', child: Text('Points')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _pattern = v);
                      widget.onStyleChanged(pattern: v);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),

              _slider(
                label: 'Texture intérieure (opacité)',
                value: _patternOpacity,
                min: 0, max: 1, divisions: 20,
                displayValue: '${(100 * _patternOpacity).round()}%',
                onChanged: _pattern == 'none'
                    ? (_) {}
                    : (v) {
                        setState(() => _patternOpacity = v);
                        widget.onStyleChanged(patternOpacity: v);
                      },
              ),

              if (widget.error != null) ...[
                const SizedBox(height: 10),
                Text(widget.error!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w700)),
              ],

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Retour'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: widget.saving ? null : () => widget.onSave(),
                      child: widget.saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Créer la zone'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
