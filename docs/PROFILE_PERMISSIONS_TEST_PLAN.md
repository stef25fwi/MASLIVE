# Plan de test — profils utilisateurs et droits MASLIVE

## Commandes rapides

Depuis `app/` :

```bash
flutter test test/security/role_normalizer_test.dart
flutter analyze
```

Après report du patch Firestore :

```bash
firebase emulators:start --only firestore,auth
firebase emulators:exec --only firestore "npm test -- --profile-permissions"
```

> Le repo n'avait pas encore de harness Jest/Mocha Firestore Rules dédié. Cette PR ajoute un test Flutter pur pour la normalisation et documente les cas emulator à convertir en tests automatisés dès que le harness Rules est ajouté.

## Matrice de scénarios à valider

| Profil | Action | Résultat attendu |
|---|---|---|
| `user` | Modifier son `displayName`, `photoUrl`, `phone`, `region` | Autorisé |
| `user` | Modifier `role`, `isAdmin`, `groupId` | Refusé |
| `user` | Créer `group_admin_requests/{uid}` en `pending` | Autorisé |
| `user` | Créer directement `group_admins/{uid}` | Refusé |
| `tracker` | Écrire sa position dans son groupe | Autorisé |
| `tracker` | Gérer membres ou boutique groupe | Refusé |
| `group` | Lire trackers de son `adminGroupId` | Autorisé |
| `group` | Gérer boutique groupe de son `adminGroupId` | Autorisé |
| `group` | Accéder dashboard admin global | Refusé |
| `admin` | Modérer contenus et demandes Pro | Autorisé |
| `admin` | Modifier rôles système | Refusé |
| `superAdmin` | Modifier rôles système et supprimer contenu sensible | Autorisé |

## Points de non-régression

- `isAdmin=true` ne doit plus donner `Permission.values` côté client.
- Les alias legacy restent lus, mais toute écriture applicative doit utiliser les rôles canoniques.
- La page profil ne doit plus afficher de nom codé en dur.
- Les tuiles profil doivent disparaître si la capacité correspondante est absente.
- Les routes admin doivent passer par `AdminRouteGuard` / `AdminGate` avec capacité.
