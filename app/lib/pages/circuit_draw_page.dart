import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class CircuitDrawPage extends StatefulWidget {
  const CircuitDrawPage({super.key});

  @override
  State<CircuitDrawPage> createState() => _CircuitDrawPageState();
}

class _CircuitDrawPageState extends State<CircuitDrawPage> {
  final MapController _map = MapController();
  final List<LatLng> _points = [];
  final List<List<LatLng>> _undoStack = [];
  final List<List<LatLng>> _redoStack = [];

  bool _drawMode = true;

  void _pushUndoSnapshot() {
    _undoStack.add(List<LatLng>.from(_points));
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(List<LatLng>.from(_points));
    final prev = _undoStack.removeLast();
    setState(() {
      _points
        ..clear()
        ..addAll(prev);
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(List<LatLng>.from(_points));
    final next = _redoStack.removeLast();
    setState(() {
      _points
        ..clear()
        ..addAll(next);
    });
  }

  void _addPoint(LatLng p) {
    _pushUndoSnapshot();
    setState(() => _points.add(p));
  }

  void _movePoint(int index, LatLng p) {
    if (index < 0 || index >= _points.length) return;
    _pushUndoSnapshot();
    setState(() => _points[index] = p);
  }

  void _removePoint(int index) {
    if (index < 0 || index >= _points.length) return;
    _pushUndoSnapshot();
    setState(() => _points.removeAt(index));
  }

  double _distanceMeters() {
    double total = 0;
    for (int i = 0; i < _points.length - 1; i++) {
      total += _haversineMeters(_points[i], _points[i + 1]);
    }
    return total;
  }

  double _haversineMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLon = _deg2rad(b.longitude - a.longitude);
    final lat1 = _deg2rad(a.latitude);
    final lat2 = _deg2rad(b.latitude);

    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return r * c;
  }

  double _deg2rad(double deg) => deg * math.pi / 180.0;

  String _fmtKm(double meters) {
    final km = meters / 1000.0;
    return km.toStringAsFixed(km < 10 ? 2 : 1);
  }

  LatLngBounds _boundsOf(List<LatLng> points) {
    if (points.isEmpty) {
      return LatLngBounds(const LatLng(0, 0), const LatLng(0, 0));
    }
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLon = points.first.longitude;
    double maxLon = points.first.longitude;

    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLon = math.min(minLon, p.longitude);
      maxLon = math.max(maxLon, p.longitude);
    }
    return LatLngBounds(LatLng(minLat, minLon), LatLng(maxLat, maxLon));
  }

  Future<void> _saveCircuit() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Circuit prêt (${_points.length} points)")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dist = _distanceMeters();
    final hasTrack = _points.length >= 2;

    final polyline = Polyline(
      points: _points,
      strokeWidth: 6,
      color: const Color(0xFF1A73E8),
      borderStrokeWidth: 2,
      borderColor: Colors.white,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Dessiner un Circuit", style: TextStyle(fontWeight: FontWeight.w700)),
            Text(
              _drawMode ? "Tracer et éditer le circuit" : "Édition des points",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: hasTrack ? _saveCircuit : null,
            child: const Text("Terminer"),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _points.isNotEmpty ? _points.first : const LatLng(16.241, -61.533),
              initialZoom: 12,
              onTap: (tapPos, latlng) {
                if (_drawMode) _addPoint(latlng);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: "com.example.maslive",
              ),
              if (_points.isNotEmpty)
                PolylineLayer(
                  polylines: [polyline],
                ),
              MarkerLayer(
                markers: List.generate(_points.length, (i) {
                  final p = _points[i];
                  return Marker(
                    width: 56,
                    height: 56,
                    point: p,
                    child: _DraggablePointMarker(
                      index: i,
                      isStart: i == 0,
                      isEnd: i == _points.length - 1 && _points.length >= 2,
                      onMove: (newPos) => _movePoint(i, newPos),
                      onDelete: () => _removePoint(i),
                    ),
                  );
                }),
              ),
            ],
          ),
          Positioned(
            left: 14,
            top: 18,
            child: _ToolColumn(
              drawMode: _drawMode,
              canUndo: _undoStack.isNotEmpty,
              canRedo: _redoStack.isNotEmpty,
              onToggleMode: () => setState(() => _drawMode = !_drawMode),
              onUndo: _undo,
              onRedo: _redo,
              onCenterOnTrack: () {
                if (_points.isEmpty) return;
                final bounds = _boundsOf(_points);
                _map.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)));
              },
              onClear: () {
                if (_points.isEmpty) return;
                _pushUndoSnapshot();
                setState(() => _points.clear());
              },
            ),
          ),
          Positioned(
            right: 14,
            top: 18,
            child: _Pill(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.route, size: 18),
                  const SizedBox(width: 8),
                  Text("${_fmtKm(dist)} km", style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DraggablePointMarker extends StatelessWidget {
  final int index;
  final bool isStart;
  final bool isEnd;
  final Function(LatLng) onMove;
  final VoidCallback onDelete;

  const _DraggablePointMarker({
    required this.index,
    required this.isStart,
    required this.isEnd,
    required this.onMove,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = isStart ? Colors.green : (isEnd ? Colors.red : Colors.blue);

    return GestureDetector(
      onLongPress: onDelete,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Text(
            "${index + 1}",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
      ),
    );
  }
}

class _ToolColumn extends StatelessWidget {
  final bool drawMode;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onToggleMode;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onCenterOnTrack;
  final VoidCallback onClear;

  const _ToolColumn({
    required this.drawMode,
    required this.canUndo,
    required this.canRedo,
    required this.onToggleMode,
    required this.onUndo,
    required this.onRedo,
    required this.onCenterOnTrack,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ToolButton(
          icon: drawMode ? Icons.edit_off : Icons.edit,
          onPressed: onToggleMode,
          tooltip: drawMode ? "Mode édition" : "Mode dessin",
        ),
        const SizedBox(height: 8),
        _ToolButton(
          icon: Icons.undo,
          onPressed: canUndo ? onUndo : null,
          tooltip: "Annuler",
        ),
        const SizedBox(height: 8),
        _ToolButton(
          icon: Icons.redo,
          onPressed: canRedo ? onRedo : null,
          tooltip: "Rétablir",
        ),
        const SizedBox(height: 8),
        _ToolButton(
          icon: Icons.zoom_out_map,
          onPressed: onCenterOnTrack,
          tooltip: "Centrer sur circuit",
        ),
        const SizedBox(height: 8),
        _ToolButton(
          icon: Icons.clear,
          onPressed: onClear,
          tooltip: "Effacer tout",
          color: Colors.red,
        ),
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final Color color;

  const _ToolButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.color = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: onPressed != null ? color : Colors.grey),
          iconSize: 24,
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final Widget child;

  const _Pill({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
