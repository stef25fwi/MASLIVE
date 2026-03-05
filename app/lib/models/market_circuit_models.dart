import 'package:cloud_firestore/cloud_firestore.dart';

class MarketMapLayer {
  final String id;
  final String label;
  final String type; // 'parking', 'wc', 'food', 'assistance', 'visit' (legacy: 'tour'), 'route'
  final bool isVisible;
  final int zIndex;
  final String? color;
  final String? icon;

  MarketMapLayer({
    required this.id,
    required this.label,
    required this.type,
    required this.isVisible,
    required this.zIndex,
    this.color,
    this.icon,
  });

  factory MarketMapLayer.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MarketMapLayer(
      id: doc.id,
      label: data['label'] ?? '',
      type: data['type'] ?? 'route',
      isVisible: data['isVisible'] ?? true,
      zIndex: data['zIndex'] ?? 0,
      color: data['color'],
      icon: data['icon'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'label': label,
      'type': type,
      'isVisible': isVisible,
      'zIndex': zIndex,
      'color': color,
      'icon': icon,
    };
  }

  MarketMapLayer copyWith({
    String? id,
    String? label,
    String? type,
    bool? isVisible,
    int? zIndex,
    String? color,
    String? icon,
  }) {
    return MarketMapLayer(
      id: id ?? this.id,
      label: label ?? this.label,
      type: type ?? this.type,
      isVisible: isVisible ?? this.isVisible,
      zIndex: zIndex ?? this.zIndex,
      color: color ?? this.color,
      icon: icon ?? this.icon,
    );
  }
}

// Modèle pour les POI
class MarketMapPOI {
  final String id;
  final String name;
  final String layerType; // 'parking', 'wc', 'food', etc.
  final double lng;
  final double lat;
  final bool isVisible;

  /// ID de la couche (doc dans `layers`). Souvent identique à `layerType`.
  final String? layerId;
  final String? description;
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

  MarketMapPOI({
    required this.id,
    required this.name,
    required this.layerType,
    required this.lng,
    required this.lat,
    this.isVisible = true,
    this.layerId,
    this.description,
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
  });

  factory MarketMapPOI.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final meta = (data['metadata'] is Map)
        ? Map<String, dynamic>.from(data['metadata'] as Map)
        : null;

    String? asString(dynamic v) => v is String ? v : null;

    Object? pick(dynamic a, dynamic b, dynamic c) {
      if (a != null) return a;
      if (b != null) return b;
      return c;
    }

    final imageUrl = asString(data['imageUrl'] ?? data['photoUrl'] ?? data['image']);
    final layerType = (data['layerType'] ?? data['type'] ?? data['layerId'] ?? 'visit').toString();
    final isVisible =
        (data['isVisible'] as bool?) ?? (data['visible'] as bool?) ?? true;

    return MarketMapPOI(
      id: doc.id,
      name: data['name'] ?? '',
      layerType: layerType,
      lng: (data['lng'] as num?)?.toDouble() ?? 0.0,
      lat: (data['lat'] as num?)?.toDouble() ?? 0.0,
      isVisible: isVisible,
      layerId: asString(data['layerId']),
      description: data['description'],
      imageUrl: imageUrl,
      address: asString(data['address'] ?? data['adresse'] ?? data['locationLabel']),
      openingHours: pick(
        data['openingHours'],
        data['hours'],
        data['horaires'],
      ),
      phone: asString(data['phone'] ?? data['tel'] ?? data['telephone']),
      website: asString(data['website'] ?? data['site']),
      instagram: asString(data['instagram'] ?? meta?['instagram'] ?? meta?['ig']),
      facebook: asString(data['facebook'] ?? meta?['facebook'] ?? meta?['fb']),
      whatsapp: asString(data['whatsapp']),
      email: asString(data['email']),
      mapsUrl: asString(data['mapsUrl'] ?? data['googleMapsUrl'] ?? data['mapUrl']),
      metadata: meta,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'layerType': layerType,
      'layerId': layerId,
      'lng': lng,
      'lat': lat,
      'isVisible': isVisible,
      'description': description,
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
    };
  }
}

// Modèle pour les segments de circuit (portions colorées)
class CircuitSegment {
  final int startIndex;
  final int endIndex;
  final String name;
  final String color;
  final String? description;

  CircuitSegment({
    required this.startIndex,
    required this.endIndex,
    required this.name,
    required this.color,
    this.description,
  });

  factory CircuitSegment.fromMap(Map<String, dynamic> map) {
    return CircuitSegment(
      startIndex: map['startIndex'] ?? 0,
      endIndex: map['endIndex'] ?? 0,
      name: map['name'] ?? '',
      color: map['color'] ?? '#1A73E8',
      description: map['description'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startIndex': startIndex,
      'endIndex': endIndex,
      'name': name,
      'color': color,
      'description': description,
    };
  }
}

// Modèle pour l'état du projet de circuit
class CircuitProject {
  final String id;
  final String name;
  final String countryId;
  final String eventId;
  final String? circuitId;
  final String? description;
  final String status; // 'draft', 'published'
  final List<Map<String, double>> perimeter;
  final List<Map<String, double>> route;
  final String? styleUrl;
  final bool isVisible;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? publishedAt;

  CircuitProject({
    required this.id,
    required this.name,
    required this.countryId,
    required this.eventId,
    this.circuitId,
    this.description,
    required this.status,
    required this.perimeter,
    required this.route,
    this.styleUrl,
    required this.isVisible,
    this.createdAt,
    this.updatedAt,
    this.publishedAt,
  });

  factory CircuitProject.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CircuitProject(
      id: doc.id,
      name: data['name'] ?? '',
      countryId: data['countryId'] ?? '',
      eventId: data['eventId'] ?? '',
      circuitId: data['circuitId'],
      description: data['description'],
      status: data['status'] ?? 'draft',
      perimeter: List<Map<String, double>>.from(
        (data['perimeter'] as List<dynamic>? ?? [])
            .map((p) => {
                  'lng': (p['lng'] as num).toDouble(),
                  'lat': (p['lat'] as num).toDouble(),
                }),
      ),
      route: List<Map<String, double>>.from(
        (data['route'] as List<dynamic>? ?? [])
            .map((p) => {
                  'lng': (p['lng'] as num).toDouble(),
                  'lat': (p['lat'] as num).toDouble(),
                }),
      ),
      styleUrl: data['styleUrl'],
      isVisible: data['isVisible'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      publishedAt: (data['publishedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'countryId': countryId,
      'eventId': eventId,
      'circuitId': circuitId,
      'description': description,
      'status': status,
      'perimeter': perimeter,
      'route': route,
      'styleUrl': styleUrl,
      'isVisible': isVisible,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
      'publishedAt': publishedAt,
    };
  }
}
