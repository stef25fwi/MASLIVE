import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Service centralisé de gestion du stockage Firebase Storage
/// 
/// Structure organisée :
/// - products/{shopId}/{productId}/original/{index}.jpg
/// - media/{scopeId}/{mediaId}/original/media.jpg
/// - articles/{articleId}/original/cover.jpg
/// - groups/{groupId}/products/{productId}/original/{index}.jpg
/// - users/{userId}/avatar/original.jpg
/// 
/// Voir STORAGE_STRUCTURE.md pour la documentation complète
class StorageService {
  static final StorageService instance = StorageService._internal();
  StorageService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get _currentUser => _auth.currentUser;

  // ========== PRODUITS ==========

  /// Upload photos d'un produit (boutique)
  /// 
  /// Retourne la liste des URLs des photos uploadées
  Future<List<String>> uploadProductPhotos({
    required String productId,
    required List<XFile> files,
    String shopId = 'global',
    void Function(double progress)? onProgress,
  }) async {
    if (files.isEmpty) return [];
    
    final urls = <String>[];
    final totalFiles = files.length;

    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final path = 'products/$shopId/$productId/original/$i.jpg';
      
      final url = await _uploadFile(
        file: file,
        path: path,
        category: 'product',
        parentId: productId,
        parentType: 'product',
        onProgress: (fileProgress) {
          final totalProgress = (i + fileProgress) / totalFiles;
          onProgress?.call(totalProgress);
        },
      );
      
      urls.add(url);
    }

    return urls;
  }

  /// Upload une seule photo de produit
  Future<String> uploadProductPhoto({
    required String productId,
    required XFile file,
    String shopId = 'global',
    int index = 0,
    void Function(double progress)? onProgress,
  }) async {
    final path = 'products/$shopId/$productId/original/$index.jpg';
    
    return await _uploadFile(
      file: file,
      path: path,
      category: 'product',
      parentId: productId,
      parentType: 'product',
      onProgress: onProgress,
    );
  }

  /// Supprime toutes les photos d'un produit
  Future<void> deleteProductPhotos({
    required String productId,
    String shopId = 'global',
  }) async {
    final folderRef = _storage.ref('products/$shopId/$productId');
    await _deleteFolder(folderRef);
  }

  // ========== MÉDIAS ==========

  /// Upload médias (photos/vidéos) pour galerie/instagram
  Future<List<String>> uploadMediaFiles({
    required String mediaId,
    required List<XFile> files,
    String scopeId = 'global',
    void Function(double progress)? onProgress,
  }) async {
    if (files.isEmpty) return [];
    
    final urls = <String>[];
    final totalFiles = files.length;

    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final ext = _getExtension(file.name);
      final path = 'media/$scopeId/$mediaId/original/media_$i.$ext';
      
      final url = await _uploadFile(
        file: file,
        path: path,
        category: 'media',
        parentId: mediaId,
        parentType: 'media',
        onProgress: (fileProgress) {
          final totalProgress = (i + fileProgress) / totalFiles;
          onProgress?.call(totalProgress);
        },
      );
      
      urls.add(url);
    }

    return urls;
  }

  /// Upload un seul média
  Future<String> uploadMediaFile({
    required String mediaId,
    required XFile file,
    String scopeId = 'global',
    void Function(double progress)? onProgress,
  }) async {
    final ext = _getExtension(file.name);
    final path = 'media/$scopeId/$mediaId/original/media.$ext';
    
    return await _uploadFile(
      file: file,
      path: path,
      category: 'media',
      parentId: mediaId,
      parentType: 'media',
      onProgress: onProgress,
    );
  }

  /// Supprime tous les médias
  Future<void> deleteMediaFiles({
    required String mediaId,
    String scopeId = 'global',
  }) async {
    final folderRef = _storage.ref('media/$scopeId/$mediaId');
    await _deleteFolder(folderRef);
  }

  // ========== ARTICLES ==========

  /// Upload image de couverture d'article
  Future<String> uploadArticleCover({
    required String articleId,
    required XFile file,
    void Function(double progress)? onProgress,
  }) async {
    final path = 'articles/$articleId/original/cover.jpg';
    
    return await _uploadFile(
      file: file,
      path: path,
      category: 'article',
      parentId: articleId,
      parentType: 'article',
      onProgress: onProgress,
    );
  }

  /// Upload images du contenu d'article
  Future<List<String>> uploadArticleContentImages({
    required String articleId,
    required List<XFile> files,
    void Function(double progress)? onProgress,
  }) async {
    if (files.isEmpty) return [];
    
    final urls = <String>[];
    final totalFiles = files.length;

    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final path = 'articles/$articleId/original/content_$i.jpg';
      
      final url = await _uploadFile(
        file: file,
        path: path,
        category: 'article',
        parentId: articleId,
        parentType: 'article',
        onProgress: (fileProgress) {
          final totalProgress = (i + fileProgress) / totalFiles;
          onProgress?.call(totalProgress);
        },
      );
      
      urls.add(url);
    }

    return urls;
  }

  /// Supprime tous les médias d'un article
  Future<void> deleteArticleMedia({required String articleId}) async {
    final folderRef = _storage.ref('articles/$articleId');
    await _deleteFolder(folderRef);
  }

  // ========== GROUPES ==========

  /// Upload avatar de groupe
  Future<String> uploadGroupAvatar({
    required String groupId,
    required XFile file,
    void Function(double progress)? onProgress,
  }) async {
    final path = 'groups/$groupId/avatar/original.jpg';
    
    return await _uploadFile(
      file: file,
      path: path,
      category: 'avatar',
      parentId: groupId,
      parentType: 'group',
      onProgress: onProgress,
    );
  }

  /// Upload banner de groupe
  Future<String> uploadGroupBanner({
    required String groupId,
    required XFile file,
    void Function(double progress)? onProgress,
  }) async {
    final path = 'groups/$groupId/banner/banner.jpg';
    
    return await _uploadFile(
      file: file,
      path: path,
      category: 'banner',
      parentId: groupId,
      parentType: 'group',
      onProgress: onProgress,
    );
  }

  /// Upload photos d'un produit de groupe
  Future<List<String>> uploadGroupProductPhotos({
    required String groupId,
    required String productId,
    required List<XFile> files,
    void Function(double progress)? onProgress,
  }) async {
    if (files.isEmpty) return [];
    
    final urls = <String>[];
    final totalFiles = files.length;

    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final path = 'groups/$groupId/products/$productId/original/${i + 1}.jpg';
      
      final url = await _uploadFile(
        file: file,
        path: path,
        category: 'product',
        parentId: productId,
        parentType: 'group',
        onProgress: (fileProgress) {
          final totalProgress = (i + fileProgress) / totalFiles;
          onProgress?.call(totalProgress);
        },
      );
      
      urls.add(url);
    }

    return urls;
  }

  /// Supprime produit d'un groupe
  Future<void> deleteGroupProduct({
    required String groupId,
    required String productId,
  }) async {
    final folderRef = _storage.ref('groups/$groupId/products/$productId');
    await _deleteFolder(folderRef);
  }

  // ========== UTILISATEURS ==========

  /// Upload avatar utilisateur
  Future<String> uploadUserAvatar({
    required XFile file,
    void Function(double progress)? onProgress,
  }) async {
    final user = _currentUser;
    if (user == null) throw Exception('User not authenticated');
    
    final path = 'users/${user.uid}/avatar/original.jpg';
    
    return await _uploadFile(
      file: file,
      path: path,
      category: 'avatar',
      parentId: user.uid,
      parentType: 'user',
      onProgress: onProgress,
    );
  }

  /// Upload fichier utilisateur générique
  Future<String> uploadUserFile({
    required XFile file,
    required String filename,
    void Function(double progress)? onProgress,
  }) async {
    final user = _currentUser;
    if (user == null) throw Exception('User not authenticated');
    
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'users/${user.uid}/uploads/${timestamp}_$filename';
    
    return await _uploadFile(
      file: file,
      path: path,
      category: 'upload',
      parentId: user.uid,
      parentType: 'user',
      onProgress: onProgress,
    );
  }

  // ========== MÉTHODES INTERNES ==========

  /// Upload un fichier avec métadonnées
  Future<String> _uploadFile({
    required XFile file,
    required String path,
    required String category,
    required String parentId,
    required String parentType,
    void Function(double progress)? onProgress,
  }) async {
    final user = _currentUser;
    if (user == null) throw Exception('User not authenticated');

    final ref = _storage.ref(path);
    
    // Métadonnées
    final metadata = SettableMetadata(
      contentType: _getContentType(file.name),
      customMetadata: {
        'uploadedBy': user.uid,
        'uploadedAt': DateTime.now().toIso8601String(),
        'originalName': file.name,
        'category': category,
        'parentId': parentId,
        'parentType': parentType,
      },
    );

    UploadTask uploadTask;

    if (kIsWeb) {
      // Web: utiliser bytes
      final bytes = await file.readAsBytes();
      uploadTask = ref.putData(bytes, metadata);
    } else {
      // Mobile: utiliser File
      final ioFile = File(file.path);
      uploadTask = ref.putFile(ioFile, metadata);
    }

    // Surveiller progression
    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress(progress);
      });
    }

    await uploadTask;
    return await ref.getDownloadURL();
  }

  /// Supprime un dossier récursivement
  Future<void> _deleteFolder(Reference folderRef) async {
    try {
      final result = await folderRef.listAll();

      // Supprimer tous les fichiers
      for (final item in result.items) {
        await item.delete();
      }

      // Supprimer les sous-dossiers récursivement
      for (final prefix in result.prefixes) {
        await _deleteFolder(prefix);
      }
    } catch (e) {
      // Ignorer si le dossier n'existe pas
    }
  }

  /// Détermine le type de contenu
  String _getContentType(String filename) {
    final ext = _getExtension(filename).toLowerCase();
    
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      default:
        return 'application/octet-stream';
    }
  }

  /// Extrait l'extension d'un nom de fichier
  String _getExtension(String filename) {
    final parts = filename.split('.');
    return parts.length > 1 ? parts.last : 'jpg';
  }

  // ========== UTILITAIRES ==========

  /// Obtient l'URL depuis une référence Storage
  Future<String?> getDownloadUrl(String path) async {
    try {
      final ref = _storage.ref(path);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  /// Vérifie si un fichier existe
  Future<bool> fileExists(String path) async {
    try {
      final ref = _storage.ref(path);
      await ref.getMetadata();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Liste les fichiers d'un répertoire
  Future<List<String>> listFiles(String path) async {
    try {
      final ref = _storage.ref(path);
      final result = await ref.listAll();
      
      final urls = <String>[];
      for (final item in result.items) {
        final url = await item.getDownloadURL();
        urls.add(url);
      }
      
      return urls;
    } catch (e) {
      return [];
    }
  }
}
