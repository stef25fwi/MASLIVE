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

    test('calcule le tarif réellement le moins cher, bonus inclus', () {
      expect(MediaMarketplacePricing.priceForPhotoCount(1), closeTo(6.90, .001));
      expect(MediaMarketplacePricing.priceForPhotoCount(2), closeTo(10.90, .001));
      expect(MediaMarketplacePricing.priceForPhotoCount(5), closeTo(19.90, .001));
      expect(MediaMarketplacePricing.priceForPhotoCount(7), closeTo(29.90, .001));
      expect(MediaMarketplacePricing.priceForPhotoCount(9), closeTo(29.90, .001));
      expect(MediaMarketplacePricing.priceForPhotoCount(20), closeTo(44.90, .001));
      expect(MediaMarketplacePricing.priceForPhotoCount(21), closeTo(51.80, .001));

      final quote = MediaMarketplacePricing.quoteForPhotoCount(9);
      expect(quote.requestedPhotoCount, 9);
      expect(quote.billedPhotoCount, 10);
      expect(quote.bonusPhotoSlots, 1);
      expect(quote.packs.single.code, 'experience');
    });

    test('ne facture jamais plus cher que la sélection à l’unité', () {
      for (var count = 1; count <= 100; count++) {
        expect(
          MediaMarketplacePricing.priceForPhotoCount(count),
          lessThanOrEqualTo((count * 6.90) + .001),
          reason: '$count photo(s)',
        );
      }
    });

    test('conserve les quatre plans et sépare les crédits IA', () {
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
      expect(plans.every((plan) => plan.includedBasicAiCredits == 0), isTrue);
      expect(plans.every((plan) => plan.includedAdvancedAiCredits == 0), isTrue);
    });

    test('expose la grille approuvée de stockage, IA et événement', () {
      final extensions = MediaMarketplacePricing.storageExtensions;
      expect(
        extensions
            .map(
              (item) => <Object>[
                item.code,
                item.monthlyPrice,
                item.extraPhotos,
                item.extraStorageBytes ~/ (1024 * 1024 * 1024),
                item.basicAiCredits,
                item.advancedAiCredits,
                item.durationDays ?? 0,
              ],
            )
            .toList(growable: false),
        <List<Object>>[
          <Object>['plus_1000', 5.90, 1000, 10, 0, 0, 0],
          <Object>['plus_5000', 19.90, 5000, 50, 0, 0, 0],
          <Object>['ai_basic_1000', 7.90, 0, 0, 1000, 0, 36500],
          <Object>['ai_advanced_1000', 11.90, 0, 0, 0, 1000, 36500],
          <Object>['event_30d', 14.90, 5000, 50, 0, 0, 30],
          <Object>['event_30d_basic', 29.90, 5000, 50, 5000, 0, 30],
          <Object>['event_30d_advanced', 39.90, 5000, 50, 0, 5000, 30],
        ],
      );
      expect(
        MediaMarketplacePricing.extensionFor('AI_BASIC_1000')
            ?.creditsNeverExpire,
        isTrue,
      );
      expect(
        MediaMarketplacePricing.extensionFor('event_30d_advanced')
            ?.creditsExpireWithExtension,
        isTrue,
      );
      expect(MediaMarketplacePricing.estimatedAiCostPerAnalysisEur, 0.01);
    });

    test('documente la règle de consommation dans les libellés', () {
      final basic = MediaMarketplacePricing.extensionFor('ai_basic_1000')!;
      final advanced = MediaMarketplacePricing.extensionFor('ai_advanced_1000')!;
      expect(basic.billingLabel, contains('achat unique'));
      expect(basic.capacityLines, contains('Crédits sans expiration'));
      expect(
        advanced.capacityLines.join(' '),
        contains('regroupement visuel'),
      );
    });
  });
}
