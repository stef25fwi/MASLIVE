import '../domain/entities/map_style_buildings_config.dart';
import '../domain/entities/map_style_enums.dart';
import '../domain/entities/map_style_global_config.dart';
import '../domain/entities/map_style_green_spaces_config.dart';
import '../domain/entities/map_style_labels_config.dart';
import '../domain/entities/map_style_lighting_config.dart';
import '../domain/entities/map_style_preset.dart';
import '../domain/entities/map_style_roads_config.dart';
import '../domain/entities/map_style_theme.dart';
import '../domain/entities/map_style_water_config.dart';

class MapStyleDefaults {
  const MapStyleDefaults._();

  static const String collection = 'mapbox_style_presets';

  static const List<String> mapboxBaseStyles = <String>[
    'mapbox://styles/mapbox/streets-v12',
    'mapbox://styles/mapbox/light-v11',
    'mapbox://styles/mapbox/dark-v11',
    'mapbox://styles/mapbox/outdoors-v12',
    'mapbox://styles/mapbox/satellite-streets-v12',
  ];

  static MapStyleTheme defaultTheme() {
    return const MapStyleTheme(
      global: MapStyleGlobalConfig(
        mapboxBaseStyle: 'mapbox://styles/mapbox/light-v11',
        brightness: 1,
        contrast: 1,
        saturation: 1,
        mode: MapStyleMode.day,
      ),
      buildings: MapStyleBuildingsConfig(
        enabled: true,
        color: '#B6BBC5',
        secondaryColor: '#E5E7EB',
        opacity: 0.92,
        extrusion: 0.72,
        roofTint: '#F9FAFB',
        shadow: 0.4,
        lightIntensity: 0.8,
      ),
      greenSpaces: MapStyleGreenSpacesConfig(
        color: '#67AE6E',
        secondaryColor: '#8FD297',
        opacity: 0.9,
        saturation: 1,
        contrast: 1,
        mode: 'naturel',
      ),
      water: MapStyleWaterConfig(
        color: '#4E8DFF',
        opacity: 0.88,
        shoreHighlight: '#BBD8FF',
        brightness: 1,
        reflection: 0.42,
      ),
      roads: MapStyleRoadsConfig(
        primaryColor: '#FFFFFF',
        secondaryColor: '#D1D5DB',
        pedestrianColor: '#FDE68A',
        trafficAccent: '#EF4444',
        closedRoadColor: '#7F1D1D',
        detourColor: '#F59E0B',
        lineThickness: 1,
      ),
      labels: MapStyleLabelsConfig(
        textColor: '#111827',
        opacity: 1,
        fontSize: 14,
        poiDensity: 1,
        showBusinesses: true,
        showTransport: true,
        showParking: true,
        showTourism: true,
      ),
      lighting: MapStyleLightingConfig(
        intensity: 0.85,
        shadowStrength: 0.4,
        lightAngle: 45,
        temperature: 6500,
        glow: 0.28,
      ),
    );
  }

  static MapStylePreset newDraft({
    required String id,
    required String ownerUid,
    required String orgId,
    required String name,
  }) {
    final now = DateTime.now();
    return MapStylePreset(
      id: id,
      name: name,
      description: '',
      category: MapStyleCategory.clair,
      thumbnailUrl: '',
      dominantColor: '#111827',
      tags: const <String>[],
      ownerUid: ownerUid,
      orgId: orgId,
      scope: MapStyleScope.org,
      status: MapStyleStatus.draft,
      visibleInWizard: false,
      isQuickPreset: false,
      isDefault: false,
      theme: defaultTheme(),
      usageCount: 0,
      referencesCount: 0,
      createdAt: now,
      updatedAt: now,
      publishedAt: null,
      archivedAt: null,
    );
  }
}
