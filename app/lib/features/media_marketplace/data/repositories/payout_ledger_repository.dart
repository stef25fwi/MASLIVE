import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/media_marketplace_collections.dart';
import '../models/payout_ledger_model.dart';

class PayoutLedgerRepository {
  PayoutLedgerRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(MediaMarketplaceCollections.payoutLedger);

  Future<String> createEntry(PayoutLedgerModel entry) async {
    final docId = entry.ledgerId.isNotEmpty ? entry.ledgerId : _collection.doc().id;
    await _collection.doc(docId).set(entry.copyWith(ledgerId: docId).toMap());
    return docId;
  }

  Future<List<PayoutLedgerModel>> getByPhotographer(String photographerId) async {
    final snapshot = await _collection
        .where('photographerId', isEqualTo: photographerId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map(PayoutLedgerModel.fromDocument).toList(growable: false);
  }

  Future<List<PayoutLedgerModel>> getByOrder(String orderId) async {
    final snapshot = await _collection.where('orderId', isEqualTo: orderId).get();
    return snapshot.docs.map(PayoutLedgerModel.fromDocument).toList(growable: false);
  }
}