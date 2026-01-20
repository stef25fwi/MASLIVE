# Système de Catégories d'Utilisateurs et Permissions - MASLIVE

## Vue d'ensemble

Ce document décrit le système de gestion des catégories d'utilisateurs (rôles) et des permissions dans MASLIVE. Le système permet de définir différents niveaux d'accès et de droits pour les utilisateurs de l'application.

## Catégories d'Utilisateurs (Rôles)

Le système définit 5 catégories principales d'utilisateurs, classées par ordre de priorité :

### 1. Utilisateur (user) - Priorité 10
**Description :** Utilisateur standard avec permissions de base

**Permissions :**
- Lire le contenu public
- Créer un compte
- Modifier son profil
- Créer des commandes
- Voir ses commandes
- Gérer son panier
- Gérer ses favoris
- Suivre des groupes

**Cas d'usage :** Tout utilisateur qui s'inscrit sur l'application

---

### 2. Traceur (tracker) - Priorité 20
**Description :** Utilisateur avec permissions de suivi de localisation

**Permissions héritées de "Utilisateur" +**
- Mettre à jour sa localisation
- Voir le suivi

**Cas d'usage :** Utilisateurs qui participent au système de tracking en direct (livreurs, guides, etc.)

---

### 3. Administrateur de Groupe (group) - Priorité 50
**Description :** Gestion complète d'un groupe spécifique

**Permissions héritées de "Utilisateur" +**
- Gérer les infos du groupe
- Gérer les produits du groupe
- Voir les commandes du groupe
- Voir les statistiques du groupe
- Gérer les membres du groupe

**Cas d'usage :** Responsable d'un groupe/association qui gère son espace sur la plateforme

**Note importante :** Un admin de groupe doit avoir un `groupId` assigné

---

### 4. Administrateur (admin) - Priorité 90
**Description :** Administrateur avec accès complet au système

**Permissions héritées de "Utilisateur" +**
- Gérer tous les groupes
- Gérer tous les utilisateurs
- Gérer tous les produits
- Gérer toutes les commandes
- Gérer les lieux
- Gérer les POIs
- Gérer les circuits
- Voir toutes les statistiques
- Modérer le contenu

**Cas d'usage :** Équipe administrative de MASLIVE

---

### 5. Super Administrateur (superAdmin) - Priorité 100
**Description :** Tous les droits sur le système

**Permissions :** TOUTES les permissions du système, incluant :
- Toutes les permissions des autres rôles
- Gérer les rôles
- Gérer les permissions
- Accès au panneau admin
- Supprimer n'importe quel contenu

**Cas d'usage :** Propriétaire/développeur principal de l'application

---

## Installation et Configuration

### 1. Déployer les règles Firestore

```bash
cd /workspaces/MASLIVE
firebase deploy --only firestore:rules
```

### 2. Déployer les Cloud Functions

```bash
cd /workspaces/MASLIVE
firebase deploy --only functions
```

### 3. Initialiser les rôles dans Firestore

**Option A : Via Cloud Function (recommandé)**

Une fois les fonctions déployées, appelez la fonction `initializeRoles` depuis votre application :

```dart
import 'package:cloud_functions/cloud_functions.dart';

Future<void> initializeRoles() async {
  try {
    final callable = FirebaseFunctions.instance
        .httpsCallable('initializeRoles');
    
    final result = await callable.call();
    
    print('Rôles initialisés: ${result.data}');
  } catch (e) {
    print('Erreur: $e');
  }
}
```

**Option B : Via le service Flutter**

```dart
import 'package:maslive/services/permission_service.dart';

// Initialiser les rôles par défaut
await PermissionService.instance.initializeDefaultRoles();
```

### 4. Créer un premier super administrateur

Depuis la console Firebase :
1. Allez dans Firestore Database
2. Trouvez votre utilisateur dans la collection `users`
3. Ajoutez/modifiez les champs :
   - `role: "superAdmin"`
   - `isAdmin: true`

---

## Utilisation dans l'Application Flutter

### Vérifier les permissions d'un utilisateur

```dart
import 'package:maslive/services/permission_service.dart';
import 'package:maslive/models/user_role_model.dart';

// Vérifier une permission spécifique
bool canManageProducts = await PermissionService.instance.hasPermission(
  userId,
  Permission.manageGroupProducts,
  groupId: 'group123',
);

// Vérifier plusieurs permissions
bool hasAny = await PermissionService.instance.hasAnyPermission(
  userId,
  [Permission.manageGroupInfo, Permission.manageAllGroups],
);

// Obtenir toutes les permissions d'un utilisateur
List<Permission> permissions = 
    await PermissionService.instance.getUserPermissions(userId);

// Obtenir un résumé complet
Map<String, dynamic> summary = 
    await PermissionService.instance.getUserPermissionsSummary(userId);
```

### Assigner un rôle à un utilisateur

**Méthode 1 : Via le service Flutter**

```dart
// Assigner le rôle "group" à un utilisateur
await PermissionService.instance.assignRole(
  userId: 'user123',
  roleType: UserRoleType.group,
  groupId: 'group456', // Requis pour le rôle groupe
);

// Assigner le rôle "admin"
await PermissionService.instance.assignRole(
  userId: 'user789',
  roleType: UserRoleType.admin,
);
```

**Méthode 2 : Via Cloud Function**

```dart
import 'package:cloud_functions/cloud_functions.dart';

final callable = FirebaseFunctions.instance
    .httpsCallable('assignUserRole');

await callable.call({
  'targetUserId': 'user123',
  'role': 'group',
  'groupId': 'group456', // Optionnel sauf pour rôle groupe
});
```

### Protéger des actions dans l'interface

```dart
// Exemple : Afficher un bouton uniquement si l'utilisateur a la permission
FutureBuilder<bool>(
  future: PermissionService.instance.hasPermission(
    currentUserId,
    Permission.manageGroupProducts,
    groupId: currentGroupId,
  ),
  builder: (context, snapshot) {
    if (snapshot.data == true) {
      return ElevatedButton(
        onPressed: () => addProduct(),
        child: Text('Ajouter un produit'),
      );
    }
    return SizedBox.shrink();
  },
)
```

---

## Règles Firestore

Les règles Firestore ont été améliorées pour utiliser le système de permissions. Voici les principales fonctions helper :

```javascript
// Vérifie si l'utilisateur est un super admin
isSuperAdmin()

// Vérifie si l'utilisateur est admin ou super admin
isMasterAdmin()

// Vérifie si l'utilisateur peut gérer un groupe spécifique
canManageGroup(groupId)

// Vérifie si l'utilisateur peut voir les données d'un groupe
canViewGroupData(groupId)

// Vérifie si l'utilisateur peut gérer le contenu
canManageContent()
```

---

## Permissions Détaillées

### Permissions de base
- `readPublicContent` : Lire le contenu public
- `createAccount` : Créer un compte
- `updateOwnProfile` : Modifier son profil

### Permissions utilisateur
- `createOrder` : Créer des commandes
- `viewOwnOrders` : Voir ses commandes
- `manageCart` : Gérer son panier
- `manageFavorites` : Gérer ses favoris
- `followGroups` : Suivre des groupes

### Permissions traceur
- `updateLocation` : Mettre à jour sa localisation
- `viewTracking` : Voir le suivi

### Permissions groupe
- `manageGroupInfo` : Gérer les infos du groupe
- `manageGroupProducts` : Gérer les produits du groupe
- `viewGroupOrders` : Voir les commandes du groupe
- `viewGroupStats` : Voir les stats du groupe
- `manageGroupMembers` : Gérer les membres du groupe

### Permissions admin
- `manageAllGroups` : Gérer tous les groupes
- `manageAllUsers` : Gérer tous les utilisateurs
- `manageAllProducts` : Gérer tous les produits
- `manageAllOrders` : Gérer toutes les commandes
- `managePlaces` : Gérer les lieux
- `managePOIs` : Gérer les POIs
- `manageCircuits` : Gérer les circuits
- `viewAllStats` : Voir toutes les statistiques
- `moderateContent` : Modérer le contenu

### Permissions super admin
- `manageRoles` : Gérer les rôles
- `managePermissions` : Gérer les permissions
- `accessAdminPanel` : Accès au panneau admin
- `deleteAnyContent` : Supprimer n'importe quel contenu

---

## Structure Firestore

### Collection `roles`
Contient les définitions de rôles :

```javascript
{
  "user": {
    "id": "user",
    "name": "Utilisateur",
    "description": "Utilisateur standard avec permissions de base",
    "roleType": "user",
    "priority": 10,
    "permissions": ["readPublicContent", "createAccount", ...],
    "isActive": true,
    "createdAt": Timestamp,
    "updatedAt": Timestamp
  },
  // ... autres rôles
}
```

### Collection `users` (modifications)
Les documents utilisateurs incluent maintenant :

```javascript
{
  "uid": "user123",
  "email": "user@example.com",
  "displayName": "John Doe",
  "role": "user", // ou "tracker", "group", "admin", "superAdmin"
  "groupId": null, // ou "group456" pour les admins de groupe
  "isAdmin": false, // true pour admin et superAdmin (rétrocompatibilité)
  // ... autres champs
}
```

---

## Migration depuis l'ancien système

Si vous avez des utilisateurs existants avec l'ancien système de rôles :

1. Les utilisateurs avec `isAdmin: true` seront automatiquement reconnus comme admins
2. Les utilisateurs avec `role: "admin"` fonctionneront avec le nouveau système
3. Les utilisateurs sans rôle défini seront considérés comme "user"

Pour migrer complètement :

```dart
// Script de migration (à exécuter une fois)
Future<void> migrateUserRoles() async {
  final usersSnapshot = await FirebaseFirestore.instance
      .collection('users')
      .get();
  
  final batch = FirebaseFirestore.instance.batch();
  
  for (final doc in usersSnapshot.docs) {
    final data = doc.data();
    if (!data.containsKey('role') || data['role'] == null) {
      // Assigner le rôle par défaut
      batch.update(doc.reference, {'role': 'user'});
    }
  }
  
  await batch.commit();
}
```

---

## Bonnes Pratiques

1. **Principe du moindre privilège** : Attribuez toujours le rôle le plus restrictif possible
2. **Vérification côté serveur** : Les permissions sont vérifiées dans les règles Firestore ET dans les Cloud Functions
3. **Ne jamais faire confiance au client** : Toujours valider les permissions côté serveur
4. **Audit trail** : Les modifications de rôles sont timestampées (updatedAt)
5. **Groupes dédiés** : Les admins de groupe doivent toujours avoir un groupId défini

---

## Dépannage

### Erreur "permission-denied" lors de l'initialisation des rôles
- Vérifiez que votre utilisateur a le rôle `superAdmin` dans Firestore
- Vérifiez que les Cloud Functions sont déployées

### Un utilisateur ne peut pas accéder à une ressource
- Vérifiez son rôle dans Firestore
- Utilisez `getUserPermissionsSummary()` pour voir ses permissions
- Vérifiez que le `groupId` est correctement défini pour les admins de groupe

### Les règles Firestore rejettent les requêtes
- Vérifiez que les règles sont déployées : `firebase deploy --only firestore:rules`
- Consultez les logs dans la console Firebase

---

## Support et Contact

Pour toute question ou problème avec le système de permissions, contactez l'équipe de développement MASLIVE.

**Fichiers clés :**
- Modèle : `/app/lib/models/user_role_model.dart`
- Service : `/app/lib/services/permission_service.dart`
- Règles : `/firestore.rules`
- Cloud Functions : `/functions/index.js`
