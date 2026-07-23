import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masslive/ui_kit/responsive/responsive_overlay_container.dart';

void main() {
  Future<Size> pumpOverlay(
    WidgetTester tester, {
    required double viewportWidth,
  }) async {
    const overlayKey = Key('responsive-overlay');
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: Size(viewportWidth, 800)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: viewportWidth,
            height: 200,
            child: const ResponsiveOverlayContainer(
              compactHorizontalInset: 16,
              mediumMaxWidth: 560,
              expandedMaxWidth: 640,
              wideMaxWidth: 720,
              child: SizedBox(
                key: overlayKey,
                width: double.infinity,
                height: 48,
              ),
            ),
          ),
        ),
      ),
    );
    return tester.getSize(find.byKey(overlayKey));
  }

  testWidgets('preserves compact horizontal insets', (tester) async {
    final size = await pumpOverlay(tester, viewportWidth: 390);
    expect(size.width, 358);
  });

  testWidgets('caps tablet overlay width', (tester) async {
    final size = await pumpOverlay(tester, viewportWidth: 800);
    expect(size.width, 560);
  });

  testWidgets('caps desktop overlay width', (tester) async {
    final size = await pumpOverlay(tester, viewportWidth: 1200);
    expect(size.width, 640);
  });

  testWidgets('caps wide overlay width', (tester) async {
    final size = await pumpOverlay(tester, viewportWidth: 1600);
    expect(size.width, 720);
  });
}
