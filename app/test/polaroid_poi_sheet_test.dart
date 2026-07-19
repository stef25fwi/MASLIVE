import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:masslive/ui/widgets/polaroid_poi_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Finder frameImageFinder() {
    return find.byWidgetPredicate((w) {
      if (w is! Image) return false;
      final img = w.image;
      return img is AssetImage &&
          img.assetName == 'assets/images/frame_polaroid.webp';
    });
  }

  Widget testHost(Widget card) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: SingleChildScrollView(child: card),
          ),
        ),
      ),
    );
  }

  testWidgets('PolaroidPoiCard affiche le frame polaroid webp', (
    tester,
  ) async {
    await tester.pumpWidget(
      testHost(
        const PolaroidPoiCard(
          title: 'Bokit',
          description: 'Test POI Bokit (Guadeloupe / MASLIVE)',
          // Pas besoin d image chargée pour vérifier le frame.
          imageUrl: null,
          meta: {
            'polaroid': {'angleDeg': 2, 'grain': 0.6},
          },
        ),
      ),
    );

    expect(frameImageFinder(), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PolaroidPoiCard prend la photo depuis meta.image.url', (
    tester,
  ) async {
    const url = 'https://example.com/bokit.jpg';

    await tester.pumpWidget(
      testHost(
        const PolaroidPoiCard(
          title: 'Bokit',
          description: 'Test meta.image.url',
          imageUrl: null,
          meta: {
            'image': {'url': url},
            'polaroid': {'angleDeg': 0, 'grain': 0.0},
          },
        ),
      ),
    );

    // Le frame est toujours présent.
    expect(frameImageFinder(), findsWidgets);

    // Et la zone photo tente bien un NetworkImage avec l'URL provenant de meta.
    final networkImages = find.byWidgetPredicate((w) {
      if (w is! Image) return false;
      final img = w.image;
      return img is NetworkImage && img.url == url;
    });
    expect(networkImages, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
