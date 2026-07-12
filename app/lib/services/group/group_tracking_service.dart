// Tracking GPS groupe optimisé batterie / Firestore.

import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/group_admin.dart';
import '../../models/track_session.dart';

class GroupTrackingService {
  static final GroupTrackingService instance = GroupTrackingService._();
  GroupTrackingService._();

  static const Duration _movingInterval = Duration(seconds: 15);
  static const Duration _slowInterval = Duration(seconds: 45);
  static const Duration _stationaryInterval = Duration(seconds: 60);
  static const Duration _stationaryDelay = Duration(minutes: 2);
  static const Duration _profileWriteInterval = Duration(minutes: 5);
  static const Duration _historyWriteInterval = Duration(seconds: 120);
  static const Duration _stationaryHistoryHeartbeat = Duration(minutes: 5);
  static const Duration _liveTtl = Duration(seconds: 120);
  static const double _historyDistanceM = 60;
  static const double _maxAccuracyM = 50;
  static const double _maxPlausibleSpeedMps = 25;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<Position>? _positionSubscription;
  Timer? _flushTimer;
  TrackSession? _currentSession;
  final List<TrackPoint> _sessionPoints = <TrackPoint>[];

  Position? _latestGoodPosition;
  GeoPosition? _lastSentPosition;
  GeoPosition? _lastHistoryPosition;
  DateTime? _lastSentAt;
  DateTime? _lastHistoryAt;
  DateTime? _lastProfileWriteAt;
  DateTime? _stationarySince;
  bool _writeInProgress = false;

  bool get isTracking =>
      _positionSubscription != null && _currentSession?.isActive == true;

  Future<TrackSession> startTracking({
    required String adminGroupId,
    required String role,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utilisateur non connecté');
    }
    if (isTracking) {
      throw Exception('Tracking déjà actif');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Permission GPS refusée');
    }

    final normalizedRole = role == 'admin' ? 'admin' : 'tracker';
    final now = DateTime.now();
    final sessionRef = _firestore
        .collection('group_tracks')
        .doc(adminGroupId)
        .collection('sessions')
        .doc();
    final session = TrackSession(
      id: sessionRef.id,
      adminGroupId: adminGroupId,
      uid: user.uid,
      role: normalizedRole,
      startedAt: now,
      updatedAt: now,
    );
    await sessionRef.set(session.toFirestore());

    _currentSession = session;
    _resetRuntimeState();

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 15,
    );
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen((position) {
      if (!_isUsablePosition(position)) {
        return;
      }
      _latestGoodPosition = position;
      _updateStationaryState(position);
      unawaited(_flushLatest(force: _lastSentAt == null));
    });

    _flushTimer = Timer.periodic(_movingInterval, (_) {
      unawaited(_flushLatest());
    });
    return session;
  }

  Future<TrackSession> stopTracking() async {
    final session = _currentSession;
    final user = _auth.currentUser;
    if (!isTracking || session == null) {
      throw Exception('Aucun tracking actif');
    }

    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _flushTimer?.cancel();
    _flushTimer = null;

    final sessionRef = _firestore
        .collection('group_tracks')
        .doc(session.adminGroupId)
        .collection('sessions')
        .doc(session.id);
    final summary = _calculateSummary(_sessionPoints, session.startedAt);
    final batch = _firestore.batch();
    batch.update(sessionRef, <String, dynamic>{
      'endedAt': FieldValue.serverTimestamp(),
      'summary': summary.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (user != null) {
      final liveRef = _firestore
          .collection('group_positions')
          .doc(session.adminGroupId)
          .collection('members')
          .doc(user.uid);
      // Le membre marque sa présence inactive. La Cloud Function la supprime
      // ensuite avec les droits serveur et déclenche le recalcul du groupe.
      batch.set(
        liveRef,
        <String, dynamic>{
          'isTracking': false,
          'expiresAt': Timestamp.fromDate(DateTime.now()),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final profileRef = session.role == 'admin'
          ? _firestore.collection('group_admins').doc(user.uid)
          : _firestore.collection('group_trackers').doc(user.uid);
      batch.set(
        profileRef,
        <String, dynamic>{
          'trackingActive': false,
          'trackingSessionId': null,
          'trackingStoppedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
    final completed = TrackSession.fromFirestore(await sessionRef.get());
    _currentSession = null;
    _resetRuntimeState();
    return completed;
  }

  void _resetRuntimeState() {
    _sessionPoints.clear();
    _latestGoodPosition = null;
    _lastSentPosition = null;
    _lastHistoryPosition = null;
    _lastSentAt = null;
    _lastHistoryAt = null;
    _lastProfileWriteAt = null;
    _stationarySince = null;
    _writeInProgress = false;
  }

  bool _isUsablePosition(Position position) {
    if (!position.latitude.isFinite || !position.longitude.isFinite) {
      return false;
    }
    if (position.latitude < -90 || position.latitude > 90) {
      return false;
    }
    if (position.longitude < -180 || position.longitude > 180) {
      return false;
    }
    if (position.latitude == 0 && position.longitude == 0) {
      return false;
    }
    return position.accuracy.isFinite &&
        position.accuracy >= 0 &&
        position.accuracy <= _maxAccuracyM;
  }

  void _updateStationaryState(Position position) {
    final speed = position.speed.isFinite && position.speed >= 0
        ? position.speed
        : 0.0;
    if (speed < 0.2) {
      _stationarySince ??= DateTime.now();
    } else {
      _stationarySince = null;
    }
  }

  Duration _adaptiveInterval(Position position) {
    final speed = position.speed.isFinite && position.speed >= 0
        ? position.speed
        : 0.0;
    if (speed >= 0.8) {
      return _movingInterval;
    }
    if (speed >= 0.2) {
      return _slowInterval;
    }
    final stationarySince = _stationarySince;
    if (stationarySince != null &&
        DateTime.now().difference(stationarySince) >= _stationaryDelay) {
      return _stationaryInterval;
    }
    return _slowInterval;
  }

  Future<void> _flushLatest({bool force = false}) async {
    if (_writeInProgress) {
      return;
    }
    final session = _currentSession;
    final position = _latestGoodPosition;
    if (session == null || position == null || !_isUsablePosition(position)) {
      return;
    }

    final now = DateTime.now();
    final lastSentAt = _lastSentAt;
    if (!force && lastSentAt != null) {
      if (now.difference(lastSentAt) < _adaptiveInterval(position)) {
        return;
      }
    }

    final previous = _lastSentPosition;
    if (previous != null) {
      final elapsedSeconds =
          now.difference(previous.timestamp).inMilliseconds / 1000;
      if (elapsedSeconds > 0) {
        final travelled = _haversineDistance(
          previous.lat,
          previous.lng,
          position.latitude,
          position.longitude,
        );
        if (travelled > 80 &&
            travelled / elapsedSeconds > _maxPlausibleSpeedMps) {
          return;
        }
      }
    }

    _writeInProgress = true;
    try {
      await _persistPosition(position, session, now);
    } finally {
      _writeInProgress = false;
    }
  }

  Future<void> _persistPosition(
    Position position,
    TrackSession session,
    DateTime now,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    final geoPosition = GeoPosition(
      lat: position.latitude,
      lng: position.longitude,
      altitude: position.altitude.isFinite ? position.altitude : null,
      accuracy: position.accuracy,
      timestamp: now,
    );
    final historyDue = _isHistoryWriteDue(geoPosition, now);
    final profileDue = _lastProfileWriteAt == null ||
        now.difference(_lastProfileWriteAt!) >= _profileWriteInterval;
    final batch = _firestore.batch();

    final memberRef = _firestore
        .collection('group_positions')
        .doc(session.adminGroupId)
        .collection('members')
        .doc(user.uid);
    batch.set(
      memberRef,
      <String, dynamic>{
        'role': session.role,
        'isTracking': true,
        'sessionId': session.id,
        'lastPosition': geoPosition.toMap(),
        'previousPosition': _lastSentPosition?.toMap(),
        'expiresAt': Timestamp.fromDate(now.add(_liveTtl)),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    if (profileDue) {
      final profileRef = session.role == 'admin'
          ? _firestore.collection('group_admins').doc(user.uid)
          : _firestore.collection('group_trackers').doc(user.uid);
      batch.set(
        profileRef,
        <String, dynamic>{
          'lastPosition': geoPosition.toMap(),
          'trackingActive': true,
          'trackingSessionId': session.id,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    TrackPoint? storedPoint;
    if (historyDue) {
      final pointRef = _firestore
          .collection('group_tracks')
          .doc(session.adminGroupId)
          .collection('sessions')
          .doc(session.id)
          .collection('points')
          .doc();
      storedPoint = TrackPoint(
        id: pointRef.id,
        lat: geoPosition.lat,
        lng: geoPosition.lng,
        altitude: geoPosition.altitude,
        accuracy: geoPosition.accuracy,
        timestamp: geoPosition.timestamp,
      );
      batch.set(pointRef, storedPoint.toFirestore());
    }

    await batch.commit();
    _lastSentPosition = geoPosition;
    _lastSentAt = now;
    if (profileDue) {
      _lastProfileWriteAt = now;
    }
    if (storedPoint != null) {
      _lastHistoryPosition = geoPosition;
      _lastHistoryAt = now;
      _sessionPoints.add(storedPoint);
    }
  }

  bool _isHistoryWriteDue(GeoPosition current, DateTime now) {
    final lastHistoryAt = _lastHistoryAt;
    final lastHistoryPosition = _lastHistoryPosition;
    if (lastHistoryAt == null || lastHistoryPosition == null) {
      return true;
    }

    final distance = _haversineDistance(
      lastHistoryPosition.lat,
      lastHistoryPosition.lng,
      current.lat,
      current.lng,
    );
    if (distance >= _historyDistanceM) {
      return true;
    }

    final stationarySince = _stationarySince;
    final isStationary = stationarySince != null &&
        now.difference(stationarySince) >= _stationaryDelay;
    final interval = isStationary
        ? _stationaryHistoryHeartbeat
        : _historyWriteInterval;
    return now.difference(lastHistoryAt) >= interval;
  }

  TrackSummary _calculateSummary(
    List<TrackPoint> points,
    DateTime startedAt,
  ) {
    if (points.isEmpty) {
      return TrackSummary(
        durationSec: 0,
        distanceM: 0,
        ascentM: 0,
        descentM: 0,
        avgSpeedMps: 0,
        pointsCount: 0,
      );
    }

    final durationSec = DateTime.now().difference(startedAt).inSeconds;
    double distanceM = 0;
    double ascentM = 0;
    double descentM = 0;
    for (var index = 1; index < points.length; index++) {
      final previous = points[index - 1];
      final current = points[index];
      final travelled = _haversineDistance(
        previous.lat,
        previous.lng,
        current.lat,
        current.lng,
      );
      final elapsedSeconds =
          current.timestamp.difference(previous.timestamp).inMilliseconds /
              1000;
      if (elapsedSeconds > 0 &&
          travelled / elapsedSeconds < _maxPlausibleSpeedMps) {
        distanceM += travelled;
      }
      if (previous.altitude != null && current.altitude != null) {
        final difference = current.altitude! - previous.altitude!;
        if (difference > 0) {
          ascentM += difference;
        } else {
          descentM += difference.abs();
        }
      }
    }

    return TrackSummary(
      durationSec: durationSec,
      distanceM: distanceM,
      ascentM: ascentM,
      descentM: descentM,
      avgSpeedMps: durationSec > 0 ? distanceM / durationSec : 0.0,
      pointsCount: points.length,
    );
  }

  double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusM = 6371000.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return earthRadiusM * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _toRadians(double degree) => degree * pi / 180;

  Stream<List<TrackSession>> streamGroupSessions(String adminGroupId) {
    return _firestore
        .collection('group_tracks')
        .doc(adminGroupId)
        .collection('sessions')
        .orderBy('startedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TrackSession.fromFirestore(doc))
              .toList(),
        );
  }

  Stream<List<TrackSession>> streamUserSessions(
    String adminGroupId,
    String uid,
  ) {
    return _firestore
        .collection('group_tracks')
        .doc(adminGroupId)
        .collection('sessions')
        .where('uid', isEqualTo: uid)
        .orderBy('startedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TrackSession.fromFirestore(doc))
              .toList(),
        );
  }

  Future<List<TrackPoint>> getSessionPoints(
    String adminGroupId,
    String sessionId,
  ) async {
    final snapshot = await _firestore
        .collection('group_tracks')
        .doc(adminGroupId)
        .collection('sessions')
        .doc(sessionId)
        .collection('points')
        .orderBy('ts')
        .get();
    return snapshot.docs
        .map((doc) => TrackPoint.fromFirestore(doc))
        .toList();
  }
}
