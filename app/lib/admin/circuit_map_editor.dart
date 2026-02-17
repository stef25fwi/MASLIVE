import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'dart:math' as math;
import '../services/mapbox_token_service.dart';
import '../ui/map/maslive_map.dart';
import '../ui/map/maslive_map_controller.dart';

typedef LngLat = ({double lng, double lat});

class CircuitMapEditorController extends ChangeNotifier {
  VoidCallback? _undo;
  VoidCallback? _redo;
  VoidCallback? _reversePath;
  VoidCallback? _closePath;
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
  void simplifyTrack() => _simplifyTrack?.call();
  void clearAll() => _clearAll?.call();

  void _attach({
    required VoidCallback undo,
    required VoidCallback redo,
    required VoidCallback reversePath,
    required VoidCallback closePath,
    required VoidCallback simplifyTrack,
    required VoidCallback clearAll,
  }) {
    _undo = undo;
    _redo = redo;
    _reversePath = reversePath;
    _closePath = closePath;
    _simplifyTrack = simplifyTrack;
    _clearAll = clearAll;
  }

  void _detach() {
    _undo = null;
    _redo = null;
    _reversePath = null;
    _closePath = null;
    _simplifyTrack = null;
    _clearAll = null;
  }

  void _updateFromEditor({
    required bool canUndo,
    required bool canRedo,
    required int pointCount,
    required double distanceKm,
  }) {
    final changed = canUndo != _canUndo ||
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

  // Style polyline (mode == 'polyline')
  final Color polylineColor;
  final double polylineWidth;
  final bool polylineRoadLike;
  final bool polylineShadow3d;
  final bool polylineShowDirection;
  final bool polylineAnimateDirection;
  final double polylineAnimationSpeed;

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

    this.polylineColor = const Color(0xFF0A84FF),
    this.polylineWidth = 4.0,
    this.polylineRoadLike = false,
    this.polylineShadow3d = false,
    this.polylineShowDirection = false,
    this.polylineAnimateDirection = false,
    this.polylineAnimationSpeed = 1.0,
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

  final MasLiveMapController _mapController = MasLiveMapController();
  bool _isMapReady = false;

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
      simplifyTrack: _simplifyTrack,
      clearAll: _clearAll,
    );
    _syncController();
  }

  @override
  void didUpdateWidget(covariant CircuitMapEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(
        undo: _undo,
        redo: _redo,
        reversePath: _reversePath,
        closePath: _closePath,
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

    final polyStyleChanged =
        oldWidget.polylineColor != widget.polylineColor ||
        oldWidget.polylineWidth != widget.polylineWidth ||
        oldWidget.polylineRoadLike != widget.polylineRoadLike ||
        oldWidget.polylineShadow3d != widget.polylineShadow3d ||
        oldWidget.polylineShowDirection != widget.polylineShowDirection ||
        oldWidget.polylineAnimateDirection != widget.polylineAnimateDirection ||
        oldWidget.polylineAnimationSpeed != widget.polylineAnimationSpeed;
    if (widget.mode == 'polyline' && polyStyleChanged) {
      _renderOnMap();
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _renderOnMap() async {
    if (!_isMapReady) return;

    final mapPoints = _points.map((p) => MapPoint(p.lng, p.lat)).toList();

    try {
      await _mapController.clearAll();

      if (mapPoints.isEmpty) return;

      await _mapController.setMarkers([
        for (int i = 0; i < mapPoints.length; i++)
          MapMarker(
            id: 'p${i + 1}',
            lng: mapPoints[i].lng,
            lat: mapPoints[i].lat,
            size: 1.0,
            label: '${i + 1}',
          ),
      ]);

      if (widget.mode == 'polygon') {
        await _mapController.setPolygon(
          points: mapPoints,
          show: mapPoints.length >= 3,
        );
      } else {
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
        );
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
      final d = _perpendiculardistance(points[i], points[0], points[points.length - 1]);
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

    final num = ((line2.lat - line1.lat) * point.lng -
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
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
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
    if (widget.mode == 'polyline' && !_isClosedLoop && index == _points.length - 1) {
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
    return Column(
      children: [
        // Header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                widget.subtitle,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),

        // Toolbar
        if (_showToolbar && widget.showToolbar)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Undo/Redo
                  IconButton(
                    icon: const Icon(Icons.undo),
                    onPressed: _historyIndex > 0 ? _undo : null,
                    tooltip: 'Annuler',
                  ),
                  IconButton(
                    icon: const Icon(Icons.redo),
                    onPressed: _historyIndex < _history.length - 1 ? _redo : null,
                    tooltip: 'Rétablir',
                  ),
                  const VerticalDivider(),

                  // Tools
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

                  // Stats
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_points.length} points',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_totalDistance().toStringAsFixed(2)} km',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Map
        Expanded(
          child: _buildMap(),
        ),
      ],
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
          initialLng: _points.isNotEmpty ? _points.first.lng : -61.533,
          initialLat: _points.isNotEmpty ? _points.first.lat : 16.241,
          initialZoom: _points.isNotEmpty ? 15.0 : 12.0,
          styleUrl: (widget.styleUrl != null && widget.styleUrl!.trim().isNotEmpty)
              ? widget.styleUrl!.trim()
              : null,
          onMapReady: (ctrl) async {
            _isMapReady = true;
            await ctrl.setEditingEnabled(
              enabled: _isEditingEnabled,
              onPointAdded: (lat, lng) {
                if (!_isEditingEnabled) return;
                _addPoint((lng: lng, lat: lat));
              },
            );
            await _renderOnMap();
          },
        ),
        Positioned(
          left: 12,
          top: 12,
          child: interceptPointersIfNeeded(
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  widget.mode == 'polygon'
                      ? 'Cliquez pour ajouter des points (polygone)'
                      : 'Cliquez pour ajouter des points (route)',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
        ),

        if (_points.isNotEmpty)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: interceptPointersIfNeeded(
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: ListView.builder(
                    itemCount: _points.length,
                    itemBuilder: (context, index) {
                      final point = _points[index];
                      final isSelected = _selectedPointIndex == index;
                      final role = _pointRoleLabel(index);
                      return ListTile(
                        dense: true,
                        selected: isSelected,
                        leading: CircleAvatar(
                          radius: 12,
                          backgroundColor: isSelected ? Colors.blue : Colors.grey,
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
                          ),
                        ),
                        subtitle: Text(
                          '${point.lng.toStringAsFixed(5)}, ${point.lat.toStringAsFixed(5)}',
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (ctx) => [
                            if (widget.mode == 'polyline' &&
                                index > 0 &&
                                index != _points.length - 1)
                              PopupMenuItem(
                                child: Text(
                                    'Définir comme Arrivée (point ${index + 1})'),
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
              ),
            ),
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
        ..color = Colors.blue
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );

    // Points
    for (final p in points) {
      final offset = convertPoint(p);
      canvas.drawCircle(
        offset,
        8,
        Paint()..color = Colors.blue,
      );
      canvas.drawCircle(
        offset,
        4,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(PathPainter oldDelegate) => oldDelegate.points != points;
}
