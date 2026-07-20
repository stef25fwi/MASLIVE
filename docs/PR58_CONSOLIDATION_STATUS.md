# Consolidation PR #58

Cette branche repart du `main` ayant intégré les PR #47 à #57 et ne reprend que les éléments encore utiles de la PR #40.

## Câblage appliqué

- export Firebase de `submitCommerceForReview` depuis `firebase-entrypoint.js` ;
- soumission commerciale transactionnelle et idempotente côté serveur ;
- contrôle du propriétaire et du rôle déclaré ;
- contrôle du SIRET et du statut vendeur ;
- contrôle Stripe Connect (`accountId`, `detailsSubmitted`, `chargesEnabled`, `payoutsEnabled`) ;
- appel de la Function en région `us-east1` depuis `CommerceService` ;
- interdiction des transitions clientes directes vers `pending` ;
- propriétaire, rôle et statut protégés par les règles Firestore ;
- journal privé et versionné du consentement tracking.

## Validation requise avant fusion

- Quality Gates ;
- tests Functions ;
- analyse et tests Flutter ;
- build Flutter Web ;
- déploiement Firebase et vérification du manifeste après fusion.
