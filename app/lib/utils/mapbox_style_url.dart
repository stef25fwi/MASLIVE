const String kDefaultMapboxStyleUrl = 'mapbox://styles/mapbox/streets-v12';

String normalizeMapboxStyleUrl(
  String? raw, {
  String fallback = kDefaultMapboxStyleUrl,
}) {
  final value = (raw ?? '').trim();
  if (value.isEmpty) return fallback;

  if (value.startsWith('mapbox://styles/')) {
    return value;
  }

  final withoutHtml = value.toLowerCase().endsWith('.html')
      ? value.substring(0, value.length - 5)
      : value;

  final uri = Uri.tryParse(withoutHtml);
  if (uri == null) return fallback;

  final host = uri.host.toLowerCase();
  final seg = uri.pathSegments;

  if (host == 'studio.mapbox.com') {
    final stylesIndex = seg.indexOf('styles');
    if (stylesIndex != -1 && seg.length >= stylesIndex + 3) {
      final user = seg[stylesIndex + 1].trim();
      final styleId = seg[stylesIndex + 2].trim();
      if (user.isNotEmpty && styleId.isNotEmpty) {
        return 'mapbox://styles/$user/$styleId';
      }
    }
    return fallback;
  }

  if (host == 'api.mapbox.com' && seg.length >= 4) {
    if (seg[0] == 'styles' && seg[1] == 'v1') {
      final user = seg[2].trim();
      final styleId = seg[3].trim();
      if (user.isNotEmpty && styleId.isNotEmpty) {
        return 'mapbox://styles/$user/$styleId';
      }
    }
  }

  return fallback;
}