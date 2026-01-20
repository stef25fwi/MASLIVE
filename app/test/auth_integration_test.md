# Tests d'intégration Firebase Auth

## Configuration requise

### 1. Firebase Console
Activer les méthodes d'authentification :
- ✅ Email/Password
- ✅ Google Sign-In
- ✅ Apple Sign-In

### 2. Google Sign-In
- Ajouter le SHA-1 de votre clé de signature dans Firebase Console
- Configurer OAuth 2.0 Client ID dans Google Cloud Console

### 3. Apple Sign-In
- Configurer Services ID dans Apple Developer
- Ajouter le domaine autorisé dans Firebase Console

## Tests manuels

### Test 1 : Inscription Email/Password
```
Email: test+{timestamp}@example.com
Password: Test123456!

Résultat attendu:
- ✅ Compte créé dans Firebase Auth
- ✅ Profil créé dans Firestore /users/{uid}
- ✅ Redirection vers /router
```

### Test 2 : Connexion Email/Password
```
Email: Utiliser un compte existant
Password: Mot de passe correct

Résultat attendu:
- ✅ Connexion réussie
- ✅ Session active
- ✅ Redirection vers /router
```

### Test 3 : Google Sign-In
```
Action: Cliquer sur "Continuer avec Google"

Résultat attendu:
- ✅ Popup Google s'ouvre
- ✅ Sélection du compte
- ✅ Profil créé/mis à jour dans Firestore
- ✅ Redirection vers /router
```

### Test 4 : Apple Sign-In
```
Action: Cliquer sur "Continuer avec Apple"

Résultat attendu:
- ✅ Interface Apple s'affiche
- ✅ Face ID / Touch ID / Password
- ✅ Profil créé/mis à jour dans Firestore
- ✅ Redirection vers /router
```

### Test 5 : Réinitialisation mot de passe
```
Email: Compte existant

Résultat attendu:
- ✅ Email de réinitialisation envoyé
- ✅ Lien fonctionnel
- ✅ Nouveau mot de passe accepté
```

### Test 6 : Gestion d'erreurs
```
Scénarios:
- Email invalide → Erreur affichée
- Mot de passe trop court → Erreur affichée
- Compte inexistant → Erreur affichée
- Mauvais mot de passe → Erreur affichée
- Annulation Google/Apple → Retour à l'écran de connexion
```

## Tests de persistance

### Test 7 : Session persistante
```
1. Se connecter
2. Fermer l'application
3. Rouvrir l'application

Résultat attendu:
- ✅ Utilisateur toujours connecté
- ✅ Pas de ré-authentification nécessaire
```

### Test 8 : Déconnexion
```
Action: Se déconnecter

Résultat attendu:
- ✅ Session terminée
- ✅ Redirection vers /login
- ✅ Profil non accessible
```

## Tests de profil utilisateur

### Test 9 : Création de profil
```
Vérifier dans Firestore /users/{uid}:
{
  "email": "test@example.com",
  "displayName": "Test User",
  "photoUrl": "https://...",
  "role": "user",
  "groupId": null,
  "createdAt": timestamp,
  "updatedAt": timestamp
}
```

### Test 10 : Mise à jour de profil
```
Modifier:
- displayName
- photoUrl
- phone
- region

Résultat attendu:
- ✅ Modifications enregistrées dans Firestore
- ✅ updatedAt mis à jour
```

## Commandes de test

```bash
# Tests unitaires
cd /workspaces/MASLIVE/app
flutter test test/auth_service_test.dart

# Analyse statique
flutter analyze

# Lancer l'app en mode debug
flutter run -d chrome

# Lancer l'app sur Android
flutter run -d android

# Lancer l'app sur iOS
flutter run -d ios
```

## Monitoring Firebase

Vérifier dans Firebase Console :
1. Authentication → Users : Nouveaux utilisateurs créés
2. Firestore → users : Documents de profil créés
3. Authentication → Sign-in method : Méthodes activées

## Sécurité

### Règles Firestore à vérifier
```javascript
// /users/{userId}
allow read: if request.auth != null && request.auth.uid == userId;
allow write: if request.auth != null && request.auth.uid == userId;
```

### OAuth Scopes
- Google: email, profile
- Apple: email, fullName

## Résolution de problèmes

### Google Sign-In ne fonctionne pas
- Vérifier SHA-1 dans Firebase Console
- Vérifier OAuth Client ID
- Recompiler l'app après modification

### Apple Sign-In ne fonctionne pas
- Vérifier Services ID
- Vérifier domaine autorisé
- Tester sur appareil physique iOS (pas simulateur pour prod)

### Email/Password erreurs
- Vérifier règles de mot de passe Firebase
- Vérifier format email
- Vérifier connexion réseau
