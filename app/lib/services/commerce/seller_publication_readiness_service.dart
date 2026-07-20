import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/commerce_submission.dart';

class SellerPublicationReadiness {
  const SellerPublicationReadiness({
    required this.canPublish,
    required this.code,
    required this.message,
    this.actionRoute,
  });

  const SellerPublicationReadiness.ready()
      : canPublish = true,
        code = 'ready',
        message = '',
        actionRoute = null;

  final bool canPublish;
  final String code;
  final String message;
  final String? actionRoute;
}

class SellerPublicationReadinessService {
  SellerPublicationReadinessService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  static final SellerPublicationReadinessService instance =
      SellerPublicationReadinessService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<SellerPublicationReadiness> check({
    required OwnerRole ownerRole,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      return const SellerPublicationReadiness(
        canPublish: false,
        code: 'authentication_required',
        message: 'Connectez-vous avant de publier.',
        actionRoute: '/login',
      );
    }

    try {
      switch (ownerRole) {
        case OwnerRole.superadmin:
        case OwnerRole.adminGroupe:
          return const SellerPublicationReadiness.ready();
        case OwnerRole.comptePro:
          return _checkBusiness(user.uid);
        case OwnerRole.createurDigital:
          return _checkPhotographer(user.uid);
      }
    } catch (_) {
      return const SellerPublicationReadiness(
        canPublish: false,
        code: 'readiness_unavailable',
        message:
            'Impossible de vérifier votre capacité de paiement. Réessayez avant de publier.',
      );
    }
  }

  Future<SellerPublicationReadiness> _checkBusiness(String uid) async {
    final snapshot = await _firestore.collection('businesses').doc(uid).get();
    final data = snapshot.data();
    if (data == null) {
      return const SellerPublicationReadiness(
        canPublish: false,
        code: 'business_profile_missing',
        message:
            'Créez votre compte professionnel et renseignez votre identité/SIRET avant de publier.',
        actionRoute: '/business',
      );
    }

    final status = (data['status'] ?? 'pending').toString().trim().toLowerCase();
    final siret = (data['siret'] ?? '').toString().trim();
    if (siret.isEmpty || (status != 'approved' && status != 'active')) {
      return const SellerPublicationReadiness(
        canPublish: false,
        code: 'business_verification_required',
        message:
            'Votre identité et votre SIRET doivent être validés avant la publication.',
        actionRoute: '/business',
      );
    }

    final stripe = data['stripe'] is Map
        ? Map<String, dynamic>.from(data['stripe'] as Map)
        : const <String, dynamic>{};
    if (!_isStripePayable(stripe)) {
      return const SellerPublicationReadiness(
        canPublish: false,
        code: 'stripe_connect_not_payable',
        message:
            'Finalisez Stripe Connect : le compte doit autoriser les encaissements et les virements avant de publier.',
        actionRoute: '/business',
      );
    }

    return const SellerPublicationReadiness.ready();
  }

  Future<SellerPublicationReadiness> _checkPhotographer(String uid) async {
    final query = await _firestore
        .collection('photographers')
        .where('ownerUid', isEqualTo: uid)
        .limit(1)
        .get();
    if (query.docs.isEmpty) {
      return const SellerPublicationReadiness(
        canPublish: false,
        code: 'photographer_profile_missing',
        message: 'Créez et faites valider votre profil créateur avant de publier.',
        actionRoute: '/media-marketplace',
      );
    }

    final data = query.docs.first.data();
    final status = (data['status'] ?? 'pending').toString().trim().toLowerCase();
    if (status != 'approved') {
      return const SellerPublicationReadiness(
        canPublish: false,
        code: 'photographer_verification_required',
        message: 'Votre profil créateur doit être validé avant la publication.',
        actionRoute: '/media-marketplace',
      );
    }

    final stripe = data['stripe'] is Map
        ? Map<String, dynamic>.from(data['stripe'] as Map)
        : const <String, dynamic>{};
    if (!_isStripePayable(stripe)) {
      return const SellerPublicationReadiness(
        canPublish: false,
        code: 'stripe_connect_not_payable',
        message:
            'Finalisez Stripe Connect : les encaissements et les virements doivent être actifs avant de publier.',
        actionRoute: '/media-marketplace',
      );
    }

    return const SellerPublicationReadiness.ready();
  }

  bool _isStripePayable(Map<String, dynamic> stripe) {
    final accountId = (stripe['accountId'] ?? '').toString().trim();
    return accountId.isNotEmpty &&
        stripe['detailsSubmitted'] == true &&
        stripe['chargesEnabled'] == true &&
        stripe['payoutsEnabled'] == true;
  }
}
