import 'package:cloud_firestore/cloud_firestore.dart';

class MarketCircuit {
  const MarketCircuit({
    required this.id,
    required this.countryId,
    required this.eventId,
    required this.name,
    required this.slug,
    required this.status,
    required this.createdByUid,
    required this.perimeterLocked,
    required this.zoomLocked,
    required this.center,
    required this.initialZoom,
    required this.isVisible,
    required this.wizardState,
    this.bounds,
    this.styleId,
    this.styleUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String countryId;
  final String eventId;
  final String name;
  final String slug;
  final String status; // draft
  final String createdByUid;

  final bool perimeterLocked;
  final bool zoomLocked;

  /// {lat: double, lng: double}
  final Map<String, double> center;
  final double initialZoom;

  /// {sw:{lat,lng}, ne:{lat,lng}} nullable
  final Map<String, dynamic>? bounds;

  final String? styleId;
  final String? styleUrl;

  /// Contrôle la visibilité de ce circuit dans le menu "Carte" de la nav.
  final bool isVisible;

  /// {wizardStep:int, completedSteps:[int]}
  final Map<String, dynamic> wizardState;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'slug': slug,
      'status': status,
      'countryId': countryId,
      'eventId': eventId,
      'createdByUid': createdByUid,
      'perimeterLocked': perimeterLocked,
      'zoomLocked': zoomLocked,
      'center': center,
      'initialZoom': initialZoom,
      'bounds': bounds,
      'styleId': styleId,
      'styleUrl': styleUrl,
      'isVisible': isVisible,
      'wizardState': wizardState,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory MarketCircuit.fromMap(
    Map<String, dynamic> map, {
    required String id,
  }) {
    DateTime? asDateTime(dynamic value) {
      if (value is Timestamp) return value.toDate();
      return null;
    }

    Map<String, double> parseCenter(dynamic value) {
      if (value is Map) {
        final lat = value['lat'];
        final lng = value['lng'];
        if (lat is num && lng is num) {
          return {'lat': lat.toDouble(), 'lng': lng.toDouble()};
        }
      }
      return const {'lat': 0.0, 'lng': 0.0};
    }

    return MarketCircuit(
      id: id,
      name: (map['name'] as String?) ?? '',
      slug: (map['slug'] as String?) ?? id,
      status: (map['status'] as String?) ?? 'draft',
      countryId: (map['countryId'] as String?) ?? '',
      eventId: (map['eventId'] as String?) ?? '',
      createdByUid: (map['createdByUid'] as String?) ?? '',
      perimeterLocked: (map['perimeterLocked'] as bool?) ?? false,
      zoomLocked: (map['zoomLocked'] as bool?) ?? false,
      center: parseCenter(map['center']),
      initialZoom: (map['initialZoom'] as num?)?.toDouble() ?? 14.0,
      bounds: map['bounds'] as Map<String, dynamic>?,
      styleId: map['styleId'] as String?,
      styleUrl: map['styleUrl'] as String?,
        isVisible: (map['isVisible'] as bool?) ?? false,
      wizardState: (map['wizardState'] as Map<String, dynamic>?) ??
          const <String, dynamic>{},
      createdAt: asDateTime(map['createdAt']),
      updatedAt: asDateTime(map['updatedAt']),
    );
  }

  factory MarketCircuit.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return MarketCircuit.fromMap(data ?? const <String, dynamic>{}, id: doc.id);
  }
}
