import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../utils/latlng.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../services/routing_service.dart';
import '../services/mapbox_token_service.dart';
import '../ui/widgets/mapbox_token_dialog.dart';
import '../ui/widgets/mapbox_web_view_platform.dart';

/// RouteDisplayPage (Mapbox-only)
/// Affiche un itinéraire calculé entre plusieurs waypoints
/// - Web : Mapbox GL JS via MapboxWebView
/// - iOS/Android : mapbox_maps_flutter (MapWidget + annotations)
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

  RouteStep? _route;
  bool _loading = true;

  // Mapbox token
  String _runtimeMapboxToken = '';
  String get _effectiveMapboxToken =>
      _runtimeMapboxToken.isNotEmpty
          ? _runtimeMapboxToken
          : MapboxTokenService.getTokenSync();

  // Web: rebuild pour recentrer
  int _webRebuildTick = 0;

  // Mobile
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointManager;
  PolylineAnnotationManager? _polylineManager;

  @override
  void initState() {
    super.initState();
    _loadRuntimeMapboxToken();
    if (!kIsWeb && _effectiveMapboxToken.isNotEmpty) {
      MapboxOptions.setAccessToken(_effectiveMapboxToken);
    }
    _loadRoute();
  }

  Future<void> _loadRuntimeMapboxToken() async {
    try {
      final info = await MapboxTokenService.getTokenInfo();
      if (!mounted) return;
      setState(() {
        _runtimeMapboxToken = info.token;
      });
      if (!kIsWeb && _runtimeMapboxToken.isNotEmpty) {
        MapboxOptions.setAccessToken(_runtimeMapboxToken);
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _configureMapboxToken() async {
    final newToken = await MapboxTokenDialog.show(
      context,
      initialValue: _effectiveMapboxToken,
    );
    if (!mounted || newToken == null) return;
    setState(() {
      _runtimeMapboxToken = newToken.trim();
    });
    if (!kIsWeb && _runtimeMapboxToken.isNotEmpty) {
      MapboxOptions.setAccessToken(_runtimeMapboxToken);
    }
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
      // Sync annotations natives
      _scheduleNativeAnnotationsSync();
    }
  }

  void _scheduleNativeAnnotationsSync() {
    if (kIsWeb) return;
    if (_mapboxMap == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ensureAnnotationManagers();
      await _syncNativeAnnotations();
    });
  }

  Future<void> _ensureAnnotationManagers() async {
    if (_mapboxMap == null) return;
    if (_pointManager == null) {
      _pointManager =
          await _mapboxMap!.annotations.createPointAnnotationManager();
    }
    if (_polylineManager == null) {
      _polylineManager =
          await _mapboxMap!.annotations.createPolylineAnnotationManager();
    }
  }

  Future<void> _syncNativeAnnotations() async {
    final pm = _pointManager;
    final plm = _polylineManager;
    if (pm == null || plm == null) return;

    try {
      await pm.deleteAll();
      await plm.deleteAll();
    } catch (_) {
      // ignore
    }

    // Route polyline
    if (_route != null && _route!.points.isNotEmpty) {
      final points =
          _route!.points.map((p) => Position(p.longitude, p.latitude)).toList();
      final opt = PolylineAnnotationOptions(
        geometry: LineString(coordinates: points),
        lineColor: 0xFF0A84FF,
        lineWidth: 6.0,
        lineOpacity: 0.8,
      );
      await plm.create(opt);
    }

    // Waypoint markers
    for (int i = 0; i < widget.waypoints.length; i++) {
      final point = widget.waypoints[i];
      final isStart = i == 0;
      final isEnd = i == widget.waypoints.length - 1;

      final opt = PointAnnotationOptions(
        geometry: Point(coordinates: Position(point.lng, point.lat)),
        iconImage: 'marker-15',
        iconSize: isStart ? 2.0 : (isEnd ? 2.0 : 1.5),
        textField: isStart ? 'Départ' : (isEnd ? 'Arrivée' : 'Point $i'),
        textOffset: const [0.0, 1.2],
        textSize: 11.0,
        textColor: 0xFF111111,
        textHaloColor: 0xFFFFFFFF,
        textHaloWidth: 1.0,
      );
      await pm.create(opt);
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
    final token = _effectiveMapboxToken.trim();
    if (token.isEmpty) {
      return _TokenMissingOverlay(onConfigure: _configureMapboxToken);
    }

    if (kIsWeb) {
      // TODO: polyline rendering (sera ajouté quand MapboxWebView supportera ce paramètre)
      // final polyline = _route != null && _route!.points.isNotEmpty
      //     ? _route!.points.map((p) => (lng: p.longitude, lat: p.latitude)).toList()
      //     : const <({double lng, double lat})>[];

      return MapboxWebView(
        key: ValueKey('route-display-web-$_webRebuildTick'),
        accessToken: token,
        initialLat: center.lat,
        initialLng: center.lng,
        initialZoom: 12.0,
        initialPitch: 0.0,
        initialBearing: 0.0,
        styleUrl: 'mapbox://styles/mapbox/streets-v12',
        showUserLocation: false,
        // TODO: polyline rendering (sera ajouté quand MapboxWebView supportera ce paramètre)
        onMapReady: () {
          // rien
        },
      );
    }

    // Mobile natif
    final initialCamera = CameraOptions(
      center: Point(coordinates: Position(center.lng, center.lat)),
      zoom: 12.0,
      pitch: 0.0,
      bearing: 0.0,
    );

    return MapWidget(
      key: const ValueKey('route-display-native'),
      cameraOptions: initialCamera,
      styleUri: 'mapbox://styles/mapbox/streets-v12',
      onMapCreated: (map) async {
        _mapboxMap = map;
        await _ensureAnnotationManagers();
        await _syncNativeAnnotations();
      },
    );
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

    if (kIsWeb) {
      // TODO: améliorer pour calculer le bon zoom basé sur les bounds
      setState(() {
        _webRebuildTick++;
      });
      return;
    }

    final map = _mapboxMap;
    if (map == null) return;

    // Centrer sur le centre des bounds
    map.setCamera(
      CameraOptions(
        center: Point(
          coordinates: Position((minLng + maxLng) / 2, (minLat + maxLat) / 2),
        ),
        padding: MbxEdgeInsets(
          top: 100,
          left: 100,
          bottom: 100,
          right: 100,
        ),
      ),
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
