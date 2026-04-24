import 'dart:math';

import 'package:flutter/foundation.dart' hide Category;
import 'package:image_picker/image_picker.dart';

import '../../data/commerce_repository.dart';
import '../../data/storage_repository.dart';
import '../../domain/commerce_models.dart';

class ProductController extends ChangeNotifier {
  final String shopId;
  final CommerceRepository commerceRepo;
  final StorageRepository storageRepo;

  ProductFilter _filter = const ProductFilter();
  String _search = '';
  bool _busy = false;

  ProductFilter get filter => _filter;
  String get search => _search;
  bool get busy => _busy;

  ProductController({
    required this.shopId,
    CommerceRepository? commerceRepo,
    StorageRepository? storageRepo,
  }) : commerceRepo = commerceRepo ?? CommerceRepository(),
       storageRepo = storageRepo ?? StorageRepository();

  Stream<List<Product>> streamProducts() =>
      commerceRepo.streamProducts(shopId, _filter, _search);
  Stream<List<Category>> streamCategories() => commerceRepo.streamCategories(shopId);

  void setSearch(String v) {
    _search = v;
    notifyListeners();
  }

  void setFilter(ProductFilter f) {
    _filter = f;
    notifyListeners();
  }

  void resetFilters() {
    _filter = const ProductFilter();
    notifyListeners();
  }

  Future<void> createOrUpdate(Product p, {required bool isNew}) async {
    _setBusy(true);
    try {
      if (isNew) {
        await commerceRepo.createProduct(shopId, p);
      } else {
        await commerceRepo.updateProduct(shopId, p);
      }
    } finally {
      _setBusy(false);
    }
  }

  Future<void> deleteProduct(Product p) async {
    _setBusy(true);
    try {
      for (final img in p.images) {
        await storageRepo.deleteByPath(img.path);
      }
      await commerceRepo.deleteProduct(shopId, p.id);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> toggleActive(Product p) async {
    _setBusy(true);
    try {
      await commerceRepo.setActive(shopId, p.id, !p.isActive);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> adjustStock(Product p, int delta) async {
    _setBusy(true);
    try {
      await commerceRepo.adjustStock(shopId, p.id, delta);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> duplicate(Product p, {bool keepImages = true}) async {
    _setBusy(true);
    try {
      await commerceRepo.duplicateProduct(shopId, p, keepImages: keepImages);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> addImagesToProduct(Product p, List<XFile> files) async {
    if (files.isEmpty) return;
    _setBusy(true);
    try {
      final existing = List<ProductImage>.from(p.images);
      int startOrder = existing.isEmpty
          ? 0
          : (existing.map((e) => e.sortOrder).reduce(max) + 1);

      for (final f in files) {
        final bytes = await f.readAsBytes();
        final img = await storageRepo.uploadProductImage(
          shopId: shopId,
          productId: p.id,
          bytes: bytes,
          contentType: _guessContentType(f.name),
          sortOrder: startOrder++,
        );
        existing.add(img);
      }

      existing.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      final main = existing.isNotEmpty ? existing.first.url : null;

      final updated = p.copyWith(
        images: existing,
        imageCount: existing.length,
        mainImageUrl: main,
      );

      await commerceRepo.updateProduct(shopId, updated);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> removeImage(Product p, ProductImage img) async {
    _setBusy(true);
    try {
      await storageRepo.deleteByPath(img.path);
      final next = List<ProductImage>.from(p.images)
        ..removeWhere((e) => e.id == img.id);
      next.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      final main = next.isNotEmpty ? next.first.url : null;
      final updated = p.copyWith(
        images: next,
        imageCount: next.length,
        mainImageUrl: main,
      );

      await commerceRepo.updateProduct(shopId, updated);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> reorderImages(Product p, List<ProductImage> newOrder) async {
    _setBusy(true);
    try {
      final reordered = <ProductImage>[];
      for (int index = 0; index < newOrder.length; index++) {
        reordered.add(newOrder[index].copyWithSortOrder(index));
      }
      final main = reordered.isNotEmpty ? reordered.first.url : null;

      final updated = p.copyWith(
        images: reordered,
        imageCount: reordered.length,
        mainImageUrl: main,
      );
      await commerceRepo.updateProduct(shopId, updated);
    } finally {
      _setBusy(false);
    }
  }

  void _setBusy(bool v) {
    _busy = v;
    notifyListeners();
  }

  static String _guessContentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}

extension on ProductImage {
  ProductImage copyWithSortOrder(int order) => ProductImage(
    id: id,
    url: url,
    path: path,
    sortOrder: order,
    createdAt: createdAt,
  );
}