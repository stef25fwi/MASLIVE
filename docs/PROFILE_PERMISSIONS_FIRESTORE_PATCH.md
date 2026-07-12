# Patch Firestore — profils, droits et demandes Admin Groupe

Ce patch complète l'implémentation des profils/droits côté Flutter. Il doit être reporté dans `firestore.rules` avant déploiement des règles.

## 1. Rôles canoniques à conserver

Les documents `users/{uid}` doivent progressivement migrer vers :

```text
user
tracker
group
admin
superAdmin
```

Alias encore acceptés en lecture pendant migration :

```text
superadmin, super-admin, super_admin -> superAdmin
admin_groupe, admin_group, group-admin -> group
tracker_groupe, tracker-group -> tracker
```

## 2. Collection `group_admin_requests`

À ajouter près des règles `users` / `group_admins` :

```javascript
match /group_admin_requests/{uid} {
  allow read: if isSignedIn() && (
    request.auth.uid == uid || isMasterAdmin()
  );

  allow create: if isSignedIn()
    && request.auth.uid == uid
    && request.resource.data.requestUid == uid
    && request.resource.data.status == 'pending'
    && request.resource.data.keys().hasOnly([
      'requestUid',
      'displayName',
      'email',
      'status',
      'requestedAt',
      'updatedAt',
      'reviewedAt',
      'reviewedBy',
      'rejectionReason'
    ])
    && !request.resource.data.keys().hasAny([
      'adminGroupId',
      'role',
      'groupId',
      'isAdmin'
    ]);

  allow update: if isMasterAdmin() || (
    isSignedIn()
    && request.auth.uid == uid
    && resource.data.status in ['pending', 'rejected']
    && request.resource.data.requestUid == resource.data.requestUid
    && request.resource.data.status == 'pending'
    && !request.resource.data.keys().hasAny([
      'adminGroupId',
      'role',
      'groupId',
      'isAdmin',
      'reviewedAt',
      'reviewedBy'
    ])
  );

  allow delete: if isMasterAdmin() || (
    isSignedIn()
    && request.auth.uid == uid
    && resource.data.status in ['pending', 'rejected']
  );
}
```

## 3. Commerce submissions : remplacer les checks legacy

Dans `match /commerce_submissions/{submissionId}`, remplacer le helper `canSubmitCommerce()` par :

```javascript
function canSubmitCommerce() {
  return hasUserDoc() && (
    isMasterAdmin()
    || userRole() == 'group'
    || userRole() == 'group-admin'
    || userRole() == 'admin_group'
    || userRole() == 'admin_groupe'
    || (getUserData().accountType == 'pro' && getUserData().keys().hasAny(['activities']))
    || userRole() == 'superAdmin'
    || userRole() == 'superadmin'
  );
}
```

Remplacer aussi `canModerate()` par :

```javascript
function canModerate() {
  return isMasterAdmin()
    || ((userRole() == 'group'
        || userRole() == 'group-admin'
        || userRole() == 'admin_group'
        || userRole() == 'admin_groupe')
      && resource.data.scopeType == 'group'
      && (
        (getUserData().keys().hasAny(['managedScopeIds'])
          && getUserData().managedScopeIds.hasAny([resource.data.scopeId]))
        || userGroupId() == resource.data.scopeId
      ));
}
```

## 4. Déploiement

```bash
firebase deploy --only firestore:rules
```

## 5. Vérifications emulator recommandées

Voir `docs/PROFILE_PERMISSIONS_TEST_PLAN.md`.
