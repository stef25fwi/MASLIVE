import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masslive/models/market_poi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MarketPoi.fromDoc', () {
    test('uses layerType when type is missing', () async {
      final firestore = FakeFirebaseFirestore();

      await firestore.collection('pois').doc('food-poi').set({
        'name': 'Stand Bokit',
        'lat': 16.24,
        'lng': -61.53,
        'layerType': 'Food',
        'layerId': 'food',
        'isVisible': true,
      });

      final doc = await firestore.collection('pois').doc('food-poi').get();
      final poi = MarketPoi.fromDoc(doc);

      expect(poi.type, 'food');
      expect(poi.layerId, 'food');
    });

    test('falls back to layerId when both type and layerType are missing', () async {
      final firestore = FakeFirebaseFirestore();

      await firestore.collection('pois').doc('visit-poi').set({
        'name': 'Belvédère',
        'lat': 16.25,
        'lng': -61.54,
        'layerId': ' visit ',
        'isVisible': true,
      });

      final doc = await firestore.collection('pois').doc('visit-poi').get();
      final poi = MarketPoi.fromDoc(doc);

      expect(poi.type, 'visit');
      expect(poi.layerId, 'visit');
    });

    test('keeps explicit type when provided', () async {
      final firestore = FakeFirebaseFirestore();

      await firestore.collection('pois').doc('wc-poi').set({
        'name': 'WC central',
        'lat': 16.26,
        'lng': -61.55,
        'type': 'WC',
        'layerType': 'food',
        'layerId': 'food',
        'isVisible': true,
      });

      final doc = await firestore.collection('pois').doc('wc-poi').get();
      final poi = MarketPoi.fromDoc(doc);

      expect(poi.type, 'wc');
      expect(poi.layerId, 'food');
    });
  });
}
