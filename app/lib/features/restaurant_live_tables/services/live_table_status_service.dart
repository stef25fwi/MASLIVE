import 'package:cloud_functions/cloud_functions.dart';

import '../models/live_table_state.dart';

class LiveTableStatusService {
  LiveTableStatusService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-east1');

  final FirebaseFunctions _functions;

  Future<void> assignBusinessRestaurantPoi({
    required String countryId,
    required String eventId,
    required String circuitId,
    required String poiId,
  }) async {
    final callable = _functions.httpsCallable('assignBusinessRestaurantPoi');
    await callable.call(<String, dynamic>{
      'countryId': countryId,
      'eventId': eventId,
      'circuitId': circuitId,
      'poiId': poiId,
    });
  }

  Future<void> setRestaurantLiveTableStatus({
    required String countryId,
    required String eventId,
    required String circuitId,
    required String poiId,
    required bool enabled,
    required LiveTableStatus status,
    int? availableTables,
    int? capacity,
    String? message,
  }) async {
    final callable = _functions.httpsCallable('setRestaurantLiveTableStatus');
    await callable.call(<String, dynamic>{
      'countryId': countryId,
      'eventId': eventId,
      'circuitId': circuitId,
      'poiId': poiId,
      'enabled': enabled,
      'status': liveTableStatusToString(status),
      'availableTables': availableTables,
      'capacity': capacity,
      'message': (message ?? '').trim(),
    });
  }
}
