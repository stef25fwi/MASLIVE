# Gestion centralisée des comptes SuperAdmin

## Accès

Depuis le profil SuperAdmin :

- **Admin Groupe & Trackers** ouvre la vue filtrée sur les comptes groupe et tracker ;
- **Tous les utilisateurs** ouvre la recherche globale.

## Actions disponibles

- rechercher par nom, email, UID, rôle ou code groupe ;
- créer un Utilisateur, un Admin MASLIVE, un Admin Groupe ou un Tracker ;
- rattacher un Tracker à un code Admin Groupe existant ;
- générer et afficher le QR code du groupe ;
- régénérer un code groupe en migrant les Trackers existants ;
- modifier nom, email, rôle, mot de passe et statut actif ;
- désactiver ou réactiver un compte ;
- supprimer un compte avec confirmation explicite.

## Sécurité

Les écritures sensibles passent par les Cloud Functions :

- `searchManagedUsers`
- `createManagedUser`
- `updateManagedUser`
- `regenerateManagedGroupCode`
- `deleteManagedUser`

Chaque fonction vérifie le rôle Firestore `superAdmin`. Les opérations sont journalisées dans `admin_audit_logs`. La suppression du compte SuperAdmin courant et la suppression d’un autre SuperAdmin sont bloquées.

Les QR codes contiennent uniquement le type de rattachement, le code groupe et le nom du groupe. Aucun mot de passe n’est intégré au QR code.

## Déploiement

Après fusion :

```bash
cd /workspaces/MASLIVE
git checkout main
git pull origin main

cd app
flutter analyze
flutter test

cd ../functions
npm test

cd ..
firebase deploy --only functions,hosting
```
