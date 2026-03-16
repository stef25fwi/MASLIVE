import '../domain/entities/map_style_preset.dart';

class MapStyleThumbnailService {
  const MapStyleThumbnailService();

  String buildFallbackGradient(MapStylePreset preset) {
    final a = preset.dominantColor.isNotEmpty ? preset.dominantColor : '#111827';
    final b = preset.theme.greenSpaces.color;
    return '$a|$b';
  }

  Future<String> generatePlaceholderThumbnail(MapStylePreset preset) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final slug = preset.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return 'map-style://thumbnail/$slug-$stamp';
  }
}
