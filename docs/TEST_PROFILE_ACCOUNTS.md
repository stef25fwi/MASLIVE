# Comptes de test MASLIVE

Le script `functions/scripts/seed-test-profile-accounts.js` crée ou met à jour les sept profils fonctionnels.

| N° | Profil | E-mail |
|---:|---|---|
| 1 | Utilisateur | `ilipresto1@mail.fr` |
| 2 | Artisan d’art / Bloom Art | `ilipresto2@mail.fr` |
| 3 | Créateur digital | `ilipresto3@mail.fr` |
| 4 | Tracker Groupe | `ilipresto4@mail.fr` |
| 5 | Admin Groupe | `ilipresto5@mail.fr` |
| 6 | Admin MASLIVE | `ilipresto6@mail.fr` |
| 7 | SuperAdmin | `ilipresto7@mail.fr` |

Le Tracker et l’Admin Groupe utilisent le groupe de test `900001`.

## Exécution sur les émulateurs

```bash
cd functions
export TEST_PROFILE_PASSWORD='IliprestoTest1!'
export FIREBASE_AUTH_EMULATOR_HOST='127.0.0.1:9099'
export FIRESTORE_EMULATOR_HOST='127.0.0.1:8080'
npm run seed:test-profiles
```

## Exécution volontaire sur un projet Firebase

Cette opération crée de vrais comptes Firebase Auth et de vrais documents Firestore. Elle est bloquée tant que l’autorisation explicite n’est pas fournie.

```bash
cd functions
export TEST_PROFILE_PASSWORD='IliprestoTest1!'
export ALLOW_TEST_PROFILE_SEED='true'
npm run seed:test-profiles
```

Les documents créés portent `isTestAccount: true` afin de pouvoir les identifier et les supprimer ensuite.

Ne pas utiliser le mot de passe d’exemple sur une application publique. Définir un mot de passe temporaire d’au moins 12 caractères, puis supprimer ou désactiver les comptes après la recette.
