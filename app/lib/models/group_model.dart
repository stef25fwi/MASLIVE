import 'package:cloud_firestore/cloud_firestore.dart';

class Group {
  final String id;
  final String name;
  final String subtitle;
  final String? bannerUrl;
  final String description;
  final String city;

  const Group({
    required this.id,
    required this.name,
    required this.subtitle,
    this.bannerUrl,
    required this.description,
    required this.city,
  });

  factory Group.fromMap(String id, Map<String, dynamic> data) {
    return Group(
      id: id,
      name: (data['name'] ?? '') as String,
      subtitle: (data['subtitle'] ?? '') as String,
      bannerUrl: data['bannerUrl'] as String?,
      description: (data['description'] ?? '') as String,
      city: (data['city'] ?? '') as String,
    );
  }

  // Convertir depuis Firestore document
  factory Group.fromFirestore(DocumentSnapshot doc) {
    return Group.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  // Convertir en Map pour Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'subtitle': subtitle,
      'bannerUrl': bannerUrl,
      'description': description,
      'city': city,
    };
  }

  @override
  String toString() => 'Group($id, $name, $subtitle)';
}
