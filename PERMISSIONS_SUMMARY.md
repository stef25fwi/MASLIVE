# Système de Catégories d'Utilisateurs - Résumé d'Implémentation

## ✅ Ce qui a été créé

### 1. Modèles de données (`/app/lib/models/user_role_model.dart`)
- **5 catégories d'utilisateurs** avec hiérarchie de priorités
- **24 permissions** granulaires organisées par catégorie
- Définitions complètes des rôles par défaut
- Extensions pour l'affichage des permissions

### 2. Service de gestion (`/app/lib/services/permission_service.dart`)
- Vérification des permissions utilisateur
- Attribution et gestion des rôles
- Cache intelligent des définitions
- Méthodes pour vérifier les droits de gestion

### 3. Widgets d'interface (`/app/lib/widgets/permission_widgets.dart`)
- `PermissionGuard` : afficher du contenu selon une permission
- `AnyPermissionGuard` : afficher si au moins une permission
- `AllPermissionsGuard` : afficher si toutes les permissions
- `RoleGuard` : afficher selon le rôle
- `UserPermissionsBuilder` : builder avec les permissions
- Extension `PermissionContext` pour faciliter les vérifications

### 4. Pages d'administration (`/app/lib/pages/role_management_page.dart`)
- `RoleManagementPage` : gestion des définitions de rôles
- `UserRolesManagementPage` : attribution de rôles aux utilisateurs
- Interface complète pour visualiser et modifier les rôles

### 5. Règles Firestore (`/firestore.rules`)
- Règles améliorées avec fonctions helper
- Permissions granulaires par collection
- Support des hiérarchies de rôles
- Protection de la collection `roles`

### 6. Cloud Functions (`/functions/index.js`)
- `initializeRoles` : initialiser les rôles par défaut
- `assignUserRole` : attribuer un rôle à un utilisateur
- Validation des permissions côté serveur

### 7. Documentation
- `ROLES_AND_PERMISSIONS.md` : documentation complète
- `scripts/init_permissions.sh` : script d'initialisation

## 📊 Les 5 Catégories d'Utilisateurs

| Rôle | Priorité | Description | Cas d'usage |
|------|----------|-------------|-------------|
| **Utilisateur** | 10 | Permissions de base | Tout utilisateur inscrit |
| **Traceur** | 20 | + localisation | Livreurs, guides |
| **Admin Groupe** | 50 | Gère un groupe spécifique | Responsable d'association |
| **Admin** | 90 | Gère tout le système | Équipe MASLIVE |
| **Super Admin** | 100 | Tous les droits | Propriétaire/Développeur |

## 🎯 Exemples d'Utilisation

### Dans l'interface Flutter

```dart
// Afficher un bouton uniquement pour les admins
PermissionGuard(
  permission: Permission.manageAllUsers,
  child: ElevatedButton(
    onPressed: () => manageUsers(),
    child: Text('Gérer les utilisateurs'),
  ),
)

// Attribuer un rôle
await PermissionService.instance.assignRole(
  userId: 'user123',
  roleType: UserRoleType.group,
  groupId: 'group456',
);

// Vérifier une permission
bool canEdit = await context.hasPermission(
  Permission.manageGroupProducts,
  groupId: currentGroupId,
);
```

### Dans les règles Firestore

```javascript
// Vérifier si l'utilisateur peut gérer un groupe
allow update: if canManageGroup(groupId);

// Vérifier si l'utilisateur peut voir les données d'un groupe
allow read: if canViewGroupData(groupId);

// Vérifier si l'utilisateur est admin
allow write: if canManageContent();
```

## 🚀 Déploiement

### Étape 1: Déployer les règles et fonctions

```bash
# Depuis la racine du projet
firebase deploy --only firestore:rules,functions
```

### Étape 2: Créer un super administrateur

Dans la console Firebase > Firestore > users > [votre-utilisateur]:
```javascript
{
  "role": "superAdmin",
  "isAdmin": true
}
```

### Étape 3: Initialiser les rôles

Depuis votre application:
```dart
await PermissionService.instance.initializeDefaultRoles();
```

Ou via Cloud Function:
```dart
final callable = FirebaseFunctions.instance.httpsCallable('initializeRoles');
await callable.call();
```

## 📁 Structure des Collections Firestore

### Collection `roles`
```javascript
{
  "user": {
    "name": "Utilisateur",
    "description": "...",
    "roleType": "user",
    "priority": 10,
    "permissions": ["readPublicContent", ...],
    "isActive": true,
    "createdAt": Timestamp
  }
}
```

### Collection `users` (modifié)
```javascript
{
  "uid": "user123",
  "email": "user@example.com",
  "role": "user", // ou tracker, group, admin, superAdmin
  "groupId": null, // pour les admins de groupe
  "isAdmin": false // pour rétrocompatibilité
}
```

## 🔒 Sécurité

- ✅ Vérifications côté client (UX)
- ✅ Vérifications dans les règles Firestore (sécurité)
- ✅ Vérifications dans les Cloud Functions (logique métier)
- ✅ Principe du moindre privilège
- ✅ Audit trail (updatedAt sur les modifications)

## 📝 Permissions Disponibles

### Base (3)
- readPublicContent, createAccount, updateOwnProfile

### Utilisateur (5)
- createOrder, viewOwnOrders, manageCart, manageFavorites, followGroups

### Traceur (2)
- updateLocation, viewTracking

### Groupe (5)
- manageGroupInfo, manageGroupProducts, viewGroupOrders, viewGroupStats, manageGroupMembers

### Admin (9)
- manageAllGroups, manageAllUsers, manageAllProducts, manageAllOrders, managePlaces, managePOIs, manageCircuits, viewAllStats, moderateContent

### Super Admin (4)
- manageRoles, managePermissions, accessAdminPanel, deleteAnyContent

## 🛠️ Maintenance

### Ajouter une nouvelle permission

1. Ajouter dans `Permission` enum ([user_role_model.dart](app/lib/models/user_role_model.dart))
2. Ajouter dans `displayName` et `category` extensions
3. Mettre à jour les `RoleDefinition.default*Role`
4. Mettre à jour les Cloud Functions
5. Redéployer les règles si nécessaire

### Modifier un rôle existant

```dart
// Récupérer le rôle
final role = await PermissionService.instance.getRoleDefinition('user');

// Modifier (créer une nouvelle instance)
final updatedRole = RoleDefinition(
  id: role!.id,
  name: role.name,
  description: 'Nouvelle description',
  roleType: role.roleType,
  permissions: [...role.permissions, Permission.newPermission],
  priority: role.priority,
  createdAt: role.createdAt,
  updatedAt: DateTime.now(),
);

// Sauvegarder (nécessite superAdmin)
await PermissionService.instance.saveRoleDefinition(updatedRole);
```

## 📞 Support

Pour toute question ou problème:
1. Consultez [ROLES_AND_PERMISSIONS.md](ROLES_AND_PERMISSIONS.md)
2. Vérifiez les logs Firebase Console
3. Utilisez `getUserPermissionsSummary()` pour déboguer

## ✨ Avantages du Système

- ✅ **Extensible** : facile d'ajouter de nouveaux rôles/permissions
- ✅ **Sécurisé** : vérifications multi-niveaux
- ✅ **Flexible** : permissions granulaires
- ✅ **Performant** : cache des définitions
- ✅ **Maintenable** : code bien structuré et documenté
- ✅ **Rétrocompatible** : fonctionne avec l'ancien système isAdmin

---

**Créé le:** 20 janvier 2026
**Version:** 1.0.0
**Projet:** MASLIVE
