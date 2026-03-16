enum MapStyleCategory {
  clair,
  nuit,
  carnaval,
  institutionnel,
  evenement,
  mobilite,
}

enum MapStyleStatus {
  draft,
  published,
  archived,
}

enum MapStyleScope {
  global,
  org,
  event,
}

enum MapStyleMode {
  day,
  sunset,
  night,
  auto,
}

T _enumByName<T>(Iterable<T> values, String raw, T fallback) {
  for (final value in values) {
    if (value.toString().split('.').last == raw) {
      return value;
    }
  }
  return fallback;
}

MapStyleCategory mapStyleCategoryFromString(String? raw) {
  return _enumByName(MapStyleCategory.values, (raw ?? '').trim(), MapStyleCategory.clair);
}

MapStyleStatus mapStyleStatusFromString(String? raw) {
  return _enumByName(MapStyleStatus.values, (raw ?? '').trim(), MapStyleStatus.draft);
}

MapStyleScope mapStyleScopeFromString(String? raw) {
  return _enumByName(MapStyleScope.values, (raw ?? '').trim(), MapStyleScope.org);
}

MapStyleMode mapStyleModeFromString(String? raw) {
  return _enumByName(MapStyleMode.values, (raw ?? '').trim(), MapStyleMode.day);
}
