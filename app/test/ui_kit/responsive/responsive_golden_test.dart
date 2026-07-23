import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masslive/ui_kit/responsive/responsive.dart';

void main() {
  group('MASLIVE responsive golden references', () {
    for (final viewport in const <({double width, String name})>[
      (width: 320, name: 'compact_320'),
      (width: 600, name: 'tablet_600'),
      (width: 1024, name: 'desktop_1024'),
      (width: 1440, name: 'wide_1440'),
    ]) {
      testWidgets(viewport.name, (tester) async {
        await tester.binding.setSurfaceSize(Size(viewport.width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF111111),
                brightness: Brightness.light,
              ),
              scaffoldBackgroundColor: const Color(0xFFF6F4F0),
            ),
            home: _GoldenViewport(width: viewport.width),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byKey(const Key('responsive-golden-boundary')),
          matchesGoldenFile('goldens/${viewport.name}.png'),
        );
      });
    }
  });
}

class _GoldenViewport extends StatelessWidget {
  const _GoldenViewport({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RepaintBoundary(
        key: const Key('responsive-golden-boundary'),
        child: ColoredBox(
          color: const Color(0xFFF6F4F0),
          child: ResponsivePageContainer(
            maxContentWidth: 1200,
            compactPadding: const EdgeInsets.fromLTRB(12, 18, 12, 18),
            mediumPadding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
            expandedPadding: const EdgeInsets.fromLTRB(30, 26, 30, 26),
            widePadding: const EdgeInsets.fromLTRB(38, 30, 38, 30),
            child: ResponsiveLayout(
              compact: (_, __) => _GoldenContent(
                viewportWidth: width,
                columns: 1,
                itemCount: 1,
                windowLabel: 'Mobile',
              ),
              medium: (_, __) => _GoldenContent(
                viewportWidth: width,
                columns: 2,
                itemCount: 4,
                windowLabel: 'Tablette',
              ),
              expanded: (_, __) => _GoldenContent(
                viewportWidth: width,
                columns: 3,
                itemCount: 3,
                windowLabel: 'Desktop',
              ),
              wide: (_, __) => _GoldenContent(
                viewportWidth: width,
                columns: 4,
                itemCount: 4,
                windowLabel: 'Grand écran',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoldenContent extends StatelessWidget {
  const _GoldenContent({
    required this.viewportWidth,
    required this.columns,
    required this.itemCount,
    required this.windowLabel,
  });

  final double viewportWidth;
  final int columns;
  final int itemCount;
  final String windowLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE6E0D8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Galerie BLoOmOod Art',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Laissez-vous séduire par une œuvre, faites une offre et concrétisez votre coup de cœur à votre rythme.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5F5A54),
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _GoldenChip(label: windowLabel),
                  _GoldenChip(label: '${viewportWidth.toInt()} px'),
                  const _GoldenChip(label: 'Peinture'),
                  const _GoldenChip(label: 'Sculpture'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 12.0;
            final itemWidth =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: List<Widget>.generate(
                itemCount,
                (index) => SizedBox(
                  width: itemWidth,
                  child: _ArtworkCard(index: index),
                ),
              ),
            );
          },
        ),
        const Spacer(),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
              label: const Text('Déposer une œuvre'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                backgroundColor: const Color(0xFF111111),
                foregroundColor: Colors.white,
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.local_offer_outlined, size: 20),
              label: const Text('Voir les offres'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: const Color(0xFF111111),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GoldenChip extends StatelessWidget {
  const _GoldenChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ArtworkCard extends StatelessWidget {
  const _ArtworkCard({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    const swatches = <Color>[
      Color(0xFFE7D7C7),
      Color(0xFFD5DFD7),
      Color(0xFFD8D4E3),
      Color(0xFFE4DDC8),
    ];

    return Container(
      height: 178,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6E0D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: swatches[index % swatches.length],
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(
                index.isEven ? Icons.brush_outlined : Icons.auto_awesome_outlined,
                size: 34,
                color: const Color(0xFF5F554C),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Création ${index + 1}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          const Text(
            'Pièce unique · offre ouverte',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Color(0xFF6C655E)),
          ),
        ],
      ),
    );
  }
}
