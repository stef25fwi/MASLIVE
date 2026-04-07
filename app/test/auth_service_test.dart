import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masslive/models/user_profile_model.dart';
import 'package:masslive/services/auth_service.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService', () {
    test('AuthService.instance reste singleton', () {
      expect(AuthService.instance, same(AuthService.instance));
      expect(AuthService(), same(AuthService.instance));
    });

    test('currentUser retourne null sans authentification', () {
      final harness = _AuthServiceHarness();

      expect(harness.service.currentUser, isNull);
    });

    test(
      'signInWithEmailPassword émet l’utilisateur et crée son profil',
      () async {
        final mockUser = MockUser(
          uid: 'email-user-1',
          email: 'pilot@example.com',
          displayName: 'Pilot',
        );
        final harness = _AuthServiceHarness(mockUser: mockUser);

        final authState = harness.service.authStateChanges.firstWhere(
          (user) => user?.uid == mockUser.uid,
        );

        final credential = await harness.service.signInWithEmailPassword(
          email: 'pilot@example.com',
          password: 'password123',
        );

        expect(credential.user?.uid, mockUser.uid);
        expect(harness.service.currentUser?.uid, mockUser.uid);

        final profileDoc = await harness.firestore
            .collection('users')
            .doc(mockUser.uid)
            .get();

        expect(profileDoc.exists, isTrue);
        expect(profileDoc.data()?['email'], 'pilot@example.com');
        expect(profileDoc.data()?['displayName'], 'Pilot');
        expect(profileDoc.data()?['role'], 'user');

        expect((await authState)?.uid, mockUser.uid);
      },
    );

    test('signInWithEmailPassword conserve un profil existant', () async {
      final mockUser = MockUser(
        uid: 'existing-user',
        email: 'admin@example.com',
        displayName: 'Admin Name',
      );
      final harness = _AuthServiceHarness(mockUser: mockUser);

      await harness.firestore.collection('users').doc(mockUser.uid).set({
        'email': 'admin@example.com',
        'displayName': 'Profil existant',
        'role': 'admin',
        'groupId': 'group-42',
        'createdAt': Timestamp.now(),
      });

      await harness.service.signInWithEmailPassword(
        email: 'admin@example.com',
        password: 'password123',
      );

      final profileDoc = await harness.firestore
          .collection('users')
          .doc(mockUser.uid)
          .get();

      expect(profileDoc.data()?['role'], 'admin');
      expect(profileDoc.data()?['groupId'], 'group-42');
      expect(profileDoc.data()?['displayName'], 'Profil existant');
    });

    test('signInWithEmailPassword relaie les erreurs Firebase Auth', () async {
      final harness = _AuthServiceHarness();

      whenCalling(
            Invocation.method(#signInWithEmailAndPassword, null, {
              #email: 'invalid@test.com',
              #password: 'wrongpassword',
            }),
          )
          .on(harness.auth)
          .thenThrow(
            FirebaseAuthException(
              code: 'wrong-password',
              message: 'Wrong password.',
            ),
          );

      await expectLater(
        harness.service.signInWithEmailPassword(
          email: 'invalid@test.com',
          password: 'wrongpassword',
        ),
        throwsA(
          isA<FirebaseAuthException>().having(
            (error) => error.code,
            'code',
            'wrong-password',
          ),
        ),
      );
    });

    test('createUserWithEmailPassword crée le profil Firestore', () async {
      final harness = _AuthServiceHarness();

      final credential = await harness.service.createUserWithEmailPassword(
        email: 'new-user@example.com',
        password: 'password123',
      );

      final createdUser = credential.user;
      expect(createdUser, isNotNull);

      final profileDoc = await harness.firestore
          .collection('users')
          .doc(createdUser!.uid)
          .get();

      expect(profileDoc.exists, isTrue);
      expect(profileDoc.data()?['email'], 'new-user@example.com');
      expect(profileDoc.data()?['role'], 'user');
    });

    test('createUserWithEmailPassword relaie invalid-email', () async {
      final harness = _AuthServiceHarness();

      whenCalling(
            Invocation.method(#createUserWithEmailAndPassword, null, {
              #email: 'invalidemail',
              #password: 'password123',
            }),
          )
          .on(harness.auth)
          .thenThrow(
            FirebaseAuthException(
              code: 'invalid-email',
              message: 'The email address is badly formatted.',
            ),
          );

      await expectLater(
        harness.service.createUserWithEmailPassword(
          email: 'invalidemail',
          password: 'password123',
        ),
        throwsA(
          isA<FirebaseAuthException>().having(
            (error) => error.code,
            'code',
            'invalid-email',
          ),
        ),
      );
    });

    test('getUserProfile retourne null si le document est absent', () async {
      final harness = _AuthServiceHarness();

      final profile = await harness.service.getUserProfile('missing-user');

      expect(profile, isNull);
    });

    test('getUserProfile retourne le profil Firestore existant', () async {
      final harness = _AuthServiceHarness();
      await harness.firestore.collection('users').doc('profile-user').set({
        'email': 'profile@example.com',
        'displayName': 'Stored User',
        'role': 'admin',
        'createdAt': Timestamp.now(),
      });

      final profile = await harness.service.getUserProfile('profile-user');

      expect(profile, isNotNull);
      expect(profile!.email, 'profile@example.com');
      expect(profile.displayName, 'Stored User');
      expect(profile.role, UserRole.admin);
    });

    test('getUserProfileStream diffuse les mises à jour Firestore', () async {
      final harness = _AuthServiceHarness();

      final emittedProfile = harness.service
          .getUserProfileStream('stream-user')
          .firstWhere((profile) => profile != null);

      await harness.firestore.collection('users').doc('stream-user').set({
        'email': 'stream@example.com',
        'displayName': 'Stream User',
        'role': 'user',
        'createdAt': Timestamp.now(),
      });

      final profile = (await emittedProfile)!;
      expect(profile.email, 'stream@example.com');
      expect(profile.displayName, 'Stream User');
    });

    test('signInWithGoogleIdToken crée le profil social', () async {
      final mockUser = MockUser(
        uid: 'google-user-1',
        email: 'google@example.com',
        displayName: 'Google User',
      );
      final harness = _AuthServiceHarness(mockUser: mockUser);

      final credential = await harness.service.signInWithGoogleIdToken(
        'fake-google-token',
      );

      expect(credential.user?.uid, mockUser.uid);

      final profileDoc = await harness.firestore
          .collection('users')
          .doc(mockUser.uid)
          .get();

      expect(profileDoc.exists, isTrue);
      expect(profileDoc.data()?['email'], 'google@example.com');
      expect(profileDoc.data()?['displayName'], 'Google User');
    });

    test('signInWithGoogleIdToken rejette un jeton vide', () async {
      final harness = _AuthServiceHarness();

      await expectLater(
        harness.service.signInWithGoogleIdToken('   '),
        throwsA(
          isA<AuthException>().having(
            (error) => error.message,
            'message',
            contains('jeton valide'),
          ),
        ),
      );
    });

    test('signOut vide currentUser', () async {
      final mockUser = MockUser(
        uid: 'signed-user',
        email: 'signed@example.com',
      );
      final harness = _AuthServiceHarness(mockUser: mockUser, signedIn: true);

      expect(harness.service.currentUser?.uid, mockUser.uid);

      await harness.service.signOut();

      expect(harness.service.currentUser, isNull);
    });

    test('resetPassword complète sans erreur si Firebase accepte', () async {
      final harness = _AuthServiceHarness();

      await expectLater(
        harness.service.resetPassword('reset@example.com'),
        completes,
      );
    });

    test('resetPassword relaie invalid-email', () async {
      final harness = _AuthServiceHarness();

      whenCalling(
            Invocation.method(#sendPasswordResetEmail, null, {
              #email: 'invalidemail',
            }),
          )
          .on(harness.auth)
          .thenThrow(
            FirebaseAuthException(
              code: 'invalid-email',
              message: 'The email address is badly formatted.',
            ),
          );

      await expectLater(
        harness.service.resetPassword('invalidemail'),
        throwsA(
          isA<FirebaseAuthException>().having(
            (error) => error.code,
            'code',
            'invalid-email',
          ),
        ),
      );
    });
  });
}

class _AuthServiceHarness {
  _AuthServiceHarness({MockUser? mockUser, bool signedIn = false})
    : auth = MockFirebaseAuth(signedIn: signedIn, mockUser: mockUser),
      firestore = FakeFirebaseFirestore() {
    firestore = FakeFirebaseFirestore(authObject: auth.authForFakeFirestore);
    service = AuthService.test(auth: auth, firestore: firestore);
  }

  late final MockFirebaseAuth auth;
  late FakeFirebaseFirestore firestore;
  late final AuthService service;
}
