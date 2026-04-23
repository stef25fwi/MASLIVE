import 'dart:math';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../domain/commerce_models.dart';

class StorageRepository {
  final FirebaseStorage _storage;

  StorageRepository({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  Reference _productFolder(String shopId, String productId) {
    return _storage.ref().child('shops/$shopId/products/$productId');
  }

  Future<void> ensureProductUploadFolder({required String shopId}) async {
    final ref = _storage.ref().child('shops/$shopId/products/_init/.keep');
    try {
      await ref.getMetadata();
      return;
    } catch (_) {
      // ignore
    }

    try {
      await ref.putData(
        Uint8List.fromList([0]),
        SettableMetadata(contentType: 'application/octet-stream'),
      );
    } catch (_) {
      // ignore
    }
  }

  Future<ProductImage> uploadProductImage({
    required String shopId,
    required String productId,
    required Uint8List bytes,
    required String contentType,
    int sortOrder = 0,
  }) async {
    final id = _randId();
    final path = 'shops/$shopId/products/$productId/original/$id.jpg';
    final ref = _storage.ref().child(path);

    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    final url = await ref.getDownloadURL();

    return ProductImage(
      id: id,
      url: url,
      path: path,
      sortOrder: sortOrder,
      createdAt: DateTime.now(),
    );
  }

  Future<void> deleteByPath(String path) async {
    try {
      await _storage.ref().child(path).delete();
    } catch (_) {
      // ignore
    }
  }

  Future<void> deleteAllProductImages(String shopId, String productId) async {
    final ref = _productFolder(shopId, productId);
    try {
      final list = await ref.listAll();
      for (final item in list.items) {
        await item.delete();
      }
      for (final prefix in list.prefixes) {
        final sub = await prefix.listAll();
        for (final item in sub.items) {
          await item.delete();
        }
      }
    } catch (_) {
      // ignore
    }
  }

  static String _randId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(12, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
