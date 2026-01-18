import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';
import '../models/user_profile_model.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();

  static AuthService get instance => _instance;

  AuthService._internal();

  factory AuthService() {
    return _instance;
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream de l'utilisateur actuel
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Utilisateur actuel
  User? get currentUser => _auth.currentUser;

  // Récupérer le profil utilisateur
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserProfile.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      // print('Erreur getUserProfile: $e');
      return null;
    }
  }

  // Stream du profil utilisateur
  Stream<UserProfile?> getUserProfileStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (doc.exists) {
        return UserProfile.fromFirestore(doc);
      }
      return null;
    });
  }

  // Créer/Mettre à jour profil utilisateur
  Future<void> createOrUpdateUserProfile({
    required String userId,
    required String email,
    String? displayName,
    String? photoUrl,
    String? phone,
    String? region,
    UserRole role = UserRole.user,
    String? groupId,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).set(
        {
          'email': email,
          'displayName': displayName,
          'photoUrl': photoUrl,
          'phone': phone,
          'region': region,
          'groupId': groupId,
          'role': UserProfile.roleToString(role),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      // print('Erreur createOrUpdateUserProfile: $e');
      rethrow;
    }
  }

  // Connexion avec email/password
  Future<UserCredential?> signInWithEmail(
    String email,
    String password,
  ) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result;
    } catch (e) {
      // print('Erreur signInWithEmail: $e');
      rethrow;
    }
  }

  // API attendue par AuthActionRunner
  Future<UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = cred.user;
    if (user != null && user.email != null) {
      final existing = await getUserProfile(user.uid);
      if (existing == null) {
        await createOrUpdateUserProfile(
          userId: user.uid,
          email: user.email!,
          displayName: user.displayName,
          photoUrl: user.photoURL,
          role: UserRole.user,
        );
      }
    }

    return cred;
  }

  // Inscription avec email/password
  Future<UserCredential?> signUpWithEmail(
    String email,
    String password,
    String? displayName,
  ) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Mettre à jour le displayName si fourni
      if (displayName != null) {
        await result.user?.updateDisplayName(displayName);
      }

      // Créer le profil Firestore
      if (result.user != null) {
        await createOrUpdateUserProfile(
          userId: result.user!.uid,
          email: email,
          displayName: displayName,
          role: UserRole.user,
        );
      }

      return result;
    } catch (e) {
      // print('Erreur signUpWithEmail: $e');
      rethrow;
    }
  }

  // API attendue par AuthActionRunner
  Future<UserCredential> createUserWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = result.user;
    if (user != null) {
      await createOrUpdateUserProfile(
        userId: user.uid,
        email: email,
        displayName: user.displayName,
        photoUrl: user.photoURL,
        role: UserRole.user,
      );
    }

    return result;
  }

  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw Exception('Connexion Google annulée');
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final result = await _auth.signInWithCredential(credential);
    final user = result.user;
    if (user != null && user.email != null) {
      await createOrUpdateUserProfile(
        userId: user.uid,
        email: user.email!,
        displayName: user.displayName,
        photoUrl: user.photoURL,
        role: UserRole.user,
      );
    }
    return result;
  }

  Future<UserCredential> signInWithApple() async {
    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
    );

    final result = await _auth.signInWithCredential(oauthCredential);
    final user = result.user;
    if (user != null && user.email != null) {
      await createOrUpdateUserProfile(
        userId: user.uid,
        email: user.email!,
        displayName: user.displayName,
        photoUrl: user.photoURL,
        role: UserRole.user,
      );
    }
    return result;
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Mise à jour profil
  Future<void> updateUserProfile({
    String? displayName,
    String? photoUrl,
    String? phone,
    String? region,
    UserRole? role,
    String? groupId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non authentifié');

      final existing = await getUserProfile(user.uid);
      final roleToPersist = role ?? existing?.role ?? UserRole.user;
      final groupIdToPersist = groupId ?? existing?.groupId;

      // Mettre à jour Firebase Auth
      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }
      if (photoUrl != null) {
        await user.updatePhotoURL(photoUrl);
      }

      // Mettre à jour Firestore
      await createOrUpdateUserProfile(
        userId: user.uid,
        email: user.email!,
        displayName: displayName ?? user.displayName,
        photoUrl: photoUrl ?? user.photoURL,
        phone: phone,
        region: region,
        role: roleToPersist,
        groupId: groupIdToPersist,
      );
    } catch (e) {
      // print('Erreur updateUserProfile: $e');
      rethrow;
    }
  }

  // Déconnexion
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      // print('Erreur signOut: $e');
      rethrow;
    }
  }

  // Réinitialiser le mot de passe
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      // print('Erreur resetPassword: $e');
      rethrow;
    }
  }

  // Supprimer le compte
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Supprimer le document Firestore
        await _firestore.collection('users').doc(user.uid).delete();
        // Supprimer le compte Firebase
        await user.delete();
      }
    } catch (e) {
      // print('Erreur deleteAccount: $e');
      rethrow;
    }
  }
}
