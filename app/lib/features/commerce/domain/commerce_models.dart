import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class ProductImage {
  final String id;
  final String url;
  final String path;
  final int sortOrder;
  final DateTime createdAt;

  const ProductImage({
    required this.id,
    required this.url,
    required this.path,
    required this.sortOrder,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'path': path,
    'sortOrder': sortOrder,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    final created = json['createdAt'];
    return ProductImage(
      id: (json['id'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      path: (json['path'] ?? '').toString(),
      sortOrder: (json['sortOrder'] ?? 0) as int,
      createdAt: created is Timestamp ? created.toDate() : DateTime.now(),
    );
  }
}

@immutable
class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String currency;
  final String? categoryId;
  final List<String> tags;
  final bool isActive;
  final bool isFeatured;
  final String status;
  final bool isVisible;
  final bool trackInventory;
  final int stockQty;
  final int stockAlertQty;
  final String? sku;
  final String? barcode;
  final String? country;
  final String? event;
  final String? circuit;
  final GeoPoint? placeGeo;
  final String? mainImageUrl;
  final int imageCount;
  final List<ProductImage> images;
  final List<String> searchTokens;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String stockStatus;

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    required this.categoryId,
    required this.tags,
    required this.isActive,
    required this.isFeatured,
    this.status = 'published',
    this.isVisible = true,
    this.trackInventory = true,
    required this.stockQty,
    required this.stockAlertQty,
    required this.sku,
    required this.barcode,
    required this.country,
    required this.event,
    required this.circuit,
    required this.placeGeo,
    required this.mainImageUrl,
    required this.imageCount,
    required this.images,
    required this.searchTokens,
    required this.createdAt,
    required this.updatedAt,
    required this.stockStatus,
  });

  Product copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? currency,
    String? categoryId,
    List<String>? tags,
    bool? isActive,
    bool? isFeatured,
    String? status,
    bool? isVisible,
    bool? trackInventory,
    int? stockQty,
    int? stockAlertQty,
    String? sku,
    String? barcode,
    String? country,
    String? event,
    String? circuit,
    GeoPoint? placeGeo,
    String? mainImageUrl,
    int? imageCount,
    List<ProductImage>? images,
    List<String>? searchTokens,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? stockStatus,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      categoryId: categoryId ?? this.categoryId,
      tags: tags ?? this.tags,
      isActive: isActive ?? this.isActive,
      isFeatured: isFeatured ?? this.isFeatured,
      status: status ?? this.status,
      isVisible: isVisible ?? this.isVisible,
      trackInventory: trackInventory ?? this.trackInventory,
      stockQty: stockQty ?? this.stockQty,
      stockAlertQty: stockAlertQty ?? this.stockAlertQty,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      country: country ?? this.country,
      event: event ?? this.event,
      circuit: circuit ?? this.circuit,
      placeGeo: placeGeo ?? this.placeGeo,
      mainImageUrl: mainImageUrl ?? this.mainImageUrl,
      imageCount: imageCount ?? this.imageCount,
      images: images ?? this.images,
      searchTokens: searchTokens ?? this.searchTokens,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      stockStatus: stockStatus ?? this.stockStatus,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'price': price,
    'currency': currency,
    'categoryId': categoryId,
    'tags': tags,
    'isActive': isActive,
    'isFeatured': isFeatured,
    'status': status,
    'isVisible': isVisible,
    'trackInventory': trackInventory,
    'stockQty': stockQty,
    'stockAlertQty': stockAlertQty,
    'stockStatus': stockStatus,
    'sku': sku,
    'barcode': barcode,
    'country': country,
    'event': event,
    'circuit': circuit,
    'placeGeo': placeGeo,
    'mainImageUrl': mainImageUrl,
    'imageCount': imageCount,
    'images': images.map((e) => e.toJson()).toList(),
    'searchTokens': searchTokens,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory Product.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final created = data['createdAt'];
    final updated = data['updatedAt'];
    final imgs = (data['images'] as List?) ?? const [];
    final tags = (data['tags'] as List?) ?? const [];
    final tokens = (data['searchTokens'] as List?) ?? const [];

    return Product(
      id: doc.id,
      name: (data['name'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      price: _asDouble(data['price']),
      currency: (data['currency'] ?? 'EUR').toString(),
      categoryId: data['categoryId']?.toString(),
      tags: tags.map((e) => e.toString()).toList(),
      isActive: (data['isActive'] ?? true) as bool,
      isFeatured: (data['isFeatured'] ?? false) as bool,
      status: (data['status'] ?? 'published').toString(),
      isVisible: (data['isVisible'] ?? true) as bool,
      trackInventory: (data['trackInventory'] ?? true) as bool,
      stockQty: (data['stockQty'] ?? 0) as int,
      stockAlertQty: (data['stockAlertQty'] ?? 3) as int,
      stockStatus: (data['stockStatus'] ?? 'ok').toString(),
      sku: data['sku']?.toString(),
      barcode: data['barcode']?.toString(),
      country: data['country']?.toString(),
      event: data['event']?.toString(),
      circuit: data['circuit']?.toString(),
      placeGeo: data['placeGeo'] is GeoPoint
          ? data['placeGeo'] as GeoPoint
          : null,
      mainImageUrl: data['mainImageUrl']?.toString(),
      imageCount: (data['imageCount'] ?? 0) as int,
      images:
          imgs
              .map(
                (e) =>
                    ProductImage.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList()
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
      searchTokens: tokens.map((e) => e.toString()).toList(),
      createdAt: created is Timestamp ? created.toDate() : DateTime.now(),
      updatedAt: updated is Timestamp ? updated.toDate() : DateTime.now(),
    );
  }

  static double _asDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}

@immutable
class Shop {
  final String id;
  final String? ownerUid;
  final String type;
  final bool isActive;
  final String? countryCode;
  final String? eventId;
  final String? circuitId;
  final String? groupId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Shop({
    required this.id,
    required this.ownerUid,
    required this.type,
    required this.isActive,
    this.countryCode,
    this.eventId,
    this.circuitId,
    this.groupId,
    required this.createdAt,
    required this.updatedAt,
  });

  Shop copyWith({
    String? id,
    String? ownerUid,
    String? type,
    bool? isActive,
    String? countryCode,
    String? eventId,
    String? circuitId,
    String? groupId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Shop(
      id: id ?? this.id,
      ownerUid: ownerUid ?? this.ownerUid,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      countryCode: countryCode ?? this.countryCode,
      eventId: eventId ?? this.eventId,
      circuitId: circuitId ?? this.circuitId,
      groupId: groupId ?? this.groupId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'ownerUid': ownerUid,
    'type': type,
    'isActive': isActive,
    'countryCode': countryCode,
    'eventId': eventId,
    'circuitId': circuitId,
    'groupId': groupId,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory Shop.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final created = data['createdAt'];
    final updated = data['updatedAt'];

    String? cleanStringField(String key) {
      final raw = data[key];
      if (raw is String) {
        final trimmed = raw.trim();
        return trimmed.isEmpty ? null : trimmed;
      }
      return null;
    }

    return Shop(
      id: doc.id,
      ownerUid: cleanStringField('ownerUid'),
      type: (data['type'] ?? 'global').toString(),
      isActive: (data['isActive'] ?? true) as bool,
      countryCode: cleanStringField('countryCode'),
      eventId: cleanStringField('eventId'),
      circuitId: cleanStringField('circuitId'),
      groupId: cleanStringField('groupId'),
      createdAt: created is Timestamp ? created.toDate() : DateTime.now(),
      updatedAt: updated is Timestamp ? updated.toDate() : DateTime.now(),
    );
  }
}

@immutable
class Category {
  final String id;
  final String name;
  final int sortOrder;
  final bool isActive;

  const Category({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.isActive,
  });

  factory Category.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Category(
      id: doc.id,
      name: (data['name'] ?? '').toString(),
      sortOrder: (data['sortOrder'] ?? 0) as int,
      isActive: (data['isActive'] ?? true) as bool,
    );
  }
}

@immutable
class ProductFilter {
  final String? categoryId;
  final bool? onlyActive;
  final String? stockStatus;
  final double? minPrice;
  final double? maxPrice;
  final String? tag;
  final String? country;
  final String? event;
  final String? circuit;

  const ProductFilter({
    this.categoryId,
    this.onlyActive,
    this.stockStatus,
    this.minPrice,
    this.maxPrice,
    this.tag,
    this.country,
    this.event,
    this.circuit,
  });

  bool get hasAny =>
      categoryId != null ||
      onlyActive != null ||
      stockStatus != null ||
      minPrice != null ||
      maxPrice != null ||
      tag != null ||
      country != null ||
      event != null ||
      circuit != null;

  ProductFilter copyWith({
    String? categoryId,
    bool? onlyActive,
    String? stockStatus,
    double? minPrice,
    double? maxPrice,
    String? tag,
    String? country,
    String? event,
    String? circuit,
    bool resetCategory = false,
    bool resetOnlyActive = false,
    bool resetStockStatus = false,
    bool resetMinPrice = false,
    bool resetMaxPrice = false,
    bool resetTag = false,
    bool resetCountry = false,
    bool resetEvent = false,
    bool resetCircuit = false,
  }) {
    return ProductFilter(
      categoryId: resetCategory ? null : (categoryId ?? this.categoryId),
      onlyActive: resetOnlyActive ? null : (onlyActive ?? this.onlyActive),
      stockStatus: resetStockStatus ? null : (stockStatus ?? this.stockStatus),
      minPrice: resetMinPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: resetMaxPrice ? null : (maxPrice ?? this.maxPrice),
      tag: resetTag ? null : (tag ?? this.tag),
      country: resetCountry ? null : (country ?? this.country),
      event: resetEvent ? null : (event ?? this.event),
      circuit: resetCircuit ? null : (circuit ?? this.circuit),
    );
  }

  ProductFilter resetAll() => const ProductFilter();
}

@immutable
class ShopMedia {
  final String id;
  final String shopId;
  final String type;
  final String url;
  final String storagePath;
  final String? thumbUrl;
  final String status;
  final bool isVisible;
  final String? countryCode;
  final String? eventId;
  final String? circuitId;
  final DateTime? takenAt;
  final GeoPoint? locationGeo;
  final String? locationName;
  final String? photographerId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ShopMedia({
    required this.id,
    required this.shopId,
    required this.type,
    required this.url,
    required this.storagePath,
    required this.thumbUrl,
    required this.status,
    required this.isVisible,
    required this.countryCode,
    required this.eventId,
    required this.circuitId,
    required this.takenAt,
    required this.locationGeo,
    required this.locationName,
    required this.photographerId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isVideo => type.toLowerCase() == 'video';

  ShopMedia copyWith({
    String? id,
    String? shopId,
    String? type,
    String? url,
    String? storagePath,
    String? thumbUrl,
    bool clearThumbUrl = false,
    String? status,
    bool? isVisible,
    String? countryCode,
    bool clearCountryCode = false,
    String? eventId,
    bool clearEventId = false,
    String? circuitId,
    bool clearCircuitId = false,
    DateTime? takenAt,
    bool clearTakenAt = false,
    GeoPoint? locationGeo,
    bool clearLocationGeo = false,
    String? locationName,
    bool clearLocationName = false,
    String? photographerId,
    bool clearPhotographerId = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShopMedia(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      type: type ?? this.type,
      url: url ?? this.url,
      storagePath: storagePath ?? this.storagePath,
      thumbUrl: clearThumbUrl ? null : (thumbUrl ?? this.thumbUrl),
      status: status ?? this.status,
      isVisible: isVisible ?? this.isVisible,
      countryCode: clearCountryCode ? null : (countryCode ?? this.countryCode),
      eventId: clearEventId ? null : (eventId ?? this.eventId),
      circuitId: clearCircuitId ? null : (circuitId ?? this.circuitId),
      takenAt: clearTakenAt ? null : (takenAt ?? this.takenAt),
      locationGeo: clearLocationGeo ? null : (locationGeo ?? this.locationGeo),
      locationName: clearLocationName
          ? null
          : (locationName ?? this.locationName),
      photographerId: clearPhotographerId
          ? null
          : (photographerId ?? this.photographerId),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory ShopMedia.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final created = data['createdAt'];
    final updated = data['updatedAt'];
    final takenAt = data['takenAt'];
    return ShopMedia(
      id: doc.id,
      shopId: (data['shopId'] ?? '').toString(),
      type: (data['type'] ?? 'photo').toString(),
      url: (data['url'] ?? '').toString(),
      storagePath: (data['storagePath'] ?? '').toString(),
      thumbUrl: data['thumbUrl']?.toString(),
      status: (data['status'] ?? 'draft').toString(),
      isVisible: (data['isVisible'] ?? false) as bool,
      countryCode: data['countryCode']?.toString(),
      eventId: data['eventId']?.toString(),
      circuitId: data['circuitId']?.toString(),
      takenAt: takenAt is Timestamp ? takenAt.toDate() : null,
      locationGeo: data['locationGeo'] is GeoPoint
          ? data['locationGeo'] as GeoPoint
          : null,
      locationName: data['locationName']?.toString(),
      photographerId: data['photographerId']?.toString(),
      createdAt: created is Timestamp ? created.toDate() : DateTime.now(),
      updatedAt: updated is Timestamp ? updated.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'shopId': shopId,
    'type': type,
    'url': url,
    'storagePath': storagePath,
    'thumbUrl': thumbUrl,
    'status': status,
    'isVisible': isVisible,
    'countryCode': countryCode,
    'eventId': eventId,
    'circuitId': circuitId,
    'takenAt': takenAt == null ? null : Timestamp.fromDate(takenAt!),
    'locationGeo': locationGeo,
    'locationName': locationName,
    'photographerId': photographerId,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };
}

@immutable
class CartItem {
  final Product product;
  final int qty;

  const CartItem({required this.product, required this.qty});

  CartItem copyWith({Product? product, int? qty}) {
    return CartItem(product: product ?? this.product, qty: qty ?? this.qty);
  }

  Map<String, dynamic> toJson() => {
    'productId': product.id,
    'name': product.name,
    'unitPrice': product.price,
    'currency': product.currency,
    'qty': qty,
    'imageUrl': product.mainImageUrl,
  };
}
