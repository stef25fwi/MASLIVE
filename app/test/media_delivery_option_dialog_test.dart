import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masslive/features/media_marketplace/presentation/widgets/media_delivery_option_dialog.dart';

void main() {
  testWidgets('affiche clairement les droits Web et HD', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MediaDeliveryOptionDialog()),
      ),
    );

    expect(find.text('Qualité de téléchargement'), findsOneWidget);
    expect(find.text('Version Web incluse'), findsOneWidget);
    expect(find.text('Fichiers HD et originaux'), findsOneWidget);
    expect(find.text('Inclus'), findsOneWidget);
    expect(find.text('+2.90 €'), findsOneWidget);
    expect(
      find.textContaining('Les fichiers originaux ne sont pas inclus'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('retourne false pour la version Web', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await showMediaDeliveryOptionDialog(context);
              },
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('media_delivery_standard')));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  testWidgets('retourne true pour le supplément HD', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await showMediaDeliveryOptionDialog(context);
              },
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('media_delivery_hd')));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });
}
