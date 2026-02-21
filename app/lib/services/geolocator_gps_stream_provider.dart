import 'package:geolocator/geolocator.dart';

import 'group_tracking_service.dart';

class GeolocatorGpsStreamProvider implements GpsStreamProvider {
  GeolocatorGpsStreamProvider({
    LocationSettings? settings,
  }) : _settings = settings ??
            const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 5,
            );

  final LocationSettings _settings;

  @override
  Stream<GpsSample> watch() async* {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('Location permission denied');
    }

    await for (final p in Geolocator.getPositionStream(locationSettings: _settings)) {
      yield GpsSample(
        lat: p.latitude,
        lng: p.longitude,
        timestamp: DateTime.now(),
        heading: p.heading.isFinite ? p.heading : null,
        speed: p.speed.isFinite ? p.speed : null,
        accuracy: p.accuracy.isFinite ? p.accuracy : null,
      );
    }
  }
}
