import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../services/mapbox_token_service.dart';
import '../ui/widgets/mapbox_token_dialog.dart';
import '../ui/map/maslive_map.dart';
import '../ui/map/maslive_map_controller.dart';

/// TrackingLivePage (Mapbox-only)
/// - Web : Mapbox GL JS via MapboxWebView
/// - iOS/Android : mapbox_maps_flutter (MapWidget + annotations)
/// 
/// Fonctionnalités :
/// - Affichage en temps réel des positions des groupes
/// - Mode "follow" pour suivre un groupe automatiquement
/// - Trails (traces) optionnels
/// - Animation smooth des déplacements
/// - Recherche/filtre par nom de groupe
class TrackingLivePage extends StatefulWidget {
  const TrackingLivePage({super.key});

  @override
  State<TrackingLivePage> createState() => _TrackingLivePageState();
}

class _TrackingLivePageState extends State<TrackingLivePage>
    with TickerProviderStateMixin {
  
  String? _followGroupId;
  final Map<String, List<({double lat, double lng})>> _trails = {};
  final int _maxTrailPoints = 120;
  
  String _searchQuery = '';
  final int _maxAgeSeconds = 120; // 2 min

  // Mapbox token
  String _runtimeMapboxToken = '';
  String get _effectiveMapboxToken =>
      _runtimeMapboxToken.isNotEmpty
          ? _runtimeMapboxToken
          : MapboxTokenService.getTokenSync();

  // Web: rebuild pour recentrer
  int _webRebuildTick = 0;
  double? _webCenterLat;
  double? _webCenterLng;
  final double _webZoom = 13.0;

  // Web: overlays (markers + trail polyline)
  final MasLiveMapController _webController = MasLiveMapController();
  bool _webMapReady = false;

  // Mobile
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointManager;
  PolylineAnnotationManager? _polylineManager;
  List<_GroupLive> _lastGroups = const [];

  @override
  void initState() {
    super.initState();
    _loadRuntimeMapboxToken();
    if (!kIsWeb && _effectiveMapboxToken.isNotEmpty) {
      MapboxOptions.setAccessToken(_effectiveMapboxToken);
    }
  }

  @override
  void dispose() {
    _webController.dispose();
    super.dispose();
  }

  Future<void> _renderWebOverlays(List<_GroupLive> groups) async {
    if (!_webMapReady) return;

    // Markers
    await _webController.setMarkers([
      for (final g in groups)
        MapMarker(
          id: g.id,
          lng: g.lng,
          lat: g.lat,
          label: _short(g.name),
          size: _followGroupId == g.id ? 1.8 : 1.4,
          color: _followGroupId == g.id
              ? const Color(0xFFFF9500)
              : const Color(0xFF0A84FF),
        ),
    ]);

    // Trail: uniquement le groupe suivi (sinon trop chargé)
    final follow = _followGroupId;
    final trail = follow != null ? _trails[follow] : null;
    if (trail == null || trail.length < 2) {
      // Cache la polyline sans effacer les markers.
      await _webController.setPolyline(points: const <MapPoint>[], show: false);
      return;
    }

    await _webController.setPolyline(
      points: [for (final p in trail) MapPoint(p.lng, p.lat)],
      color: const Color(0xFFFF9500),
      width: 4.0,
      show: true,
      roadLike: false,
      shadow3d: false,
      showDirection: false,
      opacity: 0.4,
    );
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

  Stream<QuerySnapshot<Map<String, dynamic>>> _liveStream() {
    return FirebaseFirestore.instance
        .collection('group_locations')
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  void _pushTrail(String groupId, double lat, double lng) {
    final list = _trails.putIfAbsent(groupId, () => <({double lat, double lng})>[]);
    if (list.isNotEmpty) {
      final last = list.last;
      if ((last.lat - lat).abs() < 1e-7 && (last.lng - lng).abs() < 1e-7) {
        return;
      }
    }
    list.add((lat: lat, lng: lng));
    if (list.length > _maxTrailPoints) {
      list.removeRange(0, list.length - _maxTrailPoints);
    }
  }

  void _maybeFollow(String groupId, double lat, double lng) {
    if (_followGroupId != groupId) return;

    if (kIsWeb) {
      setState(() {
        _webCenterLat = lat;
        _webCenterLng = lng;
        _webRebuildTick++;
      });
    } else {
      final map = _mapboxMap;
      if (map == null) return;
      final zoom = _webZoom;
      map.setCamera(
        CameraOptions(
          center: Point(coordinates: Position(lng, lat)),
          zoom: max(13.5, zoom),
        ),
      );
    }
  }

  bool _matchesSearch(String groupId, String? groupName) {
    if (_searchQuery.isEmpty) return true;
    final query = _searchQuery.toLowerCase();
    return groupId.toLowerCase().contains(query) ||
        (groupName?.toLowerCase().contains(query) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Carte Mapbox
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _liveStream(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snap.data!.docs;
              final now = DateTime.now();
              final groups = docs
                  .map((d) => _parseGroup(d.id, d.data()))
                  .whereType<_GroupLive>()
                  .where((g) {
                    final dt = g.updatedAt;
                    if (dt == null) return false;
                    final age = now.difference(dt).inSeconds;
                    return age <= _maxAgeSeconds;
                  })
                  .where((g) => _matchesSearch(g.id, g.name))
                  .toList();

              // Ajouter aux trails
              for (final g in groups) {
                _pushTrail(g.id, g.lat, g.lng);
                _maybeFollow(g.id, g.lat, g.lng);
              }

              // Synchroniser les annotations natives
              _scheduleNativeAnnotationsSync(groups);

              return _buildMap(groups);
            },
          ),

          // Top bar
          Positioned(
            left: 14,
            right: 14,
            top: MediaQuery.of(context).padding.top + 10,
            child: Column(
              children: [
                _TopPill(
                  title: 'Tracking LIVE',
                  subtitle: _followGroupId == null
                      ? 'Sélectionne un groupe pour le suivre'
                      : 'Suivi: $_followGroupId',
                  onStopFollow: _followGroupId == null
                      ? null
                      : () => setState(() => _followGroupId = null),
                ),
                const SizedBox(height: 10),
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Filtrer groupe...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () =>
                                  setState(() => _searchQuery = ''),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Token config button
          Positioned(
            right: 14,
            bottom: MediaQuery.of(context).padding.bottom + 80,
            child: FloatingActionButton.small(
              onPressed: _configureMapboxToken,
              tooltip: 'Configurer Mapbox Token',
              child: const Icon(Icons.key_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(List<_GroupLive> groups) {
    final token = _effectiveMapboxToken.trim();
    if (token.isEmpty) {
      return _TokenMissingOverlay(onConfigure: _configureMapboxToken);
    }

    final fallbackLat = 16.241;
    final fallbackLng = -61.533;

    if (kIsWeb) {
      final center = _getDesiredCenter(groups) ??
          (lat: _webCenterLat ?? fallbackLat, lng: _webCenterLng ?? fallbackLng);
      
      // Mettre à jour markers + trails via controller (post-frame).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_renderWebOverlays(groups));
      });

      return MasLiveMap(
        key: ValueKey('tracking-live-web-$_webRebuildTick'),
        controller: _webController,
        initialLat: center.lat,
        initialLng: center.lng,
        initialZoom: _webZoom,
        initialPitch: 0.0,
        initialBearing: 0.0,
        styleUrl: 'mapbox://styles/mapbox/streets-v12',
        showUserLocation: false,
        onMapReady: (_) {
          _webMapReady = true;
          unawaited(_renderWebOverlays(groups));
        },
      );
    }

    // Mobile natif
    final center = _getDesiredCenter(groups) ??
        (lat: fallbackLat, lng: fallbackLng);
    final initialCamera = CameraOptions(
      center: Point(coordinates: Position(center.lng, center.lat)),
      zoom: 13.0,
      pitch: 0.0,
      bearing: 0.0,
    );

    return MapWidget(
      key: const ValueKey('tracking-live-native'),
      cameraOptions: initialCamera,
      styleUri: 'mapbox://styles/mapbox/streets-v12',
      onMapCreated: (map) async {
        _mapboxMap = map;
        await _ensureAnnotationManagers();
        await _syncNativeAnnotations(_lastGroups);
      },
    );
  }

  void _scheduleNativeAnnotationsSync(List<_GroupLive> groups) {
    _lastGroups = groups;
    if (kIsWeb) return;
    if (_mapboxMap == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ensureAnnotationManagers();
      await _syncNativeAnnotations(groups);
    });
  }

  Future<void> _ensureAnnotationManagers() async {
    if (_mapboxMap == null) return;
    _pointManager ??=
        await _mapboxMap!.annotations.createPointAnnotationManager();
    _polylineManager ??=
        await _mapboxMap!.annotations.createPolylineAnnotationManager();
  }

  Future<void> _syncNativeAnnotations(List<_GroupLive> groups) async {
    final pm = _pointManager;
    final plm = _polylineManager;
    if (pm == null || plm == null) return;

    try {
      await pm.deleteAll();
      await plm.deleteAll();
    } catch (_) {
      // ignore
    }

    // Afficher les trails
    for (final groupId in _trails.keys) {
      final trail = _trails[groupId];
      if (trail == null || trail.length < 2) continue;

      final points = trail.map((p) => Position(p.lng, p.lat)).toList();
      final opt = PolylineAnnotationOptions(
        geometry: LineString(coordinates: points),
        lineColor: 0xFFFF9500,
        lineWidth: 4.0,
        lineOpacity: 0.4,
      );
      await plm.create(opt);
    }

    // Afficher les markers
    for (final g in groups) {
      final isFollowing = _followGroupId == g.id;
      final opt = PointAnnotationOptions(
        geometry: Point(coordinates: Position(g.lng, g.lat)),
        iconImage: 'marker-15',
        iconSize: isFollowing ? 2.0 : 1.4,
        textField: _short(g.name),
        textOffset: const [0.0, 1.2],
        textSize: 12.0,
        textColor: 0xFF111111,
        textHaloColor: 0xFFFFFFFF,
        textHaloWidth: 1.0,
        iconRotate: g.heading ?? 0.0,
      );
      await pm.create(opt);
    }
  }

  ({double lat, double lng})? _getDesiredCenter(List<_GroupLive> groups) {
    // Si un groupe est suivi => centre sur lui
    final sel = _followGroupId;
    if (sel != null) {
      final g = groups
          .where((x) => x.id == sel)
          .cast<_GroupLive?>()
          .firstWhere((x) => x != null, orElse: () => null);
      if (g != null) return (lat: g.lat, lng: g.lng);
    }

    if (groups.isEmpty) return null;

    // Centre moyen
    double sumLat = 0;
    double sumLng = 0;
    for (final g in groups) {
      sumLat += g.lat;
      sumLng += g.lng;
    }
    return (lat: sumLat / groups.length, lng: sumLng / groups.length);
  }

  _GroupLive? _parseGroup(String id, Map<String, dynamic> data) {
    final lat = (data['lat'] as num?)?.toDouble();
    final lng = (data['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;

    final name = (data['groupName'] ?? data['groupId'] ?? id).toString();
    final heading = (data['heading'] as num?)?.toDouble();
    final updatedAt = (data['updatedAt'] is Timestamp)
        ? (data['updatedAt'] as Timestamp).toDate()
        : null;

    return _GroupLive(
      id: id,
      name: name,
      lat: lat,
      lng: lng,
      heading: heading,
      updatedAt: updatedAt,
    );
  }

  static String _short(String s) {
    final t = s.trim();
    if (t.length <= 12) return t;
    return '${t.substring(0, 12)}…';
  }
}

class _GroupLive {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double? heading;
  final DateTime? updatedAt;

  _GroupLive({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.heading,
    this.updatedAt,
  });
}

class _TopPill extends StatelessWidget {
  const _TopPill({
    required this.title,
    required this.subtitle,
    required this.onStopFollow,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onStopFollow;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(18),
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.wifi_tethering, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style:
                          const TextStyle(color: Colors.black54, fontSize: 12)),
                ],
              ),
            ),
            if (onStopFollow != null)
              TextButton(
                onPressed: onStopFollow,
                child: const Text('Stop'),
              ),
          ],
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
