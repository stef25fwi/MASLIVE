import 'package:flutter_test/flutter_test.dart';

import 'package:masslive/route_style_pro/models/route_style_config.dart';
import 'package:masslive/route_style_pro/models/route_style_preset.dart';

void main() {
  group('RouteStyleConfig', () {
    test('toJson/fromJson roundtrip (stable values)', () {
      final cfg = const RouteStyleConfig(
        carMode: true,
        snapToleranceMeters: 42,
        mainWidth: 9,
        casingWidth: 0,
        opacity: 0.9,
        widthScale3d: 1.4,
        elevationPx: 12,
        dashEnabled: true,
        dashLength: 3.5,
        dashGap: 1.5,
        rainbowEnabled: true,
        rainbowSpeed: 60,
      ).validated();

      final decoded = RouteStyleConfig.fromJson(cfg.toJson()).validated();

      expect(decoded.schemaVersion, cfg.schemaVersion);
      expect(decoded.carMode, cfg.carMode);
      expect(decoded.snapToleranceMeters, cfg.snapToleranceMeters);
      expect(decoded.mainWidth, cfg.mainWidth);
      expect(decoded.casingWidth, cfg.casingWidth);
      expect(decoded.opacity, cfg.opacity);
      expect(decoded.widthScale3d, cfg.widthScale3d);
      expect(decoded.elevationPx, cfg.elevationPx);
      expect(decoded.dashEnabled, cfg.dashEnabled);
      expect(decoded.dashLength, cfg.dashLength);
      expect(decoded.dashGap, cfg.dashGap);
      expect(decoded.rainbowEnabled, cfg.rainbowEnabled);
      expect(decoded.rainbowSpeed, cfg.rainbowSpeed);
    });

    test('validated clamps values (including casingWidth=0)', () {
      final cfg = const RouteStyleConfig(
        snapToleranceMeters: -10,
        mainWidth: -5,
        casingWidth: -1,
        opacity: 10,
        widthScale3d: 999,
        elevationPx: 999,
        glowOpacity: -2,
        vanishingProgress: 3,
        dashLength: -1,
        dashGap: -1,
        simplifyPercent: 1000,
      ).validated();

      expect(cfg.snapToleranceMeters, inInclusiveRange(5, 150));
      expect(cfg.mainWidth, inInclusiveRange(2, 20));
      // casingWidth doit pouvoir être 0 (preset minimal)
      expect(cfg.casingWidth, inInclusiveRange(0, 30));
      expect(cfg.opacity, inInclusiveRange(0.2, 1.0));
      expect(cfg.widthScale3d, inInclusiveRange(0.5, 3.0));
      expect(cfg.elevationPx, inInclusiveRange(0.0, 40.0));
      expect(cfg.glowOpacity, inInclusiveRange(0.0, 1.0));
      expect(cfg.vanishingProgress, inInclusiveRange(0.0, 1.0));
      expect(cfg.dashLength, inInclusiveRange(0.5, 10.0));
      expect(cfg.dashGap, inInclusiveRange(0.5, 10.0));
      expect(cfg.simplifyPercent, inInclusiveRange(0.0, 100.0));
    });
  });

  group('RouteStylePresets', () {
    test('byId returns preset', () {
      final waze = RouteStylePresets.byId('waze');
      expect(waze, isNotNull);
      expect(waze!.id, 'waze');

      final minimal = RouteStylePresets.byId('minimal');
      expect(minimal, isNotNull);
      expect(minimal!.config.casingWidth, 0);
    });

    test('legacy presets are still present and valid', () {
      final ids = RouteStylePresets.all.map((p) => p.id).toSet();
      expect(ids.contains('waze'), isTrue);
      expect(ids.contains('night'), isTrue);
      expect(ids.contains('neon'), isTrue);
      expect(ids.contains('rainbow'), isTrue);
      expect(ids.contains('minimal'), isTrue);

      // (nouveaux) presets demandés
      expect(ids.contains('premium'), isTrue);
      expect(ids.contains('carnival'), isTrue);
      expect(ids.contains('collectivite'), isTrue);

      for (final p in RouteStylePresets.all) {
        final v = p.config.validated();
        // Invariants simples: rien d'inf/NaN et clamp OK.
        expect(v.mainWidth, inInclusiveRange(2.0, 20.0));
        expect(v.casingWidth, inInclusiveRange(0.0, 30.0));
        expect(v.opacity, inInclusiveRange(0.0, 1.0));
        expect(v.glowBlur, inInclusiveRange(0.0, 40.0));
        expect(v.glowWidth, inInclusiveRange(0.0, 30.0));
        expect(v.shadowBlur, inInclusiveRange(0.0, 20.0));
        expect(v.rainbowSaturation, inInclusiveRange(0.0, 1.0));
        expect(v.rainbowSpeed, inInclusiveRange(0.0, 100.0));
      }

      // Signatures attendues (sanity)
      expect(RouteStylePresets.neon.config.glowEnabled, isTrue);
      expect(RouteStylePresets.rainbow.config.rainbowEnabled, isTrue);
      expect(RouteStylePresets.minimal.config.casingWidth, 0.0);
    });

    test('all preset ids are unique', () {
      final ids = RouteStylePresets.all.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });
}
