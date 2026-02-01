import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/latlng.dart';

enum PlaceType { market, visit, food, wc }

class Place {
  final String id;
  final PlaceType type;
  final String name;
  final double lat;
  final double lng;
  final String city;
  final double rating;
  final bool active;

  Place({
    required this.id,
    required this.type,
    required this.name,
    required this.lat,
    required this.lng,
    required this.city,
    required this.rating,
    required this.active,
  });

  // Convertir en LatLng pour flutter_map
  LatLng get location => LatLng(lat, lng);

  // Convertir depuis Firestore document
  factory Place.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Place(
      id: doc.id,
      type: _parseType(data['type'] as String),
      name: data['name'] as String,
      lat: (data['lat'] as num).toDouble(),
      lng: (data['lng'] as num).toDouble(),
      city: data['city'] as String,
      rating: (data['rating'] as num).toDouble(),
      active: data['active'] as bool? ?? true,
    );
  }

  // Convertir en Map pour Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'type': _typeToString(type),
      'name': name,
      'lat': lat,
      'lng': lng,
      'city': city,
      'rating': rating,
      'active': active,
    };
  }

  static PlaceType _parseType(String typeStr) {
    switch (typeStr) {
      case 'market':
        return PlaceType.market;
      case 'visit':
        return PlaceType.visit;
      case 'food':
        return PlaceType.food;
      case 'wc':
        return PlaceType.wc;
      default:
        return PlaceType.market;
    }
  }

  static String _typeToString(PlaceType type) {
    switch (type) {
      case PlaceType.market:
        return 'market';
      case PlaceType.visit:
        return 'visit';
      case PlaceType.food:
        return 'food';
      case PlaceType.wc:
        return 'wc';
    }
  }

  @override
  String toString() => 'Place($id, $name, $type)';
}
