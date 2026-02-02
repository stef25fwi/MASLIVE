# Configuration Mapbox Access Token

## 📋 Prérequis

1. Compte Mapbox créé sur https://mapbox.com
2. Token Mapbox accès public (pk_...) généré

## 🔐 Obtenir votre Token

### Étape 1 : Créer un compte Mapbox
- Rendez-vous sur https://account.mapbox.com
- Créez un compte ou connectez-vous

### Étape 2 : Générer le Token
1. Allez dans **Tokens** (menu gauche)
2. Cliquez sur **Create a token**
3. Nommez votre token: `MASLIVE_PUBLIC`
4. Sélectionnez les scopes:
   - ✅ **Maps: Manage resources**
   - ✅ **Tokens: Create, read, delete**
   - ✅ **Styles: Read**

### Étape 3 : Copier le Token
- Votre token commencera par `pk_` (public)
- Exemple: `pk_eyJVIjoidGVzdCJ9...`

---

## 🛠️ Configuration Locale

### Créer le fichier `.env`

```bash
# À la racine du projet MASLIVE
cat > .env << 'EOF'
MAPBOX_PUBLIC_TOKEN=pk_YOUR_TOKEN_HERE
EOF
```

### Charger la variable d'environnement

**Linux/macOS:**
```bash
export MAPBOX_PUBLIC_TOKEN="pk_your_token_here"
```

**Windows (PowerShell):**
```powershell
$env:MAPBOX_PUBLIC_TOKEN = "pk_your_token_here"
```

---

## 🚀 Build avec Token Mapbox

### Option 1 : Build Local

```bash
# Linux/macOS
MAPBOX_TOKEN="pk_your_token_here"
cd /workspaces/MASLIVE/app
flutter pub get
flutter build web --release --dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_TOKEN"
cd ..
firebase deploy --only hosting
```

### Option 2 : Build avec .env

```bash
# Charger le token depuis .env
source .env
cd /workspaces/MASLIVE/app
flutter pub get
flutter build web --release --dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_PUBLIC_TOKEN"
cd ..
firebase deploy --only hosting
```

### Option 3 : Script Automatisé

```bash
bash /workspaces/MASLIVE/scripts/build_with_mapbox.sh
```

---

## 🔄 GitHub Actions (CI/CD)

### Ajouter le Secret GitHub

1. Allez à **Settings** > **Secrets and variables** > **Actions**
2. Cliquez sur **New repository secret**
3. Nom: `MAPBOX_PUBLIC_TOKEN`
4. Valeur: `pk_your_token_here`

### Utiliser dans le workflow

```yaml
- name: Build Flutter Web with Mapbox
  run: |
    cd app
    flutter build web --release \
      --dart-define=MAPBOX_ACCESS_TOKEN=${{ secrets.MAPBOX_PUBLIC_TOKEN }}
```

---

## 🧪 Tests

### Vérifier que le Token est Chargé

```dart
// Dans le code Dart
const _mapboxToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

void main() {
  if (_mapboxToken.isEmpty) {
    print('❌ MAPBOX_ACCESS_TOKEN non configuré');
  } else {
    print('✅ Token chargé: ${_mapboxToken.substring(0, 10)}...');
  }
}
```

### Tester le Build

```bash
# Vérifier que Mapbox se charge correctement
flutter build web --dart-define=MAPBOX_ACCESS_TOKEN="pk_test_token"
```

---

## 🔒 Sécurité

### ⚠️ Points Importants

- **Ne committez JAMAIS** le token dans Git
- Ajoutez `.env` au `.gitignore`
- Utilisez des secrets GitHub pour CI/CD
- Limitez les autorisations du token à ce qui est nécessaire

### `.gitignore`

```
# Environment variables
.env
.env.local
.env.*.local
```

---

## 📱 Pages Utilisant Mapbox

### POI Assistant Page (Legacy)
- Fichier: `app/lib/admin/poi_assistant_page.dart`
- Fonctionnalité: Ancien assistant POI
- Statut: ⚠️ Déprécié (remplacé par le Wizard MarketMap)

### POI Wizard MarketMap (Actuel)
- Fichier: `app/lib/admin/poi_marketmap_wizard_page.dart`
- Fonctionnalité: Wizard POIs MarketMap
- Statut: ✅ Production Ready

### Circuit Assistant (Mapbox Wizard)
- Fichier: `app/lib/admin/create_circuit_assistant_page.dart`
- Fonctionnalité: Visualisation circuits sur carte
- Statut: ✅ Production Ready

### Google Light Map Page
- Fichier: `app/lib/ui/google_light_map_page.dart`
- Fonctionnalité: Affichage carte Mapbox personnalisée
- Statut: ✅ Production Ready

---

## ❌ Troubleshooting

### Erreur: "MAPBOX_ACCESS_TOKEN manquant"

**Cause:** Token non passé au build

**Solution:**
```bash
flutter build web --dart-define=MAPBOX_ACCESS_TOKEN="pk_your_token"
```

### Carte blanche ou ne se charge pas

**Cause:** Token invalide ou expiré

**Solution:**
1. Vérifier le token sur https://account.mapbox.com/tokens/
2. Vérifier que le token a les bonnes permissions
3. Régénérer si nécessaire

### Erreur "Unauthorized access token"

**Cause:** Token avec permissions insuffisantes

**Solution:**
- Accédez au token sur Mapbox
- Vérifiez les scopes: "Maps: Manage resources" doit être ✅

---

## 📊 Checklist de Configuration

- [ ] Compte Mapbox créé
- [ ] Token public généré (pk_...)
- [ ] Fichier `.env` créé localement
- [ ] `.env` ajouté au `.gitignore`
- [ ] Secret GitHub `MAPBOX_PUBLIC_TOKEN` configuré
- [ ] Build testé localement avec token
- [ ] Mapbox visible sur https://maslive.web.app
- [ ] POI Assistant fonctionne en production

---

## 🔗 Ressources Utiles

- [Mapbox Account Tokens](https://account.mapbox.com/tokens/)
- [Mapbox GL JS Documentation](https://docs.mapbox.com/mapbox-gl-js/)
- [Mapbox API Reference](https://docs.mapbox.com/api/maps/)
- [Flutter Mapbox GL Web](https://pub.dev/packages/mapbox_gl)

---

## 📞 Support

Pour configurer Mapbox avec votre équipe:

```bash
# Partager le fichier .env.example
git add .env.example
git commit -m "docs: add mapbox env configuration template"
git push origin main

# Chaque développeur crée son .env local
cp .env.example .env
# Puis édite .env avec son token personnel
```

