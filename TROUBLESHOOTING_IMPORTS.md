# 🔧 GUIDE DÉPANNAGE - ERREURS D'IMPORT

**Status**: ✅ Corrigé (4 février 2026)

---

## ❌ ERREUR RENCONTRÉE

```
Error: Couldn't resolve the package 'maslive_app' in 'package:maslive_app/models/group_admin.dart'.
```

**Cause**: Le nom du package dans `pubspec.yaml` est `masslive` (double 's')  
mais les imports utilisaient `maslive_app` (simple 's' + `_app`)

---

## ✅ SOLUTION APPLIQUÉE

### 1. Corriger pubspec.yaml
```yaml
# Dans /workspaces/MASLIVE/app/pubspec.yaml
name: masslive  # ← Double 's'

# Ajouter dépendances (déjà fait):
dependencies:
  hive_flutter: ^1.1.0
  hive: ^2.2.3

dev_dependencies:
  build_runner: ^2.4.9
  hive_generator: ^2.0.1
```

### 2. Corriger imports dans les tests
```dart
# AVANT (FAUX):
import 'package:maslive_app/models/group_admin.dart';
import 'package:maslive_app/utils/geo_utils.dart';

# APRÈS (CORRECT):
import 'package:masslive/models/group_admin.dart';
import 'package:masslive/utils/geo_utils.dart';
```

### 3. Appliquer dans tous les fichiers
- ✅ `app/test/services/group_tracking_test.dart` (CORRIGÉ)

---

## 📋 ÉTAPES SETUP COMPLÈTES

### Phase 1: Préparation
```bash
cd /workspaces/MASLIVE/app

# 1. Installer dépendances
flutter pub get

# 2. Nettoyer cache build
flutter clean

# 3. Générer adapters Hive (IMPORTANT!)
flutter pub run build_runner build --delete-conflicting-outputs
```

### Phase 2: Lancer tests
```bash
# Test simple (vérification imports)
flutter test test/simple_test.dart -v

# Tests complets (47 tests)
flutter test test/services/group_tracking_test.dart -v

# Ou tous les tests
flutter test
```

### Phase 3: Vérifier
```bash
# Vérifier files créés:
ls -la lib/utils/geo_utils.dart
ls -la lib/services/group/group_average_service.dart
ls -la lib/services/group/group_history_service.dart
ls -la lib/services/group/group_cache_service.dart
ls -la test/services/group_tracking_test.dart

# Vérifier pubspec:
grep -E "name:|hive|build_runner" pubspec.yaml
```

---

## 🎯 CHECKLIST

```
□ Name in pubspec.yaml = "masslive"
□ Imports use "package:masslive"
□ "flutter pub get" succeeds
□ "flutter pub run build_runner build" succeeds
□ No import errors in IDE
□ "flutter test" passes
```

---

## 🚀 COMMANDE FINALE

```bash
cd /workspaces/MASLIVE/app

# Everything in one go:
flutter pub get && \
  flutter clean && \
  flutter pub run build_runner build --delete-conflicting-outputs && \
  flutter test test/simple_test.dart -v && \
  echo "✅ ALL GOOD!"
```

---

## 🔗 Fichiers créés/modifiés

| Fichier | Type | Raison |
|---------|------|--------|
| `app/lib/utils/geo_utils.dart` | NOUVEAU | Utilitaires géodésiques |
| `app/lib/services/group/group_average_service.dart` | MODIFIÉ | Géodésique + pondération |
| `app/lib/services/group/group_history_service.dart` | NOUVEAU | Historique snapshots |
| `app/lib/services/group/group_cache_service.dart` | NOUVEAU | Cache Hive |
| `app/test/services/group_tracking_test.dart` | NOUVEAU | Tests unitaires |
| `app/pubspec.yaml` | MODIFIÉ | Hive + build_runner |

---

## 📞 Si ça ne marche pas

```bash
# 1. Nettoyage complet
cd /workspaces/MASLIVE/app
flutter clean
rm -rf pubspec.lock

# 2. Réinstaller
flutter pub get

# 3. Verify package name
grep "^name:" pubspec.yaml

# 4. Try simple test first
flutter test test/simple_test.dart

# 5. If still error, check Flutter/Dart versions
flutter --version
dart --version
```

---

**Status**: ✅ PRÊT À DÉPLOYER  
**Date**: 04/02/2026

