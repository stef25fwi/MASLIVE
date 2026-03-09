import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/photographer_plan_model.dart';
import '../../data/models/photographer_profile_model.dart';
import '../../data/models/photographer_subscription_model.dart';
import '../../data/repositories/photographer_plan_repository.dart';
import '../../data/repositories/photographer_repository.dart';
import '../../data/repositories/photographer_subscription_repository.dart';

class PhotographerSubscriptionController extends ChangeNotifier {
  PhotographerSubscriptionController({
    PhotographerRepository? photographerRepository,
    PhotographerPlanRepository? photographerPlanRepository,
    PhotographerSubscriptionRepository? photographerSubscriptionRepository,
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  }) : _photographerRepository =
           photographerRepository ?? PhotographerRepository(),
       _photographerPlanRepository =
           photographerPlanRepository ?? PhotographerPlanRepository(),
       _photographerSubscriptionRepository =
           photographerSubscriptionRepository ?? PhotographerSubscriptionRepository(),
       _functions = functions ?? FirebaseFunctions.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final PhotographerRepository _photographerRepository;
  final PhotographerPlanRepository _photographerPlanRepository;
  final PhotographerSubscriptionRepository _photographerSubscriptionRepository;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  bool loading = false;
  bool processingCheckout = false;
  Object? error;
  PhotographerProfileModel? profile;
  PhotographerSubscriptionModel? activeSubscription;
  List<PhotographerPlanModel> plans = const <PhotographerPlanModel>[];
  String? checkoutUrl;

  Future<void> loadForCurrentOwner() async {
    final user = _auth.currentUser;
    if (user == null) {
      profile = null;
      activeSubscription = null;
      plans = const <PhotographerPlanModel>[];
      error = null;
      notifyListeners();
      return;
    }

    loading = true;
    error = null;
    notifyListeners();

    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _photographerRepository.getByOwnerUid(user.uid),
        _photographerPlanRepository.getActivePlans(),
      ]);
      profile = results[0] as PhotographerProfileModel?;
      plans = results[1] as List<PhotographerPlanModel>;
      activeSubscription = profile == null
          ? null
          : await _photographerSubscriptionRepository.getActiveByPhotographerId(
              profile!.photographerId,
            );
    } catch (err) {
      error = err;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<String?> startCheckout({
    required String planId,
    required String billingInterval,
    String? successUrl,
    String? cancelUrl,
  }) async {
    final currentProfile = profile;
    final user = _auth.currentUser;
    if (user == null || currentProfile == null) {
      error = StateError('Photographe non charge');
      notifyListeners();
      return null;
    }

    processingCheckout = true;
    error = null;
    checkoutUrl = null;
    notifyListeners();

    try {
      final callable = _functions.httpsCallable(
        'createPhotographerSubscriptionCheckoutSession',
      );
      final response = await callable.call(<String, dynamic>{
        'photographerId': currentProfile.photographerId,
        'planId': planId,
        'billingInterval': billingInterval,
        if (successUrl != null) 'successUrl': successUrl,
        if (cancelUrl != null) 'cancelUrl': cancelUrl,
      });
      final data = Map<String, dynamic>.from(response.data as Map);
      checkoutUrl = data['checkoutUrl']?.toString();
      return checkoutUrl;
    } catch (err) {
      error = err;
      return null;
    } finally {
      processingCheckout = false;
      notifyListeners();
    }
  }
}