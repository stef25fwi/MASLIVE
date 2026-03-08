import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:masslive/route_style_pro/models/route_style_config.dart';
import 'package:masslive/route_style_pro/models/route_style_preset.dart';
import 'package:masslive/route_style_pro/ui/widgets/route_style_controls_panel.dart';

void main() {
  testWidgets('RouteStyleControlsPanel exposes rainbow casing toggle', (
    tester,
  ) async {
    RouteStyleConfig? last;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RouteStyleControlsPanel(
            config: const RouteStyleConfig(),
            onChanged: (cfg) => last = cfg,
            onTestAutoRoute: () {},
            onUseMyTrace: () {},
            onSave: () {},
            onReset: () {},
          ),
        ),
      ),
    );

    await tester.scrollUntilVisible(find.text('Rainbow casing'), 200);

    expect(find.text('Rainbow casing'), findsOneWidget);

    await tester.tap(find.text('Rainbow casing'));
    await tester.pump();

    expect(last, isNotNull);
    expect(last!.casingRainbowEnabled, isTrue);
  });

  testWidgets('RouteStyleControlsPanel exposes fit-to-road toggle', (
    tester,
  ) async {
    RouteStyleConfig? last;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RouteStyleControlsPanel(
            config: const RouteStyleConfig(),
            onChanged: (cfg) => last = cfg,
            onTestAutoRoute: () {},
            onUseMyTrace: () {},
            onSave: () {},
            onReset: () {},
          ),
        ),
      ),
    );

    expect(find.text('Respecter la largeur de la route'), findsOneWidget);

    await tester.tap(find.text('Respecter la largeur de la route'));
    await tester.pump();

    expect(last, isNotNull);
    expect(last!.fitToRoadWidth, isTrue);
  });

  testWidgets('RouteStyleControlsPanel presets chips apply config on tap', (
    tester,
  ) async {
    RouteStyleConfig? last;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RouteStyleControlsPanel(
            config: const RouteStyleConfig(),
            onChanged: (cfg) => last = cfg,
            onTestAutoRoute: () {},
            onUseMyTrace: () {},
            onSave: () {},
            onReset: () {},
          ),
        ),
      ),
    );

    // Ouvre la section Presets
    await tester.scrollUntilVisible(find.text('Presets'), 200);
    await tester.tap(find.text('Presets'));
    await tester.pumpAndSettle();

    // Vérifie qu'au moins un preset historique est visible
    expect(
      find.widgetWithText(ChoiceChip, RouteStylePresets.wazeLike.label),
      findsOneWidget,
    );

    // Tap sur "Neon" et vérifie que le callback renvoie une config cohérente
    await tester.tap(
      find.widgetWithText(ChoiceChip, RouteStylePresets.neon.label),
    );
    await tester.pump();

    final applied = last!.validated();
    expect(
      applied.mainColor.toARGB32(),
      RouteStylePresets.neon.config.mainColor.toARGB32(),
    );
    expect(applied.glowEnabled, isTrue);

    // Tap sur "Minimal" => casingWidth doit pouvoir rester à 0
    await tester.tap(
      find.widgetWithText(ChoiceChip, RouteStylePresets.minimal.label),
    );
    await tester.pump();

    final minimalApplied = last!.validated();
    expect(minimalApplied.casingWidth, 0.0);
    expect(minimalApplied.shadowEnabled, isFalse);
  });
}
