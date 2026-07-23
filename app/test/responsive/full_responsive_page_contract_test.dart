import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Full responsive production page contracts', () {
    final contracts = <String, List<String>>{
      'lib/features/bloom_art/presentation/pages/bloom_art_seller_dashboard_page.dart': <String>[
        'ResponsivePageContainer(',
        'maxContentWidth: 1280',
        'responsiveValue<int>(',
      ],
      'lib/features/bloom_art/presentation/pages/bloom_art_item_create_page.dart': <String>[
        'ResponsivePageContainer(',
        'maxContentWidth: 1120',
        '_BloomArtResponsivePair(',
      ],
      'lib/features/bloom_art/presentation/pages/bloom_art_offer_detail_page.dart': <String>[
        'ResponsivePageContainer(',
        'LayoutBuilder(',
        'context.isCompactLayout',
      ],
      'lib/features/bloom_art/presentation/pages/bloom_art_make_offer_sheet.dart': <String>[
        'ResponsiveOverlayContainer(',
      ],
      'lib/admin/admin_main_dashboard.dart': <String>[
        'ResponsivePageContainer(',
        'maxContentWidth: 1440',
      ],
      'lib/admin/admin_analytics_page.dart': <String>[
        'ResponsivePageContainer(',
        'maxContentWidth: 1280',
        'responsiveValue<int>(',
      ],
      'lib/admin/admin_orders_page.dart': <String>[
        'ResponsivePageContainer(',
        'ResponsiveOverlayContainer(',
      ],
      'lib/admin/tracking_live/tracking_live_page.dart': <String>[
        'ResponsivePageContainer(',
        'maxContentWidth: 1440',
        'context.isCompactLayout',
      ],
      'lib/admin/circuit_wizard_entry_page.dart': <String>[
        'ResponsivePageContainer(',
        'maxContentWidth: 1200',
        'responsiveValue<double>(',
      ],
    };

    for (final entry in contracts.entries) {
      test('${entry.key} keeps its responsive contract', () {
        final file = File(entry.key);
        expect(file.existsSync(), isTrue, reason: 'Missing page: ${entry.key}');
        final source = file.readAsStringSync();

        for (final marker in entry.value) {
          expect(
            source,
            contains(marker),
            reason: '${entry.key} must retain marker: $marker',
          );
        }
      });
    }

    test('the compact range remains the smartphone source of truth', () {
      final source = File(
        'lib/ui_kit/responsive/responsive_breakpoints.dart',
      ).readAsStringSync();

      expect(source, contains('static const double compactMax = 599;'));
      expect(source, contains('static const double mediumMin = 600;'));
      expect(source, contains('static const double expandedMin = 1024;'));
      expect(source, contains('static const double wideMin = 1440;'));
    });
  });
}
