// Service de tracking GPS temps réel
// Gère les sessions, enregistrement positions, calcul trajectoires

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

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<Position>? _positionSubscription;
  TrackSession? _currentSession;
  List<TrackPoint> _sessionPoints = [];

  bool get isTracking => _positionSubscription != null && _currentSession?.isActive == true;

  // Démarre le tracking
  Future<TrackSession> startTracking({
    required String adminGroupId,
    required String role, // "admin" ou "tracker"
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utilisateur non connecté');
    }

    if (isTracking) {
      throw Exception('Tracking déjà actif');
    }

    // Vérifie permissions GPS
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || 
        permission == LocationPermission.deniedForever) {
      final requested = await Geolocator.requestPermission();
      if (requested == LocationPermission.denied || 
          requested == LocationPermission.deniedForever) {
        throw Exception('Permission GPS refusée');
      }
    }

    // Crée la session
    final now = DateTime.now();
    final sessionId = _firestore
        .collection('group_tracks')
        .doc(adminGroupId)
        .collection('sessions')
        .doc()
        .id;

    final session = TrackSession(
      id: sessionId,
      adminGroupId: adminGroupId,
      uid: user.uid,
      role: role,
      startedAt: now,
      updatedAt: now,
    );

    await _firestore
        .collection('group_tracks')
        .doc(adminGroupId)
        .collection('sessions')
        .doc(sessionId)
        .set(session.toFirestore());

    _currentSession = session;
    _sessionPoints = [];

    // Démarre le stream GPS
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Update tous les 5m
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((position) {
      _handleNewPosition(position, adminGroupId, role);
    });

    return session;
  }

  // Arrête le tracking
  Future<TrackSession> stopTracking() async {
    if (!isTracking || _currentSession == null) {
      throw Exception('Aucun tracking actif');
    }

    // Annule le stream
    await _positionSubscription?.cancel();
    _positionSubscription = null;

    // Calcule le résumé
    final summary = _calculateSummary(_sessionPoints, _currentSession!.startedAt);

    // Met à jour la session
    final sessionRef = _firestore
        .collection('group_tracks')
        .doc(_currentSession!.adminGroupId)
        .collection('sessions')
        .doc(_currentSession!.id);

    await sessionRef.update({
      'endedAt': FieldValue.serverTimestamp(),
      'summary': summary.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final updatedDoc = await sessionRef.get();
    final completedSession = TrackSession.fromFirestore(updatedDoc);

    _currentSession = null;
    _sessionPoints = [];

    return completedSession;
  }

  // Gère une nouvelle position GPS
  Future<void> _handleNewPosition(
    Position position,
    String adminGroupId,
    String role,
  ) async {
    final user = _auth.currentUser;
    if (user == null || _currentSession == null) return;

    final geoPos = GeoPosition(
      lat: position.latitude,
      lng: position.longitude,
      altitude: position.altitude,
      accuracy: position.accuracy,
      timestamp: DateTime.now(),
    );

    // Enregistre dans la sous-collection points
    final pointId = _firestore
        .collection('group_tracks')
        .doc(adminGroupId)
        .collection('sessions')
        .doc(_currentSession!.id)
        .collection('points')
        .doc()
        .id;

    final trackPoint = TrackPoint(
      id: pointId,
      lat: geoPos.lat,
      lng: geoPos.lng,
      altitude: geoPos.altitude,
      accuracy: geoPos.accuracy,
      timestamp: geoPos.timestamp,
    );

    if (trackPoint.isValid()) {
      await _firestore
          .collection('group_tracks')
          .doc(adminGroupId)
          .collection('sessions')
          .doc(_currentSession!.id)
          .collection('points')
          .doc(pointId)
          .set(trackPoint.toFirestore());

      _sessionPoints.add(trackPoint);
    }

    // Met à jour lastPosition dans le profil
    if (role == 'admin') {
      await _firestore
          .collection('group_admins')
          .doc(user.uid)
          .update({
        'lastPosition': geoPos.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await _firestore
          .collection('group_trackers')
          .doc(user.uid)
          .update({
        'lastPosition': geoPos.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // Écrit aussi dans group_positions pour agrégation Cloud Function
    await _firestore
        .collection('group_positions')
        .doc(adminGroupId)
        .collection('members')
        .doc(user.uid)
        .set({
      'role': role,
      'lastPosition': geoPos.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Calcule le résumé d'une session
  TrackSummary _calculateSummary(List<TrackPoint> points, DateTime startedAt) {
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
    double totalDistance = 0.0;
    double totalAscent = 0.0;
    double totalDescent = 0.0;

    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];

      // Distance Haversine
      final dist = _haversineDistance(
        prev.lat, prev.lng,
        curr.lat, curr.lng,
      );

      // Filtre aberrations (> 200m en < 2s = vitesse > 360 km/h)
      final timeDiff = curr.timestamp.difference(prev.timestamp).inSeconds;
      if (timeDiff > 0 && dist / timeDiff < 100) {
        totalDistance += dist;
      }

      // Dénivelé
      if (prev.altitude != null && curr.altitude != null) {
        final altDiff = curr.altitude! - prev.altitude!;
        if (altDiff > 0) {
          totalAscent += altDiff;
        } else {
          totalDescent += altDiff.abs();
        }
      }
    }

    final avgSpeedMps = durationSec > 0 ? totalDistance / durationSec : 0.0;

    return TrackSummary(
      durationSec: durationSec,
      distanceM: totalDistance,
      ascentM: totalAscent,
      descentM: totalDescent,
      avgSpeedMps: avgSpeedMps,
      pointsCount: points.length,
    );
  }

  // Distance Haversine entre 2 points (en mètres)
  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0; // Rayon Terre en mètres
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degree) => degree * pi / 180;

  // Stream des sessions d'un groupe
  Stream<List<TrackSession>> streamGroupSessions(String adminGroupId) {
    return _firestore
        .collection('group_tracks')
        .doc(adminGroupId)
        .collection('sessions')
        .orderBy('startedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TrackSession.fromFirestore(doc))
            .toList());
  }

  // Stream des sessions d'un utilisateur
  Stream<List<TrackSession>> streamUserSessions(String adminGroupId, String uid) {
    return _firestore
        .collection('group_tracks')
        .doc(adminGroupId)
        .collection('sessions')
        .where('uid', isEqualTo: uid)
        .orderBy('startedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TrackSession.fromFirestore(doc))
            .toList());
  }

  // Récupère les points d'une session
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
