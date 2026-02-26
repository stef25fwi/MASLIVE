// commerce_module_single_file.dart
//
// ✅ SINGLE FILE “COMMERCE / BOUTIQUE” MODULE (Firestore + Storage) — prêt pour Copilot
// - Gestion Produits (Admin): CRUD + filtres + popup édition + photos (upload Storage) + stock sync
// - Boutique (Public): liste produits actifs + panier local + checkout (transaction stock + création commande)
// - Stock “safe” via transaction Firestore
// - Photos: upload Firebase Storage + stockage metadata dans Firestore (images[] + mainImageUrl)
//
// 🔧 Dépendances à ajouter dans pubspec.yaml:
//   firebase_core: ^3.x
//   cloud_firestore: ^5.x
//   firebase_storage: ^12.x
//   image_picker: ^1.x
//   permission_handler: ^11.x
//
// ⚠️ IMPORTANT
// - Ce fichier est volontairement “monolithique” comme demandé (pour Copilot).
// - Ensuite tu pourras le découper en feature-first.
// - Pour les règles Firestore/Storage et indexes, reprends celles qu’on a définies plus tôt.
//
// ------------------------------------------------------------------------------

import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'ui/snack/top_snack_bar.dart';

// ------------------------------------------------------------------------------
// 1) DOMAIN MODELS
// ------------------------------------------------------------------------------

@immutable
class ProductImage {
  final String id;
  final String url;
  final String path; // storage path
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

  /// Workflow de publication et visibilité
  /// status: draft | pending | approved | rejected | archived | published
  final String status;
  final bool isVisible;

  /// Mode d'inventaire: true = stock suivi, false = stock illimité/logique
  final bool trackInventory;

  /// Stock
  final int stockQty;
  final int stockAlertQty;

  /// Identifiants
  final String? sku;
  final String? barcode;

  /// MAS’LIVE optional filters
  final String? country;
  final String? event;
  final String? circuit;
  final GeoPoint? placeGeo;

  /// Images
  final String? mainImageUrl;
  final int imageCount;
  final List<ProductImage> images;

  /// Search tokens
  final List<String> searchTokens;

  /// Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Champ calculé pour filtrer facilement le stock
  /// ("ok" | "low" | "out")
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
      placeGeo: data['placeGeo'] is GeoPoint ? data['placeGeo'] as GeoPoint : null,
      mainImageUrl: data['mainImageUrl']?.toString(),
      imageCount: (data['imageCount'] ?? 0) as int,
      images: imgs
          .map((e) => ProductImage.fromJson(Map<String, dynamic>.from(e as Map)))
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

  /// UID du propriétaire principal de la boutique (admin / compte pro)
  final String? ownerUid;

  /// Type de boutique: "global" | "group" | "event" (ou autres variantes futures)
  final String type;

  /// Contrôle d’activation logique de la boutique
  final bool isActive;

  /// Contexte MASLIVE
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
  final bool? onlyActive; // true => only active, false => only inactive, null => all
  final String? stockStatus; // "ok"|"low"|"out"|null
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

  /// "photo" ou "video"
  final String type;

  /// URL publique complète (download URL)
  final String url;

  /// Chemin dans Firebase Storage (ex: shops/{shopId}/media/{filename})
  final String storagePath;

  /// Miniature éventuelle
  final String? thumbUrl;

  /// Statut fonctionnel (draft/pending/approved/published/archived...)
  final String status;

  /// Contrôle d'affichage public
  final bool isVisible;

  /// Filtres MASLIVE (scope photo)
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
    this.thumbUrl,
    this.status = 'published',
    this.isVisible = true,
    this.countryCode,
    this.eventId,
    this.circuitId,
    this.takenAt,
    this.locationGeo,
    this.locationName,
    this.photographerId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPhoto => type == 'photo';
  bool get isVideo => type == 'video';

  ShopMedia copyWith({
    String? id,
    String? shopId,
    String? type,
    String? url,
    String? storagePath,
    String? thumbUrl,
    String? status,
    bool? isVisible,
    String? countryCode,
    String? eventId,
    String? circuitId,
    DateTime? takenAt,
    GeoPoint? locationGeo,
    String? locationName,
    String? photographerId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShopMedia(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      type: type ?? this.type,
      url: url ?? this.url,
      storagePath: storagePath ?? this.storagePath,
      thumbUrl: thumbUrl ?? this.thumbUrl,
      status: status ?? this.status,
      isVisible: isVisible ?? this.isVisible,
      countryCode: countryCode ?? this.countryCode,
      eventId: eventId ?? this.eventId,
      circuitId: circuitId ?? this.circuitId,
      takenAt: takenAt ?? this.takenAt,
      locationGeo: locationGeo ?? this.locationGeo,
      locationName: locationName ?? this.locationName,
      photographerId: photographerId ?? this.photographerId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
        'takenAt': takenAt != null ? Timestamp.fromDate(takenAt!) : null,
        'locationGeo': locationGeo,
        'locationName': locationName,
        'photographerId': photographerId,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  factory ShopMedia.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final created = data['createdAt'];
    final updated = data['updatedAt'];
    final taken = data['takenAt'];

    return ShopMedia(
      id: doc.id,
      shopId: (data['shopId'] ?? '').toString(),
      type: (data['type'] ?? 'photo').toString(),
      url: (data['url'] ?? '').toString(),
      storagePath: (data['storagePath'] ?? '').toString(),
      thumbUrl: data['thumbUrl']?.toString(),
      status: (data['status'] ?? 'published').toString(),
      isVisible: (data['isVisible'] ?? true) as bool,
      countryCode: data['countryCode']?.toString(),
      eventId: data['eventId']?.toString(),
      circuitId: data['circuitId']?.toString(),
      takenAt: taken is Timestamp ? taken.toDate() : null,
      locationGeo: data['locationGeo'] is GeoPoint ? data['locationGeo'] as GeoPoint : null,
      locationName: data['locationName']?.toString(),
      photographerId: data['photographerId']?.toString(),
      createdAt: created is Timestamp ? created.toDate() : DateTime.now(),
      updatedAt: updated is Timestamp ? updated.toDate() : DateTime.now(),
    );
  }
}

// ------------------------------------------------------------------------------
// 4bis) UI - ADMIN: Galerie de médias Shop (ShopMediaGalleryPage)
// ------------------------------------------------------------------------------

class ShopMediaGalleryPage extends StatelessWidget {
  final String shopId;
  const ShopMediaGalleryPage({super.key, required this.shopId});

  @override
  Widget build(BuildContext context) {
    final repo = CommerceRepository();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Galerie photos boutique'),
      ),
      body: StreamBuilder<List<ShopMedia>>(
        stream: repo.streamShopMedia(shopId, onlyVisible: false),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Erreur: \'${snap.error}\''));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(child: Text('Aucun média pour ce shop'));
          }

          final w = MediaQuery.of(context).size.width;
          final cross = w >= 1100 ? 5 : (w >= 800 ? 4 : (w >= 520 ? 3 : 2));

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cross,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final m = items[index];
              return GestureDetector(
                onTap: () {
                  showDialog<void>(
                    context: context,
                    builder: (_) => Dialog(
                      insetPadding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AspectRatio(
                            aspectRatio: 4 / 3,
                            child: m.isVideo
                                ? const Center(child: Icon(Icons.videocam_outlined))
                                : Image.network(m.url, fit: BoxFit.cover),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              m.locationName ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      m.isVideo
                          ? Container(
                              color: Colors.black12,
                              child: const Icon(Icons.videocam_outlined),
                            )
                          : Image.network(m.url, fit: BoxFit.cover),
                      if (!m.isVisible)
                        Container(
                          color: Colors.black38,
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.all(4),
                          child: const Icon(Icons.visibility_off, color: Colors.white, size: 18),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------------------------
// 2) REPOSITORIES (Firestore + Storage)
// ------------------------------------------------------------------------------

class CommerceRepository {
  final FirebaseFirestore _db;
  CommerceRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _shopDoc(String shopId) =>
      _db.collection('shops').doc(shopId);

  CollectionReference<Map<String, dynamic>> _productsCol(String shopId) =>
      _db.collection('shops').doc(shopId).collection('products');

  CollectionReference<Map<String, dynamic>> _categoriesCol(String shopId) =>
      _db.collection('shops').doc(shopId).collection('categories');

  CollectionReference<Map<String, dynamic>> _ordersCol(String shopId) =>
      _db.collection('shops').doc(shopId).collection('orders');

  CollectionReference<Map<String, dynamic>> _mediaCol(String shopId) =>
      _db.collection('shops').doc(shopId).collection('media');

  // ----- SHOPS (fiche boutique) -----

  Future<Shop?> fetchShop(String shopId) async {
    final snap = await _shopDoc(shopId).get();
    if (!snap.exists) return null;
    return Shop.fromDoc(snap);
  }

  Stream<Shop?> streamShop(String shopId) {
    return _shopDoc(shopId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return Shop.fromDoc(snap);
    });
  }

  Future<void> saveShop(Shop shop) async {
    await _shopDoc(shop.id).set(shop.toJson(), SetOptions(merge: true));
  }

  Stream<List<Category>> streamCategories(String shopId) {
    return _categoriesCol(shopId).orderBy('sortOrder').snapshots().map((snap) {
      return snap.docs.map((d) => Category.fromDoc(d)).toList();
    });
  }

  /// Stream des médias de boutique avec filtres de base
  Stream<List<ShopMedia>> streamShopMedia(
    String shopId, {
    bool onlyVisible = true,
    String? countryCode,
    String? eventId,
    String? circuitId,
    String? photographerId,
  }) {
    Query<Map<String, dynamic>> q = _mediaCol(shopId);

    if (onlyVisible) {
      q = q.where('isVisible', isEqualTo: true);
    }
    if (countryCode != null && countryCode.isNotEmpty) {
      q = q.where('countryCode', isEqualTo: countryCode);
    }
    if (eventId != null && eventId.isNotEmpty) {
      q = q.where('eventId', isEqualTo: eventId);
    }
    if (circuitId != null && circuitId.isNotEmpty) {
      q = q.where('circuitId', isEqualTo: circuitId);
    }
    if (photographerId != null && photographerId.isNotEmpty) {
      q = q.where('photographerId', isEqualTo: photographerId);
    }

    // Tri principal par date de prise de vue si dispo, sinon createdAt
    q = q.orderBy('takenAt', descending: true);

    return q.snapshots().map((snap) {
      return snap.docs.map(ShopMedia.fromDoc).toList();
    });
  }

  /// Stream products with filter + optional search token (first word)
  Stream<List<Product>> streamProducts(String shopId, ProductFilter filter, String searchText) {
    Query<Map<String, dynamic>> q = _productsCol(shopId);

    // Filters (Firestore-friendly)
    if (filter.onlyActive != null) {
      q = q.where('isActive', isEqualTo: filter.onlyActive);
    }
    if (filter.categoryId != null && filter.categoryId!.isNotEmpty) {
      q = q.where('categoryId', isEqualTo: filter.categoryId);
    }
    if (filter.stockStatus != null && filter.stockStatus!.isNotEmpty) {
      q = q.where('stockStatus', isEqualTo: filter.stockStatus);
    }

    // Optional MAS’LIVE filters
    if (filter.country != null && filter.country!.isNotEmpty) {
      q = q.where('country', isEqualTo: filter.country);
    }
    if (filter.event != null && filter.event!.isNotEmpty) {
      q = q.where('event', isEqualTo: filter.event);
    }
    if (filter.circuit != null && filter.circuit!.isNotEmpty) {
      q = q.where('circuit', isEqualTo: filter.circuit);
    }

    // Price range (Firestore limitation: range requires orderBy on same field)
    // -> On garde simple: on fera le range en client-side si besoin.
    q = q.orderBy('updatedAt', descending: true);

    // Search token (simple)
    final token = _firstToken(searchText);
    if (token != null && token.isNotEmpty) {
      q = q.where('searchTokens', arrayContains: token);
    }

    return q.snapshots().map((snap) {
      final list = snap.docs.map((d) => Product.fromDoc(d)).toList();

      // Client-side price filter (safe)
      return list.where((p) {
        if (filter.minPrice != null && p.price < filter.minPrice!) return false;
        if (filter.maxPrice != null && p.price > filter.maxPrice!) return false;
        if (filter.tag != null && filter.tag!.isNotEmpty) {
          final t = filter.tag!.toLowerCase().trim();
          if (!p.tags.map((e) => e.toLowerCase()).contains(t)) return false;
        }
        return true;
      }).toList();
    });
  }

  Future<String> createMedia(String shopId, ShopMedia media) async {
    final now = DateTime.now();
    final doc = _mediaCol(shopId).doc();

    final payload = media
        .copyWith(
          id: doc.id,
          shopId: shopId,
          createdAt: now,
          updatedAt: now,
        )
        .toJson();

    await doc.set(payload);
    return doc.id;
  }

  Future<void> updateMedia(String shopId, ShopMedia media) async {
    final now = DateTime.now();

    final payload = media
        .copyWith(
          updatedAt: now,
        )
        .toJson();

    await _mediaCol(shopId).doc(media.id).update(payload);
  }

  Future<void> deleteMedia(String shopId, String mediaId) async {
    await _mediaCol(shopId).doc(mediaId).delete();
  }

  Future<String> createProduct(String shopId, Product product) async {
    final now = DateTime.now();
    final doc = _productsCol(shopId).doc();
    final computed = _computeStockStatus(product.stockQty, product.stockAlertQty);

    final payload = product
        .copyWith(
          id: doc.id,
          createdAt: now,
          updatedAt: now,
          stockStatus: computed,
          searchTokens: _buildSearchTokens(product.name, product.tags),
        )
        .toJson();

    await doc.set(payload);
    return doc.id;
  }

  Future<void> updateProduct(String shopId, Product product) async {
    final now = DateTime.now();
    final computed = _computeStockStatus(product.stockQty, product.stockAlertQty);

    final payload = product
        .copyWith(
          updatedAt: now,
          stockStatus: computed,
          searchTokens: _buildSearchTokens(product.name, product.tags),
        )
        .toJson();

    await _productsCol(shopId).doc(product.id).update(payload);
  }

  Future<void> setActive(String shopId, String productId, bool isActive) async {
    await _productsCol(shopId).doc(productId).update({
      'isActive': isActive,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> deleteProduct(String shopId, String productId) async {
    await _productsCol(shopId).doc(productId).delete();
  }

  /// Duplicate product (copy doc fields, reset timestamps, clear images by default or keep)
  Future<String> duplicateProduct(String shopId, Product product, {bool keepImages = true}) async {
    final now = DateTime.now();
    final newDoc = _productsCol(shopId).doc();
    final images = keepImages ? product.images : <ProductImage>[];
    final mainUrl = keepImages ? product.mainImageUrl : null;

    final copied = product.copyWith(
      id: newDoc.id,
      name: '${product.name} (copie)',
      createdAt: now,
      updatedAt: now,
      images: images,
      imageCount: images.length,
      mainImageUrl: mainUrl,
      searchTokens: _buildSearchTokens('${product.name} copie', product.tags),
    );

    await newDoc.set(copied.toJson());
    return newDoc.id;
  }

  /// Transaction adjust stock (safe)
  Future<void> adjustStock(String shopId, String productId, int delta) async {
    final ref = _productsCol(shopId).doc(productId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Produit introuvable');

      final data = snap.data() ?? {};
      final qty = (data['stockQty'] ?? 0) as int;
      final alert = (data['stockAlertQty'] ?? 3) as int;

      final next = qty + delta;
      if (next < 0) throw Exception('Stock insuffisant');

      final status = _computeStockStatus(next, alert);

      tx.update(ref, {
        'stockQty': next,
        'stockStatus': status,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    });
  }

  /// Public order create + stock decremented in same transaction (simple)
  Future<String> checkoutCreateOrder({
    required String shopId,
    required String userId,
    required List<CartItem> items,
  }) async {
    final orderRef = _ordersCol(shopId).doc();
    final now = DateTime.now();

    await _db.runTransaction((tx) async {
      // Validate and decrement stock for each item
      for (final item in items) {
        final prodRef = _productsCol(shopId).doc(item.product.id);
        final prodSnap = await tx.get(prodRef);
        if (!prodSnap.exists) throw Exception('Produit introuvable');

        final data = prodSnap.data() ?? {};
        final qty = (data['stockQty'] ?? 0) as int;
        final alert = (data['stockAlertQty'] ?? 3) as int;

        if (qty < item.qty) throw Exception('Stock insuffisant pour ${item.product.name}');

        final next = qty - item.qty;
        final status = _computeStockStatus(next, alert);

        tx.update(prodRef, {
          'stockQty': next,
          'stockStatus': status,
          'updatedAt': Timestamp.fromDate(now),
        });
      }

      // Create order document
      final total = items.fold<double>(0, (s, i) => s + (i.product.price * i.qty));
      tx.set(orderRef, {
        'status': 'created',
        'userId': userId,
        'items': items.map((i) => i.toJson()).toList(),
        'total': total,
        'currency': items.isNotEmpty ? items.first.product.currency : 'EUR',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });
    });

    return orderRef.id;
  }

  // Helpers
  static String _computeStockStatus(int stockQty, int alertQty) {
    if (stockQty <= 0) return 'out';
    if (stockQty <= alertQty) return 'low';
    return 'ok';
  }

  static List<String> _buildSearchTokens(String name, List<String> tags) {
    final tokens = <String>{};
    void addAll(String s) {
      final t = s
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9àâçéèêëîïôûùüÿñæœ\s-]'), ' ')
          .split(RegExp(r'\s+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      for (final w in t) {
        if (w.length >= 2) tokens.add(w);
      }
    }

    addAll(name);
    for (final t in tags) {
      addAll(t);
    }
    return tokens.toList();
  }

  static String? _firstToken(String searchText) {
    final t = searchText.trim().toLowerCase();
    if (t.isEmpty) return null;
    final parts = t.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    return parts.first;
  }
}

class StorageRepository {
  final FirebaseStorage _storage;
  StorageRepository({FirebaseStorage? storage}) : _storage = storage ?? FirebaseStorage.instance;

  Reference _productFolder(String shopId, String productId) =>
      _storage.ref().child('shops/$shopId/products/$productId');

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

    final meta = SettableMetadata(contentType: contentType);
    await ref.putData(bytes, meta);
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
      // ignore (file may not exist)
    }
  }

  Future<void> deleteAllProductImages(String shopId, String productId) async {
    // Optional: listAll then delete (may be slow). Prefer storing paths in Firestore and delete those.
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
    } catch (_) {}
  }

  static String _randId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = Random();
    return List.generate(12, (_) => chars[r.nextInt(chars.length)]).join();
  }
}

// ------------------------------------------------------------------------------
// 3) CONTROLLER (ChangeNotifier)
// ------------------------------------------------------------------------------

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
  })  : commerceRepo = commerceRepo ?? CommerceRepository(),
        storageRepo = storageRepo ?? StorageRepository();

  Stream<List<Product>> streamProducts() => commerceRepo.streamProducts(shopId, _filter, _search);
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
      // delete storage images if paths present
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

  /// Upload 1..n images and attach to product (update Firestore)
  Future<void> addImagesToProduct(Product p, List<XFile> files) async {
    if (files.isEmpty) return;
    _setBusy(true);
    try {
      final existing = List<ProductImage>.from(p.images);
      int startOrder = existing.isEmpty ? 0 : (existing.map((e) => e.sortOrder).reduce(max) + 1);

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
      final next = List<ProductImage>.from(p.images)..removeWhere((e) => e.id == img.id);
      next.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      final main = next.isNotEmpty ? next.first.url : null;
      final updated = p.copyWith(images: next, imageCount: next.length, mainImageUrl: main);

      await commerceRepo.updateProduct(shopId, updated);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> reorderImages(Product p, List<ProductImage> newOrder) async {
    _setBusy(true);
    try {
      final re = <ProductImage>[];
      for (int i = 0; i < newOrder.length; i++) {
        re.add(newOrder[i].copyWithSortOrder(i));
      }
      final main = re.isNotEmpty ? re.first.url : null;

      final updated = p.copyWith(images: re, imageCount: re.length, mainImageUrl: main);
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

// ------------------------------------------------------------------------------
// 4) UI - ADMIN: ProductManagementPage + Widgets
// ------------------------------------------------------------------------------

class ProductManagementPage extends StatefulWidget {
  final String shopId;
  final int cartCountBadge; // optional: pour l’icône panier dans le header

  const ProductManagementPage({
    super.key,
    required this.shopId,
    this.cartCountBadge = 0,
  });

  @override
  State<ProductManagementPage> createState() => _ProductManagementPageState();
}

class _ProductManagementPageState extends State<ProductManagementPage> {
  late final ProductController controller;
  final TextEditingController searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller = ProductController(shopId: widget.shopId);
    searchCtrl.addListener(() => controller.setSearch(searchCtrl.text));
    _prepareMediaAccess();
  }

  Future<void> _prepareMediaAccess() async {
    await controller.storageRepo.ensureProductUploadFolder(shopId: widget.shopId);
    if (kIsWeb) return;

    try {
      await [
        Permission.camera,
        Permission.photos,
        Permission.storage,
      ].request();
    } catch (_) {
      // ignore
    }
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return ChangeNotifierProviderLite(
      notifier: controller,
      child: Builder(
        builder: (context) {
          final c = ChangeNotifierProviderLite.of<ProductController>(context);

          return Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              top: false,
              child: Column(
                children: [
                  // Header premium blanc + badge panier
                  Container(
                    padding: EdgeInsets.fromLTRB(16, topPad + 12, 16, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                          color: Colors.black.withAlpha(15),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Gestion Produits',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Galerie photos',
                          icon: const Icon(Icons.photo_library_outlined),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ShopMediaGalleryPage(shopId: widget.shopId),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        _CartIconWithBadge(count: widget.cartCountBadge),
                        const SizedBox(width: 10),
                        FilledButton(
                          onPressed: () async {
                            final created = await showDialog<Product?>(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => ProductEditDialog(
                                shopId: widget.shopId,
                                existing: null,
                              ),
                            );
                            if (created != null) {
                              await c.createOrUpdate(created, isNew: true);
                              if (context.mounted) {
                                TopSnackBar.show(
                                  context,
                                  const SnackBar(content: Text('Produit ajouté')),
                                );
                              }
                            }
                          },
                          child: const Text('Ajouter'),
                        ),
                      ],
                    ),
                  ),

                  // Search
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: TextField(
                      controller: searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Rechercher (nom, tags)…',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: const Color(0xFFF6F7FB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  // Filters bar (tiles)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: ProductFiltersBar(controller: c),
                  ),

                  // List/Grid
                  Expanded(
                    child: Stack(
                      children: [
                        StreamBuilder<List<Product>>(
                          stream: c.streamProducts(),
                          builder: (context, snap) {
                            if (snap.hasError) {
                              return Center(child: Text('Erreur: ${snap.error}'));
                            }
                            if (!snap.hasData) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            final products = snap.data!;
                            if (products.isEmpty) {
                              return const Center(child: Text('Aucun produit'));
                            }

                            final w = MediaQuery.of(context).size.width;
                            final cross = w >= 1100 ? 4 : (w >= 800 ? 3 : (w >= 520 ? 2 : 1));

                            return Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: GridView.builder(
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cross,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.92,
                                ),
                                itemCount: products.length,
                                itemBuilder: (_, i) => ProductTileAdmin(
                                  product: products[i],
                                  onEdit: () async {
                                    final updated = await showDialog<Product?>(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (_) => ProductEditDialog(
                                        shopId: widget.shopId,
                                        existing: products[i],
                                      ),
                                    );
                                    if (updated != null) {
                                      await c.createOrUpdate(updated, isNew: false);
                                      if (context.mounted) {
                                        TopSnackBar.show(
                                          context,
                                          const SnackBar(content: Text('Produit enregistré')),
                                        );
                                      }
                                    }
                                  },
                                  onPhotos: () async {
                                    await showDialog<void>(
                                      context: context,
                                      barrierDismissible: true,
                                      builder: (_) => ProductImagesEditorDialog(
                                        controller: c,
                                        product: products[i],
                                      ),
                                    );
                                  },
                                  onStock: () async {
                                    await showDialog<void>(
                                      context: context,
                                      builder: (_) => StockQuickEditorDialog(
                                        controller: c,
                                        product: products[i],
                                      ),
                                    );
                                  },
                                  onDuplicate: () => c.duplicate(products[i], keepImages: true),
                                  onToggleActive: () => c.toggleActive(products[i]),
                                  onDelete: () async {
                                    final ok = await _confirm(context,
                                        title: 'Supprimer le produit ?',
                                        message: 'Cette action est définitive.');
                                    if (ok) await c.deleteProduct(products[i]);
                                  },
                                ),
                              ),
                            );
                          },
                        ),

                        // Busy overlay
                        AnimatedBuilder(
                          animation: c,
                          builder: (context, child) {
                            if (!c.busy) return const SizedBox.shrink();
                            return Container(
                              color: Colors.black.withAlpha(20),
                              child: const Center(
                                child: SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class ProductFiltersBar extends StatelessWidget {
  final ProductController controller;
  const ProductFiltersBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Category>>(
      stream: controller.streamCategories(),
      builder: (context, snap) {
        final categories = snap.data ?? const <Category>[];

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              final f = controller.filter;

              return Row(
                children: [
                  _FilterTile(
                    label: f.categoryId == null ? 'Catégorie' : 'Catégorie ✓',
                    active: f.categoryId != null,
                    icon: Icons.category_outlined,
                    onTap: () async {
                      final selected = await _pickFromMenu<String?>(
                        context,
                        title: 'Catégorie',
                        items: [
                          const _MenuItem(value: null, label: 'Toutes'),
                          ...categories.map((c) => _MenuItem(value: c.id, label: c.name)),
                        ],
                        initial: f.categoryId,
                      );
                      controller.setFilter(f.copyWith(categoryId: selected, resetCategory: selected == null));
                    },
                  ),
                  const SizedBox(width: 10),
                  _FilterTile(
                    label: f.onlyActive == null
                        ? 'Visibilité'
                        : (f.onlyActive == true ? 'Actifs ✓' : 'Inactifs ✓'),
                    active: f.onlyActive != null,
                    icon: Icons.visibility_outlined,
                    onTap: () async {
                      final selected = await _pickFromMenu<bool?>(
                        context,
                        title: 'Visibilité',
                        items: const [
                          _MenuItem(value: null, label: 'Tous'),
                          _MenuItem(value: true, label: 'Actifs'),
                          _MenuItem(value: false, label: 'Inactifs'),
                        ],
                        initial: f.onlyActive,
                      );
                      controller.setFilter(f.copyWith(onlyActive: selected, resetOnlyActive: selected == null));
                    },
                  ),
                  const SizedBox(width: 10),
                  _FilterTile(
                    label: f.stockStatus == null
                        ? 'Stock'
                        : (f.stockStatus == 'ok'
                            ? 'OK ✓'
                            : (f.stockStatus == 'low' ? 'Faible ✓' : 'Rupture ✓')),
                    active: f.stockStatus != null,
                    icon: Icons.inventory_2_outlined,
                    onTap: () async {
                      final selected = await _pickFromMenu<String?>(
                        context,
                        title: 'Stock',
                        items: const [
                          _MenuItem(value: null, label: 'Tous'),
                          _MenuItem(value: 'ok', label: 'OK'),
                          _MenuItem(value: 'low', label: 'Faible'),
                          _MenuItem(value: 'out', label: 'Rupture'),
                        ],
                        initial: f.stockStatus,
                      );
                      controller.setFilter(f.copyWith(stockStatus: selected, resetStockStatus: selected == null));
                    },
                  ),
                  const SizedBox(width: 10),
                  _FilterTile(
                    label: (f.minPrice == null && f.maxPrice == null) ? 'Prix' : 'Prix ✓',
                    active: (f.minPrice != null || f.maxPrice != null),
                    icon: Icons.euro_outlined,
                    onTap: () async {
                      final res = await showDialog<_PriceRange?>(
                        context: context,
                        builder: (_) => _PriceRangeDialog(initialMin: f.minPrice, initialMax: f.maxPrice),
                      );
                      if (res == null) return;
                      controller.setFilter(
                        f.copyWith(
                          minPrice: res.min,
                          maxPrice: res.max,
                          resetMinPrice: res.min == null,
                          resetMaxPrice: res.max == null,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  _FilterTile(
                    label: f.tag == null ? 'Tag' : 'Tag ✓',
                    active: f.tag != null,
                    icon: Icons.tag_outlined,
                    onTap: () async {
                      final res = await showDialog<String?>(
                        context: context,
                        builder: (_) => _TextPromptDialog(
                          title: 'Tag',
                          hint: 'ex: promo, artisan, vip…',
                          initial: f.tag ?? '',
                        ),
                      );
                      final val = (res ?? '').trim();
                      controller.setFilter(f.copyWith(tag: val.isEmpty ? null : val, resetTag: val.isEmpty));
                    },
                  ),
                  const SizedBox(width: 10),
                  _FilterTile(
                    label: 'Réinitialiser',
                    active: controller.filter.hasAny,
                    icon: Icons.restart_alt,
                    onTap: controller.resetFilters,
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class ProductTileAdmin extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onPhotos;
  final VoidCallback onStock;
  final VoidCallback onDuplicate;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  const ProductTileAdmin({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onPhotos,
    required this.onStock,
    required this.onDuplicate,
    required this.onToggleActive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final badge = _stockBadge(product.stockStatus);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onEdit,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE9ECF3)),
            boxShadow: [
              BoxShadow(
                blurRadius: 18,
                offset: const Offset(0, 10),
                color: Colors.black.withAlpha(13),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: Container(
                    color: const Color(0xFFF6F7FB),
                    child: product.mainImageUrl == null
                        ? const Center(child: Icon(Icons.photo_outlined, size: 32))
                        : Image.network(
                            product.mainImageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) =>
                                const Center(child: Icon(Icons.broken_image_outlined)),
                          ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _Pill(text: product.isActive ? 'Actif' : 'Off', filled: product.isActive),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '${product.price.toStringAsFixed(2)} ${product.currency}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 10),
                        _Pill(text: badge.label, filled: badge.filled),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Actions row
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SmallAction(icon: Icons.edit_outlined, label: 'Modifier', onTap: onEdit),
                        _SmallAction(icon: Icons.photo_library_outlined, label: 'Photos', onTap: onPhotos),
                        _SmallAction(icon: Icons.inventory_outlined, label: 'Stock', onTap: onStock),
                        _SmallAction(icon: Icons.copy_outlined, label: 'Dupliquer', onTap: onDuplicate),
                        _SmallAction(
                          icon: product.isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          label: product.isActive ? 'Désactiver' : 'Activer',
                          onTap: onToggleActive,
                        ),
                        _SmallAction(icon: Icons.delete_outline, label: 'Supprimer', onTap: onDelete),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _StockBadge _stockBadge(String status) {
    switch (status) {
      case 'out':
        return const _StockBadge(label: 'Rupture', filled: true);
      case 'low':
        return const _StockBadge(label: 'Faible', filled: true);
      default:
        return const _StockBadge(label: 'Stock OK', filled: false);
    }
  }
}

class ProductEditDialog extends StatefulWidget {
  final String shopId;
  final Product? existing;

  const ProductEditDialog({super.key, required this.shopId, required this.existing});

  @override
  State<ProductEditDialog> createState() => _ProductEditDialogState();
}

class _ProductEditDialogState extends State<ProductEditDialog> {
  final formKey = GlobalKey<FormState>();

  late final TextEditingController nameCtrl;
  late final TextEditingController descCtrl;
  late final TextEditingController priceCtrl;
  late final TextEditingController tagsCtrl;
  late final TextEditingController stockCtrl;
  late final TextEditingController alertCtrl;
  late final TextEditingController skuCtrl;
  late final TextEditingController barcodeCtrl;

  bool isActive = true;
  bool isFeatured = false;
  String currency = 'EUR';
  String? categoryId;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    nameCtrl = TextEditingController(text: p?.name ?? '');
    descCtrl = TextEditingController(text: p?.description ?? '');
    priceCtrl = TextEditingController(text: p != null ? p.price.toStringAsFixed(2) : '');
    tagsCtrl = TextEditingController(text: p?.tags.join(', ') ?? '');
    stockCtrl = TextEditingController(text: p != null ? '${p.stockQty}' : '0');
    alertCtrl = TextEditingController(text: p != null ? '${p.stockAlertQty}' : '3');
    skuCtrl = TextEditingController(text: p?.sku ?? '');
    barcodeCtrl = TextEditingController(text: p?.barcode ?? '');
    isActive = p?.isActive ?? true;
    isFeatured = p?.isFeatured ?? false;
    currency = p?.currency ?? 'EUR';
    categoryId = p?.categoryId;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    descCtrl.dispose();
    priceCtrl.dispose();
    tagsCtrl.dispose();
    stockCtrl.dispose();
    alertCtrl.dispose();
    skuCtrl.dispose();
    barcodeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isNew ? 'Ajouter un produit' : 'Modifier le produit',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      children: [
                        _field(
                          label: 'Nom',
                          controller: nameCtrl,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
                        ),
                        const SizedBox(height: 10),
                        _field(
                          label: 'Description',
                          controller: descCtrl,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                label: 'Prix',
                                controller: priceCtrl,
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  final d = double.tryParse((v ?? '').replaceAll(',', '.'));
                                  if (d == null || d < 0) return 'Prix invalide';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 110,
                              child: DropdownButtonFormField<String>(
                                initialValue: currency,
                                decoration: _decor('Devise'),
                                items: const [
                                  DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                                  DropdownMenuItem(value: 'USD', child: Text('USD')),
                                ],
                                onChanged: (v) => setState(() => currency = v ?? 'EUR'),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 10),
                        _field(
                          label: 'Tags (séparés par virgule)',
                          controller: tagsCtrl,
                        ),
                        const SizedBox(height: 10),

                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                label: 'Stock',
                                controller: stockCtrl,
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  final i = int.tryParse((v ?? '').trim());
                                  if (i == null || i < 0) return 'Stock invalide';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _field(
                                label: 'Alerte stock',
                                controller: alertCtrl,
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  final i = int.tryParse((v ?? '').trim());
                                  if (i == null || i < 0) return 'Valeur invalide';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: _field(label: 'SKU', controller: skuCtrl)),
                            const SizedBox(width: 10),
                            Expanded(child: _field(label: 'Code barre', controller: barcodeCtrl)),
                          ],
                        ),
                        const SizedBox(height: 10),

                        Row(
                          children: [
                            Expanded(
                              child: SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Actif en boutique'),
                                value: isActive,
                                onChanged: (v) => setState(() => isActive = v),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Mis en avant'),
                                value: isFeatured,
                                onChanged: (v) => setState(() => isFeatured = v),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.blue),
                      onPressed: () {
                        if (!(formKey.currentState?.validate() ?? false)) return;

                        final price = double.parse(priceCtrl.text.replaceAll(',', '.'));
                        final tags = tagsCtrl.text
                            .split(',')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toSet()
                            .toList();

                        final stockQty = int.parse(stockCtrl.text.trim());
                        final alertQty = int.parse(alertCtrl.text.trim());
                        final status = CommerceRepository._computeStockStatus(stockQty, alertQty);

                        final now = DateTime.now();
                        final base = widget.existing;

                        final product = Product(
                          id: base?.id ?? '',
                          name: nameCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          price: price,
                          currency: currency,
                          categoryId: categoryId,
                          tags: tags,
                          isActive: isActive,
                          isFeatured: isFeatured,
                          stockQty: stockQty,
                          stockAlertQty: alertQty,
                          sku: skuCtrl.text.trim().isEmpty ? null : skuCtrl.text.trim(),
                          barcode: barcodeCtrl.text.trim().isEmpty ? null : barcodeCtrl.text.trim(),
                          country: base?.country,
                          event: base?.event,
                          circuit: base?.circuit,
                          placeGeo: base?.placeGeo,
                          mainImageUrl: base?.mainImageUrl,
                          imageCount: base?.imageCount ?? 0,
                          images: base?.images ?? const [],
                          searchTokens: base?.searchTokens ?? const [],
                          createdAt: base?.createdAt ?? now,
                          updatedAt: now,
                          stockStatus: status,
                        );

                        Navigator.pop(context, product);
                      },
                      child: const Text('Enregistrer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      keyboardType: keyboardType,
      decoration: _decor(label),
    );
  }

  InputDecoration _decor(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.blueGrey),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.blue.withAlpha(77)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.blue, width: 2),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}

class ProductImagesEditorDialog extends StatefulWidget {
  final ProductController controller;
  final Product product;

  const ProductImagesEditorDialog({
    super.key,
    required this.controller,
    required this.product,
  });

  @override
  State<ProductImagesEditorDialog> createState() => _ProductImagesEditorDialogState();
}

class _ProductImagesEditorDialogState extends State<ProductImagesEditorDialog> {
  late Product product;
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    product = widget.product;
  }

  Future<void> _pickAndUpload() async {
    final files = await picker.pickMultiImage(imageQuality: 88);
    if (files.isEmpty) return;
    await widget.controller.addImagesToProduct(product, files);
    // Note: stream refresh fait le reste; ici on ferme juste un snack
    if (mounted) {
      TopSnackBar.show(
        context,
        SnackBar(content: Text('${files.length} photo(s) ajoutée(s)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // On re-render à partir du stream products (simple: on affiche snapshot local)
    // Ici: on montre surtout l’éditeur; le produit se met à jour quand on relit depuis stream.
    // Pour un vrai “live” dans le dialog, tu peux passer le Product stream du doc.
    final imgs = product.images;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Photos — ${product.name}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (imgs.isEmpty)
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: const Center(child: Text('Aucune photo')),
                )
              else
                SizedBox(
                  height: 190,
                  child: ReorderableListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: imgs.length,
                    onReorder: (oldIndex, newIndex) async {
                      // local reorder
                      final list = List<ProductImage>.from(imgs);
                      if (newIndex > oldIndex) newIndex -= 1;
                      final item = list.removeAt(oldIndex);
                      list.insert(newIndex, item);

                      await widget.controller.reorderImages(product, list);
                      setState(() {
                        product = product.copyWith(images: list);
                      });
                    },
                    itemBuilder: (_, i) {
                      final img = imgs[i];
                      return Container(
                        key: ValueKey(img.id),
                        width: 220,
                        margin: const EdgeInsets.only(right: 10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(img.url, fit: BoxFit.cover),
                              Positioned(
                                top: 10,
                                right: 10,
                                child: IconButton.filled(
                                  onPressed: () async {
                                    final ok = await _confirm(
                                      context,
                                      title: 'Supprimer cette photo ?',
                                      message: 'Elle sera supprimée du stockage.',
                                    );
                                    if (!ok) return;
                                    await widget.controller.removeImage(product, img);
                                    setState(() {
                                      final next = List<ProductImage>.from(product.images)
                                        ..removeWhere((e) => e.id == img.id);
                                      product = product.copyWith(images: next);
                                    });
                                  },
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ),
                              Positioned(
                                left: 10,
                                top: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    i == 0 ? 'Main' : '#${i + 1}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue),
                      ),
                      onPressed: _pickAndUpload,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Ajouter des photos'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Astuce: glisse-dépose horizontalement pour réordonner (photo principale = 1ère).',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StockQuickEditorDialog extends StatefulWidget {
  final ProductController controller;
  final Product product;

  const StockQuickEditorDialog({
    super.key,
    required this.controller,
    required this.product,
  });

  @override
  State<StockQuickEditorDialog> createState() => _StockQuickEditorDialogState();
}

class _StockQuickEditorDialogState extends State<StockQuickEditorDialog> {
  int delta = 1;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Stock — ${p.name}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.blue.withAlpha(77)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Stock actuel: ${p.stockQty}\nAlerte: ${p.stockAlertQty}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    DropdownButton<int>(
                      value: delta,
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1')),
                        DropdownMenuItem(value: 2, child: Text('2')),
                        DropdownMenuItem(value: 5, child: Text('5')),
                        DropdownMenuItem(value: 10, child: Text('10')),
                      ],
                      onChanged: (v) => setState(() => delta = v ?? 1),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue),
                      ),
                      onPressed: () async {
                        try {
                          await widget.controller.adjustStock(p, -delta);
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (!context.mounted) return;
                          TopSnackBar.show(
                            context,
                            SnackBar(content: Text('Erreur: $e')),
                          );
                        }
                      },
                      icon: const Icon(Icons.remove),
                      label: const Text('Décrémenter'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Colors.blue),
                      onPressed: () async {
                        try {
                          await widget.controller.adjustStock(p, delta);
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (!context.mounted) return;
                          TopSnackBar.show(
                            context,
                            SnackBar(content: Text('Erreur: $e')),
                          );
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Incrémenter'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------------
// 5) UI - PUBLIC: BoutiquePage + Panier local + Checkout
// ------------------------------------------------------------------------------

@immutable
class CartItem {
  final Product product;
  final int qty;

  const CartItem({required this.product, required this.qty});

  CartItem copyWith({Product? product, int? qty}) =>
      CartItem(product: product ?? this.product, qty: qty ?? this.qty);

  Map<String, dynamic> toJson() => {
        'productId': product.id,
        'name': product.name,
        'unitPrice': product.price,
        'currency': product.currency,
        'qty': qty,
        'imageUrl': product.mainImageUrl,
      };
}

class BoutiquePage extends StatefulWidget {
  final String shopId;
  final String userId; // id utilisateur / device
  const BoutiquePage({super.key, required this.shopId, required this.userId});

  @override
  State<BoutiquePage> createState() => _BoutiquePageState();
}

class _BoutiquePageState extends State<BoutiquePage> {
  late final ProductController controller;
  final TextEditingController searchCtrl = TextEditingController();
  final Map<String, CartItem> cart = {}; // productId -> item

  @override
  void initState() {
    super.initState();
    controller = ProductController(shopId: widget.shopId);
    searchCtrl.addListener(() => controller.setSearch(searchCtrl.text));
    controller.setFilter(const ProductFilter(onlyActive: true));
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    controller.dispose();
    super.dispose();
  }

  int get cartCount => cart.values.fold<int>(0, (s, i) => s + i.qty);

  void addToCart(Product p) {
    setState(() {
      final current = cart[p.id];
      if (current == null) {
        cart[p.id] = CartItem(product: p, qty: 1);
      } else {
        cart[p.id] = current.copyWith(qty: current.qty + 1);
      }
    });
  }

  void removeFromCart(Product p) {
    setState(() {
      final current = cart[p.id];
      if (current == null) return;
      final next = current.qty - 1;
      if (next <= 0) {
        cart.remove(p.id);
      } else {
        cart[p.id] = current.copyWith(qty: next);
      }
    });
  }

  double get total => cart.values.fold<double>(0, (s, i) => s + (i.product.price * i.qty));

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return ChangeNotifierProviderLite(
      notifier: controller,
      child: Builder(
        builder: (context) {
          final c = ChangeNotifierProviderLite.of<ProductController>(context);

          return Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              top: false,
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.fromLTRB(16, topPad + 12, 16, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                          color: Colors.black.withAlpha(15),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Boutique',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                          ),
                        ),
                        _CartIconWithBadge(count: cartCount, onTap: () => _openCart(context, c)),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: TextField(
                      controller: searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Rechercher…',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: const Color(0xFFF6F7FB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  Expanded(
                    child: Stack(
                      children: [
                        StreamBuilder<List<Product>>(
                          stream: c.streamProducts(),
                          builder: (context, snap) {
                            if (snap.hasError) return Center(child: Text('Erreur: ${snap.error}'));
                            if (!snap.hasData) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            final list = snap.data!;
                            if (list.isEmpty) return const Center(child: Text('Aucun produit disponible'));

                            return ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                              itemCount: list.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final p = list[i];
                                final isOut = p.stockStatus == 'out';
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: const Color(0xFFE9ECF3)),
                                    boxShadow: [
                                      BoxShadow(
                                        blurRadius: 18,
                                        offset: const Offset(0, 10),
                                        color: Colors.black.withValues(alpha: 0.05),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: Container(
                                          width: 66,
                                          height: 66,
                                          color: const Color(0xFFF6F7FB),
                                          child: p.mainImageUrl == null
                                              ? const Icon(Icons.photo_outlined)
                                              : Image.network(p.mainImageUrl!, fit: BoxFit.cover),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.w900),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${p.price.toStringAsFixed(2)} ${p.currency}',
                                              style: const TextStyle(fontWeight: FontWeight.w800),
                                            ),
                                            const SizedBox(height: 6),
                                            _Pill(
                                              text: isOut
                                                  ? 'Rupture'
                                                  : (p.stockStatus == 'low' ? 'Stock faible' : 'En stock'),
                                              filled: isOut || p.stockStatus == 'low',
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      if (isOut)
                                        const Icon(Icons.block, color: Colors.black54)
                                      else
                                        Column(
                                          children: [
                                            IconButton.filled(
                                              onPressed: () => addToCart(p),
                                              icon: const Icon(Icons.add_shopping_cart_outlined),
                                            ),
                                            if (cart[p.id] != null)
                                              Text(
                                                'x${cart[p.id]!.qty}',
                                                style: const TextStyle(fontWeight: FontWeight.w900),
                                              ),
                                          ],
                                        ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        AnimatedBuilder(
                          animation: c,
                          builder: (context, child) {
                            if (!c.busy) return const SizedBox.shrink();
                            return Container(
                              color: Colors.black.withAlpha(20),
                              child: const Center(child: CircularProgressIndicator()),
                            );
                          },
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openCart(BuildContext context, ProductController c) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        final items = cart.values.toList();
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + MediaQuery.of(context).padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Panier', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Ton panier est vide.'),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (context, index) => const Divider(height: 16),
                    itemBuilder: (_, i) {
                      final it = items[i];
                      return Row(
                        children: [
                          Expanded(
                            child: Text(
                              it.product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          IconButton(
                            onPressed: () => removeFromCart(it.product),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text('${it.qty}', style: const TextStyle(fontWeight: FontWeight.w900)),
                          IconButton(
                            onPressed: () => addToCart(it.product),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${(it.product.price * it.qty).toStringAsFixed(2)} ${it.product.currency}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total: ${total.toStringAsFixed(2)} EUR',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                  FilledButton(
                    onPressed: items.isEmpty
                        ? null
                        : () async {
                            try {
                              final orderId = await c.commerceRepo.checkoutCreateOrder(
                                shopId: widget.shopId,
                                userId: widget.userId,
                                items: items,
                              );
                              if (!context.mounted) return;
                              setState(() => cart.clear());
                              Navigator.pop(context);
                              TopSnackBar.show(
                                context,
                                SnackBar(content: Text('Commande créée: $orderId')),
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              TopSnackBar.show(
                                context,
                                SnackBar(content: Text('Checkout impossible: $e')),
                              );
                            }
                          },
                    child: const Text('Commander'),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------------------------
// 6) SMALL UI HELPERS (chips, buttons, dialogs, provider-lite)
// ------------------------------------------------------------------------------

class _CartIconWithBadge extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;
  const _CartIconWithBadge({required this.count, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onTap,
          icon: const Icon(Icons.shopping_bag_outlined),
        ),
        if (count > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }
}

class _FilterTile extends StatelessWidget {
  final String label;
  final bool active;
  final IconData icon;
  final VoidCallback onTap;

  const _FilterTile({
    required this.label,
    required this.active,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active ? Colors.black : const Color(0xFFF6F7FB);
    final fg = active ? Colors.white : Colors.black87;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? Colors.black : const Color(0xFFE9ECF3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SmallAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F7FB),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE9ECF3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final bool filled;
  const _Pill({required this.text, required this.filled});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? Colors.black : const Color(0xFFF6F7FB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: filled ? Colors.black : const Color(0xFFE9ECF3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: filled ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _StockBadge {
  final String label;
  final bool filled;
  const _StockBadge({required this.label, required this.filled});
}

// --- Menus / dialogs helpers ---

class _MenuItem<T> {
  final T value;
  final String label;
  const _MenuItem({required this.value, required this.label});
}

Future<T?> _pickFromMenu<T>(
  BuildContext context, {
  required String title,
  required List<_MenuItem<T>> items,
  required T initial,
}) async {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final it = items[i];
                    final selected = it.value == initial;
                    return ListTile(
                      title: Text(it.label, style: const TextStyle(fontWeight: FontWeight.w800)),
                      trailing: selected ? const Icon(Icons.check) : null,
                      onTap: () => Navigator.pop(context, it.value),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<bool> _confirm(BuildContext context, {required String title, required String message}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('OK')),
      ],
    ),
  );
  return res ?? false;
}

class _TextPromptDialog extends StatefulWidget {
  final String title;
  final String hint;
  final String initial;

  const _TextPromptDialog({required this.title, required this.hint, required this.initial});

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController ctrl;
  @override
  void initState() {
    super.initState();
    ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: Text(widget.title),
      content: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          hintText: widget.hint,
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.blue.withValues(alpha: 0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.blue, width: 2),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      actions: [
        TextButton(style: TextButton.styleFrom(foregroundColor: Colors.blue), onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(context, ctrl.text),
          child: const Text('Appliquer'),
        ),
      ],
    );
  }
}

class _PriceRange {
  final double? min;
  final double? max;
  const _PriceRange({this.min, this.max});
}

class _PriceRangeDialog extends StatefulWidget {
  final double? initialMin;
  final double? initialMax;
  const _PriceRangeDialog({this.initialMin, this.initialMax});

  @override
  State<_PriceRangeDialog> createState() => _PriceRangeDialogState();
}

class _PriceRangeDialogState extends State<_PriceRangeDialog> {
  late final TextEditingController minCtrl;
  late final TextEditingController maxCtrl;

  @override
  void initState() {
    super.initState();
    minCtrl = TextEditingController(text: widget.initialMin?.toStringAsFixed(2) ?? '');
    maxCtrl = TextEditingController(text: widget.initialMax?.toStringAsFixed(2) ?? '');
  }

  @override
  void dispose() {
    minCtrl.dispose();
    maxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final decor = InputDecoration(
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.blue.withAlpha(77)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.blue, width: 2),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: const Text('Prix'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: minCtrl,
            keyboardType: TextInputType.number,
            decoration: decor.copyWith(labelText: 'Min'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: maxCtrl,
            keyboardType: TextInputType.number,
            decoration: decor.copyWith(labelText: 'Max'),
          ),
        ],
      ),
      actions: [
        TextButton(style: TextButton.styleFrom(foregroundColor: Colors.blue), onPressed: () => Navigator.pop(context, const _PriceRange()), child: const Text('Reset')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
          onPressed: () {
            final min = double.tryParse(minCtrl.text.replaceAll(',', '.').trim());
            final max = double.tryParse(maxCtrl.text.replaceAll(',', '.').trim());
            Navigator.pop(context, _PriceRange(min: min, max: max));
          },
          child: const Text('Appliquer'),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------------------
// 7) MINI Provider Lite (pour éviter une dépendance provider)
// ------------------------------------------------------------------------------

class ChangeNotifierProviderLite extends InheritedNotifier<ChangeNotifier> {
  const ChangeNotifierProviderLite({
    super.key,
    required ChangeNotifier super.notifier,
    required super.child,
  });

  static T of<T extends ChangeNotifier>(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<ChangeNotifierProviderLite>();
    if (w == null) throw Exception('ChangeNotifierProviderLite not found');
    final n = w.notifier;
    if (n == null) throw Exception('ChangeNotifierProviderLite notifier is null');
    return n as T;
  }
}

// ------------------------------------------------------------------------------
// ✅ HOW TO USE
// ------------------------------------------------------------------------------
//
// 1) Dans ton app, appelle:
//    Navigator.push(context, MaterialPageRoute(
//      builder: (_) => ProductManagementPage(shopId: "YOUR_SHOP_ID"),
//    ));
//
// 2) Pour la boutique (public):
//    Navigator.push(context, MaterialPageRoute(
//      builder: (_) => BoutiquePage(shopId: "YOUR_SHOP_ID", userId: "USER_ID"),
//    ));
//
// 3) IMPORTANT: initialise Firebase dans main.dart:
//    await Firebase.initializeApp();
//
// 4) (optionnel) Crée 1..n catégories dans:
//    shops/{shopId}/categories/{categoryId} { name, sortOrder, isActive }
//
// ------------------------------------------------------------------------------
