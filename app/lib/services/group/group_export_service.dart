// Service d'export des données de tracking
// Génère CSV et JSON avec statistiques complètes

import 'dart:convert';
import 'package:intl/intl.dart';
import '../../models/track_session.dart';
import 'group_tracking_service.dart';

class GroupExportService {
  static final GroupExportService instance = GroupExportService._();
  GroupExportService._();

  final _trackingService = GroupTrackingService.instance;

  // Exporte une session en CSV
  Future<String> exportSessionToCSV(
    String adminGroupId,
    String sessionId,
  ) async {
    final points = await _trackingService.getSessionPoints(adminGroupId, sessionId);

    if (points.isEmpty) {
      return 'No data';
    }

    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('timestamp,latitude,longitude,altitude,accuracy');

    // Points
    for (final point in points) {
      buffer.write(DateFormat('yyyy-MM-dd HH:mm:ss').format(point.timestamp));
      buffer.write(',${point.lat}');
      buffer.write(',${point.lng}');
      buffer.write(',${point.altitude ?? ""}');
      buffer.write(',${point.accuracy ?? ""}');
      buffer.writeln();
    }

    return buffer.toString();
  }

  // Exporte une session en JSON
  Future<String> exportSessionToJSON(
    String adminGroupId,
    String sessionId,
  ) async {
    final points = await _trackingService.getSessionPoints(adminGroupId, sessionId);

    final jsonData = {
      'sessionId': sessionId,
      'adminGroupId': adminGroupId,
      'exportedAt': DateTime.now().toIso8601String(),
      'pointsCount': points.length,
      'points': points.map((p) => {
        'timestamp': p.timestamp.toIso8601String(),
        'lat': p.lat,
        'lng': p.lng,
        'altitude': p.altitude,
        'accuracy': p.accuracy,
      }).toList(),
    };

    return JsonEncoder.withIndent('  ').convert(jsonData);
  }

  // Exporte plusieurs sessions avec résumés
  Future<String> exportMultipleSessionsToJSON(
    String adminGroupId,
    List<TrackSession> sessions,
  ) async {
    final sessionsData = <Map<String, dynamic>>[];

    for (final session in sessions) {
      final sessionMap = {
        'sessionId': session.id,
        'uid': session.uid,
        'role': session.role,
        'startedAt': session.startedAt.toIso8601String(),
        'endedAt': session.endedAt?.toIso8601String(),
        'isActive': session.isActive,
      };

      if (session.summary != null) {
        sessionMap['summary'] = {
          'durationSec': session.summary!.durationSec,
          'durationFormatted': session.summary!.durationFormatted,
          'distanceM': session.summary!.distanceM,
          'distanceKm': session.summary!.distanceKm,
          'ascentM': session.summary!.ascentM,
          'descentM': session.summary!.descentM,
          'avgSpeedMps': session.summary!.avgSpeedMps,
          'avgSpeedKmh': session.summary!.avgSpeedKmh,
          'pointsCount': session.summary!.pointsCount,
        };
      }

      sessionsData.add(sessionMap);
    }

    final jsonData = {
      'adminGroupId': adminGroupId,
      'exportedAt': DateTime.now().toIso8601String(),
      'sessionsCount': sessions.length,
      'sessions': sessionsData,
    };

    return JsonEncoder.withIndent('  ').convert(jsonData);
  }

  // Exporte résumé CSV (toutes sessions)
  Future<String> exportSessionsSummaryToCSV(List<TrackSession> sessions) async {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('sessionId,uid,role,startedAt,endedAt,durationSec,distanceKm,ascentM,descentM,avgSpeedKmh,pointsCount');

    // Sessions
    for (final session in sessions) {
      buffer.write(session.id);
      buffer.write(',${session.uid}');
      buffer.write(',${session.role}');
      buffer.write(',${DateFormat('yyyy-MM-dd HH:mm:ss').format(session.startedAt)}');
      buffer.write(',${session.endedAt != null ? DateFormat('yyyy-MM-dd HH:mm:ss').format(session.endedAt!) : "active"}');
      
      if (session.summary != null) {
        buffer.write(',${session.summary!.durationSec}');
        buffer.write(',${session.summary!.distanceKm}');
        buffer.write(',${session.summary!.ascentM.toStringAsFixed(1)}');
        buffer.write(',${session.summary!.descentM.toStringAsFixed(1)}');
        buffer.write(',${session.summary!.avgSpeedKmh}');
        buffer.write(',${session.summary!.pointsCount}');
      } else {
        buffer.write(',0,0,0,0,0,0');
      }
      
      buffer.writeln();
    }

    return buffer.toString();
  }

  // Calcule statistiques globales
  Map<String, dynamic> calculateGlobalStats(List<TrackSession> sessions) {
    int totalDurationSec = 0;
    double totalDistanceM = 0.0;
    double totalAscentM = 0.0;
    double totalDescentM = 0.0;
    int totalPoints = 0;

    for (final session in sessions) {
      if (session.summary != null) {
        totalDurationSec += session.summary!.durationSec;
        totalDistanceM += session.summary!.distanceM;
        totalAscentM += session.summary!.ascentM;
        totalDescentM += session.summary!.descentM;
        totalPoints += session.summary!.pointsCount;
      }
    }

    final avgSpeedMps = totalDurationSec > 0 ? totalDistanceM / totalDurationSec : 0.0;

    return {
      'sessionsCount': sessions.length,
      'totalDurationSec': totalDurationSec,
      'totalDistanceKm': (totalDistanceM / 1000).toStringAsFixed(2),
      'totalAscentM': totalAscentM.toStringAsFixed(1),
      'totalDescentM': totalDescentM.toStringAsFixed(1),
      'avgSpeedKmh': (avgSpeedMps * 3.6).toStringAsFixed(1),
      'totalPoints': totalPoints,
    };
  }
}
