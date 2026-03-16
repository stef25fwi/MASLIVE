import '../../../ui/map/maslive_map_controller.dart';
import '../domain/entities/map_style_preset.dart';

class MapStyleApplyService {
  const MapStyleApplyService();

  Future<void> applyPreset(
    MasLiveMapController controller,
    MapStylePreset preset,
  ) async {
    final styleUri = resolveMapboxStyleUri(preset);
    await controller.setStyle(styleUri);
  }

  String resolveMapboxStyleUri(MapStylePreset preset) {
    return preset.theme.global.mapboxBaseStyle;
  }
}
