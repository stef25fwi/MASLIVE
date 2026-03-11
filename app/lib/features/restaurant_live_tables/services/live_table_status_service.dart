import 'package:cloud_functions/cloud_functions.dart';

import '../models/live_table_state.dart';

class LiveTableStatusService {
  LiveTableStatusService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-east1');

  final FirebaseFunctions _functions;

  Future<({String checkoutUrl, String stripeSessionId})>
  createRestaurantLiveTableSubscriptionCheckoutSession({
    String planCode = 'food_pro_live',
    String billingInterval = 'month',
    String? successUrl,
    String? cancelUrl,
  }) async {
    final callable = _functions
        .httpsCallable('createRestaurantLiveTableSubscriptionCheckoutSession');
    final response = await callable.call(<String, dynamic>{
      'planCode': planCode,
      'billingInterval': billingInterval,
      if (successUrl != null && successUrl.trim().isNotEmpty)
        'successUrl': successUrl.trim(),
      if (cancelUrl != null && cancelUrl.trim().isNotEmpty)
        'cancelUrl': cancelUrl.trim(),
    });

    final data = Map<String, dynamic>.from(response.data as Map);
    final checkoutUrl = (data['checkoutUrl'] ?? '').toString().trim();
    final stripeSessionId = (data['stripeSessionId'] ?? '').toString().trim();
    if (checkoutUrl.isEmpty || stripeSessionId.isEmpty) {
      throw StateError('Stripe checkout response is incomplete');
    }
    return (checkoutUrl: checkoutUrl, stripeSessionId: stripeSessionId);
  }

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
