import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/routing_service.dart';

class RouteDisplayPage extends StatefulWidget {
  final List<LatLng> waypoints;
  final String? title;

  const RouteDisplayPage({
    super.key,
    required this.waypoints,
    this.title,
  });

  @override
  State<RouteDisplayPage> createState() => _RouteDisplayPageState();
}

class _RouteDisplayPageState extends State<RouteDisplayPage> {
  final _routingService = RoutingService();
  final _mapController = MapController();

  RouteStep? _route;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    setState(() => _loading = true);
    
    final route = widget.waypoints.length == 2
        ? await _routingService.getRoute(widget.waypoints[0], widget.waypoints[1])
        : await _routingService.getMultiRoute(widget.waypoints);

    if (mounted) {
      setState(() {
        _route = route;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.waypoints.first;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? "Route"),
        actions: [
          IconButton(
            tooltip: "Recharger",
            icon: const Icon(Icons.refresh),
            onPressed: _loadRoute,
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
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: "com.example.maslive",
              ),
              // Route polyline
              if (_route != null && _route!.points.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _route!.points,
                      strokeWidth: 6,
                      color: Colors.blue.withValues(alpha: 0.8),
                    ),
                  ],
                ),
              // Waypoints markers
              MarkerLayer(
                markers: _buildMarkers(),
              ),
            ],
          ),
          // Info panel
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _RouteInfoCard(
              route: _route,
              loading: _loading,
              waypointCount: widget.waypoints.length,
            ),
          ),
        ],
      ),
      floatingActionButton: _route != null
          ? FloatingActionButton.extended(
              onPressed: () => _fitBounds(),
              icon: const Icon(Icons.fit_screen),
              label: const Text("Adapter"),
            )
          : null,
    );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    for (int i = 0; i < widget.waypoints.length; i++) {
      final point = widget.waypoints[i];
      final isStart = i == 0;
      final isEnd = i == widget.waypoints.length - 1;

      IconData icon;
      String label;
      if (isStart) {
        icon = Icons.play_arrow;
        label = "Départ";
      } else if (isEnd) {
        icon = Icons.flag;
        label = "Arrivée";
      } else {
        icon = Icons.place;
        label = "Point $i";
      }

      markers.add(
        Marker(
          point: point,
          width: 48,
          height: 48,
          child: Tooltip(
            message: label,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isStart ? Colors.green : (isEnd ? Colors.red : Colors.blue),
              ),
              child: Icon(icon, color: Colors.white),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  void _fitBounds() {
    if (_route == null || _route!.points.isEmpty) return;
    
    double minLat = _route!.points.first.latitude;
    double maxLat = _route!.points.first.latitude;
    double minLng = _route!.points.first.longitude;
    double maxLng = _route!.points.first.longitude;

    for (final point in _route!.points) {
      minLat = minLat > point.latitude ? point.latitude : minLat;
      maxLat = maxLat < point.latitude ? point.latitude : maxLat;
      minLng = minLng > point.longitude ? point.longitude : minLng;
      maxLng = maxLng < point.longitude ? point.longitude : maxLng;
    }

    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(100),
      ),
    );
  }
}

class _RouteInfoCard extends StatelessWidget {
  final RouteStep? route;
  final bool loading;
  final int waypointCount;

  const _RouteInfoCard({
    required this.route,
    required this.loading,
    required this.waypointCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.95),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            color: Colors.black.withValues(alpha: 0.15),
          ),
        ],
      ),
      child: loading
          ? const SizedBox(
              height: 60,
              child: Center(child: CircularProgressIndicator()),
            )
          : route == null
              ? const SizedBox(
                  height: 60,
                  child: Center(child: Text("Route non trouvée")),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatDistance(route!.distanceMeters),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              _formatDuration(route!.durationSeconds),
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        if (waypointCount > 2)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: Colors.blue.withValues(alpha: 0.1),
                            ),
                            child: Text(
                              "$waypointCount points",
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
    );
  }

  String _formatDistance(int meters) {
    if (meters >= 1000) {
      return "${(meters / 1000).toStringAsFixed(1)} km";
    }
    return "$meters m";
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return "${hours}h ${minutes}min";
    }
    return "${minutes}min";
  }
}
