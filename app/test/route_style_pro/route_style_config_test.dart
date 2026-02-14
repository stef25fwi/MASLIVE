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

    test('all preset ids are unique', () {
      final ids = RouteStylePresets.all.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });
}
