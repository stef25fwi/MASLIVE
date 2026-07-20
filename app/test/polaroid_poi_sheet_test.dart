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

  Finder customPainterFinder(String runtimeTypeName) {
    return find.byWidgetPredicate((w) {
      return w is CustomPaint &&
          w.painter?.runtimeType.toString() == runtimeTypeName;
    });
  }

  Finder textWithFontFinder(String text, String fontFamily) {
    return find.byWidgetPredicate((w) {
      return w is Text &&
          w.data == text &&
          w.style?.fontFamily == fontFamily;
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

  const completeCard = PolaroidPoiCard(
    title: 'Bokit',
    description: 'Spécialité locale',
    hours: '08:00 - 18:00',
    phone: '+590690000000',
    lat: 16.241,
    lng: -61.534,
    imageUrl: null,
    meta: {
      'polaroid': {'angleDeg': -1.1, 'grain': 0.6},
    },
  );

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

  testWidgets('le scotch décoratif reste présent au-dessus du polaroid', (
    tester,
  ) async {
    await tester.pumpWidget(testHost(completeCard));

    final tapeFinder = customPainterFinder('_TapePainter');
    expect(tapeFinder, findsOneWidget);

    final tape = tester.widget<CustomPaint>(tapeFinder);
    expect(tape.size, const Size(112, 34));
    expect(tester.takeException(), isNull);
  });

  testWidgets('les informations conservent la typographie manuscrite MASLIVE', (
    tester,
  ) async {
    await tester.pumpWidget(testHost(completeCard));

    expect(textWithFontFinder('BOKIT', 'MASLIVEBrushV2'), findsOneWidget);
    expect(
      textWithFontFinder('Spécialité locale', 'MASLIVEBrushV2'),
      findsOneWidget,
    );
    expect(
      textWithFontFinder('08:00 - 18:00', 'MASLIVEBrushV2'),
      findsOneWidget,
    );
    expect(
      textWithFontFinder('+590690000000', 'MASLIVEBrushV2'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('les actions gardent leurs deux fonds en coup de pinceau rose', (
    tester,
  ) async {
    await tester.pumpWidget(testHost(completeCard));

    expect(customPainterFinder('_BrushStrokePainter'), findsNWidgets(2));
    expect(find.text('APPELER'), findsOneWidget);
    expect(find.text('ITINÉRAIRE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
