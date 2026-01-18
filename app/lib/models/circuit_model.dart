import 'package:cloud_firestore/cloud_firestore.dart';

class LocationPoint {
  final double lat;
  final double lng;
  final String label;
  final String? poiId;

  LocationPoint({
    required this.lat,
    required this.lng,
    required this.label,
    this.poiId,
  });

  factory LocationPoint.fromMap(Map<String, dynamic> data) {
    return LocationPoint(
      lat: (data['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0.0,
      label: data['label'] as String? ?? '',
      poiId: data['poiId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lat': lat,
      'lng': lng,
      'label': label,
      if (poiId != null) 'poiId': poiId,
    };
  }

  LocationPoint copyWith({
    double? lat,
    double? lng,
    String? label,
    String? poiId,
  }) {
    return LocationPoint(
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      label: label ?? this.label,
      poiId: poiId ?? this.poiId,
    );
  }
}

class Circuit {
  final String circuitId;
  final String title;
  final String description;
  final LocationPoint start;
  final LocationPoint end;
  final List<LocationPoint> points;
  final DateTime createdAt;
  final String createdBy;
  final bool isPublished;

  Circuit({
    required this.circuitId,
    required this.title,
    required this.description,
    required this.start,
    required this.end,
    required this.points,
    required this.createdAt,
    required this.createdBy,
    this.isPublished = false,
  });

  // Convertir depuis Firestore document
  factory Circuit.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final created = data['createdAt'] as Timestamp?;
    
    final startData = data['start'] as Map<String, dynamic>? ?? {};
    final endData = data['end'] as Map<String, dynamic>? ?? {};
    final pointsData = data['points'] as List<dynamic>? ?? [];

    return Circuit(
      circuitId: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      start: LocationPoint.fromMap(startData),
      end: LocationPoint.fromMap(endData),
      points: pointsData
          .map((p) => LocationPoint.fromMap(p as Map<String, dynamic>))
          .toList(),
      createdAt: created != null ? created.toDate() : DateTime.now(),
      createdBy: data['createdBy'] as String? ?? '',
      isPublished: data['isPublished'] as bool? ?? false,
    );
  }

  factory Circuit.fromMap(String circuitId, Map<String, dynamic> data) {
    final created = data['createdAt'] as Timestamp?;
    
    final startData = data['start'] as Map<String, dynamic>? ?? {};
    final endData = data['end'] as Map<String, dynamic>? ?? {};
    final pointsData = data['points'] as List<dynamic>? ?? [];

    return Circuit(
      circuitId: circuitId,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      start: LocationPoint.fromMap(startData),
      end: LocationPoint.fromMap(endData),
      points: pointsData
          .map((p) => LocationPoint.fromMap(p as Map<String, dynamic>))
          .toList(),
      createdAt: created != null ? created.toDate() : DateTime.now(),
      createdBy: data['createdBy'] as String? ?? '',
      isPublished: data['isPublished'] as bool? ?? false,
    );
  }

  // Convertir en Map pour Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'start': start.toMap(),
      'end': end.toMap(),
      'points': points.map((p) => p.toMap()).toList(),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'isPublished': isPublished,
    };
  }

  // Copie avec modifications
  Circuit copyWith({
    String? title,
    String? description,
    LocationPoint? start,
    LocationPoint? end,
    List<LocationPoint>? points,
    bool? isPublished,
  }) {
    return Circuit(
      circuitId: circuitId,
      title: title ?? this.title,
      description: description ?? this.description,
      start: start ?? this.start,
      end: end ?? this.end,
      points: points ?? this.points,
      createdAt: createdAt,
      createdBy: createdBy,
      isPublished: isPublished ?? this.isPublished,
    );
  }
}
