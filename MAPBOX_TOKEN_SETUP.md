# 🗺️ Mapbox Access Token Configuration - MASLIVE

> Configuration complète du token d'accès Mapbox pour l'intégration des cartes interactives.

## 📚 Table of Contents

- [🎯 Objectif](#objectif)
- [⚙️ Configuration Rapide](#configuration-rapide)
- [🔑 Obtenir le Token](#obtenir-le-token)
- [🚀 Build & Deploy](#build--deploy)
- [🧪 Tests](#tests)
- [🔒 Sécurité](#sécurité)
- [❌ Troubleshooting](#troubleshooting)
- [📊 Status](#status)

---

## 🎯 Objectif

Le token Mapbox est nécessaire pour:

- ✅ Afficher les cartes interactives Mapbox
- ✅ Charger les styles et données Mapbox
- ✅ Utiliser l'API Mapbox GL JS
- ✅ POI Assistant & Circuit Assistant (dépendent de Mapbox)

### Pages Affectées

1. **POI Assistant Page** - `lib/admin/poi_assistant_page.dart`
   - Étape 2: Mapbox fullscreen
   - Étape 3-4: Édition des POIs sur carte

2. **Circuit Assistant** - `lib/admin/create_circuit_assistant_page.dart`
   - Visualisation circuits sur Mapbox

3. **Google Light Map Page** - `lib/ui/google_light_map_page.dart`
   - Affichage personnalisé Mapbox

---

## ⚙️ Configuration Rapide

### 1️⃣ Configuration Interactive (Recommandée - 2 min)

```bash
bash /workspaces/MASLIVE/scripts/setup_mapbox.sh
```

Le script va:
1. Vous demander votre token Mapbox
2. Créer le fichier `.env`
3. Ajouter `.env` au `.gitignore`
4. Valider la configuration

### 2️⃣ Configuration Manuelle

```bash
# Créer .env
cat > /workspaces/MASLIVE/.env << 'EOF'
MAPBOX_PUBLIC_TOKEN=pk_your_token_here
EOF

# Ajouter à .gitignore
echo ".env" >> /workspaces/MASLIVE/.gitignore

# Vérifier
cat /workspaces/MASLIVE/.env
```

### 3️⃣ Configuration via Environnement

```bash
# Linux/macOS
export MAPBOX_PUBLIC_TOKEN="pk_your_token_here"

# Windows (PowerShell)
$env:MAPBOX_PUBLIC_TOKEN = "pk_your_token_here"

# Puis builder
bash /workspaces/MASLIVE/scripts/build_with_mapbox.sh
```

---

## 🔑 Obtenir le Token

### Étape 1: Créer un Compte Mapbox

1. Rendez-vous sur https://account.mapbox.com
2. Créez un compte ou connectez-vous
3. Confirmez votre email

### Étape 2: Générer le Token

1. Allez dans le menu **Tokens** (gauche)
2. Cliquez sur **Create a token** (button bleu)
3. Remplissez:
   - **Name**: `MASLIVE_PUBLIC` ou `MASLIVE_DEV`
   - **Public scope**: ✅ (obligatoire pour web)

### Étape 3: Configurer les Permissions

Sélectionnez les scopes:
- ✅ **Maps: Manage resources** (pour lire les styles)
- ✅ **Tokens: Create, read, delete** (optionnel)
- ✅ **Styles: Read** (obligatoire)
- ✅ **Datasets: Read** (optionnel)

### Étape 4: Copier le Token

- Bouton **Copy** à côté du token
- Format: `pk_eyJVIjoidGVzdCJ9...` (commence par `pk_`)
- Exemple complet:
  ```
  pk_eyJVIjoidGVzdDEyMzQ1Njc4OTAifQ.XyZ1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o
  ```

---

## 🚀 Build & Deploy

### Build Local Only

```bash
# Charger .env
source /workspaces/MASLIVE/.env

# Build
cd /workspaces/MASLIVE/app
flutter pub get
flutter build web --release \
  --dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_PUBLIC_TOKEN"

# Résultat
echo "✅ Build: /workspaces/MASLIVE/app/build/web"
```

### Build + Deploy Hosting

```bash
# Automatisé (recommandé)
bash /workspaces/MASLIVE/scripts/deploy_with_mapbox.sh

# Ou manuel
source /workspaces/MASLIVE/.env
cd /workspaces/MASLIVE/app
flutter pub get
flutter build web --release \
  --dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_PUBLIC_TOKEN"
cd ..
firebase deploy --only hosting
```

### Build Script Complet

```bash
# Tous les détails
bash /workspaces/MASLIVE/scripts/build_with_mapbox.sh

# Avec token en argument
bash /workspaces/MASLIVE/scripts/build_with_mapbox.sh "pk_your_token_here"
```

### Résultat Attendu

```
✓ Built build/web
Compiling lib/main.dart for the Web...   107.2s
✓ Built build/web

=== Deploying to 'maslive'...
i  hosting[maslive]: found 56 files in app/build/web
✔  hosting[maslive]: file upload complete
✔  hosting[maslive]: release complete

Hosting URL: https://maslive.web.app
```

---

## 🧪 Tests

### Test Local - Chrome

```bash
# Avec token
export MAPBOX_PUBLIC_TOKEN="pk_your_token_here"

# Build local
cd /workspaces/MASLIVE/app
flutter run -d chrome \
  --dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_PUBLIC_TOKEN"

# Accédez à http://localhost:53315
```

### Test Production - Web

1. Ouvrez https://maslive.web.app
2. Connectez-vous (admin)
3. Allez à **Admin Dashboard**
4. Cliquez sur **POI Assistant (New)**
5. Vérifiez:
   - ✅ L'étape 2 charge une carte Mapbox
   - ✅ La carte est interactive (zoom, pan)
   - ✅ Les POIs s'affichent correctement

### Vérifier le Token au Runtime

**Dart/Flutter:**
```dart
const _mapboxToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

void main() {
  if (_mapboxToken.isEmpty) {
    print('❌ MAPBOX_ACCESS_TOKEN vide');
  } else {
    print('✅ Token chargé: ${_mapboxToken.substring(0, 10)}...');
  }
}
```

**Vérifier dans le build:**
```bash
grep -r "MAPBOX_ACCESS_TOKEN" /workspaces/MASLIVE/app/build/web/
```

---

## 🔒 Sécurité

### ⚠️ Checklist Sécurité

- [ ] ❌ Token **JAMAIS** en dur dans le code
- [ ] ❌ Token **JAMAIS** committée dans Git
- [ ] ✅ `.env` ajouté au `.gitignore`
- [ ] ✅ Utiliser `String.fromEnvironment('MAPBOX_ACCESS_TOKEN')`
- [ ] ✅ Limiter les scopes du token (read-only si possible)
- [ ] ✅ Token rotaté régulièrement

### Configuration `.gitignore`

```bash
# S'assurer que .env est ignorée
cat >> /workspaces/MASLIVE/.gitignore << 'EOF'

# Environment variables
.env
.env.local
.env.*.local
*.pem
EOF

# Vérifier
git status | grep env
# (Aucun résultat = ok)
```

### GitHub Secrets (pour CI/CD)

**Créer un secret:**

1. Allez à **Settings** > **Secrets and variables** > **Actions**
2. Cliquez **New repository secret**
3. Nom: `MAPBOX_PUBLIC_TOKEN`
4. Valeur: `pk_your_token_here`

**Utiliser dans workflow:**

```yaml
- name: Build with Mapbox
  run: |
    cd app
    flutter build web --release \
      --dart-define=MAPBOX_ACCESS_TOKEN=${{ secrets.MAPBOX_PUBLIC_TOKEN }}
```

### Rotation du Token

```bash
# 1. Générer un nouveau token sur mapbox.com
# 2. Mettre à jour .env
# 3. Redéployer

echo "MAPBOX_PUBLIC_TOKEN=pk_new_token_here" > /workspaces/MASLIVE/.env

# 4. Supprimer l'ancien token sur mapbox.com (Settings > Tokens)
```

---

## ❌ Troubleshooting

### ❌ Erreur: "MAPBOX_ACCESS_TOKEN manquant"

**Cause:** Token non passé au build

**Solution:**
```bash
# Option 1: Vérifier .env existe
ls -la /workspaces/MASLIVE/.env

# Option 2: Créer .env
echo "MAPBOX_PUBLIC_TOKEN=pk_your_token_here" > /workspaces/MASLIVE/.env

# Option 3: Configuration interactive
bash /workspaces/MASLIVE/scripts/setup_mapbox.sh

# Option 4: Builder avec token explicite
flutter build web --dart-define=MAPBOX_ACCESS_TOKEN="pk_your_token_here"
```

### ❌ Erreur: "Unauthorized access token"

**Cause:** Token invalide, expiré ou permissions insuffisantes

**Solution:**
```bash
# 1. Vérifier le token sur mapbox.com
# Allez à https://account.mapbox.com/tokens/

# 2. Vérifier les permissions:
# - Maps: Manage resources ✅
# - Styles: Read ✅

# 3. Si nécessaire, régénérez le token

# 4. Mettre à jour .env
echo "MAPBOX_PUBLIC_TOKEN=pk_new_token_here" > /workspaces/MASLIVE/.env

# 5. Reconstruire
bash /workspaces/MASLIVE/scripts/build_with_mapbox.sh
```

### ❌ Carte blanche ou ne se charge pas

**Cause:** Token non pris en compte ou invalide

**Solution:**
```bash
# 1. Vérifier le token format
grep MAPBOX_PUBLIC_TOKEN /workspaces/MASLIVE/.env

# 2. Vérifier qu'il commence par 'pk_'
MAPBOX_TOKEN=$(grep MAPBOX_PUBLIC_TOKEN /workspaces/MASLIVE/.env | cut -d= -f2)
echo "${MAPBOX_TOKEN:0:10}"
# Résultat: pk_... ✅

# 3. Forcer un rebuild clean
cd /workspaces/MASLIVE/app
rm -rf build/
flutter clean
flutter pub get
flutter build web --release --dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_PUBLIC_TOKEN"
```

### ❌ `.env` était committée

**Solution:**
```bash
# 1. Supprimer du repository
cd /workspaces/MASLIVE
git rm --cached .env

# 2. Ajouter à .gitignore
echo ".env" >> .gitignore
git add .gitignore

# 3. Commit et push
git commit -m "fix: remove .env from git tracking"
git push origin main

# 4. Recréer .env localement
bash scripts/setup_mapbox.sh
```

### ❌ Erreur: "Token not provided at build time"

```bash
# Le token n'est pas chargé au build

# Solution: Vérifier le chemin du token
echo "1. Charger .env"
source /workspaces/MASLIVE/.env
echo "2. Vérifier le token"
echo $MAPBOX_PUBLIC_TOKEN
echo "3. Builder"
cd /workspaces/MASLIVE/app
flutter build web --dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_PUBLIC_TOKEN"
```

---

## 📊 Status

### Fichiers de Configuration

| Fichier | Description | Status |
|---------|-------------|--------|
| `.env` | Configuration locale (ignorée) | 📝 À créer |
| `.env.example` | Template de configuration | ✅ Présent |
| `scripts/setup_mapbox.sh` | Configuration interactive | ✅ Prêt |
| `scripts/build_with_mapbox.sh` | Build avec token | ✅ Prêt |
| `scripts/deploy_with_mapbox.sh` | Build + Deploy | ✅ Prêt |

### Pages Intégrées

| Page | Fichier | Status |
|------|---------|--------|
| POI Assistant | `lib/admin/poi_assistant_page.dart` | ✅ Production |
| Circuit Assistant | `lib/admin/create_circuit_assistant_page.dart` | ✅ Production |
| Google Light Map | `lib/ui/google_light_map_page.dart` | ✅ Production |

### Déploiement

| Étape | Status | Notes |
|-------|--------|-------|
| Build local | ✅ | Avec `--dart-define` |
| Deploy staging | ✅ | Testé avec token |
| Deploy production | ✅ | https://maslive.web.app |
| GitHub Actions | 📋 | À configurer avec secrets |

---

## 🔗 Ressources

- [Mapbox Account](https://account.mapbox.com/)
- [Mapbox Tokens](https://account.mapbox.com/tokens/)
- [Mapbox GL JS Docs](https://docs.mapbox.com/mapbox-gl-js/)
- [Mapbox API Reference](https://docs.mapbox.com/api/maps/)
- [Flutter Mapbox GL](https://pub.dev/packages/mapbox_gl)

---

## 📞 Support

**Pour l'équipe:**

```bash
# 1. Chaque développeur configure son token
bash /workspaces/MASLIVE/scripts/setup_mapbox.sh

# 2. Vérifier localement
flutter run -d chrome

# 3. Commit et push (sans .env)
git add .
git commit -m "feature: working with mapbox"
git push origin main
```

**Besoin d'aide?**

1. Vérifiez [MAPBOX_CONFIGURATION.md](./MAPBOX_CONFIGURATION.md)
2. Consultez la section [Troubleshooting](#troubleshooting)
3. Vérifiez que le token est valide sur mapbox.com

---

## ✨ Quick Command Reference

```bash
# Configuration
bash /workspaces/MASLIVE/scripts/setup_mapbox.sh

# Build seul
bash /workspaces/MASLIVE/scripts/build_with_mapbox.sh

# Build + Deploy
bash /workspaces/MASLIVE/scripts/deploy_with_mapbox.sh "pk_token_here"

# Test local
export MAPBOX_PUBLIC_TOKEN="pk_..."
flutter run -d chrome

# Vérifier .env
cat /workspaces/MASLIVE/.env
```

---

**Last Updated:** 2026-01-26  
**Status:** ✅ Production Ready
