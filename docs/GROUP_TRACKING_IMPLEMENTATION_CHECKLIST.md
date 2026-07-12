# Checklist validation tracking groupe

## Flutter

```bash
cd /workspaces/MASLIVE/app
flutter analyze
flutter test test/security/role_normalizer_test.dart
```

## Functions

```bash
cd /workspaces/MASLIVE/functions
node -c group_tracking.js
npm test -- --test-name-pattern="tracking|group"
```

## Tests manuels

1. Démarrer un tracker et vérifier un premier point immédiat.
2. Marcher : vérifier une cadence proche de 15 s, pas une écriture tous les 5 m.
3. Rester immobile : vérifier un heartbeat autour de 60 s.
4. Arrêter : vérifier disparition de `group_positions/{groupId}/members/{uid}`.
5. Avec 3 à 5 trackers : vérifier `qualityStatus=good|optimal`.
6. Démarrer l'Admin Groupe seul : vérifier `source=admin_fallback_only`.
7. Ajouter deux trackers : vérifier `source=trackers` et `adminFallbackUsed=false`.
8. Simuler un tracker très éloigné : vérifier `outliersRemoved > 0`.
9. Simuler un saut >150 m : vérifier `qualityStatus=jump_pending`, puis confirmation au second point cohérent.
10. Vérifier que le document circuit n'est pas réécrit si déplacement <5 m avant 30 s.
