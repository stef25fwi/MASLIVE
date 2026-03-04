enum PoiType {
  food,
  visit,
  wc,
  other,
}

class PoiNormalizer {
  static PoiType normalizePoiType(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    if (v.isEmpty) return PoiType.other;

    // WC
    if (v == 'wc' ||
        v == 'toilet' ||
        v == 'toilets' ||
        v == 'toilette' ||
        v == 'toilettes' ||
        v.contains('toilet')) {
      return PoiType.wc;
    }

    // Food
    if (v == 'food' ||
        v == 'restaurant' ||
        v == 'resto' ||
        v == 'bar' ||
        v == 'snack') {
      return PoiType.food;
    }

    // Visit (legacy: tour)
    if (v == 'visit' || v == 'visiter' || v == 'tour' || v == 'tourisme') {
      return PoiType.visit;
    }

    return PoiType.other;
  }

  static String poiTypeToString(PoiType type) {
    return switch (type) {
      PoiType.food => 'food',
      PoiType.visit => 'visit',
      PoiType.wc => 'wc',
      PoiType.other => 'other',
    };
  }
}
