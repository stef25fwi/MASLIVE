import 'package:flutter_test/flutter_test.dart';

import 'package:masslive/utils/poi_normalizer.dart';

void main() {
  group('PoiNormalizer.normalizePoiType', () {
    test('normalise wc aliases', () {
      expect(PoiNormalizer.normalizePoiType('wc'), PoiType.wc);
      expect(PoiNormalizer.normalizePoiType('Toilet'), PoiType.wc);
      expect(PoiNormalizer.normalizePoiType('toilettes'), PoiType.wc);
      expect(PoiNormalizer.normalizePoiType('public toilet'), PoiType.wc);
    });

    test('normalise visit aliases', () {
      expect(PoiNormalizer.normalizePoiType('visit'), PoiType.visit);
      expect(PoiNormalizer.normalizePoiType('tour'), PoiType.visit);
      expect(PoiNormalizer.normalizePoiType('Visiter'), PoiType.visit);
    });

    test('normalise food aliases', () {
      expect(PoiNormalizer.normalizePoiType('food'), PoiType.food);
      expect(PoiNormalizer.normalizePoiType('restaurant'), PoiType.food);
      expect(PoiNormalizer.normalizePoiType('bar'), PoiType.food);
    });

    test('unknown -> other', () {
      expect(PoiNormalizer.normalizePoiType(null), PoiType.other);
      expect(PoiNormalizer.normalizePoiType(''), PoiType.other);
      expect(PoiNormalizer.normalizePoiType('parking'), PoiType.other);
    });
  });
}
