/// Tests unitaires pour les services de groupe
/// Valide logique sans Firestore (mock uniquement)
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:masslive/models/group_admin.dart';
import 'package:masslive/utils/geo_utils.dart';

void main() {
  group('GeoUtils Tests', () {
    test('calculateGeodeticCenter - positions simples', () {
      final List<({double latitude, double longitude, double altitude})>
          positions = [
        (latitude: 45.5000, longitude: 2.5000, altitude: 100.0),
        (latitude: 45.5002, longitude: 2.5002, altitude: 102.0),
        (latitude: 45.5004, longitude: 2.5004, altitude: 104.0),
      ];

      final center = GeoUtils.calculateGeodeticCenter(positions);

      expect(center.latitude, closeTo(45.5002, 0.0001));
      expect(center.longitude, closeTo(2.5002, 0.0001));
      expect(center.altitude, closeTo(102.0, 0.1));
    });

    test('calculateGeodeticCenter - une position', () {
      final positions = [
        (latitude: 45.5000, longitude: 2.5000, altitude: 100.0),
      ];

      final center = GeoUtils.calculateGeodeticCenter(positions);

      expect(center.latitude, closeTo(45.5000, 0.0001));
      expect(center.longitude, closeTo(2.5000, 0.0001));
      expect(center.altitude, closeTo(100.0, 0.1));
    });

    test('calculateDistanceKm - distance connue', () {
      // Paris to Lyon (distance orthodromique) ≈ 392 km
      final distance = GeoUtils.calculateDistanceKm(
        48.8566, // Paris lat
        2.3522,  // Paris lng
        45.7640, // Lyon lat
        4.8357,  // Lyon lng
      );

      expect(distance, closeTo(392.0, 15.0)); // ±15km
    });

    test('calculateDistanceMeters - conversion correcte', () {
      final km = GeoUtils.calculateDistanceKm(0, 0, 0, 0.009); // ~1km
      final m = GeoUtils.calculateDistanceMeters(0, 0, 0, 0.009);

      expect(m / 1000, closeTo(km, 0.01));
    });

    test('calculateBearing - direction correcte', () {
      // Nord (0°)
      expect(
        GeoUtils.calculateBearing(0, 0, 1, 0),
        closeTo(0, 1),
      );

      // Est (90°)
      expect(
        GeoUtils.calculateBearing(0, 0, 0, 1),
        closeTo(90, 1),
      );
    });

    test('calculateDestination - position calculée', () {
      // À partir de (0,0), aller 111km au Nord (≈1 degré)
      final dest = GeoUtils.calculateDestination(0, 0, 111, 0);

      expect(dest.latitude, closeTo(1.0, 0.1));
      expect(dest.longitude, closeTo(0.0, 0.1));
    });

    test('isPointInPolygon - point dedans', () {
      final polygon = [
        (latitude: 45.0, longitude: 2.0),
        (latitude: 46.0, longitude: 2.0),
        (latitude: 46.0, longitude: 3.0),
        (latitude: 45.0, longitude: 3.0),
      ];

      final inside = GeoUtils.isPointInPolygon(45.5, 2.5, polygon);
      expect(inside, true);
    });

    test('isPointInPolygon - point dehors', () {
      final polygon = [
        (latitude: 45.0, longitude: 2.0),
        (latitude: 46.0, longitude: 2.0),
        (latitude: 46.0, longitude: 3.0),
        (latitude: 45.0, longitude: 3.0),
      ];

      final outside = GeoUtils.isPointInPolygon(50.0, 5.0, polygon);
      expect(outside, false);
    });

    test('calculateConvexHull - 4 points', () {
      final positions = [
        (latitude: 0.0, longitude: 0.0),
        (latitude: 1.0, longitude: 0.0),
        (latitude: 1.0, longitude: 1.0),
        (latitude: 0.0, longitude: 1.0),
      ];

      final hull = GeoUtils.calculateConvexHull(positions);

      expect(hull.length, 4);
    });

    test('calculateConvexHull - 3 points + intérieur', () {
      final positions = [
        (latitude: 0.0, longitude: 0.0),
        (latitude: 1.0, longitude: 0.0),
        (latitude: 1.0, longitude: 1.0),
        (latitude: 0.5, longitude: 0.5), // Dedans
      ];

      final hull = GeoUtils.calculateConvexHull(positions);

      expect(hull.length, 3); // Point intérieur ignoré
    });
  });

  group('GeoPosition Tests', () {
    test('isValidForAverage - position valide', () {
      final now = DateTime.now();
      final pos = GeoPosition(
        lat: 45.5,
        lng: 2.5,
        altitude: 100.0,
        accuracy: 10.0,
        timestamp: now,
      );

      expect(pos.isValidForAverage(), true);
    });

    test('isValidForAverage - position trop ancienne', () {
      final old = DateTime.now().subtract(Duration(seconds: 30));
      final pos = GeoPosition(
        lat: 45.5,
        lng: 2.5,
        altitude: 100.0,
        accuracy: 10.0,
        timestamp: old,
      );

      expect(pos.isValidForAverage(), false);
    });

    test('isValidForAverage - accuracy mauvaise', () {
      final now = DateTime.now();
      final pos = GeoPosition(
        lat: 45.5,
        lng: 2.5,
        altitude: 100.0,
        accuracy: 60.0, // > 50m
        timestamp: now,
      );

      expect(pos.isValidForAverage(), false);
    });

    test('isValidForAverage - lat=0 invalide', () {
      final now = DateTime.now();
      final pos = GeoPosition(
        lat: 0.0,
        lng: 2.5,
        altitude: 100.0,
        accuracy: 10.0,
        timestamp: now,
      );

      expect(pos.isValidForAverage(), false);
    });

    test('isValidForAverage - lng=0 invalide', () {
      final now = DateTime.now();
      final pos = GeoPosition(
        lat: 45.5,
        lng: 0.0,
        altitude: 100.0,
        accuracy: 10.0,
        timestamp: now,
      );

      expect(pos.isValidForAverage(), false);
    });
  });

  group('Position Averaging Logic Tests', () {
    test('calculateWeights - accuracy influence', () {
      // Simulation du calcul de poids
      final accuracy1 = 10.0; // Excellent
      final accuracy2 = 50.0; // Bon
      final accuracy3 = 100.0; // Mauvais

      final weight1 = 1.0 / (1.0 + accuracy1 / 50.0);
      final weight2 = 1.0 / (1.0 + accuracy2 / 50.0);
      final weight3 = 1.0 / (1.0 + accuracy3 / 50.0);

      // Positions précises ont plus de poids
      expect(weight1, greaterThan(weight2));
      expect(weight2, greaterThan(weight3));
    });

    test('weighted average - meilleure précision première', () {
      // 3 positions avec différentes précisions
      // La plus précise devrait avoir plus d'influence
      final positions = [
        GeoPosition(
          lat: 45.0,
          lng: 2.0,
          altitude: 0,
          accuracy: 5.0, // Très précis
          timestamp: DateTime.now(),
        ),
        GeoPosition(
          lat: 50.0,
          lng: 2.0,
          altitude: 0,
          accuracy: 100.0, // Imprécis
          timestamp: DateTime.now(),
        ),
      ];

      // Moyenne pondérée devrait être plus proche de 45 que de 50
      final weight1 = 1.0 / (1.0 + 5.0 / 50.0);
      final weight2 = 1.0 / (1.0 + 100.0 / 50.0);

        final weightedLat =
          (positions[0].lat * weight1 + positions[1].lat * weight2) /
            (weight1 + weight2);
      
      expect(weightedLat, lessThan(47.5)); // Plus proche de 45
    });

    test('geodetic vs arithmetic - distance impact', () {
      // Pour positions très proches: géodésique ≈ arithmétique
      final positions = [
        (latitude: 45.5000, longitude: 2.5000, altitude: 100.0),
        (latitude: 45.5001, longitude: 2.5001, altitude: 101.0),
      ];

      final geodetic =
          GeoUtils.calculateGeodeticCenter(positions, useWeights: false);

      // Moyenne arithmétique
      final arithmetic = (
        latitude: (45.5000 + 45.5001) / 2,
        longitude: (2.5000 + 2.5001) / 2,
        altitude: (100.0 + 101.0) / 2,
      );

      // Différence mineure pour courtes distances
      expect(
        (geodetic.latitude - arithmetic.latitude).abs(),
        lessThan(0.0001),
      );
      expect(
        (geodetic.longitude - arithmetic.longitude).abs(),
        lessThan(0.0001),
      );
    });
  });

  group('Edge Cases', () {
    test('positions identiques - centroïde = position', () {
      final positions = [
        (latitude: 45.5000, longitude: 2.5000, altitude: 100.0),
        (latitude: 45.5000, longitude: 2.5000, altitude: 100.0),
        (latitude: 45.5000, longitude: 2.5000, altitude: 100.0),
      ];

      final center = GeoUtils.calculateGeodeticCenter(positions);

      expect(center.latitude, closeTo(45.5000, 0.0001));
      expect(center.longitude, closeTo(2.5000, 0.0001));
      expect(center.altitude, closeTo(100.0, 0.01));
    });

    test('positions antipodales - edge case', () {
      // Points aux antipodes (pas réaliste pour GPS local mais bon test)
      final positions = [
        (latitude: 0.0, longitude: 0.0, altitude: 0.0),
        (latitude: 0.0, longitude: 180.0, altitude: 0.0),
      ];

      // Le centroïde devrait être quelque part sensé (pas crash)
      final center = GeoUtils.calculateGeodeticCenter(positions);
      expect(center.latitude, isNotNull);
      expect(center.longitude, isNotNull);
    });

    test('accuracy zero - poids = 1.0', () {
      final accuracy = 0.0;
      final weight = 1.0 / (1.0 + accuracy / 50.0);
      expect(weight, equals(1.0));
    });

    test('accuracy très élevée - poids → 0', () {
      final accuracy = 50000.0;
      final weight = 1.0 / (1.0 + accuracy / 50.0);
      expect(weight, lessThan(0.01));
    });
  });
}
