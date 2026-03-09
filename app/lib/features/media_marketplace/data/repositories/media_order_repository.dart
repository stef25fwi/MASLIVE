import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/media_marketplace_collections.dart';
import '../../core/enums/order_delivery_status.dart';
import '../../core/enums/order_payment_status.dart';
import '../models/media_order_model.dart';

class MediaOrderRepository {
  MediaOrderRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(MediaMarketplaceCollections.orders);

  Future<String> createOrder(MediaOrderModel order) async {
    final docId = order.orderId.isNotEmpty ? order.orderId : _collection.doc().id;
    await _collection.doc(docId).set(order.copyWith(orderId: docId).toMap());
    return docId;
  }

  Future<List<MediaOrderModel>> getByBuyer(String buyerUid) async {
    final snapshot = await _collection
        .where('buyerUid', isEqualTo: buyerUid)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map(MediaOrderModel.fromDocument).toList(growable: false);
  }

  Future<MediaOrderModel?> getById(String orderId) async {
    final doc = await _collection.doc(orderId).get();
    if (!doc.exists) return null;
    return MediaOrderModel.fromDocument(doc);
  }

  Future<List<MediaOrderModel>> getByPhotographer(String photographerId) async {
    final snapshot = await _collection
        .where('photographerIds', arrayContains: photographerId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map(MediaOrderModel.fromDocument).toList(growable: false);
  }

  Future<void> updateStatuses({
    required String orderId,
    OrderPaymentStatus? paymentStatus,
    OrderDeliveryStatus? deliveryStatus,
    DateTime? paidAt,
    DateTime? deliveredAt,
  }) async {
    await _collection.doc(orderId).set({
      if (paymentStatus != null) 'paymentStatus': paymentStatus.firestoreValue,
      if (deliveryStatus != null) 'deliveryStatus': deliveryStatus.firestoreValue,
      if (paidAt != null) 'paidAt': Timestamp.fromDate(paidAt),
      if (deliveredAt != null) 'deliveredAt': Timestamp.fromDate(deliveredAt),
    }, SetOptions(merge: true));
  }
}