import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Carte Mapbox native (mobile/desktop) simple, pour les écrans Wizard.
/// Sur Web, utiliser Mapbox GL JS (HtmlElementView).
class MapboxNativeSimpleMap extends StatefulWidget {
  const MapboxNativeSimpleMap({
    super.key,
    required this.accessToken,
    this.styleUri = MapboxStyles.MAPBOX_STREETS,
    this.initialLat = 16.241,
    this.initialLng = -61.534,
    this.initialZoom = 11.5,
    this.onTapLngLat,
  });

  final String accessToken;
  final String styleUri;
  final double initialLat;
  final double initialLng;
  final double initialZoom;
  final ValueChanged<({double lng, double lat})>? onTapLngLat;

  @override
  State<MapboxNativeSimpleMap> createState() => _MapboxNativeSimpleMapState();
}

class _MapboxNativeSimpleMapState extends State<MapboxNativeSimpleMap>
    with WidgetsBindingObserver {
  String? _error;

  // 🔥 key dynamique : on la change à la rotation pour forcer le resize natif Mapbox
  Key _mapKey = UniqueKey();
  Size? _lastSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (kIsWeb) {
      _error = 'Mapbox natif non supporté sur Web.';
      return;
    }

    if (widget.accessToken.isEmpty) {
      _error =
          'MAPBOX_ACCESS_TOKEN manquant. Lance avec --dart-define=MAPBOX_ACCESS_TOKEN=...';
      return;
    }

    MapboxOptions.setAccessToken(widget.accessToken);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = MediaQuery.sizeOf(context);

      if (_lastSize == null ||
          (size.width != _lastSize!.width ||
              size.height != _lastSize!.height)) {
        _lastSize = size;
        setState(() {
          _mapKey = UniqueKey(); // force reconstruction du platform view Mapbox
        });
      }
    });
  }

  void _onTap(MapContentGestureContext context) {
    final handler = widget.onTapLngLat;
    if (handler == null) return;
    final coords = context.point.coordinates;
    handler((lng: coords.lng.toDouble(), lat: coords.lat.toDouble()));
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(error, textAlign: TextAlign.center),
        ),
      );
    }

    return MapWidget(
      key: _mapKey,
      styleUri: widget.styleUri,
      cameraOptions: CameraOptions(
        zoom: widget.initialZoom,
        center: Point(
          coordinates: Position(widget.initialLng, widget.initialLat),
        ),
      ),
      onTapListener: _onTap,
    );
  }
}
