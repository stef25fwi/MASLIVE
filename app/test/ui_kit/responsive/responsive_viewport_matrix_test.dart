import 'dart:ui' show SemanticsFlag;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masslive/ui_kit/responsive/responsive.dart';

const _targetWidths = <double>[320, 360, 390, 430, 600, 768, 1024, 1280, 1440];

void main() {
  group('MASLIVE final responsive viewport matrix', () {
    test('the nine target widths resolve to the expected window classes', () {
      final expected = <double, MasliveWindowClass>{
        320: MasliveWindowClass.compact,
        360: MasliveWindowClass.compact,
        390: MasliveWindowClass.compact,
        430: MasliveWindowClass.compact,
        600: MasliveWindowClass.medium,
        768: MasliveWindowClass.medium,
        1024: MasliveWindowClass.expanded,
        1280: MasliveWindowClass.expanded,
        1440: MasliveWindowClass.wide,
      };

      for (final entry in expected.entries) {
        final resolved = MasliveBreakpoints.isCompact(entry.key)
            ? MasliveWindowClass.compact
            : MasliveBreakpoints.isMedium(entry.key)
            ? MasliveWindowClass.medium
            : MasliveBreakpoints.isExpanded(entry.key)
            ? MasliveWindowClass.expanded
            : MasliveWindowClass.wide;
        expect(
          resolved,
          entry.value,
          reason: 'Unexpected class at ${entry.key}px',
        );
      }
    });

    for (final width in _targetWidths) {
      testWidgets('renders without overflow at ${width.toInt()}px', (
        tester,
      ) async {
        await _pumpFixture(tester, width: width, textScale: 1);

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('matrix-content')), findsOneWidget);
        expect(find.text('Largeur ${width.toInt()} px'), findsOneWidget);
      });
    }

    for (final width in _targetWidths) {
      testWidgets(
        'remains usable at ${width.toInt()}px with 150% text scaling',
        (tester) async {
          await _pumpFixture(tester, width: width, textScale: 1.5);

          expect(tester.takeException(), isNull);
          expect(find.byKey(const Key('primary-action')), findsOneWidget);
          expect(find.byKey(const Key('secondary-action')), findsOneWidget);
        },
      );
    }

    testWidgets('interactive controls keep accessible tap targets', (
      tester,
    ) async {
      await _pumpFixture(tester, width: 320, textScale: 1.5);

      for (final finder in <Finder>[
        find.byKey(const Key('primary-action')),
        find.byKey(const Key('secondary-action')),
      ]) {
        final size = tester.getSize(finder);
        expect(size.height, greaterThanOrEqualTo(48));
        expect(size.width, greaterThanOrEqualTo(48));
      }
    });

    testWidgets('primary actions expose meaningful semantics', (tester) async {
      final semantics = tester.ensureSemantics();
      addTearDown(semantics.dispose);
      await _pumpFixture(tester, width: 390, textScale: 1.3);

      final node = tester.getSemantics(
        find.byKey(const Key('primary-action')),
      );
      expect(node.label, contains('Déposer une œuvre'));
      expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
    });
  });
}

Future<void> _pumpFixture(
  WidgetTester tester, {
  required double width,
  required double textScale,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: _ResponsiveMatrixFixture(viewportWidth: width),
    ),
  );
  await tester.pumpAndSettle();
}

class _ResponsiveMatrixFixture extends StatelessWidget {
  const _ResponsiveMatrixFixture({required this.viewportWidth});

  final double viewportWidth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      body: ResponsivePageContainer(
        maxContentWidth: 1200,
        compactPadding: const EdgeInsets.all(12),
        mediumPadding: const EdgeInsets.all(20),
        expandedPadding: const EdgeInsets.all(28),
        widePadding: const EdgeInsets.all(36),
        child: SingleChildScrollView(
          child: ResponsiveLayout(
            compact: (_, __) => _MatrixContent(
              viewportWidth: viewportWidth,
              columns: 1,
              windowClass: 'compact',
            ),
            medium: (_, __) => _MatrixContent(
              viewportWidth: viewportWidth,
              columns: 2,
              windowClass: 'medium',
            ),
            expanded: (_, __) => _MatrixContent(
              viewportWidth: viewportWidth,
              columns: 3,
              windowClass: 'expanded',
            ),
            wide: (_, __) => _MatrixContent(
              viewportWidth: viewportWidth,
              columns: 4,
              windowClass: 'wide',
            ),
          ),
        ),
      ),
    );
  }
}

class _MatrixContent extends StatelessWidget {
  const _MatrixContent({
    required this.viewportWidth,
    required this.columns,
    required this.windowClass,
  });

  final double viewportWidth;
  final int columns;
  final String windowClass;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('matrix-content'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            'Galerie BLoOmOod Art',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Largeur ${viewportWidth.toInt()} px · classe $windowClass. Découvrez, proposez un prix et concrétisez votre coup de cœur à votre rythme.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: const <Widget>[
            Chip(label: Text('Peinture')),
            Chip(label: Text('Sculpture')),
            Chip(label: Text('Photographie')),
            Chip(label: Text('Artisanat d’art')),
          ],
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 12.0;
            final cardWidth =
                (constraints.maxWidth - (spacing * (columns - 1))) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: List<Widget>.generate(
                4,
                (index) => SizedBox(
                  width: cardWidth,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const AspectRatio(
                            aspectRatio: 16 / 10,
                            child: ColoredBox(color: Color(0xFFE8E1D8)),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Création ${index + 1}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Une pièce unique présentée avec une description suffisamment longue pour tester les retours à la ligne.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            Semantics(
              button: true,
              label: 'Déposer une œuvre',
              child: FilledButton.icon(
                key: const Key('primary-action'),
                onPressed: () {},
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Déposer une œuvre'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
              ),
            ),
            OutlinedButton.icon(
              key: const Key('secondary-action'),
              onPressed: () {},
              icon: const Icon(Icons.dashboard_outlined),
              label: const Text('Ouvrir mon dashboard vendeur'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 48),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
