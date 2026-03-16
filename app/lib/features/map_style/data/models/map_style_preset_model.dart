import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/map_style_buildings_config.dart';
import '../../domain/entities/map_style_enums.dart';
import '../../domain/entities/map_style_global_config.dart';
import '../../domain/entities/map_style_green_spaces_config.dart';
import '../../domain/entities/map_style_labels_config.dart';
import '../../domain/entities/map_style_lighting_config.dart';
import '../../domain/entities/map_style_preset.dart';
import '../../domain/entities/map_style_roads_config.dart';
import '../../domain/entities/map_style_theme.dart';
import '../../domain/entities/map_style_water_config.dart';

String _stringOf(dynamic value, {String fallback = ''}) {
  final next = value?.toString().trim() ?? '';
  return next.isEmpty ? fallback : next;
}

int _intOf(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(_stringOf(value)) ?? fallback;
}

double _doubleOf(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(_stringOf(value).replaceAll(',', '.')) ?? fallback;
}

bool _boolOf(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = _stringOf(value).toLowerCase();
  if (normalized == 'true' || normalized == '1' || normalized == 'yes') return true;
  if (normalized == 'false' || normalized == '0' || normalized == 'no') return false;
  return fallback;
}

DateTime _dateOf(dynamic value, {DateTime? fallback}) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  return fallback ?? DateTime.now();
}

DateTime? _nullableDateOf(dynamic value) {
  if (value == null) return null;
  return _dateOf(value);
}

Map<String, dynamic> _mapOf(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

List<String> _listOfStrings(dynamic value) {
  if (value is! Iterable) return const <String>[];
  return value.map((entry) => _stringOf(entry)).where((entry) => entry.isNotEmpty).toList(growable: false);
}

class MapStyleGlobalConfigModel {
  const MapStyleGlobalConfigModel({
    required this.mapboxBaseStyle,
    required this.brightness,
    required this.contrast,
    required this.saturation,
    required this.mode,
  });

  final String mapboxBaseStyle;
  final double brightness;
  final double contrast;
  final double saturation;
  final MapStyleMode mode;

  factory MapStyleGlobalConfigModel.fromMap(Map<String, dynamic> map) {
    return MapStyleGlobalConfigModel(
      mapboxBaseStyle: _stringOf(map['mapboxBaseStyle'], fallback: 'mapbox://styles/mapbox/streets-v12'),
      brightness: _doubleOf(map['brightness'], fallback: 1),
      contrast: _doubleOf(map['contrast'], fallback: 1),
      saturation: _doubleOf(map['saturation'], fallback: 1),
      mode: mapStyleModeFromString(map['mode']?.toString()),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'mapboxBaseStyle': mapboxBaseStyle,
      'brightness': brightness,
      'contrast': contrast,
      'saturation': saturation,
      'mode': mode.name,
    };
  }

  MapStyleGlobalConfig toEntity() {
    return MapStyleGlobalConfig(
      mapboxBaseStyle: mapboxBaseStyle,
      brightness: brightness,
      contrast: contrast,
      saturation: saturation,
      mode: mode,
    );
  }

  factory MapStyleGlobalConfigModel.fromEntity(MapStyleGlobalConfig entity) {
    return MapStyleGlobalConfigModel(
      mapboxBaseStyle: entity.mapboxBaseStyle,
      brightness: entity.brightness,
      contrast: entity.contrast,
      saturation: entity.saturation,
      mode: entity.mode,
    );
  }
}

class MapStyleBuildingsConfigModel {
  const MapStyleBuildingsConfigModel({
    required this.enabled,
    required this.color,
    required this.secondaryColor,
    required this.opacity,
    required this.extrusion,
    required this.roofTint,
    required this.shadow,
    required this.lightIntensity,
  });

  final bool enabled;
  final String color;
  final String secondaryColor;
  final double opacity;
  final double extrusion;
  final String roofTint;
  final double shadow;
  final double lightIntensity;

  factory MapStyleBuildingsConfigModel.fromMap(Map<String, dynamic> map) {
    return MapStyleBuildingsConfigModel(
      enabled: _boolOf(map['enabled'], fallback: true),
      color: _stringOf(map['color'], fallback: '#A8A8A8'),
      secondaryColor: _stringOf(map['secondaryColor'], fallback: '#D1D5DB'),
      opacity: _doubleOf(map['opacity'], fallback: 0.9),
      extrusion: _doubleOf(map['extrusion'], fallback: 0.7),
      roofTint: _stringOf(map['roofTint'], fallback: '#F3F4F6'),
      shadow: _doubleOf(map['shadow'], fallback: 0.4),
      lightIntensity: _doubleOf(map['lightIntensity'], fallback: 0.8),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'enabled': enabled,
      'color': color,
      'secondaryColor': secondaryColor,
      'opacity': opacity,
      'extrusion': extrusion,
      'roofTint': roofTint,
      'shadow': shadow,
      'lightIntensity': lightIntensity,
    };
  }

  MapStyleBuildingsConfig toEntity() {
    return MapStyleBuildingsConfig(
      enabled: enabled,
      color: color,
      secondaryColor: secondaryColor,
      opacity: opacity,
      extrusion: extrusion,
      roofTint: roofTint,
      shadow: shadow,
      lightIntensity: lightIntensity,
    );
  }

  factory MapStyleBuildingsConfigModel.fromEntity(MapStyleBuildingsConfig entity) {
    return MapStyleBuildingsConfigModel(
      enabled: entity.enabled,
      color: entity.color,
      secondaryColor: entity.secondaryColor,
      opacity: entity.opacity,
      extrusion: entity.extrusion,
      roofTint: entity.roofTint,
      shadow: entity.shadow,
      lightIntensity: entity.lightIntensity,
    );
  }
}

class MapStyleGreenSpacesConfigModel {
  const MapStyleGreenSpacesConfigModel({
    required this.color,
    required this.secondaryColor,
    required this.opacity,
    required this.saturation,
    required this.contrast,
    required this.mode,
  });

  final String color;
  final String secondaryColor;
  final double opacity;
  final double saturation;
  final double contrast;
  final String mode;

  factory MapStyleGreenSpacesConfigModel.fromMap(Map<String, dynamic> map) {
    return MapStyleGreenSpacesConfigModel(
      color: _stringOf(map['color'], fallback: '#5FBF77'),
      secondaryColor: _stringOf(map['secondaryColor'], fallback: '#85D39C'),
      opacity: _doubleOf(map['opacity'], fallback: 0.9),
      saturation: _doubleOf(map['saturation'], fallback: 1.0),
      contrast: _doubleOf(map['contrast'], fallback: 1.0),
      mode: _stringOf(map['mode'], fallback: 'naturel'),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'color': color,
      'secondaryColor': secondaryColor,
      'opacity': opacity,
      'saturation': saturation,
      'contrast': contrast,
      'mode': mode,
    };
  }

  MapStyleGreenSpacesConfig toEntity() {
    return MapStyleGreenSpacesConfig(
      color: color,
      secondaryColor: secondaryColor,
      opacity: opacity,
      saturation: saturation,
      contrast: contrast,
      mode: mode,
    );
  }

  factory MapStyleGreenSpacesConfigModel.fromEntity(MapStyleGreenSpacesConfig entity) {
    return MapStyleGreenSpacesConfigModel(
      color: entity.color,
      secondaryColor: entity.secondaryColor,
      opacity: entity.opacity,
      saturation: entity.saturation,
      contrast: entity.contrast,
      mode: entity.mode,
    );
  }
}

class MapStyleWaterConfigModel {
  const MapStyleWaterConfigModel({
    required this.color,
    required this.opacity,
    required this.shoreHighlight,
    required this.brightness,
    required this.reflection,
  });

  final String color;
  final double opacity;
  final String shoreHighlight;
  final double brightness;
  final double reflection;

  factory MapStyleWaterConfigModel.fromMap(Map<String, dynamic> map) {
    return MapStyleWaterConfigModel(
      color: _stringOf(map['color'], fallback: '#3B82F6'),
      opacity: _doubleOf(map['opacity'], fallback: 0.92),
      shoreHighlight: _stringOf(map['shoreHighlight'], fallback: '#93C5FD'),
      brightness: _doubleOf(map['brightness'], fallback: 1.0),
      reflection: _doubleOf(map['reflection'], fallback: 0.4),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'color': color,
      'opacity': opacity,
      'shoreHighlight': shoreHighlight,
      'brightness': brightness,
      'reflection': reflection,
    };
  }

  MapStyleWaterConfig toEntity() {
    return MapStyleWaterConfig(
      color: color,
      opacity: opacity,
      shoreHighlight: shoreHighlight,
      brightness: brightness,
      reflection: reflection,
    );
  }

  factory MapStyleWaterConfigModel.fromEntity(MapStyleWaterConfig entity) {
    return MapStyleWaterConfigModel(
      color: entity.color,
      opacity: entity.opacity,
      shoreHighlight: entity.shoreHighlight,
      brightness: entity.brightness,
      reflection: entity.reflection,
    );
  }
}

class MapStyleRoadsConfigModel {
  const MapStyleRoadsConfigModel({
    required this.primaryColor,
    required this.secondaryColor,
    required this.pedestrianColor,
    required this.trafficAccent,
    required this.closedRoadColor,
    required this.detourColor,
    required this.lineThickness,
  });

  final String primaryColor;
  final String secondaryColor;
  final String pedestrianColor;
  final String trafficAccent;
  final String closedRoadColor;
  final String detourColor;
  final double lineThickness;

  factory MapStyleRoadsConfigModel.fromMap(Map<String, dynamic> map) {
    return MapStyleRoadsConfigModel(
      primaryColor: _stringOf(map['primaryColor'], fallback: '#FFFFFF'),
      secondaryColor: _stringOf(map['secondaryColor'], fallback: '#D1D5DB'),
      pedestrianColor: _stringOf(map['pedestrianColor'], fallback: '#FDE68A'),
      trafficAccent: _stringOf(map['trafficAccent'], fallback: '#EF4444'),
      closedRoadColor: _stringOf(map['closedRoadColor'], fallback: '#7F1D1D'),
      detourColor: _stringOf(map['detourColor'], fallback: '#F59E0B'),
      lineThickness: _doubleOf(map['lineThickness'], fallback: 1.0),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'primaryColor': primaryColor,
      'secondaryColor': secondaryColor,
      'pedestrianColor': pedestrianColor,
      'trafficAccent': trafficAccent,
      'closedRoadColor': closedRoadColor,
      'detourColor': detourColor,
      'lineThickness': lineThickness,
    };
  }

  MapStyleRoadsConfig toEntity() {
    return MapStyleRoadsConfig(
      primaryColor: primaryColor,
      secondaryColor: secondaryColor,
      pedestrianColor: pedestrianColor,
      trafficAccent: trafficAccent,
      closedRoadColor: closedRoadColor,
      detourColor: detourColor,
      lineThickness: lineThickness,
    );
  }

  factory MapStyleRoadsConfigModel.fromEntity(MapStyleRoadsConfig entity) {
    return MapStyleRoadsConfigModel(
      primaryColor: entity.primaryColor,
      secondaryColor: entity.secondaryColor,
      pedestrianColor: entity.pedestrianColor,
      trafficAccent: entity.trafficAccent,
      closedRoadColor: entity.closedRoadColor,
      detourColor: entity.detourColor,
      lineThickness: entity.lineThickness,
    );
  }
}

class MapStyleLabelsConfigModel {
  const MapStyleLabelsConfigModel({
    required this.textColor,
    required this.opacity,
    required this.fontSize,
    required this.poiDensity,
    required this.showBusinesses,
    required this.showTransport,
    required this.showParking,
    required this.showTourism,
  });

  final String textColor;
  final double opacity;
  final double fontSize;
  final double poiDensity;
  final bool showBusinesses;
  final bool showTransport;
  final bool showParking;
  final bool showTourism;

  factory MapStyleLabelsConfigModel.fromMap(Map<String, dynamic> map) {
    return MapStyleLabelsConfigModel(
      textColor: _stringOf(map['textColor'], fallback: '#111827'),
      opacity: _doubleOf(map['opacity'], fallback: 1.0),
      fontSize: _doubleOf(map['fontSize'], fallback: 14.0),
      poiDensity: _doubleOf(map['poiDensity'], fallback: 1.0),
      showBusinesses: _boolOf(map['showBusinesses'], fallback: true),
      showTransport: _boolOf(map['showTransport'], fallback: true),
      showParking: _boolOf(map['showParking'], fallback: true),
      showTourism: _boolOf(map['showTourism'], fallback: true),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'textColor': textColor,
      'opacity': opacity,
      'fontSize': fontSize,
      'poiDensity': poiDensity,
      'showBusinesses': showBusinesses,
      'showTransport': showTransport,
      'showParking': showParking,
      'showTourism': showTourism,
    };
  }

  MapStyleLabelsConfig toEntity() {
    return MapStyleLabelsConfig(
      textColor: textColor,
      opacity: opacity,
      fontSize: fontSize,
      poiDensity: poiDensity,
      showBusinesses: showBusinesses,
      showTransport: showTransport,
      showParking: showParking,
      showTourism: showTourism,
    );
  }

  factory MapStyleLabelsConfigModel.fromEntity(MapStyleLabelsConfig entity) {
    return MapStyleLabelsConfigModel(
      textColor: entity.textColor,
      opacity: entity.opacity,
      fontSize: entity.fontSize,
      poiDensity: entity.poiDensity,
      showBusinesses: entity.showBusinesses,
      showTransport: entity.showTransport,
      showParking: entity.showParking,
      showTourism: entity.showTourism,
    );
  }
}

class MapStyleLightingConfigModel {
  const MapStyleLightingConfigModel({
    required this.intensity,
    required this.shadowStrength,
    required this.lightAngle,
    required this.temperature,
    required this.glow,
  });

  final double intensity;
  final double shadowStrength;
  final double lightAngle;
  final double temperature;
  final double glow;

  factory MapStyleLightingConfigModel.fromMap(Map<String, dynamic> map) {
    return MapStyleLightingConfigModel(
      intensity: _doubleOf(map['intensity'], fallback: 0.85),
      shadowStrength: _doubleOf(map['shadowStrength'], fallback: 0.4),
      lightAngle: _doubleOf(map['lightAngle'], fallback: 45),
      temperature: _doubleOf(map['temperature'], fallback: 6500),
      glow: _doubleOf(map['glow'], fallback: 0.3),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'intensity': intensity,
      'shadowStrength': shadowStrength,
      'lightAngle': lightAngle,
      'temperature': temperature,
      'glow': glow,
    };
  }

  MapStyleLightingConfig toEntity() {
    return MapStyleLightingConfig(
      intensity: intensity,
      shadowStrength: shadowStrength,
      lightAngle: lightAngle,
      temperature: temperature,
      glow: glow,
    );
  }

  factory MapStyleLightingConfigModel.fromEntity(MapStyleLightingConfig entity) {
    return MapStyleLightingConfigModel(
      intensity: entity.intensity,
      shadowStrength: entity.shadowStrength,
      lightAngle: entity.lightAngle,
      temperature: entity.temperature,
      glow: entity.glow,
    );
  }
}

class MapStyleThemeModel {
  const MapStyleThemeModel({
    required this.global,
    required this.buildings,
    required this.greenSpaces,
    required this.water,
    required this.roads,
    required this.labels,
    required this.lighting,
  });

  final MapStyleGlobalConfigModel global;
  final MapStyleBuildingsConfigModel buildings;
  final MapStyleGreenSpacesConfigModel greenSpaces;
  final MapStyleWaterConfigModel water;
  final MapStyleRoadsConfigModel roads;
  final MapStyleLabelsConfigModel labels;
  final MapStyleLightingConfigModel lighting;

  factory MapStyleThemeModel.fromMap(Map<String, dynamic> map) {
    return MapStyleThemeModel(
      global: MapStyleGlobalConfigModel.fromMap(_mapOf(map['global'])),
      buildings: MapStyleBuildingsConfigModel.fromMap(_mapOf(map['buildings'])),
      greenSpaces: MapStyleGreenSpacesConfigModel.fromMap(_mapOf(map['greenSpaces'])),
      water: MapStyleWaterConfigModel.fromMap(_mapOf(map['water'])),
      roads: MapStyleRoadsConfigModel.fromMap(_mapOf(map['roads'])),
      labels: MapStyleLabelsConfigModel.fromMap(_mapOf(map['labels'])),
      lighting: MapStyleLightingConfigModel.fromMap(_mapOf(map['lighting'])),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'global': global.toMap(),
      'buildings': buildings.toMap(),
      'greenSpaces': greenSpaces.toMap(),
      'water': water.toMap(),
      'roads': roads.toMap(),
      'labels': labels.toMap(),
      'lighting': lighting.toMap(),
    };
  }

  MapStyleTheme toEntity() {
    return MapStyleTheme(
      global: global.toEntity(),
      buildings: buildings.toEntity(),
      greenSpaces: greenSpaces.toEntity(),
      water: water.toEntity(),
      roads: roads.toEntity(),
      labels: labels.toEntity(),
      lighting: lighting.toEntity(),
    );
  }

  factory MapStyleThemeModel.fromEntity(MapStyleTheme entity) {
    return MapStyleThemeModel(
      global: MapStyleGlobalConfigModel.fromEntity(entity.global),
      buildings: MapStyleBuildingsConfigModel.fromEntity(entity.buildings),
      greenSpaces: MapStyleGreenSpacesConfigModel.fromEntity(entity.greenSpaces),
      water: MapStyleWaterConfigModel.fromEntity(entity.water),
      roads: MapStyleRoadsConfigModel.fromEntity(entity.roads),
      labels: MapStyleLabelsConfigModel.fromEntity(entity.labels),
      lighting: MapStyleLightingConfigModel.fromEntity(entity.lighting),
    );
  }
}

class MapStylePresetModel {
  const MapStylePresetModel({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.thumbnailUrl,
    required this.dominantColor,
    required this.tags,
    required this.ownerUid,
    required this.orgId,
    required this.scope,
    required this.status,
    required this.visibleInWizard,
    required this.isQuickPreset,
    required this.isDefault,
    required this.theme,
    required this.usageCount,
    required this.referencesCount,
    required this.createdAt,
    required this.updatedAt,
    this.publishedAt,
    this.archivedAt,
  });

  final String id;
  final String name;
  final String description;
  final MapStyleCategory category;
  final String thumbnailUrl;
  final String dominantColor;
  final List<String> tags;
  final String ownerUid;
  final String orgId;
  final MapStyleScope scope;
  final MapStyleStatus status;
  final bool visibleInWizard;
  final bool isQuickPreset;
  final bool isDefault;
  final MapStyleThemeModel theme;
  final int usageCount;
  final int referencesCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? publishedAt;
  final DateTime? archivedAt;

  factory MapStylePresetModel.fromDocument(DocumentSnapshot<Map<String, dynamic>> document) {
    return MapStylePresetModel.fromMap(document.data() ?? const <String, dynamic>{}, id: document.id);
  }

  factory MapStylePresetModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return MapStylePresetModel(
      id: _stringOf(id ?? map['id']),
      name: _stringOf(map['name'], fallback: 'Untitled style'),
      description: _stringOf(map['description']),
      category: mapStyleCategoryFromString(map['category']?.toString()),
      thumbnailUrl: _stringOf(map['thumbnailUrl']),
      dominantColor: _stringOf(map['dominantColor'], fallback: '#111827'),
      tags: _listOfStrings(map['tags']),
      ownerUid: _stringOf(map['ownerUid']),
      orgId: _stringOf(map['orgId']),
      scope: mapStyleScopeFromString(map['scope']?.toString()),
      status: mapStyleStatusFromString(map['status']?.toString()),
      visibleInWizard: _boolOf(map['visibleInWizard']),
      isQuickPreset: _boolOf(map['isQuickPreset']),
      isDefault: _boolOf(map['isDefault']),
      theme: MapStyleThemeModel.fromMap(_mapOf(map['theme'])),
      usageCount: _intOf(map['usageCount']),
      referencesCount: _intOf(map['referencesCount']),
      createdAt: _dateOf(map['createdAt']),
      updatedAt: _dateOf(map['updatedAt']),
      publishedAt: _nullableDateOf(map['publishedAt']),
      archivedAt: _nullableDateOf(map['archivedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'description': description,
      'category': category.name,
      'thumbnailUrl': thumbnailUrl,
      'dominantColor': dominantColor,
      'tags': tags,
      'ownerUid': ownerUid,
      'orgId': orgId,
      'scope': scope.name,
      'status': status.name,
      'visibleInWizard': visibleInWizard,
      'isQuickPreset': isQuickPreset,
      'isDefault': isDefault,
      'mapboxBaseStyle': theme.global.mapboxBaseStyle,
      'theme': theme.toMap(),
      'usageCount': usageCount,
      'referencesCount': referencesCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'publishedAt': publishedAt == null ? null : Timestamp.fromDate(publishedAt!),
      'archivedAt': archivedAt == null ? null : Timestamp.fromDate(archivedAt!),
    };
  }

  MapStylePreset toEntity() {
    return MapStylePreset(
      id: id,
      name: name,
      description: description,
      category: category,
      thumbnailUrl: thumbnailUrl,
      dominantColor: dominantColor,
      tags: tags,
      ownerUid: ownerUid,
      orgId: orgId,
      scope: scope,
      status: status,
      visibleInWizard: visibleInWizard,
      isQuickPreset: isQuickPreset,
      isDefault: isDefault,
      theme: theme.toEntity(),
      usageCount: usageCount,
      referencesCount: referencesCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
      publishedAt: publishedAt,
      archivedAt: archivedAt,
    );
  }

  factory MapStylePresetModel.fromEntity(MapStylePreset entity) {
    return MapStylePresetModel(
      id: entity.id,
      name: entity.name,
      description: entity.description,
      category: entity.category,
      thumbnailUrl: entity.thumbnailUrl,
      dominantColor: entity.dominantColor,
      tags: List<String>.from(entity.tags),
      ownerUid: entity.ownerUid,
      orgId: entity.orgId,
      scope: entity.scope,
      status: entity.status,
      visibleInWizard: entity.visibleInWizard,
      isQuickPreset: entity.isQuickPreset,
      isDefault: entity.isDefault,
      theme: MapStyleThemeModel.fromEntity(entity.theme),
      usageCount: entity.usageCount,
      referencesCount: entity.referencesCount,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      publishedAt: entity.publishedAt,
      archivedAt: entity.archivedAt,
    );
  }

  MapStylePresetModel copyWith({
    String? id,
    String? name,
    String? description,
    MapStyleCategory? category,
    String? thumbnailUrl,
    String? dominantColor,
    List<String>? tags,
    String? ownerUid,
    String? orgId,
    MapStyleScope? scope,
    MapStyleStatus? status,
    bool? visibleInWizard,
    bool? isQuickPreset,
    bool? isDefault,
    MapStyleThemeModel? theme,
    int? usageCount,
    int? referencesCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? publishedAt,
    DateTime? archivedAt,
  }) {
    return MapStylePresetModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      dominantColor: dominantColor ?? this.dominantColor,
      tags: tags ?? this.tags,
      ownerUid: ownerUid ?? this.ownerUid,
      orgId: orgId ?? this.orgId,
      scope: scope ?? this.scope,
      status: status ?? this.status,
      visibleInWizard: visibleInWizard ?? this.visibleInWizard,
      isQuickPreset: isQuickPreset ?? this.isQuickPreset,
      isDefault: isDefault ?? this.isDefault,
      theme: theme ?? this.theme,
      usageCount: usageCount ?? this.usageCount,
      referencesCount: referencesCount ?? this.referencesCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      publishedAt: publishedAt ?? this.publishedAt,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MapStylePresetModel &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.category == category &&
        other.thumbnailUrl == thumbnailUrl &&
        other.dominantColor == dominantColor &&
        _sameList(other.tags, tags) &&
        other.ownerUid == ownerUid &&
        other.orgId == orgId &&
        other.scope == scope &&
        other.status == status &&
        other.visibleInWizard == visibleInWizard &&
        other.isQuickPreset == isQuickPreset &&
        other.isDefault == isDefault &&
        other.theme == theme &&
        other.usageCount == usageCount &&
        other.referencesCount == referencesCount &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.publishedAt == publishedAt &&
        other.archivedAt == archivedAt;
  }

  @override
  int get hashCode {
    return Object.hashAll(<Object?>[
      id,
      name,
      description,
      category,
      thumbnailUrl,
      dominantColor,
      Object.hashAll(tags),
      ownerUid,
      orgId,
      scope,
      status,
      visibleInWizard,
      isQuickPreset,
      isDefault,
      theme,
      usageCount,
      referencesCount,
      createdAt,
      updatedAt,
      publishedAt,
      archivedAt,
    ]);
  }

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
