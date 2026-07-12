import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GpsSample {
  final double lat;
  final double lng;
  final double? heading;
  final double? speed;
  final double? accuracy;
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

/// Service live générique conservé pour les cartes projet.
///
/// La cadence est plafonnée à 15 secondes. Le premier point est envoyé
/// immédiatement, puis le timer n'écrit que le dernier échantillon disponible.
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
  DateTime? _lastSentAt;
  bool _sending = false;

  bool get isTracking => _gpsSub != null;

  Future<void> startTracking({
    required String projectId,
    required String groupId,
    required String roleInGroup,
    required GpsStreamProvider gps,
    Duration minInterval = const Duration(seconds: 15),
    Duration ttl = const Duration(seconds: 120),
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('User not signed in');

    await _gpsSub?.cancel();
    _throttleTimer?.cancel();
    _pending = null;
    _lastSentAt = null;
    _sending = false;

    _gpsSub = gps.watch().listen((sample) {
      if (!_isUsable(sample)) return;
      _pending = sample;
      _samples.add(sample);
      if (_lastSentAt == null) {
        unawaited(_flush(
          projectId: projectId,
          groupId: groupId,
          roleInGroup: roleInGroup,
          ttl: ttl,
        ));
      }
    });

    _throttleTimer = Timer.periodic(minInterval, (_) {
      unawaited(_flush(
        projectId: projectId,
        groupId: groupId,
        roleInGroup: roleInGroup,
        ttl: ttl,
      ));
    });
  }

  bool _isUsable(GpsSample sample) {
    if (!sample.lat.isFinite || !sample.lng.isFinite) return false;
    if (sample.lat < -90 || sample.lat > 90) return false;
    if (sample.lng < -180 || sample.lng > 180) return false;
    if (sample.lat == 0 && sample.lng == 0) return false;
    final accuracy = sample.accuracy;
    return accuracy == null || (accuracy.isFinite && accuracy <= 50);
  }

  Future<void> stopTracking({required String projectId}) async {
    await _gpsSub?.cancel();
    _gpsSub = null;
    _throttleTimer?.cancel();
    _throttleTimer = null;
    _pending = null;
    _lastSentAt = null;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db
          .collection('map_projects')
          .doc(projectId)
          .collection('live_locations')
          .doc(uid)
          .delete();
    } catch (_) {
      // Nettoyage idempotent.
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
      await _db
          .collection('map_projects')
          .doc(projectId)
          .collection('live_locations')
          .doc(uid)
          .set(<String, dynamic>{
        'groupId': groupId,
        'roleInGroup': roleInGroup,
        'pos': GeoPoint(sample.lat, sample.lng),
        'heading': sample.heading ?? 0.0,
        'speed': sample.speed ?? 0.0,
        'accuracy': sample.accuracy ?? 50.0,
        'updatedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(now.add(ttl)),
      }, SetOptions(merge: true));
      _lastSentAt = now;
      _pending = null;
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
