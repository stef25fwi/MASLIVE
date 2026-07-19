import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/media_marketplace_collections.dart';
import '../../core/constants/media_marketplace_pricing.dart';
import '../models/photographer_plan_model.dart';

class PhotographerPlanRepository {
  PhotographerPlanRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(MediaMarketplaceCollections.photographerPlans);

  List<PhotographerPlanModel> get _fallbackPlans =>
      MediaMarketplacePricing.photographerPlans
          .map((spec) => spec.toModel())
          .toList(growable: false);

  Future<List<PhotographerPlanModel>> getActivePlans() async {
    try {
      final snapshot = await _collection
          .where('isActive', isEqualTo: true)
          .orderBy('monthlyPrice')
          .get();
      if (snapshot.docs.isEmpty) return _fallbackPlans;

      final remote = snapshot.docs
          .map(PhotographerPlanModel.fromDocument)
          .toList(growable: false);
      final merged = <String, PhotographerPlanModel>{
        for (final plan in _fallbackPlans) plan.code: plan,
        for (final plan in remote) plan.code: plan,
      }.values.toList()
        ..sort((a, b) => a.monthlyPrice.compareTo(b.monthlyPrice));
      return merged;
    } on FirebaseException {
      return _fallbackPlans;
    }
  }

  Future<PhotographerPlanModel?> getById(String planId) async {
    final normalized = planId.trim().toLowerCase();
    if (normalized.isEmpty) {
      return MediaMarketplacePricing.photographerPlans.first.toModel();
    }
    try {
      final doc = await _collection.doc(planId).get();
      if (doc.exists) return PhotographerPlanModel.fromDocument(doc);
    } on FirebaseException {
      // Le catalogue local garantit l'affichage pendant le bootstrap Firestore.
    }
    return MediaMarketplacePricing.planFor(normalized).toModel();
  }

  Future<PhotographerPlanModel?> getByCode(String code) async {
    final normalized = code.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    try {
      final snapshot = await _collection
          .where('code', isEqualTo: normalized)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return PhotographerPlanModel.fromDocument(snapshot.docs.first);
      }
    } on FirebaseException {
      // Fallback local ci-dessous.
    }
    return MediaMarketplacePricing.planFor(normalized).toModel();
  }
}
