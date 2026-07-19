import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masslive/models/commerce_submission.dart';
import 'package:masslive/services/commerce/seller_publication_readiness_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SellerPublicationReadinessService', () {
    test('autorise un compte professionnel validé et payable', () async {
      final firestore = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'business-user'),
        signedIn: true,
      );
      await firestore.collection('businesses').doc('business-user').set({
        'status': 'approved',
        'siret': '12345678901234',
        'stripe': {
          'accountId': 'acct_ready',
          'detailsSubmitted': true,
          'chargesEnabled': true,
          'payoutsEnabled': true,
        },
      });

      final service = SellerPublicationReadinessService(
        firestore: firestore,
        auth: auth,
      );
      final result = await service.check(ownerRole: OwnerRole.comptePro);

      expect(result.canPublish, isTrue);
      expect(result.code, 'ready');
    });

    test('bloque un compte professionnel sans virements Stripe', () async {
      final firestore = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'business-user'),
        signedIn: true,
      );
      await firestore.collection('businesses').doc('business-user').set({
        'status': 'approved',
        'siret': '12345678901234',
        'stripe': {
          'accountId': 'acct_incomplete',
          'detailsSubmitted': true,
          'chargesEnabled': true,
          'payoutsEnabled': false,
        },
      });

      final service = SellerPublicationReadinessService(
        firestore: firestore,
        auth: auth,
      );
      final result = await service.check(ownerRole: OwnerRole.comptePro);

      expect(result.canPublish, isFalse);
      expect(result.code, 'stripe_connect_not_payable');
      expect(result.actionRoute, '/business');
    });

    test('bloque un créateur dont le profil n’est pas validé', () async {
      final firestore = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'creator-user'),
        signedIn: true,
      );
      await firestore.collection('photographers').doc('photographer-1').set({
        'ownerUid': 'creator-user',
        'status': 'pending',
        'stripe': {
          'accountId': 'acct_creator',
          'detailsSubmitted': true,
          'chargesEnabled': true,
          'payoutsEnabled': true,
        },
      });

      final service = SellerPublicationReadinessService(
        firestore: firestore,
        auth: auth,
      );
      final result = await service.check(
        ownerRole: OwnerRole.createurDigital,
      );

      expect(result.canPublish, isFalse);
      expect(result.code, 'photographer_verification_required');
    });

    test('conserve le parcours plateforme des admins groupe', () async {
      final service = SellerPublicationReadinessService(
        firestore: FakeFirebaseFirestore(),
        auth: MockFirebaseAuth(
          mockUser: MockUser(uid: 'group-admin'),
          signedIn: true,
        ),
      );

      final result = await service.check(ownerRole: OwnerRole.adminGroupe);

      expect(result.canPublish, isTrue);
    });
  });
}
