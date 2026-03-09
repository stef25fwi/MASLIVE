import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/media_marketplace_collections.dart';
import '../../data/models/admin_moderation_queue_model.dart';

class AdminModerationQueueController extends ChangeNotifier {
  AdminModerationQueueController({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  bool loading = false;
  Object? error;
  String? statusFilter;
  String? photographerIdFilter;
  List<AdminModerationQueueModel> items =
      const <AdminModerationQueueModel>[];

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  void watch({String? status, String? photographerId}) {
    _subscription?.cancel();
    loading = true;
    error = null;
    statusFilter = status;
    photographerIdFilter = photographerId;
    notifyListeners();

    Query<Map<String, dynamic>> query = _firestore
        .collection(MediaMarketplaceCollections.adminModerationQueue);

    if (status != null && status.isNotEmpty) {
      query = query.where('status', isEqualTo: status);
    }
    if (photographerId != null && photographerId.isNotEmpty) {
      query = query.where('photographerId', isEqualTo: photographerId);
    }

    query = query.orderBy('createdAt', descending: true);

    _subscription = query.snapshots().listen(
      (snapshot) {
        items = snapshot.docs
            .map(AdminModerationQueueModel.fromDocument)
            .toList(growable: false);
        loading = false;
        error = null;
        notifyListeners();
      },
      onError: (Object err) {
        loading = false;
        error = err;
        notifyListeners();
      },
    );
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}