import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;

typedef TrackCoord = ({double lat, double lng});

class MapboxLiveTrackingLayer {
  mbx.PointAnnotationManager? _pointManager;
  mbx.PolylineAnnotationManager? _polylineManager;

  Future<void> attach(mbx.MapboxMap map) async {
    _pointManager ??= await map.annotations.createPointAnnotationManager();
    _polylineManager ??= await map.annotations.createPolylineAnnotationManager();
  }

  Future<void> render({
    required TrackCoord? current,
    required List<TrackCoord> polyline,
  }) async {
    final pm = _pointManager;
    final plm = _polylineManager;
    if (pm == null || plm == null) return;

    try {
      await pm.deleteAll();
      await plm.deleteAll();
    } catch (_) {
      // ignore
    }

    if (polyline.length >= 2) {
      final coords = polyline
          .map((p) => mbx.Position(p.lng, p.lat))
          .toList(growable: false);

      await plm.create(
        mbx.PolylineAnnotationOptions(
          geometry: mbx.LineString(coordinates: coords),
          lineColor: 0xFF1A73E8,
          lineWidth: 5.0,
        ),
      );
    }

    if (current != null) {
      await pm.create(
        mbx.PointAnnotationOptions(
          geometry: mbx.Point(
            coordinates: mbx.Position(current.lng, current.lat),
          ),
          iconImage: 'marker-15',
          iconSize: 1.6,
        ),
      );
    }
  }

  Future<void> dispose() async {
    try {
      await _pointManager?.deleteAll();
      await _polylineManager?.deleteAll();
    } catch (_) {
      // ignore
    }
    _pointManager = null;
    _polylineManager = null;
  }
}
