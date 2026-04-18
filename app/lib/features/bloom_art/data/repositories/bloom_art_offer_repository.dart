import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/bloom_art_offer.dart';

class BloomArtOfferRepository {
  BloomArtOfferRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-east1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _offers =>
      _firestore.collection('bloom_art_offers');

  double computeAutoAcceptMin(double referencePrice) => referencePrice * 0.90;

  bool shouldAutoAccept(double proposedPrice, double referencePrice) {
    if (referencePrice <= 0) return false;
    return proposedPrice >= computeAutoAcceptMin(referencePrice);
  }

  Stream<List<BloomArtOffer>> watchSellerOffers(String sellerId) {
    return _offers.where('sellerId', isEqualTo: sellerId).snapshots().map((snapshot) {
      final items = snapshot.docs.map(BloomArtOffer.fromDocument).toList(growable: false)
        ..sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
      return items;
    });
  }

  Stream<List<BloomArtOffer>> watchBuyerOffers(String buyerId) {
    return _offers.where('buyerId', isEqualTo: buyerId).snapshots().map((snapshot) {
      final items = snapshot.docs.map(BloomArtOffer.fromDocument).toList(growable: false)
        ..sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
      return items;
    });
  }

  Stream<BloomArtOffer?> watchOffer(String offerId) {
    return _offers.doc(offerId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return BloomArtOffer.fromDocument(doc);
    });
  }

  Future<BloomArtOffer?> getOffer(String offerId) async {
    final doc = await _offers.doc(offerId).get();
    if (!doc.exists) return null;
    return BloomArtOffer.fromDocument(doc);
  }

  Future<BloomArtOffer> submitOffer({
    required String itemId,
    required double proposedPrice,
    String buyerMessage = '',
  }) async {
    final callable = _functions.httpsCallable('submitBloomArtOffer');
    final response = await callable.call<Map<String, dynamic>>(<String, dynamic>{
      'itemId': itemId,
      'proposedPrice': proposedPrice,
      'buyerMessage': buyerMessage,
    });

    final data = Map<String, dynamic>.from(response.data);
    final offerId = (data['offerId'] ?? '').toString();
    if (offerId.isEmpty) {
      throw StateError('submitBloomArtOffer n\'a pas retourne offerId');
    }

    final offer = await getOffer(offerId);
    if (offer == null) {
      throw StateError('Offre introuvable apres creation');
    }
    return offer;
  }

  Future<void> acceptOffer(String offerId) async {
    final callable = _functions.httpsCallable('acceptBloomArtOffer');
    await callable.call<Map<String, dynamic>>(<String, dynamic>{'offerId': offerId});
  }

  Future<void> declineOffer(String offerId) async {
    final callable = _functions.httpsCallable('declineBloomArtOffer');
    await callable.call<Map<String, dynamic>>(<String, dynamic>{'offerId': offerId});
  }
}