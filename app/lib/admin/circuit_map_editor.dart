import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'dart:async';
import 'dart:math' as math;
import '../services/mapbox_token_service.dart';
import '../ui/map/maslive_map.dart';
import '../ui/map/maslive_map_controller.dart';
import '../ui/widgets/glass_scrollbar.dart';
import '../ui_kit/glass/glass_panel.dart';
import '../ui_kit/tokens/maslive_tokens.dart';

typedef LngLat = ({double lng, double lat});

class CircuitMapEditorController extends ChangeNotifier {
  VoidCallback? _undo;
  VoidCallback? _redo;
  VoidCallback? _reversePath;
  VoidCallback? _closePath;
  VoidCallback? _openPath;
  VoidCallback? _simplifyTrack;
  VoidCallback? _clearAll;

  bool _canUndo = false;
  bool _canRedo = false;
  int _pointCount = 0;
  double _distanceKm = 0;

  bool get canUndo => _canUndo;
  bool get canRedo => _canRedo;
  int get pointCount => _pointCount;
  double get distanceKm => _distanceKm;

  void undo() => _undo?.call();
  void redo() => _redo?.call();
  void reversePath() => _reversePath?.call();
  void closePath() => _closePath?.call();
  void openPath() => _openPath?.call();
  void simplifyTrack() => _simplifyTrack?.call();
  void clearAll() => _clearAll?.call();

  void _attach({
    required VoidCallback undo,
    required VoidCallback redo,
    required VoidCallback reversePath,
    required VoidCallback closePath,
    required VoidCallback openPath,
    required VoidCallback simplifyTrack,
    required VoidCallback clearAll,
  }) {
    _undo = undo;
    _redo = redo;
    _reversePath = reversePath;
    _closePath = closePath;
    _openPath = openPath;
    _simplifyTrack = simplifyTrack;
    _clearAll = clearAll;
  }

  void _detach() {
    _undo = null;
    _redo = null;
    _reversePath = null;
    _closePath = null;
    _openPath = null;
    _simplifyTrack = null;
    _clearAll = null;
  }

  void _updateFromEditor({
    required bool canUndo,
    required bool canRedo,
    required int pointCount,
    required double distanceKm,
  }) {
    final changed =
        canUndo != _canUndo ||
        canRedo != _canRedo ||
        pointCount != _pointCount ||
        distanceKm != _distanceKm;

    _canUndo = canUndo;
    _canRedo = canRedo;
    _pointCount = pointCount;
    _distanceKm = distanceKm;

    if (changed) notifyListeners();
  }
}

class CircuitMapEditor extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<LngLat> points;
  final ValueChanged<List<LngLat>> onPointsChanged;
  final VoidCallback onSave;
  final String mode; // 'polygon' ou 'polyline'
  final bool showToolbar;
  final CircuitMapEditorController? controller;
  final String? styleUrl;

  /// Overlay optionnel affiché sur la carte (top-right).
  /// Permet au parent (wizard) d'injecter sa barre d'outils sans qu'elle
  /// recouvre le header/liste de points quand on scroll.
  final Widget? mapTopRightOverlay;

  /// Réglage bâtiments 3D (Style Pro): visible/masqué + opacité.
  /// Si null, l'éditeur ne touche pas aux bâtiments.
  final bool? buildings3dEnabled;
  final double? buildingsOpacity;

  /// Afficher (ou non) le header interne (titre + sous-titre).
  /// Utile quand la page parente affiche déjà le titre sous l'AppBar.
  final bool showHeader;

  /// Hauteur max de la liste des points en bas.
  /// Réduire cette valeur donne plus de place à la carte.
  final double pointsListMaxHeight;

  /// Si true, l'éditeur devient scrollable verticalement.
  /// Utile dans le wizard pour garder une carte plus grande sans écraser
  /// la liste des points sur petits écrans.
  final bool allowVerticalScroll;

  /// Hauteur fixe de la carte quand [allowVerticalScroll] est activé.
  /// Si null, une valeur par défaut basée sur la taille d'écran est utilisée.
  final double? mapHeight;

  /// Périmètre (polygon) affiché en surcouche, même en mode polyline.
  /// Typiquement: afficher le périmètre défini à l'étape précédente.
  final List<LngLat> perimeterOverlay;

  /// Si true, et si un périmètre est défini, la caméra est verrouillée dans
  /// les bounds du périmètre (anti-pan hors zone).
  final bool lockMapToPerimeter;

  /// Zoom initial (à l'ouverture de la carte).
  /// Si null, l'éditeur utilise sa valeur par défaut.
  final double? cameraInitialZoom;

  /// Zoom maximal autorisé (anti-zoom excessif).
  final double? cameraMaxZoom;

  /// Pitch (degrés) appliqué quand le zoom dépasse [cameraPitchZoomThreshold].
  final double? cameraPitchDegrees;

  /// Seuil de zoom à partir duquel on applique [cameraPitchDegrees].
  final double? cameraPitchZoomThreshold;

  /// Activer l'édition par clic sur carte (ajout de points).
  /// Utile pour des modes alternatifs (ex: périmètre cercle) où le tap sert
  /// à poser un repère plutôt qu'à ajouter des sommets.
  final bool editingEnabled;

  /// Override du comportement quand l'utilisateur clique sur la carte.
  /// Reçoit un point (lng/lat). Si fourni, l'éditeur ne rajoute pas de point
  /// automatiquement dans la liste.
  final ValueChanged<LngLat>? onPointAddedOverride;

  /// Affiche un repère (marker) optionnel sur la carte (ex: centre de cercle).
  final LngLat? centerMarker;

  /// Affiche (ou non) les markers des points de [points].
  final bool showPointMarkers;

  /// Affiche (ou non) la section liste des points.
  final bool showPointsList;

  // Style polyline (mode == 'polyline')
  final Color polylineColor;
  final double polylineWidth;
  final bool polylineRoadLike;
  final bool polylineShadow3d;
  final bool polylineShowDirection;
  final bool polylineAnimateDirection;
  final double polylineAnimationSpeed;
  final double? polylineOpacity;

  const CircuitMapEditor({
    super.key,
    required this.title,
    required this.subtitle,
    required this.points,
    required this.onPointsChanged,
    required this.onSave,
    this.mode = 'polygon',
    this.showToolbar = true,
    this.controller,
    this.styleUrl,
    this.mapTopRightOverlay,
    this.buildings3dEnabled,
    this.buildingsOpacity,

    this.showHeader = true,
    this.pointsListMaxHeight = 180,
    this.perimeterOverlay = const [],

    this.lockMapToPerimeter = false,
    this.cameraInitialZoom,
    this.cameraMaxZoom,
    this.cameraPitchDegrees,
    this.cameraPitchZoomThreshold,

    this.editingEnabled = true,
    this.onPointAddedOverride,
    this.centerMarker,
    this.showPointMarkers = true,
    this.showPointsList = true,

    this.allowVerticalScroll = false,
    this.mapHeight,

    this.polylineColor = const Color(0xFF0A84FF),
    this.polylineWidth = 4.0,
    this.polylineRoadLike = false,
    this.polylineShadow3d = false,
    this.polylineShowDirection = false,
    this.polylineAnimateDirection = false,
    this.polylineAnimationSpeed = 1.0,
    this.polylineOpacity,
  });

  @override
  State<CircuitMapEditor> createState() => _CircuitMapEditorState();
}

class _CircuitMapEditorState extends State<CircuitMapEditor> {
  late List<LngLat> _points;
  final List<List<LngLat>> _history = [];
  int _historyIndex = -1;
  final bool _isEditingEnabled = true;
  int? _selectedPointIndex;
  final double _simplificationThreshold = 0.0001;
  final bool _showToolbar = true;

  // Bloque le scroll parent pendant les gestes de carte (évite conflit scroll/page).
  int _mapPointerCount = 0;
  bool get _isMapInteracting => _mapPointerCount > 0;

  final MasLiveMapController _mapController = MasLiveMapController();
  final ScrollController _scrollController = ScrollController();
  bool _isMapReady = false;

  Timer? _cameraWatchTimer;
  double? _lastAppliedPitch;
  bool _lastHadBoundsLock = false;

  ({double west, double south, double east, double north}) _boundsFor(
    List<LngLat> pts,
  ) {
    var west = pts.first.lng;
    var east = pts.first.lng;
    var south = pts.first.lat;
    var north = pts.first.lat;
    for (final p in pts) {
      if (p.lng < west) west = p.lng;
      if (p.lng > east) east = p.lng;
      if (p.lat < south) south = p.lat;
      if (p.lat > north) north = p.lat;
    }
    return (west: west, south: south, east: east, north: north);
  }

  bool _isPolygonClosed(List<LngLat> pts) {
    if (pts.length < 3) return false;
    final dKm = _distanceBetween(pts.first, pts.last);
    return (dKm * 1000) <= 30.0;
  }

  List<LngLat> _perimeterForLock() {
    if (!widget.lockMapToPerimeter) return const [];

    // En mode tracé (polyline), on verrouille sur perimeterOverlay.
    if (widget.mode == 'polyline') {
      final overlay = widget.perimeterOverlay;
      if (overlay.length < 3) return const [];
      final first = overlay.first;
      final last = overlay.last;
      final isClosed =
          (first.lng == last.lng && first.lat == last.lat) ||
          _isPolygonClosed(overlay);
      return isClosed ? overlay : [...overlay, first];
    }

    // En mode périmètre, on verrouille quand le polygone est défini (bouclé).
    if (_points.length < 3) return const [];
    if (!_isPolygonClosed(_points)) return const [];
    return _points;
  }

  Future<void> _applyCameraConstraints() async {
    if (!_isMapReady) return;

    // 1) Zoom max
    final maxZoom = widget.cameraMaxZoom;
    if (maxZoom != null) {
      await _mapController.setZoomRange(maxZoom: maxZoom);
    }

    // 2) Verrouillage bounds périmètre
    final perim = _perimeterForLock();
    if (perim.length >= 3) {
      final b = _boundsFor(perim);
      await _mapController.setMaxBounds(
        west: b.west,
        south: b.south,
        east: b.east,
        north: b.north,
      );
      _lastHadBoundsLock = true;
    } else {
      if (_lastHadBoundsLock) {
        await _mapController.setMaxBounds();
        _lastHadBoundsLock = false;
      }
    }
  }

  void _syncCameraWatch() {
    _cameraWatchTimer?.cancel();
    _cameraWatchTimer = null;

    final threshold = widget.cameraPitchZoomThreshold;
    final pitch = widget.cameraPitchDegrees;
    if (!_isMapReady || threshold == null || pitch == null) return;

    _cameraWatchTimer = Timer.periodic(const Duration(milliseconds: 350), (_) {
      unawaited(_tickCameraWatch(threshold: threshold, pitch: pitch));
    });
  }

  Future<void> _tickCameraWatch({
    required double threshold,
    required double pitch,
  }) async {
    if (!_isMapReady) return;
    final state = await _mapController.getCameraState();
    if (state == null) return;
    final z = state.zoom;
    if (z.isNaN) return;

    final desiredPitch = (z >= threshold) ? pitch : 0.0;
    final prev = _lastAppliedPitch;
    if (prev != null && (prev - desiredPitch).abs() < 0.5) return;

    _lastAppliedPitch = desiredPitch;
    await _mapController.setPitch(pitch: desiredPitch.clamp(0.0, 60.0));
  }

  Future<void> _applyBuildings3dIfNeeded() async {
    final enabled = widget.buildings3dEnabled;
    if (enabled == null) return;
    final opacity = (widget.buildingsOpacity ?? 0.6).clamp(0.0, 1.0);
    await _mapController.setBuildings3d(enabled: enabled, opacity: opacity);
  }

  @override
  void initState() {
    super.initState();
    _points = List.from(widget.points);
    _saveToHistory();

    widget.controller?._attach(
      undo: _undo,
      redo: _redo,
      reversePath: _reversePath,
      closePath: _closePath,
      openPath: _openPath,
      simplifyTrack: _simplifyTrack,
      clearAll: _clearAll,
    );
    _syncController();
  }

  @override
  void didUpdateWidget(covariant CircuitMapEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    final cameraConfigChanged =
        oldWidget.lockMapToPerimeter != widget.lockMapToPerimeter ||
        oldWidget.cameraMaxZoom != widget.cameraMaxZoom ||
        oldWidget.cameraPitchDegrees != widget.cameraPitchDegrees ||
        oldWidget.cameraPitchZoomThreshold != widget.cameraPitchZoomThreshold;

    if (_isMapReady && cameraConfigChanged) {
      unawaited(_applyCameraConstraints());
      _syncCameraWatch();
    }

    if (_isMapReady &&
        oldWidget.cameraInitialZoom != widget.cameraInitialZoom) {
      final nextZoom = widget.cameraInitialZoom;
      if (nextZoom != null) {
        unawaited(() async {
          final state = await _mapController.getCameraState();
          if (state == null) return;
          await _mapController.moveTo(
            lng: state.center.lng,
            lat: state.center.lat,
            zoom: nextZoom,
            animate: true,
          );
        }());
      }
    }

    final buildingsChanged =
        oldWidget.buildings3dEnabled != widget.buildings3dEnabled ||
        oldWidget.buildingsOpacity != widget.buildingsOpacity;
    if (buildingsChanged && _isMapReady) {
      unawaited(_applyBuildings3dIfNeeded());
    }

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(
        undo: _undo,
        redo: _redo,
        reversePath: _reversePath,
        closePath: _closePath,
        openPath: _openPath,
        simplifyTrack: _simplifyTrack,
        clearAll: _clearAll,
      );
    }

    if (!listEquals(oldWidget.points, widget.points)) {
      _points = List.from(widget.points);
      _history
        ..clear()
        ..add(List.from(_points));
      _historyIndex = 0;
      _syncController();
      _renderOnMap();
    }

    if (!listEquals(oldWidget.perimeterOverlay, widget.perimeterOverlay)) {
      _renderOnMap();
    }

    final polyStyleChanged =
        oldWidget.polylineColor != widget.polylineColor ||
        oldWidget.polylineWidth != widget.polylineWidth ||
        oldWidget.polylineRoadLike != widget.polylineRoadLike ||
        oldWidget.polylineShadow3d != widget.polylineShadow3d ||
        oldWidget.polylineShowDirection != widget.polylineShowDirection ||
        oldWidget.polylineAnimateDirection != widget.polylineAnimateDirection ||
        oldWidget.polylineAnimationSpeed != widget.polylineAnimationSpeed ||
        oldWidget.polylineOpacity != widget.polylineOpacity;
    if (widget.mode == 'polyline' && polyStyleChanged) {
      _renderOnMap();
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _cameraWatchTimer?.cancel();
    _cameraWatchTimer = null;
    _scrollController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _renderOnMap() async {
    if (!_isMapReady) return;

    final mapPoints = _points.map((p) => MapPoint(p.lng, p.lat)).toList();

    List<MapPoint> closedOverlayPerimeterPoints() {
      final overlay = widget.perimeterOverlay;
      if (overlay.length < 3) return const [];
      final first = overlay.first;
      final last = overlay.last;
      final isClosed = first.lng == last.lng && first.lat == last.lat;
      final closed = isClosed ? overlay : [...overlay, first];
      return closed.map((p) => MapPoint(p.lng, p.lat)).toList();
    }

    final overlayPerimeter = closedOverlayPerimeterPoints();

    // Applique les contraintes caméra (bounds + zoom max) dès que le périmètre
    // devient "défini" (bouclé) ou que l'overlay périmètre est présent.
    await _applyCameraConstraints();

    try {
      await _mapController.clearAll();

      final hasAny = mapPoints.isNotEmpty || overlayPerimeter.isNotEmpty;
      if (!hasAny) return;

      // En mode polyline (tracé), on peut afficher le périmètre (polygon) en fond.
      if (widget.mode == 'polyline' && overlayPerimeter.length >= 4) {
        await _mapController.setPolygon(points: overlayPerimeter, show: true);
      }

      final markers = <MapMarker>[];
      if (widget.centerMarker != null) {
        markers.add(
          MapMarker(
            id: 'center',
            lng: widget.centerMarker!.lng,
            lat: widget.centerMarker!.lat,
            size: 1.2,
            label: 'C',
          ),
        );
      }
      if (widget.showPointMarkers && mapPoints.isNotEmpty) {
        markers.addAll([
          for (int i = 0; i < mapPoints.length; i++)
            MapMarker(
              id: 'p${i + 1}',
              lng: mapPoints[i].lng,
              lat: mapPoints[i].lat,
              size: 1.0,
              label: '${i + 1}',
            ),
        ]);
      }
      if (markers.isNotEmpty) {
        await _mapController.setMarkers(markers);
      }

      if (widget.mode == 'polygon') {
        final isClosed =
            _points.length >= 3 &&
            (_distanceBetween(_points.first, _points.last) * 1000) <= 30.0;
        if (isClosed) {
          await _mapController.setPolygon(
            points: mapPoints,
            show: mapPoints.length >= 3,
          );
        } else {
          // Important: éviter l'effet "polygone rempli" alors que le périmètre n'est pas bouclé.
          if (mapPoints.length >= 2) {
            await _mapController.setPolyline(
              points: mapPoints,
              show: true,
              color: const Color(0xFF0A84FF),
              width: 3.0,
              roadLike: false,
              shadow3d: false,
              showDirection: false,
              animateDirection: false,
              animationSpeed: 1.0,
              opacity: widget.polylineOpacity,
            );
          }
        }
      } else {
        if (mapPoints.isNotEmpty) {
          await _mapController.setPolyline(
            points: mapPoints,
            show: mapPoints.length >= 2,
            color: widget.polylineColor,
            width: widget.polylineWidth,
            roadLike: widget.polylineRoadLike,
            shadow3d: widget.polylineShadow3d,
            showDirection: widget.polylineShowDirection,
            animateDirection: widget.polylineAnimateDirection,
            animationSpeed: widget.polylineAnimationSpeed,
            opacity: widget.polylineOpacity,
          );
        }
      }
    } catch (_) {
      // Garder le wizard stable même si la carte n'est pas prête/interop KO.
    }
  }

  void _syncController() {
    widget.controller?._updateFromEditor(
      canUndo: _historyIndex > 0,
      canRedo: _historyIndex < _history.length - 1,
      pointCount: _points.length,
      distanceKm: _totalDistance(),
    );
  }

  // ============ Gestion historique (Undo/Redo) ============

  void _saveToHistory() {
    // Supprimer les redo après le point courant
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(List.from(_points));
    _historyIndex = _history.length - 1;
    _syncController();
  }

  void _undo() {
    if (_historyIndex > 0) {
      _historyIndex--;
      setState(() => _points = List.from(_history[_historyIndex]));
      widget.onPointsChanged(_points);
      _syncController();
      _renderOnMap();
    }
  }

  void _redo() {
    if (_historyIndex < _history.length - 1) {
      _historyIndex++;
      setState(() => _points = List.from(_history[_historyIndex]));
      widget.onPointsChanged(_points);
      _syncController();
      _renderOnMap();
    }
  }

  // ============ Édition points ============

  void _addPoint(LngLat point) {
    setState(() {
      _points.add(point);
      _selectedPointIndex = _points.length - 1;
    });
    _saveToHistory();
    widget.onPointsChanged(_points);
    _syncController();
    _renderOnMap();
  }

  void _removePoint(int index) {
    setState(() {
      _points.removeAt(index);
      _selectedPointIndex = null;
    });
    _saveToHistory();
    widget.onPointsChanged(_points);
    _syncController();
    _renderOnMap();
  }

  // ============ Outils avancés ============

  void _simplifyTrack() {
    // Algorithme Douglas-Peucker simplifié
    if (_points.length < 3) return;

    final simplified = _douglasPeucker(_points, _simplificationThreshold);
    setState(() => _points = simplified);
    _saveToHistory();
    widget.onPointsChanged(_points);
    _syncController();
    _renderOnMap();
  }

  List<LngLat> _douglasPeucker(List<LngLat> points, double epsilon) {
    if (points.length < 3) return points;

    double dmax = 0;
    int index = 0;
    for (int i = 1; i < points.length - 1; i++) {
      final d = _perpendiculardistance(
        points[i],
        points[0],
        points[points.length - 1],
      );
      if (d > dmax) {
        index = i;
        dmax = d;
      }
    }

    if (dmax > epsilon) {
      final rec1 = _douglasPeucker(points.sublist(0, index + 1), epsilon);
      final rec2 = _douglasPeucker(points.sublist(index), epsilon);
      return [...rec1.sublist(0, rec1.length - 1), ...rec2];
    }

    return [points[0], points[points.length - 1]];
  }

  double _perpendiculardistance(LngLat point, LngLat line1, LngLat line2) {
    final denom = _distanceBetween(line1, line2);
    if (denom == 0) return _distanceBetween(point, line1);

    final num =
        ((line2.lat - line1.lat) * point.lng -
                (line2.lng - line1.lng) * point.lat +
                line2.lng * line1.lat -
                line2.lat * line1.lng)
            .abs();

    return num / denom;
  }

  double _distanceBetween(LngLat p1, LngLat p2) {
    const earthRadiusKm = 6371;
    final dLat = _toRad(p2.lat - p1.lat);
    final dLng = _toRad(p2.lng - p1.lng);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(p1.lat)) *
            math.cos(_toRad(p2.lat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _toRad(double deg) => deg * math.pi / 180;

  void _reversePath() {
    setState(() => _points = _points.reversed.toList());
    _saveToHistory();
    widget.onPointsChanged(_points);
    _syncController();
    _renderOnMap();
  }

  void _closePath() {
    if (_points.length < 2) return;
    if (_points.first != _points.last) {
      setState(() => _points.add(_points.first));
      _saveToHistory();
      widget.onPointsChanged(_points);
      _syncController();
      _renderOnMap();
    }
  }

  void _openPath() {
    if (_points.length < 2) return;
    if (_points.first == _points.last) {
      setState(() {
        _points.removeLast();
        _selectedPointIndex = _points.isNotEmpty ? _points.length - 1 : null;
      });
      _saveToHistory();
      widget.onPointsChanged(_points);
      _syncController();
      _renderOnMap();
    }
  }

  bool get _isClosedLoop {
    if (_points.length < 2) return false;
    return _points.first == _points.last;
  }

  Future<void> _promptCloseLoopIfNeeded() async {
    if (!mounted) return;
    if (widget.mode != 'polyline') return;
    if (_points.length < 2) return;
    if (_isClosedLoop) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Boucler le circuit ?'),
        content: const Text(
          'Voulez-vous fermer le tracé en plaçant le dernier point sur la même position que le 1er point (Départ) ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Oui, boucler'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _closePath();
    }
  }

  void _setArrivalPoint(int index) {
    if (widget.mode != 'polyline') return;
    if (_points.length < 2) return;
    if (index <= 0) return; // départ intouchable

    // Si le tracé est bouclé (dernier == premier), on enlève le point de bouclage.
    final points = List<LngLat>.from(_points);
    if (points.length >= 2 && points.first == points.last) {
      points.removeLast();
    }

    if (index >= points.length) return;

    final picked = points.removeAt(index);
    points.add(picked);

    setState(() {
      _points = points;
      _selectedPointIndex = points.length - 1;
    });
    _saveToHistory();
    widget.onPointsChanged(_points);
    _syncController();
    _renderOnMap();
  }

  String _pointRoleLabel(int index) {
    if (index == 0) return 'Départ';
    if (_isClosedLoop && index == _points.length - 1) return 'Bouclage';
    if (widget.mode == 'polyline' &&
        !_isClosedLoop &&
        index == _points.length - 1) {
      return 'Arrivée';
    }
    return 'Point';
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Effacer tous les points ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _points.clear());
              _saveToHistory();
              widget.onPointsChanged(_points);
              _syncController();
              _renderOnMap();
            },
            child: const Text('Effacer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ============ Calculate stats ============

  double _totalDistance() {
    double total = 0;
    for (int i = 0; i < _points.length - 1; i++) {
      total += _distanceBetween(_points[i], _points[i + 1]);
    }
    return total;
  }

  // ============ Build ============

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final scale = (w / 390.0).clamp(0.85, 1.15);
    const toolbarSectionStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w800,
      color: MasliveTokens.text,
      letterSpacing: 0.1,
    );
    final toolbarHintStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: MasliveTokens.textSoft,
    );

    final header = widget.showHeader
        ? Padding(
            padding: const EdgeInsets.fromLTRB(
              MasliveTokens.m,
              MasliveTokens.m,
              MasliveTokens.m,
              MasliveTokens.s,
            ),
            child: GlassPanel(
              padding: const EdgeInsets.all(MasliveTokens.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 18 * scale,
                      fontWeight: FontWeight.w800,
                      color: MasliveTokens.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    textAlign: TextAlign.justify,
                    style: TextStyle(
                      fontSize: 13 * scale,
                      fontWeight: FontWeight.w600,
                      color: MasliveTokens.textSoft,
                    ),
                  ),
                ],
              ),
            ),
          )
        : const SizedBox.shrink();

    final toolbar = (_showToolbar && widget.showToolbar)
        ? Padding(
            padding: const EdgeInsets.fromLTRB(
              MasliveTokens.m,
              0,
              MasliveTokens.m,
              MasliveTokens.s,
            ),
            child: GlassPanel(
              radius: MasliveTokens.rM,
              opacity: 0.90,
              padding: const EdgeInsets.symmetric(
                horizontal: MasliveTokens.s,
                vertical: MasliveTokens.xs,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.undo),
                      onPressed: _historyIndex > 0 ? _undo : null,
                      tooltip: 'Annuler',
                    ),
                    IconButton(
                      icon: const Icon(Icons.redo),
                      onPressed: _historyIndex < _history.length - 1
                          ? _redo
                          : null,
                      tooltip: 'Rétablir',
                    ),
                    const VerticalDivider(),
                    if (widget.mode == 'polygon')
                      IconButton(
                        icon: const Icon(Icons.loop_rounded),
                        onPressed: _closePath,
                        tooltip: 'Fermer le polygone',
                      ),
                    IconButton(
                      icon: const Icon(Icons.flip_to_back),
                      onPressed: _reversePath,
                      tooltip: 'Inverser sens',
                    ),
                    IconButton(
                      icon: const Icon(Icons.compress_rounded),
                      onPressed: _simplifyTrack,
                      tooltip: 'Simplifier tracé',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_sweep),
                      onPressed: _clearAll,
                      tooltip: 'Effacer tous',
                    ),
                    const VerticalDivider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MasliveTokens.s,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_points.length} points',
                            style: toolbarSectionStyle,
                          ),
                          Text(
                            '${_totalDistance().toStringAsFixed(2)} km',
                            style: toolbarHintStyle,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        : const SizedBox.shrink();

    if (widget.allowVerticalScroll) {
      final screenH = MediaQuery.of(context).size.height;
      final mapH = widget.mapHeight ?? (screenH * 0.62).clamp(380.0, 820.0);

      return GlassScrollbar(
        controller: _scrollController,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: _isMapInteracting
              ? const NeverScrollableScrollPhysics()
              : null,
          child: Column(
            children: [
              if (widget.showHeader) header,
              if (_showToolbar && widget.showToolbar) toolbar,
              SizedBox(
                height: mapH,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (_) {
                    if (!mounted) return;
                    setState(() => _mapPointerCount++);
                  },
                  onPointerUp: (_) {
                    if (!mounted) return;
                    setState(
                      () => _mapPointerCount = math.max(0, _mapPointerCount - 1),
                    );
                  },
                  onPointerCancel: (_) {
                    if (!mounted) return;
                    setState(
                      () => _mapPointerCount = math.max(0, _mapPointerCount - 1),
                    );
                  },
                  child: _buildMap(),
                ),
              ),
              _buildPointsSection(),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        if (widget.showHeader) header,
        if (_showToolbar && widget.showToolbar) toolbar,
        Expanded(child: _buildMap()),
        _buildPointsSection(),
      ],
    );
  }

  Widget _buildPointsSection() {
    if (!widget.showPointsList) {
      return const SizedBox.shrink();
    }

    if (_points.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          MasliveTokens.m,
          0,
          MasliveTokens.m,
          MasliveTokens.m,
        ),
        child: GlassPanel(
          radius: MasliveTokens.rM,
          opacity: 0.82,
          padding: const EdgeInsets.fromLTRB(
            MasliveTokens.m,
            MasliveTokens.s,
            MasliveTokens.m,
            MasliveTokens.s,
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: MasliveTokens.textSoft),
              const SizedBox(width: MasliveTokens.xs),
              Expanded(
                child: Text(
                  'Liste des points: ajoutez des points sur la carte',
                  textAlign: TextAlign.justify,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: MasliveTokens.textSoft,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MasliveTokens.m,
        0,
        MasliveTokens.m,
        MasliveTokens.m,
      ),
      child: GlassPanel(
        radius: MasliveTokens.rL,
        opacity: 0.84,
        padding: const EdgeInsets.fromLTRB(
          0,
          MasliveTokens.s,
          0,
          MasliveTokens.s,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                MasliveTokens.m,
                0,
                MasliveTokens.m,
                MasliveTokens.xs,
              ),
              child: Text(
                'Liste des points',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: MasliveTokens.text,
                ),
              ),
            ),
            Divider(height: 1, color: MasliveTokens.borderSoft),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: widget.pointsListMaxHeight,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _points.length,
                itemBuilder: (context, index) {
                  final point = _points[index];
                  final isSelected = _selectedPointIndex == index;
                  final role = _pointRoleLabel(index);
                  return ListTile(
                    dense: true,
                    selected: isSelected,
                    selectedTileColor: MasliveTokens.primary.withValues(
                      alpha: 0.08,
                    ),
                    leading: CircleAvatar(
                      radius: 12,
                      backgroundColor: isSelected
                          ? MasliveTokens.primary
                          : MasliveTokens.textSoft.withValues(alpha: 0.30),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      '${index + 1}/ $role',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: role == 'Point'
                            ? FontWeight.w600
                            : FontWeight.bold,
                        color: MasliveTokens.text,
                      ),
                    ),
                    subtitle: Text(
                      '${point.lng.toStringAsFixed(5)}, ${point.lat.toStringAsFixed(5)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: MasliveTokens.textSoft,
                      ),
                    ),
                    trailing: PopupMenuButton(
                      itemBuilder: (ctx) => [
                        if (widget.mode == 'polyline' &&
                            index > 0 &&
                            index != _points.length - 1)
                          PopupMenuItem(
                            child: Text(
                              'Définir comme Arrivée (point ${index + 1})',
                            ),
                            onTap: () => _setArrivalPoint(index),
                          ),
                        PopupMenuItem(
                          child: Text('Supprimer (point ${index + 1})'),
                          onTap: () => _removePoint(index),
                        ),
                      ],
                    ),
                    onTap: () async {
                      setState(() => _selectedPointIndex = index);
                      if (index == 0 && _points.length >= 2) {
                        await _promptCloseLoopIfNeeded();
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    Widget interceptPointersIfNeeded(Widget child) {
      // Sur Flutter web + HtmlElementView (Mapbox), certains clics peuvent
      // "traverser" les overlays et déclencher aussi le handler JS du map.
      // PointerInterceptor évite ce click-through.
      if (!kIsWeb) return child;
      return PointerInterceptor(child: child);
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final overlayTopInset =
        widget.mapTopRightOverlay != null && screenWidth < 1180 ? 72.0 : 12.0;

    final token = MapboxTokenService.getTokenSync();

    if (token.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            const Text('Token Mapbox manquant'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Retour'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        MasLiveMap(
          controller: _mapController,
          initialLng: _points.isNotEmpty
              ? _points.first.lng
              : (widget.perimeterOverlay.isNotEmpty
                    ? widget.perimeterOverlay.first.lng
                    : -61.533),
          initialLat: _points.isNotEmpty
              ? _points.first.lat
              : (widget.perimeterOverlay.isNotEmpty
                    ? widget.perimeterOverlay.first.lat
                    : 16.241),
          initialZoom:
              widget.cameraInitialZoom ??
              ((_points.isNotEmpty || widget.perimeterOverlay.isNotEmpty)
                  ? 15.0
                  : 12.0),
          initialPitch: () {
            final threshold = widget.cameraPitchZoomThreshold;
            final pitch = widget.cameraPitchDegrees;
            final z =
                widget.cameraInitialZoom ??
                ((_points.isNotEmpty || widget.perimeterOverlay.isNotEmpty)
                    ? 15.0
                    : 12.0);
            if (threshold == null || pitch == null) return 0.0;
            return z >= threshold ? pitch.clamp(0.0, 60.0) : 0.0;
          }(),
          styleUrl:
              (widget.styleUrl != null && widget.styleUrl!.trim().isNotEmpty)
              ? widget.styleUrl!.trim()
              : null,
          onMapReady: (ctrl) async {
            _isMapReady = true;
            await ctrl.setEditingEnabled(
              enabled: _isEditingEnabled && widget.editingEnabled,
              onPointAdded: (lat, lng) {
                if (!_isEditingEnabled || !widget.editingEnabled) return;
                final override = widget.onPointAddedOverride;
                if (override != null) {
                  override((lng: lng, lat: lat));
                  return;
                }
                _addPoint((lng: lng, lat: lat));
              },
            );
            await _applyCameraConstraints();
            _syncCameraWatch();
            await _renderOnMap();
            await _applyBuildings3dIfNeeded();
          },
        ),
        Positioned(
          left: 12,
          top: 12,
          child: interceptPointersIfNeeded(
            GlassPanel(
              radius: MasliveTokens.rM,
              opacity: 0.90,
              padding: const EdgeInsets.symmetric(
                horizontal: MasliveTokens.m,
                vertical: MasliveTokens.xs,
              ),
              child: Text(
                widget.mode == 'polygon'
                    ? 'Cliquez pour ajouter des points (polygone)'
                    : 'Cliquez pour ajouter des points (route)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MasliveTokens.text,
                ),
              ),
            ),
          ),
        ),

        if (widget.mapTopRightOverlay != null)
          Positioned(
            right: 12,
            top: overlayTopInset,
            child: interceptPointersIfNeeded(widget.mapTopRightOverlay!),
          ),
      ],
    );
  }
}

class PathPainter extends CustomPainter {
  final List<LngLat> points;
  final String mode;

  PathPainter({required this.points, this.mode = 'polygon'});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    // Conversion approximative lng/lat en pixels
    Offset convertPoint(LngLat p) {
      final x = (p.lng + 61.5) * 3000; // Approximatif
      final y = (16.2 - p.lat) * 2000; // Approximatif
      return Offset(x.clamp(0, size.width), y.clamp(0, size.height));
    }

    final path = Path();
    path.moveTo(convertPoint(points[0]).dx, convertPoint(points[0]).dy);
    for (int i = 1; i < points.length; i++) {
      final p = convertPoint(points[i]);
      path.lineTo(p.dx, p.dy);
    }

    if (mode == 'polygon' && points.length > 2) {
      path.close();
    }

    // Ligne
    canvas.drawPath(
      path,
      Paint()
        ..color = MasliveTokens.primary
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );

    // Points
    for (final p in points) {
      final offset = convertPoint(p);
      canvas.drawCircle(offset, 8, Paint()..color = MasliveTokens.primary);
      canvas.drawCircle(offset, 4, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(PathPainter oldDelegate) => oldDelegate.points != points;
}
