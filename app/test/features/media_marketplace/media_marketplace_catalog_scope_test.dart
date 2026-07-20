import 'package:flutter_test/flutter_test.dart';
import 'package:masslive/features/media_marketplace/domain/models/photo_shop_navigation_context.dart';
import 'package:masslive/features/media_marketplace/domain/models/photo_search_query.dart';

void main() {
  group('PhotoShopNavigationContext', () {
    test('normalise et conserve les champs contextuels', () {
      final context = PhotoShopNavigationContext.fromRouteArguments(
        <String, dynamic>{
          'selectedCircuitId': ' circuit-1 ',
          'selectedMapId': ' map-1 ',
          'selectedCountryId': ' GP ',
          'selectedEventId': ' event-1 ',
          'selectedPhotographerId': ' photographer-1 ',
          'selectedPointId': ' point-1 ',
          'selectedTimeSlot': ' 08:00-10:00 ',
          'selectedEventDate': '2026-07-18T08:30:00.000Z',
        },
      );

      expect(context.selectedCircuitId, 'circuit-1');
      expect(context.selectedMapId, 'map-1');
      expect(context.selectedCountryId, 'GP');
      expect(context.selectedEventId, 'event-1');
      expect(context.selectedPhotographerId, 'photographer-1');
      expect(context.selectedPointId, 'point-1');
      expect(context.selectedTimeSlot, '08:00-10:00');
      expect(context.selectedEventDate, isNotNull);
    });

    test('reste compatible avec les anciens arguments de route', () {
      final context = PhotoShopNavigationContext.fromRouteArguments(
        <String, dynamic>{
          'circuitId': 'legacy-circuit',
          'countryId': 'legacy-country',
          'eventId': 'legacy-event',
          'photographerId': 'legacy-photographer',
          'eventDate': DateTime.utc(2026, 7, 18),
        },
      );

      expect(context.selectedCircuitId, 'legacy-circuit');
      expect(context.selectedCountryId, 'legacy-country');
      expect(context.selectedEventId, 'legacy-event');
      expect(context.selectedPhotographerId, 'legacy-photographer');
      expect(context.selectedEventDate, DateTime.utc(2026, 7, 18));
    });

    test('toRouteArguments expose les clés modernes et historiques', () {
      const context = PhotoShopNavigationContext(
        selectedCircuitId: 'circuit-1',
        selectedMapId: 'map-1',
        selectedCountryId: 'GP',
        selectedEventId: 'event-1',
      );

      final arguments = context.toRouteArguments(includeLegacyAliases: true);

      expect(arguments['selectedCircuitId'], 'circuit-1');
      expect(arguments['circuitId'], 'circuit-1');
      expect(arguments['selectedMapId'], 'map-1');
      expect(arguments['selectedCountryId'], 'GP');
      expect(arguments['countryId'], 'GP');
      expect(arguments['selectedEventId'], 'event-1');
      expect(arguments['eventId'], 'event-1');
    });

    test('les valeurs vides sont retirées du contexte', () {
      final context = PhotoShopNavigationContext.fromRouteArguments(
        <String, dynamic>{
          'selectedCircuitId': '   ',
          'selectedCountryId': '',
          'selectedEventId': null,
        },
      );

      expect(context.selectedCircuitId, isNull);
      expect(context.selectedCountryId, isNull);
      expect(context.selectedEventId, isNull);
      expect(context.toRouteArguments(), isEmpty);
    });
  });

  group('PhotoSearchQuery', () {
    test('normalise les critères de recherche participant', () {
      final query = PhotoSearchQuery.fromMap(<String, dynamic>{
        'circuitId': ' circuit-1 ',
        'participantNumber': ' 42 ',
        'bibNumber': ' B-42 ',
        'outfitColor': ' Rouge ',
        'groupId': ' group-1 ',
        'teamId': ' team-1 ',
        'timeSlot': ' 08:00-10:00 ',
        'participantQrCode': ' QR-42 ',
      });

      expect(query.circuitId, 'circuit-1');
      expect(query.participantNumber, '42');
      expect(query.bibNumber, 'B-42');
      expect(query.outfitColor, 'Rouge');
      expect(query.groupId, 'group-1');
      expect(query.teamId, 'team-1');
      expect(query.timeSlot, '08:00-10:00');
      expect(query.participantQrCode, 'QR-42');
      expect(query.hasCriteria, isTrue);
    });

    test('une recherche vide ne déclenche aucun critère', () {
      final query = PhotoSearchQuery.fromMap(<String, dynamic>{
        'participantNumber': ' ',
        'bibNumber': null,
      });

      expect(query.hasCriteria, isFalse);
    });
  });
}
