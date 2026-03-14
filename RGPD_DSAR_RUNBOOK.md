# RGPD/DSAR Runbook (MASLIVE)

Ce document formalise la gestion des demandes RGPD (DSAR): export, suppression et traçabilité.

## 1) Portée

- Backend: Firebase Auth, Firestore, Firebase Storage, Cloud Functions.
- Fonctionnalités concernées:
  - exportMyPersonalData (callable)
  - deleteMyAccountGdpr (callable)
- Journal d'audit: collection Firestore gdpr_requests.

## 2) Flux techniques implémentés

### 2.1 Export des données personnelles

- Callable: exportMyPersonalData
- Auth requise: oui (utilisateur connecté)
- Résultat: payload JSON incluant:
  - metadata (generatedAt, uid)
  - auth (email, providerIds, metadata de compte)
  - firestore.profile
  - firestore.subCollections (docs + count + truncated)

### 2.2 Suppression de compte (droit a l'oubli)

- Callable: deleteMyAccountGdpr
- Auth requise: oui (utilisateur connecté)
- Etapes backend:
  1. Création d'une entrée gdpr_requests (status=processing)
  2. Suppression des prefixes Storage user-scoped
  3. Suppression recursive Firestore de users/{uid}
  4. Suppression du compte Firebase Auth
  5. Mise a jour gdpr_requests (status=completed ou failed)

## 3) Journal d'audit RGPD (preuve)

Collection: gdpr_requests

Champs minimum attendus:
- uid: string
- type: export | delete
- status: processing | completed | failed
- createdAt: timestamp serveur
- completedAt: timestamp serveur (si completed)
- updatedAt: timestamp serveur (si failed/retry)
- errorCode: string|null (si failed)

### 3.1 Requetes de controle (Firestore)

- Dernieres suppressions completees:
  - where(type=="delete")
  - where(status=="completed")
  - orderBy(createdAt, desc)

- Demandes en echec a reprendre:
  - where(status=="failed")
  - orderBy(createdAt, desc)

- Demandes export completees par utilisateur:
  - where(type=="export")
  - where(uid=="<UID>")

## 4) Procedure operationnelle production (SOP)

### 4.1 Reception de demande DSAR

- Canaux acceptes: in-app (prioritaire) et support.
- Ticket obligatoire avec:
  - requestId interne
  - uid (si connu)
  - type (export/delete)
  - date/heure de reception

### 4.2 Verification d'identite

- In-app authentifie: verification implicite via Firebase Auth.
- Support hors app:
  - verifier email + preuve de possession du compte
  - ne jamais traiter sans verification forte.

### 4.3 Delais cibles

- Accuse de reception: < 72h.
- Traitement: <= 30 jours (RGPD standard).
- Extension exceptionnelle: +60 jours avec justification tracee.

### 4.4 Execution

- Export:
  1. Demander a l'utilisateur d'utiliser exportMyPersonalData.
  2. Si demande support, lancer procedure interne et transmettre reponse DSAR.

- Suppression:
  1. Inviter l'utilisateur a lancer deleteMyAccountGdpr depuis l'app.
  2. Verifier l'entree gdpr_requests status=completed.
  3. Verifier absence du user en Auth et users/{uid} en Firestore.

### 4.5 Verification post-traitement

Checklist suppression:
- Utilisateur absent de Firebase Auth.
- users/{uid} absent en Firestore.
- Sous-collections users/{uid} absentes.
- Prefix Storage user-scoped nettoyes.
- gdpr_requests status=completed.

### 4.6 Communication utilisateur

- Utiliser le template DSAR standard (voir RGPD_DSAR_RESPONSE_TEMPLATE.json).
- Mentionner date de traitement et perimetre traite.

## 5) Gestion des incidents

### 5.1 Echec suppression (status=failed)

- Actions:
  1. Lire errorCode dans gdpr_requests.
  2. Corriger la cause (permissions, ressource bloquee, quota).
  3. Relancer la suppression via support securise.
  4. Journaliser la reprise (nouvelle entree ou mise a jour tracee).

### 5.2 Donnees residuelles detectees

- Ouvrir incident securite niveau medium.
- Purger residus sous 24h.
- Ajouter post-mortem et action preventive.

## 6) Limites connues et decisions

- Les exports sont limites en volume par sous-collection (protection anti payload massif).
- Les donnees strictement comptables/fiscales peuvent etre conservees selon obligations legales, hors profil actif utilisateur.
- Les journaux techniques de securite peuvent etre conserves de facon minimisee et conformes aux obligations en vigueur.

## 7) Matrice de responsabilites (RACI)

- Produit: validation de la reponse DSAR
- Engineering: execution technique et verification
- Security/Compliance: revue de conformite et audit periodique
- Support: reception, suivi, communication utilisateur

## 8) Evidence pack audit (a conserver)

- Copie de la demande (ticket/requestId)
- Extrait gdpr_requests correspondant
- Horodatage execution
- Preuve de verification post-traitement
- Reponse envoyee a l'utilisateur

## 9) Revue periodique

- Mensuel:
  - taux de success/fail gdpr_requests
  - delai moyen de traitement
- Trimestriel:
  - test de bout en bout export + suppression sur compte de test
  - validation de la procedure et mise a jour du runbook
