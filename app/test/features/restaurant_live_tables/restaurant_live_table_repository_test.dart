import 'package:flutter_test/flutter_test.dart';
import 'package:masslive/features/restaurant_live_tables/repositories/restaurant_live_table_repository.dart';

void main() {
  group('RestaurantLiveTableRepository.resolvePreferredState', () {
    test('prend la desactivation metadata si elle est plus recente que le remote', () {
      final state = RestaurantLiveTableRepository.resolvePreferredState(
        remoteData: <String, dynamic>{
          'enabled': true,
          'status': 'available',
          'updatedAt': '2026-03-11T10:00:00.000Z',
        },
        fallbackMeta: <String, dynamic>{
          'liveTable': <String, dynamic>{
            'enabled': false,
            'status': 'unknown',
            'updatedAt': '2026-03-11T10:05:00.000Z',
          },
        },
      );

      expect(state.enabled, isFalse);
      expect(state.source, 'metadata');
    });

    test('garde le remote si la metadata desactivee est plus ancienne', () {
      final state = RestaurantLiveTableRepository.resolvePreferredState(
        remoteData: <String, dynamic>{
          'enabled': true,
          'status': 'limited',
          'updatedAt': '2026-03-11T10:05:00.000Z',
        },
        fallbackMeta: <String, dynamic>{
          'liveTable': <String, dynamic>{
            'enabled': false,
            'status': 'unknown',
            'updatedAt': '2026-03-11T10:00:00.000Z',
          },
        },
      );

      expect(state.enabled, isTrue);
      expect(state.source, 'restaurant_live_status');
    });
  });
}
