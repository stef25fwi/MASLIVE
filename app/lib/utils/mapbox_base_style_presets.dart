class MapboxBaseStylePreset {
  const MapboxBaseStylePreset(this.label, this.styleUrl);

  final String label;
  final String styleUrl;
}

/// Source unique des presets de style de fond Mapbox standard (Streets,
/// Outdoors, Light, Dark, Satellite). Utilisée par la tuile "Couleurs carte",
/// le "Style Designer" du Wizard Circuit Pro et la tuile "Style par défaut"
/// du dashboard admin pour éviter que les cinq URLs soient recopiées et
/// désynchronisées à plusieurs endroits.
const List<MapboxBaseStylePreset> kMapboxBaseStylePresets = <MapboxBaseStylePreset>[
  MapboxBaseStylePreset('Streets', 'mapbox://styles/mapbox/streets-v12'),
  MapboxBaseStylePreset('Outdoors', 'mapbox://styles/mapbox/outdoors-v12'),
  MapboxBaseStylePreset('Light', 'mapbox://styles/mapbox/light-v11'),
  MapboxBaseStylePreset('Dark', 'mapbox://styles/mapbox/dark-v11'),
  MapboxBaseStylePreset('Satellite Streets', 'mapbox://styles/mapbox/satellite-streets-v12'),
];
