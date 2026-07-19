import 'package:flutter_test/flutter_test.dart';
import 'package:masslive/features/media_marketplace/domain/catalog/photographer_commercial_catalog.dart';

void main() {
  group('PhotographerCommercialCatalog', () {
    test('propose les quatre offres avec quotas croissants', () {
      final plans = PhotographerCommercialCatalog.plans;

      expect(plans, hasLength(4));
      expect(plans.first.code, 'discovery');
      expect(plans.last.code, 'agency');
      expect(plans[1].maxPublishedPhotos, greaterThan(plans[0].maxPublishedPhotos));
      expect(plans[2].maxStorageBytes, greaterThan(plans[1].maxStorageBytes));
      expect(plans[3].commissionRate, lessThan(plans[2].commissionRate));
    });

    test('met en avant le pack essentiel à 19,90 euros', () {
      final recommended = PhotographerCommercialCatalog.buyerPacks
          .singleWhere((pack) => pack.recommended);

      expect(recommended.code, 'essential');
      expect(recommended.pickCount, 5);
      expect(recommended.price, 19.90);
      expect(recommended.unitPrice, closeTo(3.98, 0.001));
    });

    test('résout les codes Stripe ou Firestore vers le bon plan', () {
      expect(PhotographerCommercialCatalog.resolve('photo_pro_monthly').code, 'pro');
      expect(PhotographerCommercialCatalog.resolve('STUDIO_ANNUAL').code, 'studio');
      expect(PhotographerCommercialCatalog.resolve('agence').code, 'agency');
      expect(PhotographerCommercialCatalog.resolve(null).code, 'discovery');
    });
  });
}
