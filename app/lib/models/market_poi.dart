import 'package:cloud_firestore/cloud_firestore.dart';

class MarketPoi {
  const MarketPoi({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.layerId,
    required this.isVisible,
    this.description,
    this.type,
    this.createdByUid,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;
  final String? type;

  final double lat;
  final double lng;

  /// ID du document dans la subcollection `layers` du circuit.
  final String layerId;

  /// Détermine si le POI doit apparaître dans la liste et sur la couche.
  final bool isVisible;

  final String? createdByUid;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory MarketPoi.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};

    DateTime? asDateTime(dynamic value) {
      if (value is Timestamp) return value.toDate();
      return null;
    }

    return MarketPoi(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      description: data['description'] as String?,
      type: data['type'] as String?,
      lat: (data['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0.0,
      layerId: (data['layerId'] as String?) ?? '',
      isVisible: (data['isVisible'] as bool?) ?? true,
      createdByUid: data['createdByUid'] as String?,
      createdAt: asDateTime(data['createdAt']),
      updatedAt: asDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap({bool withServerTimestamps = true}) {
    return {
      'name': name,
      'description': description,
      'type': type,
      'lat': lat,
      'lng': lng,
      'layerId': layerId,
      'isVisible': isVisible,
      'createdByUid': createdByUid,
      if (withServerTimestamps) 'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
