import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/media_marketplace_collections.dart';
import '../models/photographer_plan_model.dart';

class PhotographerPlanRepository {
  PhotographerPlanRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(MediaMarketplaceCollections.photographerPlans);

  Future<List<PhotographerPlanModel>> getActivePlans() async {
    final snapshot = await _collection
        .where('isActive', isEqualTo: true)
        .orderBy('monthlyPrice')
        .get();
    return snapshot.docs.map(PhotographerPlanModel.fromDocument).toList(growable: false);
  }

  Future<PhotographerPlanModel?> getById(String planId) async {
    final doc = await _collection.doc(planId).get();
    if (!doc.exists) return null;
    return PhotographerPlanModel.fromDocument(doc);
  }

  Future<PhotographerPlanModel?> getByCode(String code) async {
    final snapshot = await _collection.where('code', isEqualTo: code).limit(1).get();
    if (snapshot.docs.isEmpty) return null;
    return PhotographerPlanModel.fromDocument(snapshot.docs.first);
  }
}