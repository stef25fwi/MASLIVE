import 'map_style_buildings_config.dart';
import 'map_style_global_config.dart';
import 'map_style_green_spaces_config.dart';
import 'map_style_labels_config.dart';
import 'map_style_lighting_config.dart';
import 'map_style_roads_config.dart';
import 'map_style_water_config.dart';

class MapStyleTheme {
  const MapStyleTheme({
    required this.global,
    required this.buildings,
    required this.greenSpaces,
    required this.water,
    required this.roads,
    required this.labels,
    required this.lighting,
  });

  final MapStyleGlobalConfig global;
  final MapStyleBuildingsConfig buildings;
  final MapStyleGreenSpacesConfig greenSpaces;
  final MapStyleWaterConfig water;
  final MapStyleRoadsConfig roads;
  final MapStyleLabelsConfig labels;
  final MapStyleLightingConfig lighting;

  MapStyleTheme copyWith({
    MapStyleGlobalConfig? global,
    MapStyleBuildingsConfig? buildings,
    MapStyleGreenSpacesConfig? greenSpaces,
    MapStyleWaterConfig? water,
    MapStyleRoadsConfig? roads,
    MapStyleLabelsConfig? labels,
    MapStyleLightingConfig? lighting,
  }) {
    return MapStyleTheme(
      global: global ?? this.global,
      buildings: buildings ?? this.buildings,
      greenSpaces: greenSpaces ?? this.greenSpaces,
      water: water ?? this.water,
      roads: roads ?? this.roads,
      labels: labels ?? this.labels,
      lighting: lighting ?? this.lighting,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MapStyleTheme &&
        other.global == global &&
        other.buildings == buildings &&
        other.greenSpaces == greenSpaces &&
        other.water == water &&
        other.roads == roads &&
        other.labels == labels &&
        other.lighting == lighting;
  }

  @override
  int get hashCode {
    return Object.hash(global, buildings, greenSpaces, water, roads, labels, lighting);
  }
}
