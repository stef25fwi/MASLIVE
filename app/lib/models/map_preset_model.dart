import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

/// Modèle pour une couche de carte (circuits, POIs, etc.)
class LayerModel {
  final String id;
  final String name;
  final String description;
  final String type; // 'circuits', 'pois', 'routes', 'geofence', etc.
  final bool visible;
  final String? color;
  final String? iconName;
  final Map<String, dynamic> metadata;

  LayerModel({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.visible = true,
    this.color,
    this.iconName,
    Map<String, dynamic>? metadata,
  }) : metadata = metadata ?? {};

  /// Crée une copie avec les modifications apportées
  LayerModel copyWith({
    String? id,
    String? name,
    String? description,
    String? type,
    bool? visible,
    String? color,
    String? iconName,
    Map<String, dynamic>? metadata,
  }) {
    return LayerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      visible: visible ?? this.visible,
      color: color ?? this.color,
      iconName: iconName ?? this.iconName,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convertit en Map pour Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type,
      'visible': visible,
      'color': color,
      'iconName': iconName,
      'metadata': metadata,
    };
  }

  /// Crée un LayerModel depuis un Map Firestore
  factory LayerModel.fromMap(Map<String, dynamic> map) {
    return LayerModel(
      id: map['id'] as String? ?? 'layer_${DateTime.now().millisecondsSinceEpoch}',
      name: map['name'] as String? ?? 'Sans titre',
      description: map['description'] as String? ?? '',
      type: map['type'] as String? ?? 'pois',
      visible: map['visible'] as bool? ?? true,
      color: map['color'] as String?,
      iconName: map['iconName'] as String?,
      metadata: map['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Crée un LayerModel depuis un DocumentSnapshot Firestore
  factory LayerModel.fromDoc(DocumentSnapshot doc) {
    return LayerModel.fromMap({...doc.data() as Map<String, dynamic>, 'id': doc.id});
  }
}

/// Modèle pour une carte pré-enregistrée avec ses couches
class MapPresetModel {
  final String id;
  final String title;
  final String description;
  final LatLng center;
  final double zoom;
  final List<LayerModel> layers;
  final String? imageUrl; // URL pour la vignette
  final String groupId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPublic;

  MapPresetModel({
    required this.id,
    required this.title,
    required this.description,
    required this.center,
    required this.zoom,
    required this.layers,
    required this.groupId,
    this.imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isPublic = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Crée une copie avec les modifications
  MapPresetModel copyWith({
    String? id,
    String? title,
    String? description,
    LatLng? center,
    double? zoom,
    List<LayerModel>? layers,
    String? imageUrl,
    String? groupId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPublic,
  }) {
    return MapPresetModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      center: center ?? this.center,
      zoom: zoom ?? this.zoom,
      layers: layers ?? this.layers,
      imageUrl: imageUrl ?? this.imageUrl,
      groupId: groupId ?? this.groupId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPublic: isPublic ?? this.isPublic,
    );
  }

  /// Récupère une couche par son ID
  LayerModel? getLayer(String layerId) {
    try {
      return layers.firstWhere((layer) => layer.id == layerId);
    } catch (e) {
      return null;
    }
  }

  /// Récupère les couches visibles
  List<LayerModel> getVisibleLayers() {
    return layers.where((layer) => layer.visible).toList();
  }

  /// Ajoute ou met à jour une couche
  MapPresetModel withLayer(LayerModel layer) {
    final newLayers = [...layers];
    final index = newLayers.indexWhere((l) => l.id == layer.id);
    if (index >= 0) {
      newLayers[index] = layer;
    } else {
      newLayers.add(layer);
    }
    return copyWith(layers: newLayers);
  }

  /// Supprime une couche
  MapPresetModel withoutLayer(String layerId) {
    return copyWith(
      layers: layers.where((layer) => layer.id != layerId).toList(),
    );
  }

  /// Convertit en Map pour Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'center': {
        'latitude': center.latitude,
        'longitude': center.longitude,
      },
      'zoom': zoom,
      'layers': layers.map((layer) => layer.toMap()).toList(),
      'imageUrl': imageUrl,
      'groupId': groupId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isPublic': isPublic,
    };
  }

  /// Crée un MapPresetModel depuis un Map Firestore
  factory MapPresetModel.fromMap(Map<String, dynamic> map, {required String docId}) {
    final centerMap = map['center'] as Map<String, dynamic>?;
    final center = centerMap != null
        ? LatLng(
            centerMap['latitude'] as double? ?? 0.0,
            centerMap['longitude'] as double? ?? 0.0,
          )
        : const LatLng(16.241, -61.533);

    final layersList = (map['layers'] as List?) ?? [];
    final layers = layersList
        .map((layerMap) => LayerModel.fromMap(layerMap as Map<String, dynamic>))
        .toList();

    return MapPresetModel(
      id: docId,
      title: map['title'] as String? ?? 'Sans titre',
      description: map['description'] as String? ?? '',
      center: center,
      zoom: (map['zoom'] as num?)?.toDouble() ?? 12.0,
      layers: layers,
      imageUrl: map['imageUrl'] as String?,
      groupId: map['groupId'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isPublic: map['isPublic'] as bool? ?? false,
    );
  }

  /// Crée un MapPresetModel depuis un DocumentSnapshot Firestore
  factory MapPresetModel.fromDoc(DocumentSnapshot doc) {
    return MapPresetModel.fromMap(
      doc.data() as Map<String, dynamic>,
      docId: doc.id,
    );
  }
}
