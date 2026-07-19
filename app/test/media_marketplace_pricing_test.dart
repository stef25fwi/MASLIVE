import 'package:flutter_test/flutter_test.dart';
import 'package:masslive/features/media_marketplace/core/constants/media_marketplace_pricing.dart';

void main() {
  group('MediaMarketplacePricing', () {
    test('expose les cinq packs acheteurs approuvés', () {
      expect(
        MediaMarketplacePricing.buyerPacks
            .map((pack) => <Object>[pack.photoCount, pack.price])
            .toList(growable: false),
        <List<Object>>[
          <Object>[1, 6.90],
          <Object>[2, 10.90],
          <Object>[5, 19.90],
          <Object>[10, 29.90],
          <Object>[20, 44.90],
        ],
      );
      expect(
        MediaMarketplacePricing.buyerPacks
            .singleWhere((pack) => pack.highlighted)
            .code,
        'essential',
      );
    });

    test('calcule la meilleure combinaison de packs', () {
      expect(MediaMarketplacePricing.priceForPhotoCount(1), 6.90);
      expect(MediaMarketplacePricing.priceForPhotoCount(2), 10.90);
      expect(MediaMarketplacePricing.priceForPhotoCount(5), 19.90);
      expect(MediaMarketplacePricing.priceForPhotoCount(7), 30.80);
      expect(MediaMarketplacePricing.priceForPhotoCount(20), 44.90);
      expect(MediaMarketplacePricing.priceForPhotoCount(21), 51.80);
    });

    test('conserve les quatre plans et commissions', () {
      final plans = MediaMarketplacePricing.photographerPlans;
      expect(plans.map((plan) => plan.code), <String>[
        'discovery',
        'pro',
        'studio',
        'agency',
      ]);
      expect(plans.map((plan) => plan.monthlyPrice), <double>[
        0,
        19.90,
        39.90,
        79.90,
      ]);
      expect(plans.map((plan) => plan.maxPublishedPhotos), <int>[
        250,
        3000,
        10000,
        30000,
      ]);
      expect(plans.map((plan) => plan.commissionRate), <double>[
        0.30,
        0.25,
        0.20,
        0.15,
      ]);
    });

    test('conserve les extensions de stockage', () {
      final extensions = MediaMarketplacePricing.storageExtensions;
      expect(extensions.map((item) => item.monthlyPrice), <double>[
        5.90,
        19.90,
        9.90,
      ]);
      expect(extensions.map((item) => item.extraPhotos), <int>[
        1000,
        5000,
        5000,
      ]);
      expect(extensions.last.durationDays, 30);
    });
  });
}
