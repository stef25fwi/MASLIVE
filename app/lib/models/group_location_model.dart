import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class GroupLocation {
  final String id;
  final String groupId;
  final String? groupName;
  final double lat;
  final double lng;
  final double? heading;        // optionnel, direction en degrés
  final double? speed;          // optionnel, m/s
  final DateTime updatedAt;

  GroupLocation({
    required this.id,
    required this.groupId,
    this.groupName,
    required this.lat,
    required this.lng,
    this.heading,
    this.speed,
    required this.updatedAt,
  });

  // Convertir en LatLng pour flutter_map
  LatLng get location => LatLng(lat, lng);

  // Convertir depuis Firestore document
  factory GroupLocation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupLocation(
      id: doc.id,
      groupId: data['groupId'] as String,
      groupName: data['groupName'] as String?,
      lat: (data['lat'] as num).toDouble(),
      lng: (data['lng'] as num).toDouble(),
      heading: data['heading'] != null ? (data['heading'] as num).toDouble() : null,
      speed: data['speed'] != null ? (data['speed'] as num).toDouble() : null,
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  // Convertir en Map pour Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'groupId': groupId,
      'groupName': groupName,
      'lat': lat,
      'lng': lng,
      'heading': heading,
      'speed': speed,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  @override
  String toString() => 'GroupLocation($id, $groupId, $lat, $lng)';
}
