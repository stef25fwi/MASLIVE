import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String relativePath) => File(relativePath).readAsStringSync();

  test('seller dashboard uses responsive content and adaptive grids', () {
    final dashboard = source(
      'lib/features/bloom_art/presentation/pages/bloom_art_seller_dashboard_page.dart',
    );

    expect(dashboard, contains('ResponsivePageContainer('));
    expect(dashboard, contains('maxContentWidth: 1280'));
    expect(dashboard, contains('compact: 1'));
    expect(dashboard, contains('wide: 3'));
  });

  test('creation form preserves mobile flow and enables desktop pairs', () {
    final createPage = source(
      'lib/features/bloom_art/presentation/pages/bloom_art_item_create_page.dart',
    );

    expect(createPage, contains('maxContentWidth: 1120'));
    expect(createPage, contains('class _BloomArtResponsivePair'));
    expect(createPage, contains('context.isCompactLayout'));
  });

  test('offer and checkout surfaces are constrained on large screens', () {
    final offerDetail = source(
      'lib/features/bloom_art/presentation/pages/bloom_art_offer_detail_page.dart',
    );
    final makeOffer = source(
      'lib/features/bloom_art/presentation/pages/bloom_art_make_offer_sheet.dart',
    );

    expect(offerDetail, contains('Expanded(flex: 3, child: summary)'));
    expect(offerDetail, contains('Expanded(flex: 2, child: actions)'));
    expect(makeOffer, contains('ResponsiveOverlayContainer('));
    expect(makeOffer, contains('mediumMaxWidth: 620'));
    expect(makeOffer, contains('wideMaxWidth: 720'));
  });
}
