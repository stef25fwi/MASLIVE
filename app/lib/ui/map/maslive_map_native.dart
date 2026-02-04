import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'maslive_map_controller.dart';
import '../../services/mapbox_token_service.dart';

/// Implémentation Native (iOS/Android) de MasLiveMap
/// Utilise mapbox_maps_flutter avec API Phase 1 complète
class MasLiveMapNative extends StatefulWidget {
  final MasLiveMapController? controller;
  final double initialLng;
  final double initialLat;
  final double initialZoom;
  final double initialPitch;
  final double initialBearing;
  final String? styleUrl;
  final bool showUserLocation;
  final double? userLng;
  final double? userLat;
  final ValueChanged<MapPoint>? onTap;
  final void Function(MasLiveMapController)? onMapReady;

  const MasLiveMapNative({
    super.key,
    this.controller,
    required this.initialLng,
    required this.initialLat,
    required this.initialZoom,
    this.initialPitch = 0.0,
    this.initialBearing = 0.0,
    this.styleUrl,
    this.showUserLocation = false,
    this.userLng,
    this.userLat,
    this.onTap,
    this.onMapReady,
  });

  @override
  State<MasLiveMapNative> createState() => _MasLiveMapNativeState();
}

class _MasLiveMapNativeState extends State<MasLiveMapNative> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _markersManager;
  PolylineAnnotationManager? _polylineManager;
  PolygonAnnotationManager? _polygonManager;
  PointAnnotationManager? _userLocationManager;
  bool _isMapReady = false;
  void Function(double lat, double lng)? _onPointAddedCallback;

  @override
  void initState() {
    super.initState();
    _initMapboxToken();
    _connectController();
  }

  Future<void> _initMapboxToken() async {
    try {
      final info = await MapboxTokenService.getTokenInfo();
      if (info.token.isNotEmpty) {
        MapboxOptions.setAccessToken(info.token);
      }
    } catch (e) {
      debugPrint('⚠️ Erreur chargement token Mapbox: $e');
    }
  }

  void _connectController() {
    final controller = widget.controller;
    if (controller == null) return;

    controller.moveToImpl = (lng, lat, zoom, animate) async {
      if (_mapboxMap == null) return;
      final camera = CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: zoom,
      );
      if (animate) {
        await _mapboxMap!.flyTo(camera, MapAnimationOptions(duration: 1000));
      } else {
        await _mapboxMap!.setCamera(camera);
      }
    };

    controller.setStyleImpl = (styleUri) async {
      await _mapboxMap?.loadStyleURI(styleUri);
    };

    controller.setUserLocationImpl = (lng, lat, show) async {
      if (!show) {
        await _userLocationManager?.deleteAll();
        return;
      }
      await _ensureUserLocationManager();
      await _userLocationManager?.deleteAll();
      final opt = PointAnnotationOptions(
        geometry: Point(coordinates: Position(lng, lat)),
        iconImage: 'marker-15',
        iconSize: 1.5,
        iconColor: Colors.blue.toARGB32(),
      );
      await _userLocationManager?.create(opt);
    };

    controller.setMarkersImpl = (markers) async {
      await _ensureMarkersManager();
      await _markersManager?.deleteAll();
      for (final m in markers) {
        final opt = PointAnnotationOptions(
          geometry: Point(coordinates: Position(m.lng, m.lat)),
          iconImage: 'marker-15',
          iconSize: m.size,
          iconColor: m.color.toARGB32(),
          textField: m.label,
          textSize: 12.0,
          textOffset: const [0.0, 1.2],
          textColor: Colors.black.toARGB32(),
          textHaloColor: Colors.white.toARGB32(),
          textHaloWidth: 1.0,
        );
        await _markersManager?.create(opt);
      }
    };

    controller.setPolylineImpl = (points, color, width, show) async {
      if (!show) {
        await _polylineManager?.deleteAll();
        return;
      }
      await _ensurePolylineManager();
      await _polylineManager?.deleteAll();
      final coords = points.map((p) => Position(p.lng, p.lat)).toList();
      final opt = PolylineAnnotationOptions(
        geometry: LineString(coordinates: coords),
        lineColor: color.toARGB32(),
        lineWidth: width,
      );
      await _polylineManager?.create(opt);
    };

    controller.setPolygonImpl = (points, fillColor, strokeColor, strokeWidth, show) async {
      if (!show) {
        await _polygonManager?.deleteAll();
        return;
      }
      await _ensurePolygonManager();
      await _polygonManager?.deleteAll();
      final coords = points.map((p) => Position(p.lng, p.lat)).toList();
      final opt = PolygonAnnotationOptions(
        geometry: Polygon(coordinates: [coords]),
        fillColor: fillColor.toARGB32(),
        fillOutlineColor: strokeColor.toARGB32(),
      );
      await _polygonManager?.create(opt);
    };

    controller.setEditingEnabledImpl = (enabled, onPointAdded) async {
      _onPointAddedCallback = enabled ? onPointAdded : null;
    };

    controller.clearAllImpl = () async {
      await _markersManager?.deleteAll();
      await _polylineManager?.deleteAll();
      await _polygonManager?.deleteAll();
      await _userLocationManager?.deleteAll();
    };
  }

  Future<void> _ensureMarkersManager() async {
    if (_markersManager != null) return;
    _markersManager = await _mapboxMap?.annotations.createPointAnnotationManager();
  }

  Future<void> _ensurePolylineManager() async {
    if (_polylineManager != null) return;
    _polylineManager = await _mapboxMap?.annotations.createPolylineAnnotationManager();
  }

  Future<void> _ensurePolygonManager() async {
    if (_polygonManager != null) return;
    _polygonManager = await _mapboxMap?.annotations.createPolygonAnnotationManager();
  }

  Future<void> _ensureUserLocationManager() async {
    if (_userLocationManager != null) return;
    _userLocationManager = await _mapboxMap?.annotations.createPointAnnotationManager();
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    if (!_isMapReady) {
      _isMapReady = true;
      final controller = widget.controller;
      if (controller != null) {
        widget.onMapReady?.call(controller);
      }
    }
  }

  @override
  void dispose() {
    _onPointAddedCallback = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final styleUri = widget.styleUrl ?? MapboxStyles.STANDARD;

    return MapWidget(
      cameraOptions: CameraOptions(
        center: Point(
          coordinates: Position(widget.initialLng, widget.initialLat),
        ),
        zoom: widget.initialZoom,
        pitch: widget.initialPitch,
        bearing: widget.initialBearing,
      ),
      styleUri: styleUri,
      onMapCreated: _onMapCreated,
      onTapListener: (gestureContext) async {
        // gestureContext.point est de type Point (Mapbox) avec coordinates
        final lngLat = gestureContext.point.coordinates;
        final lng = lngLat.lng.toDouble();
        final lat = lngLat.lat.toDouble();
        
        // Mode édition: callback onPointAdded
        if (_onPointAddedCallback != null) {
          _onPointAddedCallback!(lat, lng);
        }
        // Callback onTap standard
        widget.onTap?.call(MapPoint(lng, lat));
      },
    );
  }
}
