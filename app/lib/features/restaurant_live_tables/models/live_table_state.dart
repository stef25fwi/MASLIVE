import 'package:cloud_firestore/cloud_firestore.dart';

enum LiveTableStatus {
  available,
  limited,
  full,
  closed,
  unknown,
}

LiveTableStatus liveTableStatusFromString(String? raw) {
  final v = (raw ?? '').trim().toLowerCase();
  switch (v) {
    case 'available':
      return LiveTableStatus.available;
    case 'limited':
    case 'filling_fast':
      return LiveTableStatus.limited;
    case 'full':
      return LiveTableStatus.full;
    case 'closed':
      return LiveTableStatus.closed;
    default:
      return LiveTableStatus.unknown;
  }
}

String liveTableStatusToString(LiveTableStatus status) {
  switch (status) {
    case LiveTableStatus.available:
      return 'available';
    case LiveTableStatus.limited:
      return 'limited';
    case LiveTableStatus.full:
      return 'full';
    case LiveTableStatus.closed:
      return 'closed';
    case LiveTableStatus.unknown:
      return 'unknown';
  }
}

class LiveTableState {
  const LiveTableState({
    required this.enabled,
    required this.status,
    this.availableTables,
    this.capacity,
    this.message,
    this.updatedAt,
    this.updatedBy,
    this.source = 'metadata',
  });

  final bool enabled;
  final LiveTableStatus status;
  final int? availableTables;
  final int? capacity;
  final String? message;
  final DateTime? updatedAt;
  final String? updatedBy;
  final String source;

  bool get isFresh {
    final ts = updatedAt;
    if (ts == null) return false;
    return DateTime.now().difference(ts).inMinutes <= 20;
  }

  factory LiveTableState.fromMap(
    Map<String, dynamic>? map, {
    String source = 'metadata',
  }) {
    final data = map ?? const <String, dynamic>{};
    final enabled = data['enabled'] == true;
    final status = liveTableStatusFromString(data['status']?.toString());

    DateTime? parseTs(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      if (raw is String) return DateTime.tryParse(raw);
      return null;
    }

    int? parseInt(dynamic raw) {
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw);
      return null;
    }

    final available = parseInt(data['availableTables']);
    final capacity = parseInt(data['capacity']);
    final message = (data['message'] ?? '').toString().trim();

    return LiveTableState(
      enabled: enabled,
      status: status,
      availableTables: available,
      capacity: capacity,
      message: message.isEmpty ? null : message,
      updatedAt: parseTs(data['updatedAt']),
      updatedBy: data['updatedBy']?.toString(),
      source: source,
    );
  }

  static LiveTableState disabled() {
    return const LiveTableState(enabled: false, status: LiveTableStatus.unknown);
  }
}
