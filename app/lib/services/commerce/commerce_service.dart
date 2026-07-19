import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/commerce_submission.dart';
import '../../security/role_normalizer.dart';
import '../storage_service.dart';
import 'seller_publication_readiness_service.dart';

/// Service de gestion des soumissions commerce (produits et médias).
class CommerceService {
  static final CommerceService instance = CommerceService._internal();
  CommerceService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final StorageService _storageService = StorageService.instance;

  CollectionReference<Map<String, dynamic>> get _submissions =>
      _firestore.collection('commerce_submissions');

  User? get _currentUser => _auth.currentUser;

  Future<String> createDraftSubmission({
    required SubmissionType type,
    required OwnerRole ownerRole,
    required ScopeType scopeType,
    required String scopeId,
    String title = '',
    String description = '',
    List<String> mediaUrls = const [],
    String? thumbUrl,
    double? price,
    String? currency,
    int? stock,
    bool? isActive,
    MediaType? mediaType,
    DateTime? takenAt,
    GeoPoint? location,
    String? photographer,
    String? countryId,
    String? countryName,
    String? eventId,
    String? eventName,
    String? circuitId,
    String? circuitName,
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
      submission['price'] = price;
      submission['currency'] = currency ?? 'EUR';
      submission['mediaType'] = mediaType?.toJson() ?? 'photo';
      if (takenAt != null) submission['takenAt'] = Timestamp.fromDate(takenAt);
      if (location != null) submission['location'] = location;
      if (photographer != null) submission['photographer'] = photographer;
      if (countryId != null) submission['countryId'] = countryId;
      if (countryName != null) submission['countryName'] = countryName;
      if (eventId != null) submission['eventId'] = eventId;
      if (eventName != null) submission['eventName'] = eventName;
      if (circuitId != null) submission['circuitId'] = circuitId;
      if (circuitName != null) submission['circuitName'] = circuitName;
    }

    final doc = await _submissions.add(submission);
    return doc.id;
  }

  Future<void> updateSubmission(
    String submissionId,
    Map<String, dynamic> updates,
  ) async {
    final user = _currentUser;
    if (user == null) throw Exception('User not authenticated');
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _submissions.doc(submissionId).update(updates);
  }

  Future<void> submitForReview(String submissionId) async {
    final user = _currentUser;
    if (user == null) throw Exception('User not authenticated');

    final doc = await _submissions.doc(submissionId).get();
    if (!doc.exists) throw Exception('Submission not found');

    final submission = CommerceSubmission.fromFirestore(doc);
    if (submission.ownerUid != user.uid) {
      throw Exception('Not authorized to submit this publication');
    }

    if (submission.isMedia) {
      final hasSelection =
          (submission.countryId?.trim().isNotEmpty ?? false) &&
          (submission.eventId?.trim().isNotEmpty ?? false) &&
          (submission.circuitId?.trim().isNotEmpty ?? false);
      if (!hasSelection) {
        throw Exception(
          'Pays, evenement et circuit sont obligatoires pour un media',
        );
      }
      if ((submission.price ?? 0) <= 0) {
        throw Exception('Le prix photo doit etre superieur a 0');
      }
    }

    final readiness = await SellerPublicationReadinessService.instance.check(
      ownerRole: submission.ownerRole,
    );
    if (!readiness.canPublish) {
      throw StateError(readiness.message);
    }

    await _submissions.doc(submissionId).update({
      'status': SubmissionStatus.pending.toJson(),
      'submittedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteSubmission(String submissionId) async {
    final user = _currentUser;
    if (user == null) throw Exception('User not authenticated');

    final doc = await _submissions.doc(submissionId).get();
    if (!doc.exists) throw Exception('Submission not found');

    final submission = CommerceSubmission.fromFirestore(doc);
    if (!submission.canEdit) {
      throw Exception('Cannot delete submission in status: ${submission.status}');
    }
    if (submission.ownerUid != user.uid) {
      throw Exception('Not authorized to delete this submission');
    }

    await _deleteStorageFolder(submission.scopeId, user.uid, submissionId);
    await _submissions.doc(submissionId).delete();
  }

  Future<void> _deleteStorageFolder(
    String scopeId,
    String ownerUid,
    String submissionId,
  ) async {
    try {
      final folderRef = _storage.ref(
        'commerce/$scopeId/$ownerUid/$submissionId',
      );
      final result = await folderRef.listAll();
      for (final item in result.items) {
        await item.delete();
      }
      for (final prefix in result.prefixes) {
        await _deleteStorageFolderRecursive(prefix);
      }
    } catch (_) {
      // Ignorer si le dossier n'existe pas.
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

  Future<List<String>> uploadMediaFiles({
    required String scopeId,
    required String submissionId,
    required List<File> files,
    void Function(double progress)? onProgress,
  }) async {
    final xfiles = files.map((file) => XFile(file.path)).toList();
    return _storageService.uploadMediaFiles(
      mediaId: submissionId,
      files: xfiles,
      scopeId: scopeId,
      onProgress: onProgress,
    );
  }

  Future<String> uploadMediaBytes({
    required String scopeId,
    required String submissionId,
    required List<int> bytes,
    required String filename,
    void Function(double progress)? onProgress,
  }) async {
    final xfile = XFile.fromData(
      Uint8List.fromList(bytes),
      name: filename,
      mimeType: 'image/jpeg',
    );

    return _storageService.uploadMediaFile(
      mediaId: submissionId,
      file: xfile,
      scopeId: scopeId,
      onProgress: onProgress,
    );
  }

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

  Future<void> reject(String submissionId, String note) async {
    final user = _currentUser;
    if (user == null) throw Exception('User not authenticated');
    try {
      final callable = _functions.httpsCallable('rejectCommerceSubmission');
      await callable.call({'submissionId': submissionId, 'note': note});
    } catch (e) {
      throw Exception('Failed to reject submission: $e');
    }
  }

  Future<CommerceSubmission?> getSubmission(String submissionId) async {
    final doc = await _submissions.doc(submissionId).get();
    if (!doc.exists) return null;
    return CommerceSubmission.fromFirestore(doc);
  }

  Stream<CommerceSubmission?> watchSubmission(String submissionId) {
    return _submissions.doc(submissionId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return CommerceSubmission.fromFirestore(doc);
    });
  }

  Future<bool> canModerate({String? scopeId}) async {
    final user = _currentUser;
    if (user == null) return false;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) return false;

    final data = userDoc.data()!;
    final role = RoleNormalizer.normalize(
      data['role'] as String?,
      isAdminFlag: data['isAdmin'] as bool? ?? false,
    );

    if (role == RoleNormalizer.admin || role == RoleNormalizer.superAdmin) {
      return true;
    }

    if (role == RoleNormalizer.group && scopeId != null) {
      final managedScopeIds =
          (data['managedScopeIds'] as List<dynamic>?)?.cast<String>();
      final userGroupId = data['groupId'] as String?;
      return managedScopeIds?.contains(scopeId) == true ||
          userGroupId == scopeId;
    }

    return false;
  }

  Future<OwnerRole?> getCurrentUserRole() async {
    final user = _currentUser;
    if (user == null) return null;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) return null;

    final data = userDoc.data()!;
    final role = RoleNormalizer.normalize(
      data['role'] as String?,
      isAdminFlag: data['isAdmin'] as bool? ?? false,
    );
    final activities = (data['activities'] as List<dynamic>?)?.cast<String>();

    if (role == RoleNormalizer.superAdmin) return OwnerRole.superadmin;
    if (role == RoleNormalizer.admin) return OwnerRole.superadmin;
    if (role == RoleNormalizer.group) return OwnerRole.adminGroupe;

    if (activities?.contains('createur_digital') == true ||
        activities?.contains('creator_digital') == true) {
      return OwnerRole.createurDigital;
    }

    final businessDoc = await _firestore
        .collection('businesses')
        .doc(user.uid)
        .get();
    if (businessDoc.exists) {
      return OwnerRole.comptePro;
    }

    return null;
  }

  Future<bool> canSubmitCommerce() async {
    final role = await getCurrentUserRole();
    return role != null;
  }
}
