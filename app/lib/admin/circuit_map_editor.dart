import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/mapbox_token_service.dart';

typedef LngLat = ({double lng, double lat});

class CircuitMapEditor extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<LngLat> points;
  final ValueChanged<List<LngLat>> onPointsChanged;
  final VoidCallback onSave;
  final String mode; // 'polygon' ou 'polyline'

  const CircuitMapEditor({
    super.key,
    required this.title,
    required this.subtitle,
    required this.points,
    required this.onPointsChanged,
    required this.onSave,
    this.mode = 'polygon',
  });

  @override
  State<CircuitMapEditor> createState() => _CircuitMapEditorState();
}

class _CircuitMapEditorState extends State<CircuitMapEditor> {
  late List<LngLat> _points;
  final List<List<LngLat>> _history = [];
  int _historyIndex = -1;
  bool _isEditingEnabled = true;
  int? _selectedPointIndex;
  double _simplificationThreshold = 0.0001;
  bool _showToolbar = true;

  @override
  void initState() {
    super.initState();
    _points = List.from(widget.points);
    _saveToHistory();
  }

  // ============ Gestion historique (Undo/Redo) ============

  void _saveToHistory() {
    // Supprimer les redo après le point courant
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(List.from(_points));
    _historyIndex = _history.length - 1;
  }

  void _undo() {
    if (_historyIndex > 0) {
      _historyIndex--;
      setState(() => _points = List.from(_history[_historyIndex]));
      widget.onPointsChanged(_points);
    }
  }

  void _redo() {
    if (_historyIndex < _history.length - 1) {
      _historyIndex++;
      setState(() => _points = List.from(_history[_historyIndex]));
      widget.onPointsChanged(_points);
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
  }

  void _removePoint(int index) {
    setState(() {
      _points.removeAt(index);
      _selectedPointIndex = null;
    });
    _saveToHistory();
    widget.onPointsChanged(_points);
  }

  void _movePoint(int index, LngLat newPoint) {
    setState(() {
      _points[index] = newPoint;
    });
    _saveToHistory();
    widget.onPointsChanged(_points);
  }

  void _insertPointAfter(int index, LngLat point) {
    setState(() {
      _points.insert(index + 1, point);
    });
    _saveToHistory();
    widget.onPointsChanged(_points);
  }

  // ============ Outils avancés ============

  void _snapToExistingPoints(int index, double snapDistance) {
    final point = _points[index];
    for (int i = 0; i < _points.length; i++) {
      if (i == index) continue;
      final other = _points[i];
      final distance = _distanceBetween(point, other);
      if (distance < snapDistance) {
        _movePoint(index, other);
        return;
      }
    }
  }

  void _simplifyTrack() {
    // Algorithme Douglas-Peucker simplifié
    if (_points.length < 3) return;

    final simplified = _douglasPeucker(_points, _simplificationThreshold);
    setState(() => _points = simplified);
    _saveToHistory();
    widget.onPointsChanged(_points);
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
  }

  void _closePath() {
    if (_points.length < 2) return;
    if (_points.first != _points.last) {
      setState(() => _points.add(_points.first));
      _saveToHistory();
      widget.onPointsChanged(_points);
    }
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
          color: Colors.grey.shade100,
          padding: const EdgeInsets.all(16),
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
        if (_showToolbar)
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

        // Point list
        if (_points.isNotEmpty)
          Container(
            color: Colors.white,
            constraints: const BoxConstraints(maxHeight: 120),
            child: ListView.builder(
              itemCount: _points.length,
              itemBuilder: (context, index) {
                final point = _points[index];
                final isSelected = _selectedPointIndex == index;
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
                    '${point.lng.toStringAsFixed(5)}, ${point.lat.toStringAsFixed(5)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: PopupMenuButton(
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        child: const Text('Supprimer'),
                        onTap: () => _removePoint(index),
                      ),
                    ],
                  ),
                  onTap: () => setState(() => _selectedPointIndex = index),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildMap() {
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

    // Pour la démo, afficher un placeholder
    // En production, intégrer la vraie carte Mapbox
    return GestureDetector(
      onTapDown: (details) {
        if (_isEditingEnabled) {
          // Convertir les coordonnées d'écran en lng/lat (approximatif)
          // À remplacer par l'intégration vraie Mapbox
          final lng = -61.5 + (details.localPosition.dx / 300) * 0.1;
          final lat = 16.2 + (details.localPosition.dy / 200) * 0.1;
          _addPoint((lng: lng, lat: lat));
        }
      },
      child: Container(
        color: Colors.grey.shade200,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Placeholder map
            Container(
              color: Colors.blue.withValues(alpha: 0.1),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.map, size: 48, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Cliquez pour ajouter des points',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    if (_points.isNotEmpty)
                      Text(
                        '${_points.length} points tracés',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Points visualization
            CustomPaint(
              painter: PathPainter(
                points: _points,
                mode: widget.mode,
              ),
              size: Size.fromHeight(400),
            ),
          ],
        ),
      ),
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
    final convertPoint = (LngLat p) {
      final x = (p.lng + 61.5) * 3000; // Approximatif
      final y = (16.2 - p.lat) * 2000; // Approximatif
      return Offset(x.clamp(0, size.width), y.clamp(0, size.height));
    };

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
