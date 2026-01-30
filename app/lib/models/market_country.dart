import 'package:cloud_firestore/cloud_firestore.dart';

class MarketCountry {
  const MarketCountry({
    required this.id,
    required this.name,
    required this.slug,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String slug;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'slug': slug,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory MarketCountry.fromMap(Map<String, dynamic> map, {required String id}) {
    final createdAt = map['createdAt'];
    final updatedAt = map['updatedAt'];

    return MarketCountry(
      id: id,
      name: (map['name'] as String?) ?? '',
      slug: (map['slug'] as String?) ?? id,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
      updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
    );
  }

  factory MarketCountry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return MarketCountry.fromMap(data ?? const <String, dynamic>{}, id: doc.id);
  }
}
