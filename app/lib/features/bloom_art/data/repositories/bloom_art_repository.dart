import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../services/storage_service.dart';
import '../models/bloom_art_item.dart';
import '../models/bloom_art_order.dart';
import '../models/bloom_art_seller_profile.dart';

class BloomArtRepository {
  BloomArtRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    StorageService? storageService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-east1'),
       _storage = storageService ?? StorageService.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final StorageService _storage;

  CollectionReference<Map<String, dynamic>> get _items =>
      _firestore.collection('bloom_art_items');

  CollectionReference<Map<String, dynamic>> get _sellerProfiles =>
      _firestore.collection('bloom_art_seller_profiles');

  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection('bloom_art_orders');

  Stream<List<BloomArtItem>> watchPublishedItems() {
    return _items.snapshots().map((snapshot) {
      final items = snapshot.docs
          .map(BloomArtItem.fromDocument)
          .where((item) => item.isPublished)
          .toList(growable: false)
        ..sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
      return items;
    });
  }

  Stream<List<BloomArtItem>> watchSellerItems(String sellerId) {
    return _items.where('sellerId', isEqualTo: sellerId).snapshots().map((snapshot) {
      final items = snapshot.docs.map(BloomArtItem.fromDocument).toList(growable: false)
        ..sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
      return items;
    });
  }

  Stream<BloomArtItem?> watchItem(String itemId) {
    return _items.doc(itemId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return BloomArtItem.fromDocument(doc);
    });
  }

  Future<BloomArtItem?> getItem(String itemId) async {
    final doc = await _items.doc(itemId).get();
    if (!doc.exists) return null;
    return BloomArtItem.fromDocument(doc);
  }

  Future<double?> getPrivateReferencePrice(String itemId) async {
    final pricingDoc = await _items.doc(itemId).collection('private').doc('pricing').get();
    if (!pricingDoc.exists) return null;
    return double.tryParse((pricingDoc.data()?['referencePrice'] ?? '').toString());
  }

  Stream<BloomArtSellerProfile?> watchSellerProfile(String userId) {
    return _sellerProfiles.doc(userId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return BloomArtSellerProfile.fromDocument(doc);
    });
  }

  Future<BloomArtSellerProfile?> getSellerProfile(String userId) async {
    final doc = await _sellerProfiles.doc(userId).get();
    if (!doc.exists) return null;
    return BloomArtSellerProfile.fromDocument(doc);
  }

  Future<void> saveSellerProfile(BloomArtSellerProfile profile) async {
    await _sellerProfiles.doc(profile.userId).set(
      profile.copyWith(id: profile.userId, userId: profile.userId).toMap(),
      SetOptions(merge: true),
    );
  }

  Future<String> createItem({
    required BloomArtItem item,
    required double referencePrice,
  }) async {
    final callable = _functions.httpsCallable('createBloomArtItem');
    final response = await callable.call<Map<String, dynamic>>(<String, dynamic>{
      ...item.toMap(includeReferencePrice: false),
      'referencePrice': referencePrice,
    });
    final data = Map<String, dynamic>.from(response.data);
    return (data['itemId'] ?? '').toString();
  }

  Future<List<String>> uploadItemImages({
    required String itemId,
    required List<XFile> files,
  }) {
    return _storage.uploadArticleContentImages(articleId: itemId, files: files);
  }

  Future<void> updateItemPublicData(String itemId, Map<String, dynamic> data) async {
    await _items.doc(itemId).set(
      <String, dynamic>{
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<List<BloomArtOrder>> getOrdersForBuyer(String buyerId) async {
    final snapshot = await _orders.where('buyerId', isEqualTo: buyerId).get();
    final items = snapshot.docs.map(BloomArtOrder.fromDocument).toList(growable: false)
      ..sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
    return items;
  }
}