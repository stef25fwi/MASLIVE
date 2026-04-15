const String kDefaultMapboxStyleUrl =
    'mapbox://styles/stef971fwi/cmmgh2oa000rk01qr65il695n';
const String kMasliveProMapboxStyleUrl =
    'mapbox://styles/stef971fwi/cmmgh2oa000rk01qr65il695n';

const Map<String, String> kKnownMapboxStyleUrlsById = <String, String>{
  'streets-v12': 'mapbox://styles/mapbox/streets-v12',
  'outdoors-v12': 'mapbox://styles/mapbox/outdoors-v12',
  'satellite-streets-v12': 'mapbox://styles/mapbox/satellite-streets-v12',
  'light-v11': 'mapbox://styles/mapbox/light-v11',
  'dark-v11': 'mapbox://styles/mapbox/dark-v11',
  'maslive-pro': kMasliveProMapboxStyleUrl,
};

String? tryNormalizeMapboxStyleUrl(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty) return null;

  if (value.startsWith('mapbox://styles/')) {
    return value;
  }

  final withoutHtml = value.toLowerCase().endsWith('.html')
      ? value.substring(0, value.length - 5)
      : value;

  final uri = Uri.tryParse(withoutHtml);
  if (uri == null) return null;

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
    return null;
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

  return null;
}

String? mapboxStyleUrlForStyleId(String? styleId) {
  final normalized = (styleId ?? '').trim();
  if (normalized.isEmpty) return null;
  return kKnownMapboxStyleUrlsById[normalized];
}

String? extractMapboxStyleUrlFromData(Map<String, dynamic>? data) {
  if (data == null) return null;

  Map<String, dynamic>? asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  final current = asMap(data['current']);
  final style = asMap(data['style']);
  final published = asMap(data['published']);

  final rawCandidates = <dynamic>[
    data['styleUrl'],
    current?['styleUrl'],
    published?['styleUrl'],
    style?['styleUrl'],
    style?['url'],
    style?['mapboxBaseStyle'],
    data['mapboxBaseStyle'],
    data['mapStyleUrl'],
    data['currentStyleUrl'],
  ];

  for (final candidate in rawCandidates) {
    if (candidate is! String) continue;
    final normalized = tryNormalizeMapboxStyleUrl(candidate);
    if (normalized != null) return normalized;
  }

  final styleIdCandidates = <dynamic>[
    data['styleId'],
    current?['styleId'],
    style?['styleId'],
  ];

  for (final candidate in styleIdCandidates) {
    if (candidate is! String) continue;
    final resolved = mapboxStyleUrlForStyleId(candidate);
    if (resolved != null) return resolved;
  }

  return null;
}

String normalizeMapboxStyleUrl(
  String? raw, {
  String fallback = kDefaultMapboxStyleUrl,
}) {
  return tryNormalizeMapboxStyleUrl(raw) ?? fallback;
}
