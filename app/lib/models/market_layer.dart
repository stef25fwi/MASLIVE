import 'package:cloud_firestore/cloud_firestore.dart';

class MarketLayer {
  const MarketLayer({
    required this.id,
    required this.type,
    required this.isEnabled,
    required this.order,
    required this.style,
    required this.params,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String type; // perimeter|pois|track|heatmap|zones
  final bool isEnabled;
  final int order;
  final Map<String, dynamic> style;
  final Map<String, dynamic> params;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'isEnabled': isEnabled,
      'order': order,
      'style': style,
      'params': params,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory MarketLayer.fromMap(Map<String, dynamic> map, {required String id}) {
    DateTime? asDateTime(dynamic value) {
      if (value is Timestamp) return value.toDate();
      return null;
    }

    return MarketLayer(
      id: id,
      type: (map['type'] as String?) ?? 'pois',
      isEnabled: (map['isEnabled'] as bool?) ?? true,
      order: (map['order'] as num?)?.toInt() ?? 0,
      style: (map['style'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      params:
          (map['params'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      createdAt: asDateTime(map['createdAt']),
      updatedAt: asDateTime(map['updatedAt']),
    );
  }

  factory MarketLayer.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return MarketLayer.fromMap(data ?? const <String, dynamic>{}, id: doc.id);
  }
}
