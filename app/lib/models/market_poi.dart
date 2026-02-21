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
    this.imageUrl,
    this.address,
    this.openingHours,
    this.phone,
    this.website,
    this.instagram,
    this.facebook,
    this.whatsapp,
    this.email,
    this.mapsUrl,
    this.metadata,
    this.createdByUid,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;
  final String? type;

  // Champs “fiche” (optionnels)
  final String? imageUrl;
  final String? address;
  final Object? openingHours;
  final String? phone;
  final String? website;
  final String? instagram;
  final String? facebook;
  final String? whatsapp;
  final String? email;
  final String? mapsUrl;
  final Map<String, dynamic>? metadata;

  // Aliases pour compat (home_map_page_3d.dart utilise ces noms)
  String? get photoUrl => imageUrl;
  String? get image => imageUrl;

  String? get adresse => address;
  String? get locationLabel => address;

  Object? get hours => openingHours;
  Object? get horaires => openingHours;

  String? get tel => phone;
  String? get telephone => phone;

  String? get site => website;

  String? get ig => instagram;
  String? get fb => facebook;

  String? get googleMapsUrl => mapsUrl;
  String? get mapUrl => mapsUrl;

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

    String? asString(dynamic value) {
      if (value is String) return value;
      return null;
    }

    DateTime? asDateTime(dynamic value) {
      if (value is Timestamp) return value.toDate();
      return null;
    }

    return MarketPoi(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      description: data['description'] as String?,
      type: data['type'] as String?,
      imageUrl: asString(data['imageUrl'] ?? data['photoUrl'] ?? data['image']),
      address: asString(data['address'] ?? data['adresse'] ?? data['locationLabel']),
      openingHours: data['openingHours'] ?? data['hours'] ?? data['horaires'],
      phone: asString(data['phone'] ?? data['tel'] ?? data['telephone']),
      website: asString(data['website'] ?? data['site']),
      instagram: asString(data['instagram'] ?? data['ig']),
      facebook: asString(data['facebook'] ?? data['fb']),
      whatsapp: asString(data['whatsapp']),
      email: asString(data['email']),
      mapsUrl: asString(data['mapsUrl'] ?? data['googleMapsUrl'] ?? data['mapUrl']),
      metadata: (data['metadata'] is Map)
          ? Map<String, dynamic>.from(data['metadata'] as Map)
          : null,
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
      'imageUrl': imageUrl,
      'address': address,
      'openingHours': openingHours,
      'phone': phone,
      'website': website,
      'instagram': instagram,
      'facebook': facebook,
      'whatsapp': whatsapp,
      'email': email,
      'mapsUrl': mapsUrl,
      'metadata': metadata,
      'lat': lat,
      'lng': lng,
      'layerId': layerId,
      'isVisible': isVisible,
      'createdByUid': createdByUid,
      if (withServerTimestamps) 'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
