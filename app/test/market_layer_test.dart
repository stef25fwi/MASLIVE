import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masslive/models/market_circuit.dart';
import 'package:masslive/models/market_circuit_models.dart';
import 'package:masslive/models/market_layer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Market layer visibility compatibility', () {
    test('MarketLayer.fromDoc falls back to isVisible and visible', () async {
      final firestore = FakeFirebaseFirestore();

      await firestore.collection('layers').doc('food-layer').set({
        'type': 'food',
        'isVisible': true,
      });
      await firestore.collection('layers').doc('wc-layer').set({
        'type': 'wc',
        'visible': false,
      });

      final foodDoc = await firestore.collection('layers').doc('food-layer').get();
      final wcDoc = await firestore.collection('layers').doc('wc-layer').get();

      expect(MarketLayer.fromDoc(foodDoc).isEnabled, isTrue);
      expect(MarketLayer.fromDoc(wcDoc).isEnabled, isFalse);
    });

    test('MarketMapLayer.fromFirestore falls back to visible aliases', () async {
      final firestore = FakeFirebaseFirestore();

      await firestore.collection('layers').doc('food').set({
        'label': 'Food',
        'type': 'food',
        'visible': true,
      });
      await firestore.collection('layers').doc('visit').set({
        'label': 'Visit',
        'type': 'visit',
        'isEnabled': false,
      });

      final foodDoc = await firestore.collection('layers').doc('food').get();
      final visitDoc = await firestore.collection('layers').doc('visit').get();

      expect(MarketMapLayer.fromFirestore(foodDoc).isVisible, isTrue);
      expect(MarketMapLayer.fromFirestore(visitDoc).isVisible, isFalse);
    });

    test('MarketCircuit.fromMap falls back to legacy visible flag', () {
      final circuit = MarketCircuit.fromMap({
        'name': 'Circuit food',
        'countryId': 'gp',
        'eventId': 'event-1',
        'visible': true,
      }, id: 'circuit-1');

      expect(circuit.isVisible, isTrue);
    });

    test('CircuitProject.fromFirestore falls back to legacy visible flag', () async {
      final firestore = FakeFirebaseFirestore();

      await firestore.collection('projects').doc('project-1').set({
        'name': 'Projet 1',
        'countryId': 'gp',
        'eventId': 'event-1',
        'status': 'published',
        'visible': true,
        'perimeter': const <Map<String, double>>[],
        'route': const <Map<String, double>>[],
      });

      final doc = await firestore.collection('projects').doc('project-1').get();
      final project = CircuitProject.fromFirestore(doc);

      expect(project.isVisible, isTrue);
    });
  });
}