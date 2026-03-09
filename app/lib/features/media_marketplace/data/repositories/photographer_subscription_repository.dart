import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/media_marketplace_collections.dart';
import '../../core/enums/subscription_status.dart';
import '../models/photographer_subscription_model.dart';

class PhotographerSubscriptionRepository {
  PhotographerSubscriptionRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection(
        MediaMarketplaceCollections.photographerSubscriptions,
      );

  Future<PhotographerSubscriptionModel?> getActiveByPhotographerId(
    String photographerId,
  ) async {
    final snapshot = await _collection
        .where('photographerId', isEqualTo: photographerId)
        .where('status', whereIn: <String>['trialing', 'active', 'past_due'])
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return PhotographerSubscriptionModel.fromDocument(snapshot.docs.first);
  }

  Future<PhotographerSubscriptionModel?> getByStripeSubscriptionId(
    String stripeSubscriptionId,
  ) async {
    final snapshot = await _collection
        .where('stripeSubscriptionId', isEqualTo: stripeSubscriptionId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return PhotographerSubscriptionModel.fromDocument(snapshot.docs.first);
  }

  Future<String> upsertSubscriptionFromStripeWebhook(
    PhotographerSubscriptionModel subscription,
  ) async {
    final existing = subscription.stripeSubscriptionId == null
        ? null
        : await getByStripeSubscriptionId(subscription.stripeSubscriptionId!);
    final docId = existing?.subscriptionId.isNotEmpty == true
        ? existing!.subscriptionId
        : (subscription.subscriptionId.isNotEmpty
              ? subscription.subscriptionId
              : _collection.doc().id);
    await _collection.doc(docId).set(
      subscription.copyWith(subscriptionId: docId).toMap(),
      SetOptions(merge: true),
    );
    return docId;
  }

  Future<void> cancelSubscriptionState({
    required String subscriptionId,
    DateTime? canceledAt,
    bool cancelAtPeriodEnd = false,
  }) async {
    await _collection.doc(subscriptionId).set({
      'status': SubscriptionStatus.canceled.firestoreValue,
      'cancelAtPeriodEnd': cancelAtPeriodEnd,
      'canceledAt': canceledAt == null ? null : Timestamp.fromDate(canceledAt),
    }, SetOptions(merge: true));
  }
}