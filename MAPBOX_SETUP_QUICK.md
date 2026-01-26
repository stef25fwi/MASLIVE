# ⚡ Configuration Mapbox - Guide Rapide

## 🎯 Objectif

Configurer le token d'accès Mapbox pour que les cartes Mapbox s'affichent correctement dans l'application MASLIVE.

---

## ⚙️ Configuration Rapide (2 minutes)

### Option 1️⃣ : Configuration Interactive (Recommandée)

```bash
bash /workspaces/MASLIVE/scripts/setup_mapbox.sh
```

Ce script:
- ✅ Vous demande votre token Mapbox
- ✅ Crée le fichier `.env`
- ✅ Ajoute `.env` au `.gitignore`
- ✅ Teste le build automatiquement

### Option 2️⃣ : Configuration Manuelle

**1. Créer le fichier `.env`:**
```bash
cat > /workspaces/MASLIVE/.env << 'EOF'
MAPBOX_PUBLIC_TOKEN=pk_your_token_here
EOF
```

**2. Remplacer `pk_your_token_here` par votre token réel**

**3. Vérifier la configuration:**
```bash
cat /workspaces/MASLIVE/.env
```

---

## 🔑 Obtenir votre Token Mapbox

1. Allez sur https://account.mapbox.com/tokens/
2. Cliquez **Create a token**
3. Nommez-le: `MASLIVE_PUBLIC`
4. Copiez le token public (commence par `pk_`)
5. Exemple: `pk_eyJVIjoidGVzdCJ9Zm9vYmFy...`

---

## 🚀 Build & Deploy avec Mapbox

### Build Seul
```bash
bash /workspaces/MASLIVE/scripts/build_with_mapbox.sh
```

### Build + Deploy Hosting
```bash
bash /workspaces/MASLIVE/scripts/deploy_with_mapbox.sh
```

### Passer le Token en Argument
```bash
bash /workspaces/MASLIVE/scripts/deploy_with_mapbox.sh "pk_your_token_here"
```

---

## ✅ Vérification

### Local (Chrome)
```bash
cd /workspaces/MASLIVE/app
flutter run -d chrome --dart-define=MAPBOX_ACCESS_TOKEN="pk_your_token_here"
```

### Production
1. Ouvrez https://maslive.web.app
2. Allez à **Admin Dashboard**
3. Cliquez sur **POI Assistant (New)**
4. Vérifiez que la carte Mapbox se charge

---

## 🔒 Sécurité

- ❌ **NE COMMITTEZ PAS** le `.env` dans Git
- ✅ `.env` est ignoré par `.gitignore`
- ✅ Utilisez des secrets GitHub pour CI/CD

**Vérifier que `.env` est ignoré:**
```bash
git status | grep -i env
# (Aucun résultat = ok)
```

---

## 📱 Pages Utilisant Mapbox

✅ **POI Assistant** (`lib/admin/poi_assistant_page.dart`)
- Étape 2: Chargement carte en plein écran
- Étape 3-4: Édition des POIs sur la carte

✅ **Circuit Assistant** (`lib/admin/create_circuit_assistant_page.dart`)
- Affichage et édition circuits sur Mapbox

✅ **Google Light Map Page** (`lib/ui/google_light_map_page.dart`)
- Affichage personnalisé Mapbox

---

## ❌ Troubleshooting

| Problème | Solution |
|----------|----------|
| "Token manquant" | `bash scripts/setup_mapbox.sh` |
| Carte blanche | Vérifiez token valide sur mapbox.com |
| "Unauthorized" | Régénérez le token (permissions insuffisantes) |
| `.env` committée | `git rm --cached .env` |

---

## 📞 Support

**Documentation Complète:**
- [MAPBOX_CONFIGURATION.md](./MAPBOX_CONFIGURATION.md)

**Scripts Disponibles:**
```bash
bash scripts/setup_mapbox.sh          # Configuration interactive
bash scripts/build_with_mapbox.sh     # Build avec token
bash scripts/deploy_with_mapbox.sh    # Build + Deploy
```

---

## ✨ Résumé des Étapes

1. ✅ Obtenir token sur mapbox.com
2. ✅ Exécuter `bash scripts/setup_mapbox.sh`
3. ✅ Tester le build localement
4. ✅ Déployer avec `bash scripts/deploy_with_mapbox.sh`
5. ✅ Vérifier sur https://maslive.web.app

**Durée estimée: 5 minutes**
