import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/media_marketplace_collections.dart';
import '../models/cart_item_model.dart';
import '../models/cart_model.dart';

class CartRepository {
  CartRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(MediaMarketplaceCollections.carts);

  Future<CartModel?> getCart(String uid) async {
    final doc = await _collection.doc(uid).get();
    if (!doc.exists) return null;
    return CartModel.fromDocument(doc);
  }

  Future<void> addItem({required String uid, required CartItemModel item}) async {
    final existing = await getCart(uid);
    final items = <CartItemModel>[...(existing?.items ?? const <CartItemModel>[])];
    final index = items.indexWhere(
      (entry) => entry.assetId == item.assetId && entry.assetType == item.assetType,
    );
    if (index >= 0) {
      final current = items[index];
      items[index] = current.copyWith(quantity: current.quantity + item.quantity);
    } else {
      items.add(item);
    }
    await replaceCart(
      CartModel(
        uid: uid,
        items: items,
        currency: existing?.currency ?? item.currency,
        createdAt: existing?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> removeItem({
    required String uid,
    required String assetId,
  }) async {
    final existing = await getCart(uid);
    if (existing == null) return;
    final nextItems = existing.items.where((item) => item.assetId != assetId).toList(growable: false);
    await replaceCart(existing.copyWith(items: nextItems, updatedAt: DateTime.now()));
  }

  Future<void> clearCart(String uid) async {
    await _collection.doc(uid).delete();
  }

  Future<void> replaceCart(CartModel cart) async {
    await _collection.doc(cart.uid).set(cart.toMap(), SetOptions(merge: true));
  }
}