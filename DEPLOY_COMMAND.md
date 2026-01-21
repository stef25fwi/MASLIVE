# Commande complète : Commit → Push → Build → Deploy vers MAIN

## Option 1 : Une seule commande (idéale)

```bash
cd /workspaces/MASLIVE && \
git add -A && \
git commit -m "Feat: Add map presets system with superadmin permissions - Complete map preset implementation with dual-mode UI, permission controls, and comprehensive documentation" && \
git push origin V2 && \
git checkout main && \
git pull origin main && \
git merge V2 -m "Merge branch 'V2' into main" && \
git push origin main && \
git checkout V2 && \
cd app && \
flutter pub get && \
flutter build web --release && \
cd .. && \
firebase deploy --only hosting,functions,firestore:rules,storage:rules
```

## Option 2 : Étape par étape (plus lisible)

### 1. Commit sur V2
```bash
cd /workspaces/MASLIVE
git add -A
git commit -m "Feat: Add map presets system with superadmin permissions - Complete map preset implementation with dual-mode UI and permission controls"
```

### 2. Push vers V2
```bash
git push origin V2
```

### 3. Merge et push vers main
```bash
git checkout main
git pull origin main
git merge V2 -m "Merge branch 'V2' into main"
git push origin main
```

### 4. Retour sur V2
```bash
git checkout V2
```

### 5. Build web
```bash
cd app
flutter pub get
flutter build web --release
cd ..
```

### 6. Deploy Firebase
```bash
firebase deploy --only hosting,functions,firestore:rules,storage:rules
```

## Option 3 : Via le script bash créé

```bash
bash /workspaces/MASLIVE/scripts/commit_build_deploy_main.sh
```

---

## Résultat attendu

✅ Tous les fichiers stagés et committés  
✅ Pushés vers `origin/V2`  
✅ Merged et pushés vers `origin/main`  
✅ Build web complété  
✅ Déployement Firebase (hosting + functions + rules)  

## Fichiers inclus dans ce commit

### Modèles créés
- `app/lib/models/map_preset_model.dart` - MapPresetModel & LayerModel

### Services créés
- `app/lib/services/map_presets_service.dart` - Firestore CRUD
- `app/lib/services/route_validator.dart` - Validation des routes
- `app/lib/services/gallery_counts_service.dart` - Comptage des galeries
- `app/lib/services/draft_manager.dart` - Gestion des brouillons

### Pages créées
- `app/lib/pages/map_selector_page.dart` - Sélecteur de cartes

### Services modifiés
- `app/lib/services/permission_service.dart` - Ajout `isCurrentUserSuperAdmin()`

### Pages modifiées
- `app/lib/pages/media_galleries_page.dart` - Intégration Firestore
- `app/lib/pages/route_drawing_page.dart` - Améliorations
- `app/lib/pages/shop_page.dart` - Intégration galeries
- Autres pages circuits/admin

### Documentation
- `MAP_PRESETS_SYSTEM.md` - Documentation système
- `MAP_PRESETS_IMPLEMENTATION_SUMMARY.md` - Résumé implémentation
- `MAP_PERMISSIONS_IMPLEMENTATION.md` - Documentation permissions
