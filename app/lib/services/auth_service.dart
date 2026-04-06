import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
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

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  Future<void>? _googleInitialization;
  static const String _appleServiceId = String.fromEnvironment(
    'APPLE_SERVICE_ID',
  );
  static const String _appleRedirectUri = String.fromEnvironment(
    'APPLE_REDIRECT_URI',
  );

  bool get _isAppleWebFlowConfigured {
    final uri = Uri.tryParse(_appleRedirectUri);
    return _appleServiceId.isNotEmpty && uri != null && uri.isAbsolute;
  }

  bool get supportsAppleSignInUi {
    if (kIsWeb) return _isAppleWebFlowConfigured;

    if (defaultTargetPlatform == TargetPlatform.android) {
      return _isAppleWebFlowConfigured;
    }

    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  bool get _firebaseReady => Firebase.apps.isNotEmpty;

  // Stream de l'utilisateur actuel
  Stream<User?> get authStateChanges {
    if (!_firebaseReady) return const Stream<User?>.empty();
    return _auth.authStateChanges();
  }

  // Utilisateur actuel
  User? get currentUser {
    if (!_firebaseReady) return null;
    return _auth.currentUser;
  }

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
    bool preserveRoleAndGroup = true,
  }) async {
    try {
      final existing = await _firestore.collection('users').doc(userId).get();

      final isExistingUser = existing.exists;

      final Map<String, dynamic> data = {
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'phone': phone,
        'region': region,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // On ne positionne role/groupId que lors de la création (ou si explicitement demandé)
      if (!isExistingUser || preserveRoleAndGroup == false) {
        data['groupId'] = groupId;
        data['role'] = UserProfile.roleToString(role);
      }

      await _firestore.collection('users').doc(userId).set(
        {
          ...data,
          if (!isExistingUser) 'createdAt': FieldValue.serverTimestamp(),
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
    try {
      await ensureGoogleSignInInitialized();

      if (kIsWeb) {
        throw const AuthException(
          'Utilisez le bouton Google affiche dans la fenetre de connexion.',
        );
      }

      final googleUser = await GoogleSignIn.instance.authenticate();
      return _signInWithGoogleAccount(googleUser);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthException('Connexion Google annulée');
      }
      throw AuthException('Erreur Google: ${e.description ?? e.code.name}');
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Erreur Google: $e');
    }
  }

  Future<void> ensureGoogleSignInInitialized() {
    return _googleInitialization ??= GoogleSignIn.instance.initialize();
  }

  Future<UserCredential> signInWithGoogleAccount(
    GoogleSignInAccount googleUser,
  ) {
    return _signInWithGoogleAccount(googleUser);
  }

  Future<UserCredential> _signInWithGoogleAccount(
    GoogleSignInAccount googleUser,
  ) async {
    final idToken = googleUser.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('Token Google invalide ou manquant');
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final result = await _auth.signInWithCredential(credential);
    await _syncSocialUserProfile(result.user);
    return result;
  }

  Future<UserCredential> signInWithApple() async {
    try {
      final requiresWebOptions =
          kIsWeb || defaultTargetPlatform == TargetPlatform.android;

      if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android) {
        final available = await SignInWithApple.isAvailable();
        if (!available) {
          throw const AuthException(
            'Apple Sign-In n\'est pas disponible sur cet appareil.',
          );
        }
      }

      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final AuthorizationCredentialAppleID appleCredential;
      if (requiresWebOptions) {
        final redirectUri = Uri.tryParse(_appleRedirectUri);
        if (_appleServiceId.isEmpty ||
            redirectUri == null ||
            !redirectUri.isAbsolute) {
          throw const AuthException(
            'Configuration Apple manquante (APPLE_SERVICE_ID / APPLE_REDIRECT_URI).',
          );
        }
        appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
          nonce: nonce,
          webAuthenticationOptions: WebAuthenticationOptions(
            clientId: _appleServiceId,
            redirectUri: redirectUri,
          ),
        );
      } else {
        appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
          nonce: nonce,
        );
      }

      if (appleCredential.identityToken == null) {
        throw const AuthException('Token Apple invalide ou manquant.');
      }

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      final result = await _auth.signInWithCredential(oauthCredential);
      await _syncSocialUserProfile(result.user);
      return result;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    } on SignInWithAppleAuthorizationException catch (e) {
      switch (e.code) {
        case AuthorizationErrorCode.canceled:
          throw const AuthException('Connexion Apple annulée');
        case AuthorizationErrorCode.failed:
          throw const AuthException('La connexion Apple a échoué');
        case AuthorizationErrorCode.invalidResponse:
          throw const AuthException('Réponse Apple invalide');
        case AuthorizationErrorCode.notHandled:
          throw const AuthException('Connexion Apple non prise en charge');
        case AuthorizationErrorCode.notInteractive:
          throw const AuthException(
            'Connexion Apple indisponible dans ce contexte',
          );
        case AuthorizationErrorCode.credentialExport:
          throw const AuthException('Export des identifiants Apple impossible');
        case AuthorizationErrorCode.credentialImport:
          throw const AuthException('Import des identifiants Apple impossible');
        case AuthorizationErrorCode.matchedExcludedCredential:
          throw const AuthException(
            'Une credentielle Apple exclue a ete detectee',
          );
        case AuthorizationErrorCode.unknown:
          throw AuthException('Erreur Apple inconnue: ${e.message}');
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Erreur Apple: $e');
    }
  }

  Future<void> _syncSocialUserProfile(User? user) async {
    if (user == null) return;

    final existing = await getUserProfile(user.uid);
    if (existing != null) return;

    final email = user.email;
    if (email == null || email.isEmpty) {
      throw const AuthException(
        'Impossible de créer le profil: email manquant pour ce compte social.',
      );
    }

    await createOrUpdateUserProfile(
      userId: user.uid,
      email: email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
      role: UserRole.user,
    );
  }

  String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return 'Ce compte existe déjà avec une autre méthode de connexion.';
      case 'invalid-credential':
        return 'Identifiants invalides. Réessayez.';
      case 'operation-not-allowed':
        return 'Méthode de connexion non activée côté Firebase.';
      case 'user-disabled':
        return 'Ce compte a été désactivé.';
      case 'user-not-found':
        return 'Aucun compte trouvé pour cet utilisateur.';
      case 'network-request-failed':
        return 'Problème réseau. Vérifiez votre connexion.';
      default:
        return e.message ?? 'Erreur d\'authentification.';
    }
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
      // Also clear Google provider session when present.
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Ignore: user may not be signed in with Google.
      }
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
        final functions = FirebaseFunctions.instanceFor(region: 'us-east1');
        final callable = functions.httpsCallable('deleteMyAccountGdpr');
        await callable.call();
      }
    } catch (e) {
      // print('Erreur deleteAccount: $e');
      rethrow;
    }
  }

  // Export des données personnelles (RGPD)
  Future<Map<String, dynamic>> exportMyPersonalData() async {
    final functions = FirebaseFunctions.instanceFor(region: 'us-east1');
    final callable = functions.httpsCallable('exportMyPersonalData');
    final result = await callable.call();
    final data = result.data;
    if (data is Map<String, dynamic>) {
      return data;
    }
    return {'success': false, 'export': null};
  }
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}
