# ✅ PRE-PRODUCTION CHECKLIST

## 📋 Avant le déploiement

- [ ] Lire TASK_SUMMARY.md
- [ ] Vérifier toutes les 5 tâches sont "ready"
- [ ] Avoir accès au compte Firebase
- [ ] Avoir Firebase CLI installé (`firebase --version`)
- [ ] Être connecté Firebase: `firebase login`

---

## 🚀 Déploiement (10 min)

### Option 1: Script automatisé (recommandé)
```bash
chmod +x deploy.sh
./deploy.sh
```

### Option 2: Commandes manuelles
```bash
firebase deploy --only functions:calculateGroupAveragePosition
firebase deploy --only firestore:rules
firebase deploy --only storage
```

### ✅ Vérifier après
```bash
firebase functions:log --lines 20
# Chercher: "Calcul position moyenne" ou erreurs
```

---

## 🧪 Tests rapides (15 min)

### Test 1: Admin creation
- [ ] Ouvrir `/group-admin`
- [ ] Vérifier code 6 chiffres affiché
- [ ] Code doit être unique et lisible

### Test 2: Tracker linking
- [ ] Ouvrir `/group-tracker`
- [ ] Entrer code du Test 1
- [ ] Cliquer "Se rattacher"
- [ ] Vérifier "Rattaché" affiché

### Test 3: GPS tracking
- [ ] Autoriser GPS quand demandé
- [ ] Simuler position (si émulateur)
- [ ] Vérifier Firestore: positions écrites
- [ ] Admin doit voir tracker "Online"

### Test 4: Position moyenne
- [ ] Avoir 2+ trackers en suivi
- [ ] Attendre Cloud Function (~2-3 sec)
- [ ] Vérifier Firebase: `group_admins.averagePosition` calculée
- [ ] Vérifier logs: `firebase functions:log`

### Test 5: Live map
- [ ] Ouvrir `/group-live`
- [ ] Vérifier 1 marqueur unique
- [ ] Simuler mouvement
- [ ] Vérifier marqueur se met à jour

### Test 6: Exports
- [ ] Ouvrir `/group-export`
- [ ] Sélectionner session
- [ ] Exporter CSV
- [ ] Vérifier fichier téléchargé avec données

---

## 🎯 Tests E2E complets (60 min)

Consulter: [E2E_TESTS_GUIDE.md](E2E_TESTS_GUIDE.md)

| # | Test | Durée |
|----|------|-------|
| 1 | Admin code créé | 5 min |
| 2 | Tracker rattaché | 5 min |
| 3 | GPS tracking | 10 min |
| 4 | Position moyenne | 10 min |
| 5 | Exports CSV/JSON | 10 min |
| 6 | Permissions GPS | 5 min |
| 7 | Carte live | 10 min |
| 8 | Bar chart stats | 5 min |

---

## 🛡️ Vérifications finales

### Sécurité
- [ ] Firestore Rules déployées
  ```bash
  firebase firestore:indexes:list
  ```
- [ ] Storage Rules déployées
  ```bash
  firebase storage:get
  ```
- [ ] Cloud Function exécutée sans erreur
  ```bash
  firebase functions:log
  ```

### Performance
- [ ] Cloud Function latency < 2 sec
- [ ] UI responsive (pas de lag)
- [ ] Carte loads correctly

### Data integrity
- [ ] Admin code unique
- [ ] Tracker rattachement persiste
- [ ] Positions écrites correctement
- [ ] Position moyenne calculée
- [ ] Exports complets et exacts

---

## 📊 Validation globale

- [ ] Toutes les 5 routes fonctionnent
- [ ] Tous les 6 tests rapides passent
- [ ] Cloud Function exécutée avec succès
- [ ] Firestore Rules appliquées
- [ ] Storage Rules appliquées
- [ ] GPS permissions OK (Android + iOS)
- [ ] Pas d'erreurs dans `firebase functions:log`
- [ ] Pas de "Permission denied" Firestore
- [ ] Pas de erreurs de compilation

---

## 🆘 Troubleshooting rapide

| Problème | Solution |
|----------|----------|
| "Permission denied" | Vérifier Firestore Rules + UID authentification |
| Cloud Function ne trigger pas | Vérifier chemin collection + logs |
| averagePosition null | Vérifier Cloud Function logs |
| GPS ne marche pas | Vérifier manifest Android + Info.plist iOS |
| Exports vides | Vérifier group_tracks/.../points créés |
| Carte vide | Vérifier Mapbox token (dart-define) |

Détails complets: [DEPLOYMENT_COMMANDS.md](DEPLOYMENT_COMMANDS.md)

---

## 🎯 Rollback (si besoin)

```bash
# Rollback Cloud Function
firebase deploy --only functions --delete-missing-functions

# Rollback Firestore Rules (restore previous version)
# Manuelle via Firebase Console ou git revert

# Check deployment status
firebase deploy:list
```

---

## 📝 Log all validations

```bash
# Créer un fichier de log
echo "🚀 Déploiement Group Tracking - $(date)" > deployment.log

# Logs Cloud Function
firebase functions:log >> deployment.log

# Status
firebase deploy:list >> deployment.log

# Review
cat deployment.log
```

---

## ✨ Final checklist before "Production Ready"

- [ ] All 6 quick tests passed
- [ ] All 8 E2E tests passed
- [ ] No errors in logs
- [ ] Firestore data verified
- [ ] Cloud Function working
- [ ] Security rules applied
- [ ] GPS permissions OK
- [ ] Performance acceptable
- [ ] Documentation reviewed
- [ ] Team notified

---

## 🎉 GO/NO-GO Decision

```
✅ GO FOR PRODUCTION if:
   - All tests passed
   - No critical errors
   - All rules deployed
   - Cloud Function working

❌ NO-GO if:
   - Any test failed
   - Critical errors in logs
   - Permission issues
   - Cloud Function not executing
```

---

## 📞 Support contacts

- **Firebase Issues**: [firebase.google.com/support](https://firebase.google.com/support)
- **Flutter Issues**: [github.com/flutter/flutter/issues](https://github.com/flutter/flutter/issues)
- **Geolocator**: [pub.dev/packages/geolocator](https://pub.dev/packages/geolocator)
- **FL_CHART**: [pub.dev/packages/fl_chart](https://pub.dev/packages/fl_chart)

---

## 📚 Reference documents

- [TASK_SUMMARY.md](TASK_SUMMARY.md) - Overview of 5 tasks
- [E2E_TESTS_GUIDE.md](E2E_TESTS_GUIDE.md) - Complete test guide
- [SYSTEM_ARCHITECTURE_VISUAL.md](SYSTEM_ARCHITECTURE_VISUAL.md) - Architecture
- [DEPLOYMENT_COMMANDS.md](DEPLOYMENT_COMMANDS.md) - Detailed commands
- [DEPLOY_NOW.md](DEPLOY_NOW.md) - Quick copy/paste

---

**Status**: ✅ READY FOR DEPLOYMENT  
**Timeline**: 1-2 hours to 100% operational  
**Last updated**: 04/02/2025

🚀 **Let's ship it!**
