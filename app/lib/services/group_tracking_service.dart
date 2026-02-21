import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// NOTE: branche ton provider GPS (Geolocator / background_location / etc.)
// Ici on garde une API générique pour MASLIVE.
class GpsSample {
  final double lat;
  final double lng;
  final double? heading; // degrees
  final double? speed; // m/s
  final double? accuracy; // meters
  final DateTime timestamp;

  const GpsSample({
    required this.lat,
    required this.lng,
    required this.timestamp,
    this.heading,
    this.speed,
    this.accuracy,
  });
}

abstract class GpsStreamProvider {
  Stream<GpsSample> watch();
}

class GroupTrackingService {
  GroupTrackingService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  final StreamController<GpsSample> _samples =
      StreamController<GpsSample>.broadcast();
  Stream<GpsSample> get samples => _samples.stream;

  StreamSubscription<GpsSample>? _gpsSub;
  Timer? _throttleTimer;
  GpsSample? _pending;
  bool _sending = false;

  bool get isTracking => _gpsSub != null;

  /// Throttle: envoi max 1 fois / [minInterval]
  Future<void> startTracking({
    required String projectId,
    required String groupId,
    required String roleInGroup, // "tracker" | "admin_group"
    required GpsStreamProvider gps,
    Duration minInterval = const Duration(seconds: 3),
    Duration ttl = const Duration(seconds: 120),
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('User not signed in');
    }

    await _gpsSub?.cancel();
    _gpsSub = null;

    _throttleTimer?.cancel();
    _throttleTimer = null;

    _pending = null;
    _sending = false;

    _gpsSub = gps.watch().listen((sample) async {
      _pending = sample;
      _samples.add(sample);

      // Si pas de timer actif, on en crée un. Le timer enverra à cadence fixe.
      _throttleTimer ??= Timer.periodic(minInterval, (_) {
        unawaited(
          _flush(
            projectId: projectId,
            groupId: groupId,
            roleInGroup: roleInGroup,
            ttl: ttl,
          ),
        );
      });

      // Premier flush immédiat (bonne UX)
      await _flush(
        projectId: projectId,
        groupId: groupId,
        roleInGroup: roleInGroup,
        ttl: ttl,
      );
    });
  }

  Future<void> stopTracking({required String projectId}) async {
    await _gpsSub?.cancel();
    _gpsSub = null;

    _throttleTimer?.cancel();
    _throttleTimer = null;

    _pending = null;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final ref = _db
        .collection('map_projects')
        .doc(projectId)
        .collection('live_locations')
        .doc(uid);
    try {
      await ref.delete();
    } catch (_) {
      // ignore
    }
  }

  Future<void> _flush({
    required String projectId,
    required String groupId,
    required String roleInGroup,
    required Duration ttl,
  }) async {
    if (_sending) return;
    final uid = _auth.currentUser?.uid;
    final sample = _pending;
    if (uid == null || sample == null) return;

    _sending = true;
    try {
      final now = DateTime.now();
      final expiresAt = now.add(ttl);

      final ref = _db
          .collection('map_projects')
          .doc(projectId)
          .collection('live_locations')
          .doc(uid);

      await ref.set({
        'groupId': groupId,
        'roleInGroup': roleInGroup,
        'pos': GeoPoint(sample.lat, sample.lng),
        'heading': sample.heading ?? 0.0,
        'speed': sample.speed ?? 0.0,
        'accuracy': sample.accuracy ?? 50.0,
        'updatedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
      }, SetOptions(merge: true));
    } finally {
      _sending = false;
    }
  }

  Future<void> dispose() async {
    await _gpsSub?.cancel();
    _gpsSub = null;
    _throttleTimer?.cancel();
    _throttleTimer = null;
    await _samples.close();
  }
}
