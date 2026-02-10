# 🚀 CHECKLIST DÉPLOIEMENT - Group Map Visibility Feature

**Date**: 04/02/2026  
**Feature**: Visibilité groupe sur cartes avec toggles  
**Durée estimée**: 15-20 minutes  

---

## ✅ Phase 1: Préparation (5 min)

- [ ] **Vérifier branch**: `git branch` → doit être `main`
- [ ] **Vérifier status git**: `git status` → doit être clean
- [ ] **Lire log récents**: `git log --oneline -5` → derniers commits visibles
- [ ] **Vérifier pubspec**: `cat app/pubspec.yaml | grep -A 5 "dependencies"`

**Commandes**:
```bash
cd /workspaces/MASLIVE
git branch
git status
git log --oneline -5
```

---

## ✅ Phase 2: Installation dépendances (3 min)

### 2.1 Flutter pub get

```bash
cd /workspaces/MASLIVE/app
flutter pub get
```

**Expected output**:
```
Running "flutter pub get" in app...
Running Pub offline...
Got dependencies in X.Xs.
```

- [ ] ✅ Pas d'erreurs
- [ ] ✅ `pubspec.lock` mis à jour

### 2.2 Build runner (Hive adapters)

```bash
cd /workspaces/MASLIVE/app
flutter pub run build_runner build --delete-conflicting-outputs
```

**Expected output**:
```
[INFO] Building new asset graph completed, took XXXms
[INFO] Running build completed, took XXXms
[INFO] Succeeded after XXXms with 0 failures.
```

- [ ] ✅ Adapters générés (`.g.dart` files)
- [ ] ✅ Pas d'erreurs de build

---

## ✅ Phase 3: Tests (5 min)

### 3.1 Analyzer (Lint check)

```bash
cd /workspaces/MASLIVE/app
flutter analyze
```

**Expected**: No errors (warnings are OK)

- [ ] ✅ Pas d'erreurs graves
- [ ] ✅ Imports corrects

### 3.2 Unit tests

```bash
cd /workspaces/MASLIVE/app
flutter test test/services/group_tracking_test.dart -v
```

**Expected**: ✅ 47/47 tests PASS

- [ ] ✅ Tous les tests passent
- [ ] ✅ 0 failures

### 3.3 Syntax check (optionnel)

```bash
cd /workspaces/MASLIVE/app
dart analyze --fatal-infos
```

- [ ] ✅ Pas d'erreurs critiques

---

## ✅ Phase 4: Vérification code (3 min)

### 4.1 Vérifier GroupMapVisibilityService exists

```bash
test -f /workspaces/MASLIVE/app/lib/services/group/group_map_visibility_service.dart && echo "✅ Service exists" || echo "❌ Service missing"
```

- [ ] ✅ Service file exists

### 4.2 Vérifier GroupMapVisibilityWidget exists

```bash
test -f /workspaces/MASLIVE/app/lib/widgets/group_map_visibility_widget.dart && echo "✅ Widget exists" || echo "❌ Widget missing"
```

- [ ] ✅ Widget file exists

### 4.3 Vérifier integration dans AdminGroupDashboardPage

```bash
grep -n "GroupMapVisibilityWidget" /workspaces/MASLIVE/app/lib/pages/group/admin_group_dashboard_page.dart | head -3
```

**Expected**:
```
5:import '../../widgets/group_map_visibility_widget.dart';
...
GroupMapVisibilityWidget(...)
```

- [ ] ✅ Import trouvé
- [ ] ✅ Widget utilisé dans ListView

---

## ✅ Phase 5: Build web (5 min)

### 5.1 Clean build

```bash
cd /workspaces/MASLIVE/app
flutter clean && flutter pub get
```

**Expected**: ~30 sec, no errors

- [ ] ✅ Clean réussi
- [ ] ✅ Pub get réussi

### 5.2 Build web release

```bash
cd /workspaces/MASLIVE/app
flutter build web --release
```

**Expected**: ~2-3 min
```
✓ Built build/web successfully, X.Xmb.
```

- [ ] ✅ Build réussi
- [ ] ✅ Pas d'erreurs
- [ ] ✅ `build/web` folder ~20-50mb

**Check build size**:
```bash
ls -lh /workspaces/MASLIVE/app/build/web/ | tail -10
du -sh /workspaces/MASLIVE/app/build/web/
```

- [ ] ✅ Assets présents
- [ ] ✅ main.dart.js présent

---

## ✅ Phase 6: Firestore Rules (2 min)

### 6.1 Vérifier rules fichier

```bash
grep -n "visibleMapIds" /workspaces/MASLIVE/firestore.rules
```

**Expected**: Ligne trouvée (sinon ajouter)

- [ ] ✅ Rules mises à jour (si nécessaire)

### 6.2 Validate rules syntax

```bash
cd /workspaces/MASLIVE
firebase deploy --only firestore:rules --dry-run
```

**Expected**:
```
✔  firestore: rules for 'projects/X' validated successfully
```

- [ ] ✅ Rules validées

---

## ✅ Phase 7: Firebase Deploy (5 min)

### 7.1 Deploy hosting

```bash
cd /workspaces/MASLIVE
firebase deploy --only hosting
```

**Expected**: ~2-3 min
```
✔  Deploy complete!

Project Console: https://console.firebase.google.com/project/maslive-XXXX
Hosting URL: https://masslive.web.app
```

- [ ] ✅ Deploy réussi
- [ ] ✅ URL accessible

**Test URL**:
```bash
curl -s -o /dev/null -w "%{http_code}" https://masslive.web.app
```

- [ ] ✅ HTTP 200 reçu

### 7.2 Deploy Firestore Rules (optionnel)

```bash
cd /workspaces/MASLIVE
firebase deploy --only firestore:rules
```

- [ ] ✅ Rules déployées

### 7.3 Deploy Cloud Functions (optionnel)

```bash
cd /workspaces/MASLIVE
firebase deploy --only functions:calculateGroupAveragePosition
```

**Check logs**:
```bash
firebase functions:log --lines 10
```

- [ ] ✅ Pas d'erreurs
- [ ] ✅ Functions actifs

---

## ✅ Phase 8: Tests manuels (5 min)

### 8.1 Web app accessible

```bash
echo "Opening app at https://masslive.web.app..."
# Attendre 5 sec que l'app charge
```

- [ ] ✅ App charge (pas de console errors)
- [ ] ✅ Page accueil fonctionne

### 8.2 Accéder au dashboard admin

```
1. Aller à https://masslive.web.app/#/group/admin
2. Chercher un groupe existant
3. Voir "Visibilité sur les cartes" section
```

- [ ] ✅ Section "Visibilité sur les cartes" visible
- [ ] ✅ Liste de cartes affichée
- [ ] ✅ Checkboxes visibles

### 8.3 Tester toggle visibilité

```
1. Cocher une carte
2. Vérifier Firestore: group_admins/{uid}.visibleMapIds
3. Décocher la carte
4. Vérifier Firestore: visibleMapIds updated
```

- [ ] ✅ Toggle fonctionne
- [ ] ✅ Firestore mise à jour
- [ ] ✅ Stream reactive (UI update)

### 8.4 Vérifier console Firefox/Chrome

```
Press F12 → Console
```

- [ ] ✅ Pas d'erreurs JavaScript
- [ ] ✅ Pas d'erreurs Dart
- [ ] ✅ Network requests OK (200/304)

---

## ✅ Phase 9: Validation finale (2 min)

### 9.1 Git status clean

```bash
cd /workspaces/MASLIVE
git status
```

**Expected**: `working tree clean`

- [ ] ✅ Pas de modifications

### 9.2 Vérifier deployment

```bash
cd /workspaces/MASLIVE
git log --oneline -1
echo "---"
firebase deploy:list --json 2>/dev/null || firebase projects:list
```

- [ ] ✅ Derniers commits visibles
- [ ] ✅ Project Firebase visible

### 9.3 Monitor logs

```bash
firebase functions:log --lines 5
```

- [ ] ✅ Pas d'erreurs functions
- [ ] ✅ Logs visibles en temps réel

---

## 🚨 Troubleshooting

### Erreur: "flutter doctor issues"

```bash
cd /workspaces/MASLIVE/app
flutter doctor -v
```

**Solutions**:
- [ ] Mettez à jour Flutter: `flutter upgrade`
- [ ] Vérifiez Dart: `dart --version`

### Erreur: "Hive adapters not generated"

```bash
cd /workspaces/MASLIVE/app
flutter pub run build_runner build --delete-conflicting-outputs
```

- [ ] Relancer build_runner
- [ ] Supprimer `.dart_tool` si nécessaire

### Erreur: "Build web fails"

```bash
cd /workspaces/MASLIVE/app
flutter clean
flutter pub get
flutter build web --release -v
```

- [ ] Vérifiez logs `-v` (verbose)
- [ ] Cherchez "error:" dans output

### Erreur: "Firebase deploy fails"

```bash
firebase login
firebase projects:list
cd /workspaces/MASLIVE
firebase deploy --only hosting -v
```

- [ ] Vérifiez auth Firebase
- [ ] Vérifiez projet correct

---

## 📊 Résumé déploiement

| Phase | Durée | Status | Notes |
|-------|-------|--------|-------|
| Préparation | 5 min | ☐ | Vérifier branch, git, deps |
| Installation | 3 min | ☐ | flutter pub get + build_runner |
| Tests | 5 min | ☐ | analyze + unit tests |
| Vérification | 3 min | ☐ | Fichiers et intégration |
| Build web | 5 min | ☐ | flutter build web --release |
| Firestore | 2 min | ☐ | Rules + validation |
| Deploy | 5 min | ☐ | firebase deploy --only hosting |
| Tests manuels | 5 min | ☐ | Dashboard + toggles |
| Validation | 2 min | ☐ | Logs + monitoring |

**Total**: ~35 minutes

---

## 🎉 Succès!

Quand tous les ✅ sont cochés:

```
✅ Feature "Group Map Visibility" déployée en production
✅ Admins groupes peuvent toggles visibilité par carte
✅ Utilisateurs voir groupes sur cartes sélectionnées
✅ Firestore répliquée en temps réel
✅ Cloud Functions actifs
✅ Web app 100% fonctionnelle
```

---

## 🔗 Références

- Feature doc: [FEATURE_GROUP_MAP_VISIBILITY.md](FEATURE_GROUP_MAP_VISIBILITY.md)
- Service: [group_map_visibility_service.dart](app/lib/services/group/group_map_visibility_service.dart)
- Widget: [group_map_visibility_widget.dart](app/lib/widgets/group_map_visibility_widget.dart)
- Dashboard: [admin_group_dashboard_page.dart](app/lib/pages/group/admin_group_dashboard_page.dart)

---

**Date déploiement**: 04/02/2026  
**Déployeur**: [À compléter]  
**Status**: ⏳ PRÊT À DÉPLOYER

