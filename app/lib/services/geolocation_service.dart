import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'cloud_function_service.dart';

class GeolocationService {
  GeolocationService._();
  static final instance = GeolocationService._();

  Timer? _locationTimer;
  bool _isTracking = false;

  /// Demande les permissions et démarre le tracking toutes les 15s
  /// Appelle updateGroupLocation() à intervalle régulier
  Future<bool> startTracking({
    required String groupId,
    int intervalSeconds = 15,
  }) async {
    // Vérifier et demander les permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // print('GPS permissions denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // print('GPS permissions permanently denied, cannot request again');
      return false;
    }

    // ✅ Première position immédiate
    await _sendPosition(groupId);

    // ✅ Timer toutes les 15s
    _locationTimer?.cancel();
    _isTracking = true;
    _locationTimer = Timer.periodic(Duration(seconds: intervalSeconds), (_) async {
      if (_isTracking) {
        await _sendPosition(groupId);
      }
    });

    // print('✅ Geolocation tracking started for $groupId every ${intervalSeconds}s');
    return true;
  }

  /// Arrête le tracking
  void stopTracking() {
    _locationTimer?.cancel();
    _isTracking = false;
    // print('✅ Geolocation tracking stopped');
  }

  /// Récupère la position actuelle et l'envoie à Firestore
  Future<void> _sendPosition(String groupId) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // ✅ Envoyer via Cloud Function
      await CloudFunctionService().updateGroupLocation(
        groupId: groupId,
        lat: position.latitude,
        lng: position.longitude,
        heading: position.heading > 0 ? position.heading : null,
        speed: position.speed > 0 ? position.speed : null,
      );

      // print('✅ Position sent: (${position.latitude}, ${position.longitude})');
    } catch (e) {
      // print('❌ Erreur sendPosition: $e');
    }
  }

  /// Récupère une position unique (sans tracking continu)
  Future<Position?> getCurrentPosition() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        // print('GPS permissions not granted');
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      // print('❌ Erreur getCurrentPosition: $e');
      return null;
    }
  }

  bool get isTracking => _isTracking;
}
