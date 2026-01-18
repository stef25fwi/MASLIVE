import 'package:cloud_firestore/cloud_firestore.dart';

class POI {
  final String poiId;
  final String name;
  final String category;
  final String description;
  final double lat;
  final double lng;
  final String address;
  final DateTime createdAt;
  final String createdBy;
  final bool isActive;

  POI({
    required this.poiId,
    required this.name,
    required this.category,
    required this.description,
    required this.lat,
    required this.lng,
    required this.address,
    required this.createdAt,
    required this.createdBy,
    this.isActive = true,
  });

  // Convertir depuis Firestore document
  factory POI.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final created = data['createdAt'] as Timestamp?;
    return POI(
      poiId: doc.id,
      name: data['name'] as String? ?? '',
      category: data['category'] as String? ?? '',
      description: data['description'] as String? ?? '',
      lat: (data['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0.0,
      address: data['address'] as String? ?? '',
      createdAt: created != null ? created.toDate() : DateTime.now(),
      createdBy: data['createdBy'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  factory POI.fromMap(String poiId, Map<String, dynamic> data) {
    final created = data['createdAt'] as Timestamp?;
    return POI(
      poiId: poiId,
      name: data['name'] as String? ?? '',
      category: data['category'] as String? ?? '',
      description: data['description'] as String? ?? '',
      lat: (data['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0.0,
      address: data['address'] as String? ?? '',
      createdAt: created != null ? created.toDate() : DateTime.now(),
      createdBy: data['createdBy'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  // Convertir en Map pour Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'description': description,
      'lat': lat,
      'lng': lng,
      'address': address,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'isActive': isActive,
    };
  }

  // Copie avec modifications
  POI copyWith({
    String? name,
    String? category,
    String? description,
    double? lat,
    double? lng,
    String? address,
    bool? isActive,
  }) {
    return POI(
      poiId: poiId,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      address: address ?? this.address,
      createdAt: createdAt,
      createdBy: createdBy,
      isActive: isActive ?? this.isActive,
    );
  }
}
