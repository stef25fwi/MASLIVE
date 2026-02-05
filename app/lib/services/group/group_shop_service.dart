// Service de gestion boutique groupe
// CRUD produits et médias avec upload Storage
// ✅ Utilise maintenant StorageService centralisé

import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/group_product.dart';
import '../../models/group_media.dart';
import '../storage_service.dart';

class GroupShopService {
  static final GroupShopService instance = GroupShopService._();
  GroupShopService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final StorageService _storageService = StorageService.instance;

  // ========== PRODUITS ==========

  // Crée un produit
  // ✅ Upload via StorageService avec structure organisée: groups/{groupId}/products/{productId}
  Future<GroupShopProduct> createProduct({
    required String adminGroupId,
    required String title,
    required String description,
    required double price,
    String currency = 'EUR',
    required int stock,
    required List<XFile> photoFiles,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utilisateur non connecté');
    }

    // Créer l'ID produit d'abord
    final productRef = _firestore
        .collection('group_shops')
        .doc(adminGroupId)
        .collection('products')
        .doc();

    // Upload photos via StorageService
    final photoUrls = await _storageService.uploadGroupProductPhotos(
      groupId: adminGroupId,
      productId: productRef.id,
      files: photoFiles,
    );

    final now = DateTime.now();
    final product = GroupShopProduct(
      id: productRef.id,
      adminGroupId: adminGroupId,
      title: title,
      description: description,
      price: price,
      currency: currency,
      stock: stock,
      photoUrls: photoUrls,
      isVisible: true,
      createdAt: now,
      updatedAt: now,
    );

    await productRef.set(product.toFirestore());
    return product;
  }

  // Met à jour un produit
  Future<void> updateProduct({
    required String adminGroupId,
    required String productId,
    String? title,
    String? description,
    double? price,
    int? stock,
    bool? isVisible,
  }) async {
    final updates = <String, dynamic>{};
    
    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (price != null) updates['price'] = price;
    if (stock != null) updates['stock'] = stock;
    if (isVisible != null) updates['isVisible'] = isVisible;
    
    updates['updatedAt'] = FieldValue.serverTimestamp();

    await _firestore
        .collection('group_shops')
        .doc(adminGroupId)
        .collection('products')
        .doc(productId)
        .update(updates);
  }

  // Supprime un produit
  // ✅ Utilise StorageService pour supprimer les photos
  Future<void> deleteProduct(String adminGroupId, String productId) async {
    // Supprime le dossier Storage via StorageService
    await _storageService.deleteGroupProduct(
      groupId: adminGroupId,
      productId: productId,
    );

    // Supprime le document Firestore
    await _firestore
        .collection('group_shops')
        .doc(adminGroupId)
        .collection('products')
        .doc(productId)
        .delete();
  }

  // Stream des produits
  Stream<List<GroupShopProduct>> streamProducts(String adminGroupId) {
    return _firestore
        .collection('group_shops')
        .doc(adminGroupId)
        .collection('products')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GroupShopProduct.fromFirestore(doc))
            .toList());
  }

  // Stream des produits visibles
  Stream<List<GroupShopProduct>> streamVisibleProducts(String adminGroupId) {
    return _firestore
        .collection('group_shops')
        .doc(adminGroupId)
        .collection('products')
        .where('isVisible', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GroupShopProduct.fromFirestore(doc))
            .toList());
  }

  // ========== MÉDIAS ==========

  // Crée un média
  // ✅ Upload via StorageService avec structure: groups/{groupId}/media/{mediaId}
  Future<GroupMedia> createMedia({
    required String adminGroupId,
    required XFile mediaFile,
    required String type, // "image" ou "video"
    String? title,
    Map<String, dynamic>? tags,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Utilisateur non connecté');
    }

    // Créer l'ID média d'abord
    final mediaRef = _firestore
        .collection('group_shops')
        .doc(adminGroupId)
        .collection('media')
        .doc();

    // Upload via StorageService (utilise structure groups/{groupId}/media/{mediaId}/original/)
    // Note: createMedia n'est pas spécifique aux groupes dans StorageService,
    // donc on emprunte uploadMediaFile mais avec la structure groups
    final url = await _storageService.uploadMediaFile(
      mediaId: mediaRef.id,
      file: mediaFile,
      scopeId: adminGroupId,
    );

    final now = DateTime.now();
    final media = GroupMedia(
      id: mediaRef.id,
      adminGroupId: adminGroupId,
      url: url,
      type: type,
      title: title,
      tags: tags ?? {},
      isVisible: true,
      createdAt: now,
      updatedAt: now,
    );

    await mediaRef.set(media.toFirestore());

    // Écriture miroir dans le shop public + fiche shop minimale
    // On utilise adminGroupId comme shopId pour garder une correspondance simple.
    try {
      final shopRef = _firestore.collection('shops').doc(adminGroupId);

      // Fiche shop minimale (type group)
      await shopRef.set({
        'ownerUid': user.uid,
        'type': 'group',
        'isActive': true,
        'groupId': adminGroupId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Média miroir dans shops/{shopId}/media/{mediaId}
      final path = 'media/$adminGroupId/${mediaRef.id}/original/media.${type == "video" ? "mp4" : "jpg"}';
      await shopRef
          .collection('media')
          .doc(media.id)
          .set({
        'shopId': adminGroupId,
        'type': type == 'video' ? 'video' : 'photo',
        'url': url,
        'storagePath': path,
        'thumbUrl': null,
        'status': 'published',
        'isVisible': true,
        // Filtres optionnels (remplis plus tard si besoin)
        'countryCode': null,
        'eventId': null,
        'circuitId': null,
        'takenAt': null,
        'locationGeo': null,
        'locationName': null,
        'photographerId': user.uid,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });
    } catch (_) {
      // En cas d'erreur, on ne casse pas le flux historique group_shops
    }

    return media;
  }

  // Met à jour un média
  Future<void> updateMedia({
    required String adminGroupId,
    required String mediaId,
    String? title,
    Map<String, dynamic>? tags,
    bool? isVisible,
  }) async {
    final updates = <String, dynamic>{};
    
    if (title != null) updates['title'] = title;
    if (tags != null) updates['tags'] = tags;
    if (isVisible != null) updates['isVisible'] = isVisible;
    
    updates['updatedAt'] = FieldValue.serverTimestamp();

    await _firestore
        .collection('group_shops')
        .doc(adminGroupId)
        .collection('media')
        .doc(mediaId)
        .update(updates);
    // Miroir dans shops/{shopId}/media/{mediaId}
    try {
      final mirrorUpdates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (isVisible != null) {
        mirrorUpdates['isVisible'] = isVisible;
      }

      if (mirrorUpdates.isNotEmpty) {
        await _firestore
            .collection('shops')
            .doc(adminGroupId)
            .collection('media')
            .doc(mediaId)
            .update(mirrorUpdates);
      }
    } catch (_) {
      // best effort
    }
  }

  // Supprime un média
  Future<void> deleteMedia(String adminGroupId, String mediaId) async {
    final doc = await _firestore
        .collection('group_shops')
        .doc(adminGroupId)
        .collection('media')
        .doc(mediaId)
        .get();

    if (doc.exists) {
      final media = GroupMedia.fromFirestore(doc);
      
      // Supprime le fichier du Storage
      try {
        final ref = _storage.refFromURL(media.url);
        await ref.delete();
      } catch (e) {
        // Ignore si déjà supprimé
      }
    }

    await doc.reference.delete();
    // Supprime aussi le miroir dans shops/{shopId}/media
    try {
      await _firestore
          .collection('shops')
          .doc(adminGroupId)
          .collection('media')
          .doc(mediaId)
          .delete();
    } catch (_) {
      // ignore
    }
  }

  // Stream des médias
  Stream<List<GroupMedia>> streamMedia(String adminGroupId) {
    return _firestore
        .collection('group_shops')
        .doc(adminGroupId)
        .collection('media')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GroupMedia.fromFirestore(doc))
            .toList());
  }

  // Stream des médias visibles
  Stream<List<GroupMedia>> streamVisibleMedia(String adminGroupId) {
    return _firestore
        .collection('group_shops')
        .doc(adminGroupId)
        .collection('media')
        .where('isVisible', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GroupMedia.fromFirestore(doc))
            .toList());
  }
}
