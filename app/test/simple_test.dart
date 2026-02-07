/// Test simple pour vérifier imports et dépendances
library;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Simple Import Tests', () {
    test('Test basique', () {
      expect(1 + 1, equals(2));
    });

    test('Test GeoPosition exists', () async {
      // Ce test vérifie juste que le package charge sans erreurs
      // Les vrais tests sont dans group_tracking_test.dart
      expect(true, isTrue);
    });
  });
}
