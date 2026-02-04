/// Service de cache local avec Hive
/// Stocke positions et données groupe pour offline mode

import 'package:hive_flutter/hive_flutter.dart';
import '../../models/group_admin.dart';

part 'group_cache_service.g.dart';

@HiveType(typeId: 101)
class CachedGroupPosition extends HiveObject {
  @HiveField(0)
  late String adminGroupId;

  @HiveField(1)
  late double lat;

  @HiveField(2)
  late double lng;

  @HiveField(3)
  late double? altitude;

  @HiveField(4)
  late int? accuracy; // en entiers (mètres)

  @HiveField(5)
  late DateTime timestamp;

  @HiveField(6)
  late int memberCount;

  Map<String, dynamic> toMap() => {
        'adminGroupId': adminGroupId,
        'lat': lat,
        'lng': lng,
        'altitude': altitude,
        'accuracy': accuracy,
        'timestamp': timestamp.toIso8601String(),
        'memberCount': memberCount,
      };
}

@HiveType(typeId: 102)
class CachedGroupTracker extends HiveObject {
  @HiveField(0)
  late String uid;

  @HiveField(1)
  late String adminGroupId;

  @HiveField(2)
  late String displayName;

  @HiveField(3)
  late String? photoUrl;

  @HiveField(4)
  late DateTime cachedAt;

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'adminGroupId': adminGroupId,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'cachedAt': cachedAt.toIso8601String(),
      };
}

class GroupCacheService {
  static final GroupCacheService instance = GroupCacheService._();
  GroupCacheService._();

  late Box<CachedGroupPosition> positionsBox;
  late Box<CachedGroupTracker> trackersBox;

  bool _initialized = false;

  /// Initialise Hive et les boxes de cache
  Future<void> initialize() async {
    if (_initialized) return;

    await Hive.initFlutter();
    Hive.registerAdapter(CachedGroupPositionAdapter());
    Hive.registerAdapter(CachedGroupTrackerAdapter());

    positionsBox = await Hive.openBox<CachedGroupPosition>('group_positions');
    trackersBox = await Hive.openBox<CachedGroupTracker>('group_trackers');

    _initialized = true;
    print('✅ GroupCacheService initialized');
  }

  /// Cache une position moyenne
  Future<void> cacheAveragePosition({
    required String adminGroupId,
    required GeoPosition position,
    required int memberCount,
  }) async {
    final cached = CachedGroupPosition()
      ..adminGroupId = adminGroupId
      ..lat = position.lat
      ..lng = position.lng
      ..altitude = position.altitude
      ..accuracy = (position.accuracy?.toInt()) ?? 0
      ..timestamp = DateTime.now()
      ..memberCount = memberCount;

    final key = 'avg_$adminGroupId';
    await positionsBox.put(key, cached);
  }

  /// Récupère la position moyenne en cache (la plus récente)
  CachedGroupPosition? getCachedAveragePosition(String adminGroupId) {
    final key = 'avg_$adminGroupId';
    return positionsBox.get(key);
  }

  /// Stream des positions en cache
  Stream<List<CachedGroupPosition>> streamCachedPositions(String adminGroupId) {
    return positionsBox
        .watch(key: 'avg_$adminGroupId')
        .map((_) => getCachedAveragePosition(adminGroupId))
        .where((pos) => pos != null)
        .cast<CachedGroupPosition>()
        .map((pos) => [pos]);
  }

  /// Cache une position brute d'un tracker
  Future<void> cacheTrackerPosition({
    required String uid,
    required String adminGroupId,
    required GeoPosition position,
  }) async {
    final key = '${adminGroupId}_${uid}_latest';
    final cached = CachedGroupPosition()
      ..adminGroupId = adminGroupId
      ..lat = position.lat
      ..lng = position.lng
      ..altitude = position.altitude
      ..accuracy = (position.accuracy?.toInt()) ?? 0
      ..timestamp = DateTime.now()
      ..memberCount = 1;

    await positionsBox.put(key, cached);
  }

  /// Récupère position en cache d'un tracker
  CachedGroupPosition? getCachedTrackerPosition(String adminGroupId, String uid) {
    final key = '${adminGroupId}_${uid}_latest';
    return positionsBox.get(key);
  }

  /// Cache un profil tracker
  Future<void> cacheTracker({
    required String uid,
    required String adminGroupId,
    required String displayName,
    String? photoUrl,
  }) async {
    final cached = CachedGroupTracker()
      ..uid = uid
      ..adminGroupId = adminGroupId
      ..displayName = displayName
      ..photoUrl = photoUrl
      ..cachedAt = DateTime.now();

    await trackersBox.put(uid, cached);
  }

  /// Récupère tracker en cache
  CachedGroupTracker? getCachedTracker(String uid) {
    return trackersBox.get(uid);
  }

  /// Récupère tous les trackers en cache pour un groupe
  List<CachedGroupTracker> getCachedTrackersForGroup(String adminGroupId) {
    return trackersBox.values
        .where((t) => t.adminGroupId == adminGroupId)
        .toList();
  }

  /// Exporte cache en JSON (pour debug)
  Map<String, dynamic> exportCacheAsJson() {
    final positions = positionsBox.values.map((p) => p.toMap()).toList();
    final trackers = trackersBox.values.map((t) => t.toMap()).toList();

    return {
      'positions': positions,
      'trackers': trackers,
      'exportedAt': DateTime.now().toIso8601String(),
      'totalPositions': positions.length,
      'totalTrackers': trackers.length,
    };
  }

  /// Nettoie le cache (positions > 7 jours)
  Future<int> cleanupOldCache({int keepDays = 7}) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: keepDays));
    int removed = 0;

    final keysToRemove = <String>[];
    for (final entry in positionsBox.toMap().entries) {
      if (entry.value.timestamp.isBefore(cutoffDate)) {
        keysToRemove.add(entry.key as String);
      }
    }

    for (final key in keysToRemove) {
      await positionsBox.delete(key);
      removed++;
    }

    print('🧹 Cache nettoyé: $removed positions supprimées');
    return removed;
  }

  /// Vide complètement le cache
  Future<void> clearAllCache() async {
    await positionsBox.clear();
    await trackersBox.clear();
    print('🗑️  Cache vidé complètement');
  }

  /// Récupère stats du cache
  Map<String, dynamic> getCacheStats() {
    return {
      'totalPositions': positionsBox.length,
      'totalTrackers': trackersBox.length,
      'oldestPosition': positionsBox.values.isNotEmpty
          ? positionsBox.values
              .map((p) => p.timestamp)
              .reduce((a, b) => a.isBefore(b) ? a : b)
              .toIso8601String()
          : null,
      'newestPosition': positionsBox.values.isNotEmpty
          ? positionsBox.values
              .map((p) => p.timestamp)
              .reduce((a, b) => a.isAfter(b) ? a : b)
              .toIso8601String()
          : null,
    };
  }

  /// Sync cache avec Firestore (batch update)
  /// Utile pour synchroniser après reconnexion réseau
  Future<void> syncCacheMetadata() async {
    print('🔄 Sync cache metadata...');
    // À implémenter selon besoins métier
    // Exemple: mettre à jour timestamps, marquer comme synced, etc.
  }

  /// Récupère une position depuis cache ou Firestore (fallback)
  Future<GeoPosition?> getPositionWithFallback({
    required String adminGroupId,
    required bool useCache,
  }) async {
    if (useCache) {
      final cached = getCachedAveragePosition(adminGroupId);
      if (cached != null) {
        return GeoPosition(
          lat: cached.lat,
          lng: cached.lng,
          altitude: cached.altitude,
          accuracy: cached.accuracy?.toDouble(),
          timestamp: cached.timestamp,
        );
      }
    }
    // Fallback: chercher dans Firestore (dans le vrai service)
    return null;
  }
}
