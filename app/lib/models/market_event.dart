import 'package:cloud_firestore/cloud_firestore.dart';

class MarketEvent {
  const MarketEvent({
    required this.id,
    required this.countryId,
    required this.name,
    required this.slug,
    this.startDate,
    this.endDate,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String countryId;
  final String name;
  final String slug;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'slug': slug,
      'countryId': countryId,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory MarketEvent.fromMap(
    Map<String, dynamic> map, {
    required String id,
    required String countryId,
  }) {
    DateTime? asDateTime(dynamic value) {
      if (value is Timestamp) return value.toDate();
      return null;
    }

    return MarketEvent(
      id: id,
      countryId: (map['countryId'] as String?) ?? countryId,
      name: (map['name'] as String?) ?? '',
      slug: (map['slug'] as String?) ?? id,
      startDate: asDateTime(map['startDate']),
      endDate: asDateTime(map['endDate']),
      createdAt: asDateTime(map['createdAt']),
      updatedAt: asDateTime(map['updatedAt']),
    );
  }

  factory MarketEvent.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String countryId,
  }) {
    final data = doc.data();
    return MarketEvent.fromMap(
      data ?? const <String, dynamic>{},
      id: doc.id,
      countryId: countryId,
    );
  }
}
