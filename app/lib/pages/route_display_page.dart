import 'package:flutter/material.dart';
import '../utils/latlng.dart';
import '../services/routing_service.dart';
import '../services/mapbox_token_service.dart';
import '../ui/widgets/mapbox_token_dialog.dart';
import '../ui/map/maslive_map.dart';
import '../ui/map/maslive_map_controller.dart';

/// RouteDisplayPage (Mapbox-only)
/// Affiche un itinéraire calculé entre plusieurs waypoints
/// - Web : Mapbox GL JS via MasLiveMapWeb
/// - iOS/Android : mapbox_maps_flutter via MasLiveMapNative
class RouteDisplayPage extends StatefulWidget {
  final List<({double lat, double lng})> waypoints;
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
  final MasLiveMapController _mapController = MasLiveMapController();

  RouteStep? _route;
  bool _loading = true;

  // Mapbox token
  int _mapRebuildTick = 0;

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _configureMapboxToken() async {
    final newToken = await MapboxTokenDialog.show(
      context,
      initialValue: MapboxTokenService.getTokenSync(),
    );
    if (!mounted || newToken == null) return;
    setState(() {
      // Force un remount de MasLiveMap pour recharger le token.
      _mapRebuildTick++;
    });

    // Re-sync l'affichage map (polyline/markers) après le remount.
    _scheduleMapSync();
  }

  Future<void> _loadRoute() async {
    setState(() => _loading = true);
    
    // Convertir waypoints en format LatLng pour RoutingService
    final latlngs = widget.waypoints.map((p) => LatLng(p.lat, p.lng)).toList();
    
    final route = latlngs.length == 2
        ? await _routingService.getRoute(latlngs[0], latlngs[1])
        : await _routingService.getMultiRoute(latlngs);

    if (mounted) {
      setState(() {
        _route = route;
        _loading = false;
      });
      _scheduleMapSync();
    }
  }

  void _scheduleMapSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _syncMapOverlays();
    });
  }

  Future<void> _syncMapOverlays() async {
    final token = MapboxTokenService.getTokenSync().trim();
    if (token.isEmpty) return;

    await _mapController.clearAll();

    // Waypoints
    final markers = <MapMarker>[
      for (int i = 0; i < widget.waypoints.length; i++)
        MapMarker(
          id: 'wp_$i',
          lng: widget.waypoints[i].lng,
          lat: widget.waypoints[i].lat,
          size: i == 0 || i == widget.waypoints.length - 1 ? 2.0 : 1.5,
          label: i == 0 ? 'Départ' : (i == widget.waypoints.length - 1 ? 'Arrivée' : 'Point $i'),
        ),
    ];
    await _mapController.setMarkers(markers);

    // Route
    final route = _route;
    if (route != null && route.points.isNotEmpty) {
      await _mapController.setPolyline(
        points: [
          for (final p in route.points) MapPoint(p.longitude, p.latitude),
        ],
        color: const Color(0xFF0A84FF),
        width: 6.0,
        roadLike: false,
        shadow3d: false,
        showDirection: false,
        animateDirection: false,
      );
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.waypoints.first;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? "Route"),
        actions: [
          IconButton(
            tooltip: "Configurer Mapbox Token",
            icon: const Icon(Icons.key_rounded),
            onPressed: _configureMapboxToken,
          ),
          IconButton(
            tooltip: "Recharger",
            icon: const Icon(Icons.refresh),
            onPressed: _loadRoute,
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildMap(center),
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

  Widget _buildMap(({double lat, double lng}) center) {
    final token = MapboxTokenService.getTokenSync().trim();
    if (token.isEmpty) {
      return _TokenMissingOverlay(onConfigure: _configureMapboxToken);
    }

    return MasLiveMap(
      key: ValueKey('route-display-${token.hashCode}-$_mapRebuildTick'),
      controller: _mapController,
      initialLat: center.lat,
      initialLng: center.lng,
      initialZoom: 12.0,
      initialPitch: 0.0,
      initialBearing: 0.0,
      styleUrl: 'mapbox://styles/mapbox/streets-v12',
      showUserLocation: false,
      onMapReady: (_) async {
        await _syncMapOverlays();
      },
    );
  }

  Future<void> _fitBounds() async {
    final route = _route;
    if (route == null || route.points.isEmpty) return;

    double minLat = route.points.first.latitude;
    double maxLat = route.points.first.latitude;
    double minLng = route.points.first.longitude;
    double maxLng = route.points.first.longitude;

    for (final point in route.points) {
      minLat = minLat > point.latitude ? point.latitude : minLat;
      maxLat = maxLat < point.latitude ? point.latitude : maxLat;
      minLng = minLng > point.longitude ? point.longitude : minLng;
      maxLng = maxLng < point.longitude ? point.longitude : maxLng;
    }

    await _mapController.fitBounds(
      west: minLng,
      south: minLat,
      east: maxLng,
      north: maxLat,
      padding: 100,
      animate: true,
    );
  }
}

class _TokenMissingOverlay extends StatelessWidget {
  final VoidCallback onConfigure;
  const _TokenMissingOverlay({required this.onConfigure});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.map_rounded, size: 42),
                  const SizedBox(height: 12),
                  const Text(
                    'Mapbox inactif: token manquant',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Configure MAPBOX_ACCESS_TOKEN pour afficher la carte.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: onConfigure,
                    icon: const Icon(Icons.key_rounded),
                    label: const Text('Configurer'),
                  ),
                ],
              ),
            ),
          ),
        ),
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
