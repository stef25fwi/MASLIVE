import 'package:cloud_firestore/cloud_firestore.dart';

class GroupCircuitPublicPosition {
  const GroupCircuitPublicPosition({
    required this.adminGroupId,
    required this.lat,
    required this.lng,
    this.displayName,
    this.memberCount,
    this.updatedAt,
  });

  final String adminGroupId;
  final String? displayName;
  final double lat;
  final double lng;
  final int? memberCount;
  final DateTime? updatedAt;

  static GroupCircuitPublicPosition? fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) return null;

    double? lat;
    double? lng;

    final pos = data['position'];
    if (pos is GeoPoint) {
      lat = pos.latitude;
      lng = pos.longitude;
    }

    final rawLat = data['lat'];
    final rawLng = data['lng'];
    if (lat == null && rawLat is num) lat = rawLat.toDouble();
    if (lng == null && rawLng is num) lng = rawLng.toDouble();

    if (lat == null || lng == null) return null;
    if (lat == 0 || lng == 0) return null;

    final ts = data['updatedAt'];
    final updatedAt = ts is Timestamp ? ts.toDate() : null;

    final memberCount = data['memberCount'];

    return GroupCircuitPublicPosition(
      adminGroupId: (data['adminGroupId'] as String?)?.trim().isNotEmpty == true
          ? (data['adminGroupId'] as String).trim()
          : doc.id,
      displayName: (data['displayName'] as String?)?.trim(),
      lat: lat,
      lng: lng,
      memberCount: memberCount is num ? memberCount.toInt() : null,
      updatedAt: updatedAt,
    );
  }
}
