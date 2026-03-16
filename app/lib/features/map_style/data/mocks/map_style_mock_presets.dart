import '../../domain/entities/map_style_enums.dart';
import '../../domain/entities/map_style_preset.dart';
import '../../utils/map_style_defaults.dart';

class MapStyleMockPresets {
  const MapStyleMockPresets._();

  static List<MapStylePreset> build({
    required String ownerUid,
    required String orgId,
  }) {
    final base = MapStyleDefaults.defaultTheme();
    final now = DateTime.now();

    MapStylePreset make({
      required String id,
      required String name,
      required MapStyleCategory category,
      required MapStyleStatus status,
      required String color,
      bool visibleInWizard = false,
      bool isQuickPreset = false,
      bool isDefault = false,
      String baseStyle = 'mapbox://styles/mapbox/light-v11',
    }) {
      return MapStyleDefaults.newDraft(id: id, ownerUid: ownerUid, orgId: orgId, name: name).copyWith(
        category: category,
        status: status,
        dominantColor: color,
        visibleInWizard: visibleInWizard,
        isQuickPreset: isQuickPreset,
        isDefault: isDefault,
        publishedAt: status == MapStyleStatus.published ? now : null,
        theme: base.copyWith(
          global: base.global.copyWith(mapboxBaseStyle: baseStyle),
        ),
      );
    }

    return <MapStylePreset>[
      make(
        id: 'maslive-light',
        name: 'MASLIVE Light',
        category: MapStyleCategory.clair,
        status: MapStyleStatus.published,
        color: '#0EA5E9',
        visibleInWizard: true,
        isQuickPreset: true,
        isDefault: true,
      ),
      make(
        id: 'maslive-night',
        name: 'MASLIVE Night',
        category: MapStyleCategory.nuit,
        status: MapStyleStatus.published,
        color: '#111827',
        visibleInWizard: true,
        isQuickPreset: true,
        baseStyle: 'mapbox://styles/mapbox/dark-v11',
      ),
      make(
        id: 'carnival-glow',
        name: 'Carnival Glow',
        category: MapStyleCategory.carnaval,
        status: MapStyleStatus.published,
        color: '#F97316',
        visibleInWizard: true,
        isQuickPreset: true,
      ),
      make(
        id: 'green-city',
        name: 'Green City',
        category: MapStyleCategory.mobilite,
        status: MapStyleStatus.published,
        color: '#22C55E',
        visibleInWizard: true,
        isQuickPreset: true,
      ),
      make(
        id: 'institutional-blue',
        name: 'Institutional Blue',
        category: MapStyleCategory.institutionnel,
        status: MapStyleStatus.draft,
        color: '#1D4ED8',
      ),
      make(
        id: 'traffic-control',
        name: 'Traffic Control',
        category: MapStyleCategory.mobilite,
        status: MapStyleStatus.archived,
        color: '#EF4444',
      ),
    ];
  }
}
