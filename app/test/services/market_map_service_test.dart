import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masslive/services/market_map_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MarketMapService.watchVisiblePois', () {
    test('keeps legacy food POIs visible when layerId is missing', () async {
      final firestore = FakeFirebaseFirestore();
      final service = MarketMapService(firestore: firestore);

      final poisCol = firestore
          .collection('marketMap')
          .doc('gp')
          .collection('events')
          .doc('event-1')
          .collection('circuits')
          .doc('circuit-1')
          .collection('pois');

      await poisCol.doc('food-legacy').set({
        'name': 'Food Truck Legacy',
        'lat': 16.24,
        'lng': -61.53,
        'layerType': 'food',
        'type': 'restaurant',
        'isVisible': true,
      });

      await poisCol.doc('visit-poi').set({
        'name': 'Belvédère',
        'lat': 16.25,
        'lng': -61.54,
        'layerId': 'visit',
        'layerType': 'visit',
        'isVisible': true,
      });

      final pois = await service
          .watchVisiblePois(
            countryId: 'gp',
            eventId: 'event-1',
            circuitId: 'circuit-1',
            layerIds: const <String>{'food'},
          )
          .first;

      expect(pois, hasLength(1));
      expect(pois.single.id, 'food-legacy');
      expect(pois.single.type, 'food');
      expect(pois.single.layerId, 'food');
    });

    test('still filters out visible POIs from other layers', () async {
      final firestore = FakeFirebaseFirestore();
      final service = MarketMapService(firestore: firestore);

      final poisCol = firestore
          .collection('marketMap')
          .doc('gp')
          .collection('events')
          .doc('event-1')
          .collection('circuits')
          .doc('circuit-1')
          .collection('pois');

      await poisCol.doc('wc-poi').set({
        'name': 'WC central',
        'lat': 16.26,
        'lng': -61.55,
        'layerType': 'wc',
        'isVisible': true,
      });

      final pois = await service
          .watchVisiblePois(
            countryId: 'gp',
            eventId: 'event-1',
            circuitId: 'circuit-1',
            layerIds: const <String>{'food'},
          )
          .first;

      expect(pois, isEmpty);
    });

    test('accepts legacy visible flag when isVisible is absent', () async {
      final firestore = FakeFirebaseFirestore();
      final service = MarketMapService(firestore: firestore);

      final poisCol = firestore
          .collection('marketMap')
          .doc('gp')
          .collection('events')
          .doc('event-1')
          .collection('circuits')
          .doc('circuit-1')
          .collection('pois');

      await poisCol.doc('food-visible-legacy').set({
        'name': 'Resto legacy',
        'lat': 16.27,
        'lng': -61.56,
        'layerType': 'food',
        'visible': true,
      });

      final pois = await service
          .watchVisiblePois(
            countryId: 'gp',
            eventId: 'event-1',
            circuitId: 'circuit-1',
            layerIds: const <String>{'food'},
          )
          .first;

      expect(pois, hasLength(1));
      expect(pois.single.id, 'food-visible-legacy');
    });
  });
}