import 'package:flutter_test/flutter_test.dart';

import 'package:masslive/services/poi_popup_service.dart';

void main() {
  group('PoiPopupService.isPopupEnabled', () {
    test('fallback wc=false when missing', () {
      expect(
        PoiPopupService.isPopupEnabled(type: 'wc', meta: const {}),
        isFalse,
      );
      expect(
        PoiPopupService.isPopupEnabled(type: 'toilet', meta: const {}),
        isFalse,
      );
    });

    test('fallback non-wc=true when missing', () {
      expect(
        PoiPopupService.isPopupEnabled(type: 'food', meta: const {}),
        isTrue,
      );
      expect(
        PoiPopupService.isPopupEnabled(type: 'visit', meta: const {}),
        isTrue,
      );
      expect(
        PoiPopupService.isPopupEnabled(type: 'parking', meta: const {}),
        isTrue,
      );
    });

    test('parses bool/num/string from meta', () {
      expect(
        PoiPopupService.isPopupEnabled(type: 'wc', meta: {'popupEnabled': true}),
        isTrue,
      );
      expect(
        PoiPopupService.isPopupEnabled(type: 'visit', meta: {'popupEnabled': 0}),
        isFalse,
      );
      expect(
        PoiPopupService.isPopupEnabled(
          type: 'visit',
          meta: {'popupEnabled': 'yes'},
        ),
        isTrue,
      );
      expect(
        PoiPopupService.isPopupEnabled(
          type: 'visit',
          meta: {'popupEnabled': 'no'},
        ),
        isFalse,
      );
    });

    test('rootPopupEnabled is used when meta missing', () {
      expect(
        PoiPopupService.isPopupEnabled(type: 'visit', rootPopupEnabled: false),
        isFalse,
      );
      expect(
        PoiPopupService.isPopupEnabled(type: 'wc', rootPopupEnabled: true),
        isTrue,
      );
    });

    test('requireImage forces false when no image', () {
      expect(
        PoiPopupService.isPopupEnabled(
          type: 'visit',
          meta: {'popupEnabled': true},
          requireImage: true,
          hasImage: false,
        ),
        isFalse,
      );
    });
  });
}
