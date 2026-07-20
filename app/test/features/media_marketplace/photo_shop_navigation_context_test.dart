import 'package:flutter_test/flutter_test.dart';
import 'package:masslive/features/media_marketplace/domain/models/photo_shop_navigation_context.dart';

void main() {
  test('accepts legacy and selected route argument names', () {
    final context = PhotoShopNavigationContext.fromRouteArguments(
      <String, dynamic>{
        'selectedCircuitId': 'circuit-1',
        'mapId': 'map-1',
        'selectedEventDate': '2026-07-18T08:30:00.000',
        'countryId': 'GP',
        'eventId': 'event-1',
        'photographerId': 'photo-1',
      },
    );

    expect(context.selectedCircuitId, 'circuit-1');
    expect(context.selectedMapId, 'map-1');
    expect(context.selectedCountryId, 'GP');
    expect(context.selectedEventId, 'event-1');
    expect(context.selectedPhotographerId, 'photo-1');
    expect(context.selectedEventDate, DateTime(2026, 7, 18, 8, 30));
    expect(context.hasSelection, isTrue);
  });

  test('serializes only meaningful values', () {
    const context = PhotoShopNavigationContext(
      selectedCircuitId: ' circuit-1 ',
      selectedCountryId: 'GP',
    );

    expect(
      context.toRouteArguments(),
      <String, dynamic>{'circuitId': 'circuit-1', 'countryId': 'GP'},
    );
  });
}
