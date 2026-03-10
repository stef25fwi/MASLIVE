import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/media_entitlement_model.dart';
import '../../data/repositories/media_entitlement_repository.dart';

class MediaDownloadController extends ChangeNotifier {
  MediaDownloadController({
    MediaEntitlementRepository? mediaEntitlementRepository,
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  }) : _mediaEntitlementRepository =
           mediaEntitlementRepository ?? MediaEntitlementRepository(),
       _functions = functions ?? FirebaseFunctions.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final MediaEntitlementRepository _mediaEntitlementRepository;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  bool loading = false;
  Object? error;
  List<MediaEntitlementModel> entitlements = const <MediaEntitlementModel>[];
  final Set<String> _downloadingKeys = <String>{};

  bool isDownloading(String key) => _downloadingKeys.contains(key);

  Future<void> loadCurrentUserEntitlements() async {
    final user = _auth.currentUser;
    if (user == null) {
      entitlements = const <MediaEntitlementModel>[];
      error = null;
      notifyListeners();
      return;
    }

    loading = true;
    error = null;
    notifyListeners();

    try {
      entitlements = await _mediaEntitlementRepository.getByBuyer(user.uid);
    } catch (err) {
      error = err;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<String?> createDownloadUrl({
    required String entitlementId,
    required String assetId,
    String? photoId,
    String variant = 'original',
  }) async {
    final key = '$entitlementId::$assetId::${photoId ?? ''}::$variant';
    _downloadingKeys.add(key);
    error = null;
    notifyListeners();

    try {
      final callable = _functions.httpsCallable('getMediaDownloadUrl');
      final response = await callable.call(<String, dynamic>{
        'entitlementId': entitlementId,
        'assetId': assetId,
        'photoId': ?photoId,
        'variant': variant,
      });
      final data = Map<String, dynamic>.from(response.data as Map);
      return data['url']?.toString();
    } catch (err) {
      error = err;
      return null;
    } finally {
      _downloadingKeys.remove(key);
      notifyListeners();
    }
  }
}