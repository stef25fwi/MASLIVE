import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/commerce_submission.dart';
import '../storage_service.dart';

/// Service de gestion des soumissions commerce (produits et médias)
class CommerceService {
  static final CommerceService instance = CommerceService._internal();
  CommerceService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final StorageService _storageService = StorageService.instance;

  /// Collection des soumissions
  CollectionReference<Map<String, dynamic>> get _submissions =>
      _firestore.collection('commerce_submissions');

  /// Utilisateur actuel
  User? get _currentUser => _auth.currentUser;

  /// Créer une soumission brouillon
  Future<String> createDraftSubmission({
    required SubmissionType type,
    required OwnerRole ownerRole,
    required ScopeType scopeType,
    required String scopeId,
    String title = '',
    String description = '',
    List<String> mediaUrls = const [],
    String? thumbUrl,
    // Champs produit
    double? price,
    String? currency,
    int? stock,
    bool? isActive,
    // Champs media
    MediaType? mediaType,
    DateTime? takenAt,
    GeoPoint? location,
    String? photographer,
  }) async {
    final user = _currentUser;
    if (user == null) throw Exception('User not authenticated');

    final now = FieldValue.serverTimestamp();
    final submission = <String, dynamic>{
      'type': type.toJson(),
      'status': SubmissionStatus.draft.toJson(),
      'ownerUid': user.uid,
      'ownerRole': ownerRole.toJson(),
      'scopeType': scopeType.toJson(),
      'scopeId': scopeId,
      'title': title,
      'description': description,
      'mediaUrls': mediaUrls,
      'thumbUrl': thumbUrl,
      'createdAt': now,
      'updatedAt': now,
    };

    if (type == SubmissionType.product) {
      submission['price'] = price ?? 0.0;
      submission['currency'] = currency ?? 'EUR';
      submission['stock'] = stock ?? 0;
      submission['isActive'] = isActive ?? true;
    }

    if (type == SubmissionType.media) {
      submission['mediaType'] = mediaType?.toJson() ?? 'photo';
      if (takenAt != null) submission['takenAt'] = Timestamp.fromDate(takenAt);
      if (location != null) submission['location'] = location;
      if (photographer != null) submission['photographer'] = photographer;
    }

    final doc = await _submissions.add(submission);
    return doc.id;
  }

  /// Mettre à jour une soumission
  Future<void> updateSubmission(
    String submissionId,
    Map<String, dynamic> updates,
  ) async {
    final user = _currentUser;
    if (user == null) throw Exception('User not authenticated');

    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _submissions.doc(submissionId).update(updates);
  }

  /// Soumettre pour validation
  Future<void> submitForReview(String submissionId) async {
    final user = _currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _submissions.doc(submissionId).update({
      'status': SubmissionStatus.pending.toJson(),
      'submittedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Supprimer une soumission (uniquement draft ou rejected)
  Future<void> deleteSubmission(String submissionId) async {
    final user = _currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Récupérer la soumission pour vérifier le statut
    final doc = await _submissions.doc(submissionId).get();
    if (!doc.exists) throw Exception('Submission not found');

    final submission = CommerceSubmission.fromFirestore(doc);
    if (!submission.canEdit) {
      throw Exception('Cannot delete submission in status: ${submission.status}');
    }

    if (submission.ownerUid != user.uid) {
      throw Exception('Not authorized to delete this submission');
    }

    // Supprimer les fichiers Storage
    await _deleteStorageFolder(submission.scopeId, user.uid, submissionId);

    // Supprimer le document
    await _submissions.doc(submissionId).delete();
  }

  /// Supprimer le dossier Storage d'une soumission
  Future<void> _deleteStorageFolder(
    String scopeId,
    String ownerUid,
    String submissionId,
  ) async {
    try {
      final folderRef = _storage.ref('commerce/$scopeId/$ownerUid/$submissionId');
      final result = await folderRef.listAll();

      // Supprimer tous les fichiers
      for (final item in result.items) {
        await item.delete();
      }

      // Supprimer les sous-dossiers récursivement
      for (final prefix in result.prefixes) {
        await _deleteStorageFolderRecursive(prefix);
      }
    } catch (e) {
      // Ignorer si le dossier n'existe pas
    }
  }

  Future<void> _deleteStorageFolderRecursive(Reference folderRef) async {
    final result = await folderRef.listAll();

    for (final item in result.items) {
      await item.delete();
    }

    for (final prefix in result.prefixes) {
      await _deleteStorageFolderRecursive(prefix);
    }
  }

  /// Uploader des fichiers média
  /// ✅ Utilise maintenant StorageService avec structure organisée
  Future<List<String>> uploadMediaFiles({
    required String scopeId,
    required String submissionId,
    required List<File> files,
    void Function(double progress)? onProgress,
  }) async {
    // Convertit File en XFile pour utiliser StorageService
    final xfiles = files.map((f) => XFile(f.path)).toList();
    
    return await _storageService.uploadMediaFiles(
      mediaId: submissionId,
      files: xfiles,
      scopeId: scopeId,
      onProgress: onProgress,
    );
  }

  /// Uploader depuis bytes (web)
  /// ✅ Utilise maintenant StorageService avec structure organisée
  Future<String> uploadMediaBytes({
    required String scopeId,
    required String submissionId,
    required List<int> bytes,
    required String filename,
    void Function(double progress)? onProgress,
  }) async {
    // Crée XFile depuis bytes pour web
    final xfile = XFile.fromData(
      Uint8List.fromList(bytes),
      name: filename,
      mimeType: 'image/jpeg',
    );
    
    return await _storageService.uploadMediaFile(
      mediaId: submissionId,
      file: xfile,
      scopeId: scopeId,
      onProgress: onProgress,
    );
  }

  /// Regarder mes soumissions
  Stream<List<CommerceSubmission>> watchMySubmissions({
    SubmissionStatus? status,
  }) {
    final user = _currentUser;
    if (user == null) return Stream.value([]);

    Query<Map<String, dynamic>> query = _submissions
        .where('ownerUid', isEqualTo: user.uid)
        .orderBy('updatedAt', descending: true);

    if (status != null) {
      query = _submissions
          .where('ownerUid', isEqualTo: user.uid)
          .where('status', isEqualTo: status.toJson())
          .orderBy('updatedAt', descending: true);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => CommerceSubmission.fromFirestore(doc))
          .toList();
    });
  }

  /// Regarder les soumissions en attente (modération)
  Stream<List<CommerceSubmission>> watchPendingSubmissions({
    SubmissionType? type,
    ScopeType? scopeType,
    String? scopeId,
  }) {
    Query<Map<String, dynamic>> query = _submissions
        .where('status', isEqualTo: SubmissionStatus.pending.toJson())
        .orderBy('submittedAt', descending: true);

    if (type != null) {
      query = _submissions
          .where('status', isEqualTo: SubmissionStatus.pending.toJson())
          .where('type', isEqualTo: type.toJson())
          .orderBy('submittedAt', descending: true);
    }

    if (scopeType != null) {
      query = _submissions
          .where('status', isEqualTo: SubmissionStatus.pending.toJson())
          .where('scopeType', isEqualTo: scopeType.toJson())
          .orderBy('submittedAt', descending: true);
    }

    if (scopeId != null && scopeId.isNotEmpty) {
      query = _submissions
          .where('status', isEqualTo: SubmissionStatus.pending.toJson())
          .where('scopeId', isEqualTo: scopeId)
          .orderBy('submittedAt', descending: true);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => CommerceSubmission.fromFirestore(doc))
          .toList();
    });
  }

  /// Approuver une soumission (via Cloud Function)
  Future<void> approve(String submissionId) async {
    final user = _currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      final callable = _functions.httpsCallable('approveCommerceSubmission');
      await callable.call({'submissionId': submissionId});
    } catch (e) {
      throw Exception('Failed to approve submission: $e');
    }
  }

  /// Refuser une soumission (via Cloud Function)
  Future<void> reject(String submissionId, String note) async {
    final user = _currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      final callable = _functions.httpsCallable('rejectCommerceSubmission');
      await callable.call({
        'submissionId': submissionId,
        'note': note,
      });
    } catch (e) {
      throw Exception('Failed to reject submission: $e');
    }
  }

  /// Récupérer une soumission par ID
  Future<CommerceSubmission?> getSubmission(String submissionId) async {
    final doc = await _submissions.doc(submissionId).get();
    if (!doc.exists) return null;
    return CommerceSubmission.fromFirestore(doc);
  }

  /// Stream d'une soumission
  Stream<CommerceSubmission?> watchSubmission(String submissionId) {
    return _submissions.doc(submissionId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return CommerceSubmission.fromFirestore(doc);
    });
  }

  /// Vérifier si l'utilisateur peut modérer
  Future<bool> canModerate({String? scopeId}) async {
    final user = _currentUser;
    if (user == null) return false;

    // Récupérer le profil utilisateur
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) return false;

    final data = userDoc.data()!;
    final role = data['role'] as String?;
    final isAdmin = data['isAdmin'] as bool? ?? false;

    // SuperAdmin peut tout modérer
    if (isAdmin || role == 'admin' || role == 'superadmin') {
      return true;
    }

    // Admin groupe peut modérer uniquement son scope
    if (role == 'admin_groupe' && scopeId != null) {
      final managedScopeIds = (data['managedScopeIds'] as List<dynamic>?)?.cast<String>();
      return managedScopeIds?.contains(scopeId) ?? false;
    }

    return false;
  }

  /// Récupérer le rôle de l'utilisateur actuel
  Future<OwnerRole?> getCurrentUserRole() async {
    final user = _currentUser;
    if (user == null) return null;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) return null;

    final data = userDoc.data()!;
    final role = data['role'] as String?;
    final accountType = data['accountType'] as String?;
    final activities = (data['activities'] as List<dynamic>?)?.cast<String>();

    // Déterminer le rôle owner
    if (role == 'superadmin' || (data['isAdmin'] as bool? ?? false)) {
      return OwnerRole.superadmin;
    }

    if (role == 'admin_groupe') {
      return OwnerRole.adminGroupe;
    }

    if (accountType == 'pro') {
      if (activities?.contains('createur_digital') == true) {
        return OwnerRole.createurDigital;
      }
      return OwnerRole.comptePro;
    }

    return null; // L'utilisateur ne peut pas soumettre
  }

  /// Vérifier si l'utilisateur peut soumettre du commerce
  Future<bool> canSubmitCommerce() async {
    final role = await getCurrentUserRole();
    return role != null;
  }
}
