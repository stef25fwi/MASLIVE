import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;
import 'package:provider/provider.dart';

import '../../models/draft_circuit.dart';
import '../../providers/wizard_circuit_provider.dart';
import '../../services/mapbox_directions_service.dart';
import '../../services/mapbox_token_service.dart';
import '../map/maslive_map.dart';
import '../map/maslive_map_controller.dart';

enum _PerimeterUiMode { polygon, circle }

enum _RouteUiMode { points, stylePro }

class _PoiDraft {
  _PoiDraft({
    required this.id,
    required this.lng,
    required this.lat,
    required this.layerId,
    this.title = '',
    this.description = '',
    this.photoUrl = '',
    this.instagram = '',
    this.facebook = '',
  });

  final String id;
  final double lng;
  final double lat;
  final String layerId;
  String title;
  String description;
  String photoUrl;
  String instagram;
  String facebook;

  Map<String, dynamic> toFirestore() => <String, dynamic>{
        'lng': lng,
        'lat': lat,
        'layerId': layerId,
        'title': title,
        'description': description,
        'photoUrl': photoUrl,
      'instagram': instagram,
      'facebook': facebook,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static _PoiDraft fromFirestore(String id, Map<String, dynamic> data) {
    return _PoiDraft(
      id: id,
      lng: (data['lng'] as num?)?.toDouble() ?? 0,
      lat: (data['lat'] as num?)?.toDouble() ?? 0,
      layerId: (data['layerId'] as String?) ?? 'pois',
      title: (data['title'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      photoUrl: (data['photoUrl'] as String?) ?? '',
      instagram: (data['instagram'] as String?) ?? '',
      facebook: (data['facebook'] as String?) ?? '',
    );
  }
}

typedef _Bounds = ({double west, double south, double east, double north});

class ProCircuitWizardPage extends StatefulWidget {
  final String projectId;

  const ProCircuitWizardPage({super.key, required this.projectId});

  @override
  State<ProCircuitWizardPage> createState() => _ProCircuitWizardPageState();
}

class _ProCircuitWizardPageState extends State<ProCircuitWizardPage> {
  final _firestore = FirebaseFirestore.instance;
  final MasLiveMapController _mapController = MasLiveMapController();
  late final WizardCircuitProvider _wizard = WizardCircuitProvider();

  // Recalcul Directions en continu (debounce + ignore résultats obsolètes)
  Timer? _routeRecalcDebounce;
  int _routeRecalcSeq = 0;
  // bool _isRouteRecalculating = false;

  int _step = 2; // Step1 déjà fait via dialog côté entry page

  _PerimeterUiMode _mode = _PerimeterUiMode.polygon;
  _RouteUiMode _routeUiMode = _RouteUiMode.points;

  // --- POIs (Step 4) ---
  final List<_PoiDraft> _pois = <_PoiDraft>[];
  String _selectedPoiLayerId = 'pois';

  final List<MapPoint> _polygonPoints = <MapPoint>[];

  MapPoint? _circleCenter;
  double _circleRadiusMeters = 250.0;

  bool _isSaving = false;
  bool _didInitFromFirestore = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadExistingPois());
  }

  @override
  void dispose() {
    _routeRecalcDebounce?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _scheduleContinuousRouteRecalc(RouteMode mode) {
    // Recalc uniquement si assez de points et mode auto/hybride.
    final route = context.read<WizardCircuitProvider>().draft.route;
    if (route.routePoints.length < 2) return;
    if (mode == RouteMode.manual) return;

    _routeRecalcDebounce?.cancel();
    final seq = ++_routeRecalcSeq;
    _routeRecalcDebounce = Timer(const Duration(milliseconds: 650), () async {
      if (!mounted) return;
      // Si une action plus récente est arrivée, on ignore.
      if (seq != _routeRecalcSeq) return;
      await _recalcRouteGeometry(mode: mode, showFailureSnackBar: false, persist: false, seq: seq);
    });
  }

  Future<void> _recalcRouteGeometry({
    required RouteMode mode,
    required bool showFailureSnackBar,
    required bool persist,
    required int seq,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final p = context.read<WizardCircuitProvider>();
    final r = p.draft.route;
    if (r.routePoints.length < 2) return;

    final svc = await _directions();
    if (svc == null) return;
    try {
      final geom = switch (mode) {
        RouteMode.autoDriving => await svc.getDrivingRouteGeometry(r.routePoints),
        RouteMode.hybrid => await svc.getHybridGeometry(r.routePoints),
        _ => const <mbx.Point>[],
      };

      if (!mounted) return;
      if (seq != _routeRecalcSeq) return;

      if (geom.isEmpty) {
        if (showFailureSnackBar && mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(mode == RouteMode.autoDriving ? 'Directions (Auto) a échoué.' : 'Directions (Hybride) a échoué.'),
            ),
          );
        }
        return;
      }

      p.setRouteConnected(true);
      p.setRouteMode(mode);
      p.setRouteGeometry(geom);
    } finally {
      // no-op
    }

    // Re-rendu
    await _renderRouteFromProvider();

    // Persistance uniquement sur action explicite (boutons/étapes), pas en continu.
    if (persist) {
      await _saveStep3RouteFromProvider();
    }
  }

  DocumentReference<Map<String, dynamic>> get _projectRef =>
      _firestore.collection('map_projects').doc(widget.projectId);

  Future<void> _loadExistingPois() async {
    try {
      final snap = await _projectRef.collection('pois').get();
      final pois = <_PoiDraft>[
        for (final d in snap.docs) _PoiDraft.fromFirestore(d.id, d.data()),
      ];
      if (!mounted) return;
      setState(() {
        _pois
          ..clear()
          ..addAll(pois);
      });
    } catch (_) {
      // ignore: on first run there may be no subcollection yet
    }
  }

  Future<void> _savePois() async {
    setState(() => _isSaving = true);
    try {
      final batch = _firestore.batch();
      final col = _projectRef.collection('pois');

      final existing = await col.get();
      final keepIds = _pois.map((p) => p.id).toSet();

      for (final d in existing.docs) {
        if (!keepIds.contains(d.id)) {
          batch.delete(d.reference);
        }
      }

      for (final p in _pois) {
        batch.set(col.doc(p.id), p.toFirestore(), SetOptions(merge: true));
      }

      batch.set(_projectRef, {
        'poisSummary': {'count': _pois.length},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _editPoiDialog(_PoiDraft poi) async {
    final titleCtl = TextEditingController(text: poi.title);
    final descCtl = TextEditingController(text: poi.description);
    final instagramCtl = TextEditingController(text: poi.instagram);
    final facebookCtl = TextEditingController(text: poi.facebook);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier le POI'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtl,
                decoration: const InputDecoration(labelText: 'Titre'),
              ),
              TextField(
                controller: descCtl,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              TextField(
                controller: instagramCtl,
                decoration: const InputDecoration(labelText: 'Instagram'),
              ),
              TextField(
                controller: facebookCtl,
                decoration: const InputDecoration(labelText: 'Facebook'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('OK')),
        ],
      ),
    );

    if (ok != true) return;
    setState(() {
      poi.title = titleCtl.text.trim();
      poi.description = descCtl.text.trim();
      poi.instagram = instagramCtl.text.trim();
      poi.facebook = facebookCtl.text.trim();
    });
    await _savePois();
    await _renderStep();
  }

  Future<void> _loadExistingPerimeter(Map<String, dynamic> data) async {
    final rawMode = (data['perimeterMode'] as String?)?.trim();

    final perimeter = data['perimeter'];
    List<MapPoint> perimeterPoints = [];
    if (perimeter is List) {
      perimeterPoints = perimeter
          .whereType<Map>()
          .map((m) {
            final lng = m['lng'];
            final lat = m['lat'];
            if (lng is num && lat is num) {
              return MapPoint(lng.toDouble(), lat.toDouble());
            }
            return null;
          })
          .whereType<MapPoint>()
          .toList();
    }

    final circle = data['circle'];
    MapPoint? circleCenter;
    double? circleRadius;
    if (circle is Map) {
      final c = circle['center'];
      final r = circle['radiusMeters'];
      if (c is Map && r is num) {
        final lng = c['lng'];
        final lat = c['lat'];
        if (lng is num && lat is num) {
          circleCenter = MapPoint(lng.toDouble(), lat.toDouble());
          circleRadius = r.toDouble();
        }
      }
    }

    if (!mounted) return;

    if (rawMode == 'circle' && circleCenter != null && circleRadius != null) {
      _mode = _PerimeterUiMode.circle;
      _circleCenter = circleCenter;
      _circleRadiusMeters = circleRadius;
      _polygonPoints
        ..clear()
        ..addAll(perimeterPoints);
    } else {
      _mode = _PerimeterUiMode.polygon;
      _polygonPoints
        ..clear()
        ..addAll(perimeterPoints);
      if (_polygonPoints.isNotEmpty) {
        _circleCenter = null;
      }
    }

    // Init route depuis Firestore (si présent)
    final rawRoute = data['route'];
    if (rawRoute is List) {
      final pts = <mbx.Point>[];
      for (final p in rawRoute) {
        if (p is Map) {
          final lng = p['lng'];
          final lat = p['lat'];
          if (lng is num && lat is num) {
            pts.add(mbx.Point(coordinates: mbx.Position(lng.toDouble(), lat.toDouble())));
          }
        }
      }
      if (pts.isNotEmpty) {
        _wizard.setRoutePoints(pts);
        _wizard.setRouteConnected(pts.length >= 2);
        _wizard.setRouteGeometry(pts);
      }
    }

    await _renderStep();

    final initialFocus = _initialFocusPoint();
    if (initialFocus != null) {
      await _mapController.moveTo(lng: initialFocus.lng, lat: initialFocus.lat, zoom: 14.5, animate: false);
    }
  }

  MapPoint? _initialFocusPoint() {
    if (_mode == _PerimeterUiMode.circle && _circleCenter != null) {
      return _circleCenter;
    }
    if (_polygonPoints.isNotEmpty) return _polygonPoints.first;
    return null;
  }

  Future<void> _renderStep() async {
    await _mapController.clearAll();

    if (_mode == _PerimeterUiMode.polygon) {
      if (_step == 2) {
        await _renderPolygonEditing();
      } else {
        await _renderPolygonPerimeterOnly();
      }
    } else {
      if (_step == 2) {
        await _renderCircleEditing();
      } else {
        await _renderCirclePerimeterOnly();
      }
    }

    // Route preview/edit (step3) and also visible in step4
    if (_step == 3 || _step == 4) {
      await _renderRouteFromProvider();
    }

    // POIs (step4)
    if (_step == 4) {
      await _mapController.setMarkers([
        for (int i = 0; i < _pois.length; i++)
          MapMarker(
            id: _pois[i].id,
            lng: _pois[i].lng,
            lat: _pois[i].lat,
            label: '${i + 1}',
            size: 1.1,
          ),
      ]);
    }
  }

  Future<void> _renderPolygonPerimeterOnly() async {
    if (_polygonPoints.length >= 3) {
      await _mapController.setPolygon(
        points: [..._polygonPoints, _polygonPoints.first],
        fillColor: const Color(0x330A84FF),
        strokeColor: const Color(0xFF0A84FF),
        strokeWidth: 2,
        show: true,
      );
    }
  }

  Future<void> _renderCirclePerimeterOnly() async {
    if (_circleCenter == null) return;
    final circlePoints = _approxCirclePoints(
      center: _circleCenter!,
      radiusMeters: _circleRadiusMeters,
      samples: 48,
    );
    await _mapController.setPolygon(
      points: circlePoints,
      fillColor: const Color(0x330A84FF),
      strokeColor: const Color(0xFF0A84FF),
      strokeWidth: 2,
      show: true,
    );
  }

  Future<void> _renderPolygonEditing() async {
    // Markers numérotés
    await _mapController.setMarkers([
      for (int i = 0; i < _polygonPoints.length; i++)
        MapMarker(
          id: 'p$i',
          lng: _polygonPoints[i].lng,
          lat: _polygonPoints[i].lat,
          label: '${i + 1}',
          size: 1.1,
          color: const Color(0xFF0A84FF),
        ),
    ]);

    if (_polygonPoints.length >= 3) {
      await _mapController.setPolygon(
        points: [..._polygonPoints, _polygonPoints.first],
        fillColor: const Color(0x330A84FF),
        strokeColor: const Color(0xFF0A84FF),
        strokeWidth: 2,
        show: true,
      );
    } else if (_polygonPoints.length >= 2) {
      await _mapController.setPolyline(
        points: _polygonPoints,
        color: const Color(0xFF0A84FF),
        width: 4,
        show: true,
        roadLike: false,
      );
    }
  }

  Future<void> _renderCircleEditing() async {
    if (_circleCenter != null) {
      await _mapController.setMarkers([
        MapMarker(
          id: 'c',
          lng: _circleCenter!.lng,
          lat: _circleCenter!.lat,
          label: 'C',
          size: 1.2,
          color: const Color(0xFF0A84FF),
        ),
      ]);

      final circlePoints = _approxCirclePoints(
        center: _circleCenter!,
        radiusMeters: _circleRadiusMeters,
        samples: 48,
      );

      await _mapController.setPolygon(
        points: circlePoints,
        fillColor: const Color(0x330A84FF),
        strokeColor: const Color(0xFF0A84FF),
        strokeWidth: 2,
        show: true,
      );
    }
  }

  _Bounds? _boundsFromPoints(List<MapPoint> points) {
    if (points.isEmpty) return null;
    double west = points.first.lng;
    double east = points.first.lng;
    double south = points.first.lat;
    double north = points.first.lat;

    for (final p in points.skip(1)) {
      west = math.min(west, p.lng);
      east = math.max(east, p.lng);
      south = math.min(south, p.lat);
      north = math.max(north, p.lat);
    }

    // Petite marge pour éviter un fit trop serré
    final lngPad = (east - west).abs() * 0.1 + 0.0002;
    final latPad = (north - south).abs() * 0.1 + 0.0002;

    return (
      west: west - lngPad,
      south: south - latPad,
      east: east + lngPad,
      north: north + latPad,
    );
  }

  Future<void> _fitToPerimeter() async {
    final points = _currentPerimeterRenderPoints();
    final b = _boundsFromPoints(points);
    if (b == null) return;
    await _mapController.fitBounds(
      west: b.west,
      south: b.south,
      east: b.east,
      north: b.north,
      padding: 56,
      animate: true,
    );
  }

  List<MapPoint> _currentPerimeterRenderPoints() {
    if (_mode == _PerimeterUiMode.circle && _circleCenter != null) {
      return _approxCirclePoints(center: _circleCenter!, radiusMeters: _circleRadiusMeters, samples: 36);
    }
    if (_polygonPoints.length >= 3) {
      return [..._polygonPoints, _polygonPoints.first];
    }
    return [..._polygonPoints];
  }

  List<MapPoint> _currentPerimeterSavePoints() {
    if (_mode == _PerimeterUiMode.circle && _circleCenter != null) {
      final ring = _approxCirclePoints(center: _circleCenter!, radiusMeters: _circleRadiusMeters, samples: 36);
      // On évite de sauvegarder le point de fermeture en double.
      if (ring.length >= 2 && ring.first == ring.last) {
        return ring.sublist(0, ring.length - 1);
      }
      return ring;
    }
    return [..._polygonPoints];
  }

  static List<MapPoint> _approxCirclePoints({
    required MapPoint center,
    required double radiusMeters,
    int samples = 48,
  }) {
    final latRad = center.lat * math.pi / 180.0;
    final metersPerDegLat = 111320.0;
    final metersPerDegLng = 111320.0 * math.cos(latRad).abs().clamp(0.2, 1.0);

    final dLat = radiusMeters / metersPerDegLat;
    final dLng = radiusMeters / metersPerDegLng;

    final pts = <MapPoint>[];
    for (int i = 0; i < samples; i++) {
      final t = (i / samples) * 2 * math.pi;
      final lat = center.lat + math.sin(t) * dLat;
      final lng = center.lng + math.cos(t) * dLng;
      pts.add(MapPoint(lng, lat));
    }
    // Ferme le polygone
    if (pts.isNotEmpty) pts.add(pts.first);
    return pts;
  }

  Future<void> _saveStep2Perimeter() async {
    setState(() => _isSaving = true);
    try {
      final perimeterPoints = _currentPerimeterSavePoints();
      final perimeterJson = [
        for (final p in perimeterPoints)
          <String, double>{'lng': p.lng, 'lat': p.lat},
      ];

      final data = <String, dynamic>{
        'perimeterMode': _mode == _PerimeterUiMode.circle ? 'circle' : 'polygon',
        'perimeter': perimeterJson,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_mode == _PerimeterUiMode.circle && _circleCenter != null) {
        data['circle'] = {
          'center': {'lng': _circleCenter!.lng, 'lat': _circleCenter!.lat},
          'radiusMeters': _circleRadiusMeters,
        };
      } else {
        data['circle'] = FieldValue.delete();
      }

      await _projectRef.set(data, SetOptions(merge: true));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveStep3RouteFromProvider() async {
    final r = _wizard.draft.route;
    final geometry = r.routeGeometry.isNotEmpty ? r.routeGeometry : r.routePoints;

    setState(() => _isSaving = true);
    try {
      final routeJson = [
        for (final p in geometry)
          <String, double>{
            'lng': p.coordinates.lng.toDouble(),
            'lat': p.coordinates.lat.toDouble(),
          },
      ];

      await _projectRef.set({
        'route': routeJson,
        'routeConnected': r.connected,
        'routeMode': r.mode.name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _goToStep3() async {
    if (_mode == _PerimeterUiMode.polygon && _polygonPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins 3 points pour définir un périmètre.')),
      );
      return;
    }
    if (_mode == _PerimeterUiMode.circle && _circleCenter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Touchez la carte pour définir le centre du cercle.')),
      );
      return;
    }

    await _saveStep2Perimeter();

    if (!mounted) return;
    setState(() => _step = 3);

    await _renderStep();
    await _fitToPerimeter();
  }

  Future<void> _goToStep4() async {
    await _saveStep3RouteFromProvider();
    if (!mounted) return;
    setState(() => _step = 4);
    await _renderStep();
    await _fitToPerimeter();
  }

  Future<void> _backToStep3() async {
    if (!mounted) return;
    setState(() => _step = 3);
    await _renderStep();
    await _fitToPerimeter();
  }

  Future<void> _backToStep2() async {
    if (!mounted) return;
    setState(() => _step = 2);
    await _renderStep();
  }

  Future<void> _finish() async {
    // Always persist latest route + pois before closing
    await _saveStep3RouteFromProvider();
    await _savePois();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _onMapTap(MapPoint p) async {
    // Step 4: POIs
    if (_step == 4) {
      final poi = _PoiDraft(
        id: 'poi_${DateTime.now().millisecondsSinceEpoch}',
        lng: p.lng,
        lat: p.lat,
        layerId: _selectedPoiLayerId,
      );
      setState(() => _pois.add(poi));
      await _savePois();
      await _renderStep();
      if (!mounted) return;
      await _editPoiDialog(poi);
      return;
    }

    // Step 3: route points (Tracé & Style Pro)
    if (_step == 3) {
      final wizardProvider = context.read<WizardCircuitProvider>();
      wizardProvider.addRoutePoint(
            mbx.Point(coordinates: mbx.Position(p.lng, p.lat)),
          );
      await _renderRouteFromProvider();

      // Si l'utilisateur est en mode Directions (Auto/Hybride), on recalcule en continu.
      final route = wizardProvider.draft.route;
      if (route.mode == RouteMode.autoDriving || route.mode == RouteMode.hybrid) {
        _scheduleContinuousRouteRecalc(route.mode);
      }
      return;
    }

    if (_mode == _PerimeterUiMode.polygon) {
      setState(() {
        _polygonPoints.add(p);
      });
      await _renderStep();
      return;
    }

    // mode cercle
    setState(() {
      _circleCenter = p;
    });
    await _renderStep();
  }

  Future<MapboxDirectionsService?> _directions() async {
    final messenger = ScaffoldMessenger.of(context);
    final sync = MapboxTokenService.getTokenSync();
    final token = sync.isNotEmpty ? sync : await MapboxTokenService.getToken();
    if (token.isEmpty) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Token Mapbox manquant (MAPBOX_ACCESS_TOKEN).')),
        );
      }
      return null;
    }
    return MapboxDirectionsService(token);
  }

  Future<void> _renderRouteFromProvider() async {
    final draft = context.read<WizardCircuitProvider>().draft;
    final r = draft.route;

    // 1) points numérotés
    await _mapController.setMarkers([
      for (int i = 0; i < r.routePoints.length; i++)
        MapMarker(
          id: 'r$i',
          lng: r.routePoints[i].coordinates.lng.toDouble(),
          lat: r.routePoints[i].coordinates.lat.toDouble(),
          label: '${i + 1}',
          size: 1.1,
          color: const Color(0xFF0A84FF),
        ),
    ]);

    // 2) tracer segments si "connected" (géométrie)
    if (r.connected && r.routeGeometry.length >= 2) {
      final mp = r.routeGeometry
          .map(
            (p) => MapPoint(
              p.coordinates.lng.toDouble(),
              p.coordinates.lat.toDouble(),
            ),
          )
          .toList();
      await _mapController.setPolyline(
        points: mp,
        color: const Color(0xFF0A84FF),
        width: 4,
        show: true,
        roadLike: false,
      );
    } else {
      await _mapController.setPolyline(points: const [], show: false);
    }
  }

  Future<void> _connectRoutePoints() async {
    final p = context.read<WizardCircuitProvider>();
    final r = p.draft.route;
    if (r.routePoints.length < 2) return;
    p.setRouteConnected(true);
    p.setRouteMode(RouteMode.manual);
    p.setRouteGeometry([...r.routePoints]);
    await _renderRouteFromProvider();
    await _saveStep3RouteFromProvider();
  }

  Future<void> _applyAutoRoute() async {
    final r = context.read<WizardCircuitProvider>().draft.route;
    if (r.routePoints.length < 2) return;

    setState(() => _isSaving = true);
    final seq = ++_routeRecalcSeq;
    try {
      await _recalcRouteGeometry(mode: RouteMode.autoDriving, showFailureSnackBar: true, persist: true, seq: seq);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _applyHybridRoute() async {
    final r = context.read<WizardCircuitProvider>().draft.route;
    if (r.routePoints.length < 2) return;

    setState(() => _isSaving = true);
    final seq = ++_routeRecalcSeq;
    try {
      await _recalcRouteGeometry(mode: RouteMode.hybrid, showFailureSnackBar: true, persist: true, seq: seq);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _wizard,
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _projectRef.snapshots(),
        builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Wizard Pro')),
            body: Center(child: Text('Erreur: ${snap.error}')),
          );
        }

        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Wizard Pro')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final doc = snap.data!;
        final data = doc.data() ?? <String, dynamic>{};

        // On initialise l'état local une seule fois au premier snapshot.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_didInitFromFirestore) return;
          _didInitFromFirestore = true;
          _loadExistingPerimeter(data);
        });

        final title = (data['name'] as String?)?.trim();

        return Scaffold(
          appBar: AppBar(
            title: Text(title == null || title.isEmpty ? 'Wizard Pro' : 'Wizard Pro • $title'),
          ),
          body: Column(
            children: [
              Expanded(
                child: MasLiveMap(
                  controller: _mapController,
                  initialLng: _initialFocusPoint()?.lng ?? 2.3522,
                  initialLat: _initialFocusPoint()?.lat ?? 48.8566,
                  initialZoom: 14.0,
                  onTap: _onMapTap,
                  onMapReady: (_) async {
                    await _renderStep();
                    if (_step == 3 || _step == 4) await _fitToPerimeter();
                  },
                ),
              ),
              Container(
                height: 240,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: const Border(top: BorderSide(color: Color(0x11000000))),
                ),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      _step == 2 ? 'Étape 2/4 • Périmètre' : (_step == 3 ? 'Étape 3/4 • Tracé & Style Pro' : 'Étape 4/4 • POIs & Couches'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (_step == 2) ...[
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Libre'),
                            selected: _mode == _PerimeterUiMode.polygon,
                            onSelected: (v) async {
                              if (!v) return;
                              setState(() => _mode = _PerimeterUiMode.polygon);
                              await _renderStep();
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Cercle'),
                            selected: _mode == _PerimeterUiMode.circle,
                            onSelected: (v) async {
                              if (!v) return;
                              setState(() => _mode = _PerimeterUiMode.circle);
                              await _renderStep();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _mode == _PerimeterUiMode.polygon
                            ? 'Touchez la carte pour ajouter des points (marqueurs numérotés).'
                            : 'Touchez la carte pour définir le centre, puis ajustez le rayon.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      if (_mode == _PerimeterUiMode.circle) ...[
                        Row(
                          children: [
                            IconButton(
                              onPressed: () async {
                                setState(() {
                                  _circleRadiusMeters = math.max(25.0, _circleRadiusMeters - 25.0);
                                });
                                await _renderStep();
                              },
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text('${_circleRadiusMeters.toStringAsFixed(0)} m'),
                            IconButton(
                              onPressed: () async {
                                setState(() {
                                  _circleRadiusMeters = math.min(5000.0, _circleRadiusMeters + 25.0);
                                });
                                await _renderStep();
                              },
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      if (_mode == _PerimeterUiMode.polygon) ...[
                        Text('Points: ${_polygonPoints.length}', style: Theme.of(context).textTheme.bodySmall),
                        if (_polygonPoints.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          // Liste sous la carte (jamais par-dessus)
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _polygonPoints.length,
                            separatorBuilder: (_, _) => const Divider(height: 8),
                            itemBuilder: (context, i) {
                              final p = _polygonPoints[i];
                              return Row(
                                children: [
                                  SizedBox(
                                    width: 28,
                                    child: Text('${i + 1}.', style: Theme.of(context).textTheme.bodySmall),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${p.lat.toStringAsFixed(5)}, ${p.lng.toStringAsFixed(5)}',
                                      style: Theme.of(context).textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ] else ...[
                        Text(
                          _circleCenter == null
                              ? 'Centre: non défini'
                              : 'Centre: ${_circleCenter!.lat.toStringAsFixed(5)}, ${_circleCenter!.lng.toStringAsFixed(5)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                              child: const Text('Annuler'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _goToStep3,
                              child: _isSaving
                                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Text('Continuer'),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                    if (_step == 3) ...[

                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Points'),
                            selected: _routeUiMode == _RouteUiMode.points,
                            onSelected: (v) {
                              if (!v) return;
                              setState(() => _routeUiMode = _RouteUiMode.points);
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Style Pro'),
                            selected: _routeUiMode == _RouteUiMode.stylePro,
                            onSelected: (v) {
                              if (!v) return;
                              setState(() => _routeUiMode = _RouteUiMode.stylePro);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_routeUiMode == _RouteUiMode.points) ...[
                        Text(
                          'Touchez la carte pour ajouter des points de tracé, puis cliquez “Relier les points”.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        Builder(
                          builder: (context) {
                            final route = context.watch<WizardCircuitProvider>().draft.route;
                            final pts = route.routePoints;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('Points: ${pts.length}', style: Theme.of(context).textTheme.bodySmall),
                                if (pts.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: pts.length,
                                    separatorBuilder: (_, _) => const Divider(height: 8),
                                    itemBuilder: (context, i) {
                                      final p = pts[i].coordinates;
                                      return Row(
                                        children: [
                                          SizedBox(
                                            width: 28,
                                            child: Text('${i + 1}.', style: Theme.of(context).textTheme.bodySmall),
                                          ),
                                          Expanded(
                                            child: Text(
                                              '${p.lat.toDouble().toStringAsFixed(5)}, ${p.lng.toDouble().toStringAsFixed(5)}',
                                              style: Theme.of(context).textTheme.bodySmall,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton(
                                    onPressed: (_isSaving || pts.length < 2) ? null : _connectRoutePoints,
                                    child: const Text('Relier les points'),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ] else ...[
                        Text(
                          'Choisissez un mode de calcul du tracé.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _applyAutoRoute,
                                child: const Text('Auto'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isSaving ? null : _applyHybridRoute,
                                child: const Text('Hybride'),
                              ),
                            ),
                          ],
                        ),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isSaving ? null : _backToStep2,
                              child: const Text('Retour'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _goToStep4,
                              child: _isSaving
                                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Text('Continuer'),
                            ),
                          ),
                        ],
                      ),

                    ] else ...[

                      Text(
                        'Touchez la carte pour ajouter des POIs sur la couche sélectionnée.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('Couche:'),
                          const SizedBox(width: 12),
                          DropdownButton<String>(
                            value: _selectedPoiLayerId,
                            items: const [
                              DropdownMenuItem(value: 'pois', child: Text('POIs')),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _selectedPoiLayerId = v);
                            },
                          ),
                          const Spacer(),
                          Text('Total: \${_pois.length}', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_pois.isEmpty)
                        const Text('Aucun POI pour le moment. Touchez la carte pour en ajouter.')
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _pois.length,
                          separatorBuilder: (ctx, i) => const Divider(height: 8),
                          itemBuilder: (context, i) {
                            final poi = _pois[i];
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(poi.title.isEmpty ? 'POI \${i + 1}' : poi.title),
                              subtitle: Text('\${poi.lat.toStringAsFixed(5)}, \${poi.lng.toStringAsFixed(5)}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Modifier',
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _editPoiDialog(poi),
                                  ),
                                  IconButton(
                                    tooltip: 'Supprimer',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () async {
                                      setState(() => _pois.removeAt(i));
                                      await _savePois();
                                      await _renderStep();
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: _isSaving ? null : _backToStep3,
                              child: const Text('Retour'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _finish,
                              child: _isSaving
                                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Text('Terminer'),
                            ),
                          ),
                        ],
                      ),

                    ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
        },
      ),
    );
  }
}
