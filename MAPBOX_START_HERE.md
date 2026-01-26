# 🗺️ Configuration Mapbox - COMMENCER ICI

> **Configuration complète du token d'accès Mapbox pour MASLIVE**

---

## ⚡ Démarrage 2 Secondes

### Choisir votre niveau:

#### 🏃 Très Pressé (2 minutes)
```bash
bash /workspaces/MASLIVE/scripts/setup_mapbox.sh
```

#### 🚶 Pressé (5 minutes)
→ Lire: [MAPBOX_SETUP_QUICK.md](./MAPBOX_SETUP_QUICK.md)

#### 🧘 Patient (15 minutes)
→ Lire: [MAPBOX_TOKEN_SETUP.md](./MAPBOX_TOKEN_SETUP.md)

---

## 🎯 Ce que Vous Obtenez

✅ **Carte Mapbox** dans POI Assistant (Étape 2)  
✅ **Circuit Assistant** avec visualisation Mapbox  
✅ **Google Light Map** avec affichage personnalisé  
✅ **Auto-deploy** sur Firebase via GitHub Actions  
✅ **Sécurité** - Token dans .env (pas committée)

---

## 📍 Fichiers Clés

| Fichier | Raison | Temps |
|---------|--------|-------|
| **mapbox-start.sh** | Menu interactif | 2 min |
| **MAPBOX_SETUP_QUICK.md** | Guide rapide | 5 min |
| **MAPBOX_TOKEN_SETUP.md** | Doc complète | 30 min |
| **scripts/setup_mapbox.sh** | Configuration auto | 2 min |
| **scripts/deploy_with_mapbox.sh** | Build + Deploy | 10 min |

---

## 🚀 Trois Options

### Option 1️⃣ : Menu Interactif (Recommandé)

```bash
bash /workspaces/MASLIVE/mapbox-start.sh
```

### Option 2️⃣ : Configuration Rapide

```bash
bash /workspaces/MASLIVE/scripts/setup_mapbox.sh
bash /workspaces/MASLIVE/scripts/deploy_with_mapbox.sh
```

### Option 3️⃣ : Manuel Step by Step

Voir [MAPBOX_SETUP_QUICK.md](./MAPBOX_SETUP_QUICK.md)

---

## 🔑 Vous Avez Besoin De

Un token Mapbox public (`pk_...`)

### Comment l'obtenir (2 minutes):

1. Allez sur https://account.mapbox.com/tokens/
2. Créez un compte si nécessaire
3. Cliquez **Create a token**
4. Copiez le token public
5. C'est tout! 🎉

---

## ✅ Après Configuration

Vérifiez que tout fonctionne:

```bash
# 1. Ouvrez l'app
https://maslive.web.app

# 2. Allez à Admin Dashboard
# 3. Cliquez POI Assistant (New)
# 4. Étape 2 - Mapbox doit charger ✅
```

---

## 📚 Documentation Complète

| Doc | Contenu | Lecteurs |
|-----|---------|----------|
| **MAPBOX_INDEX.md** | Navigation complète | Tout le monde |
| **MAPBOX_SETUP_QUICK.md** | Guide 5 minutes | Developpeurs |
| **MAPBOX_TOKEN_SETUP.md** | Configuration détaillée | Tech leads |
| **MAPBOX_DEMO_USAGE.md** | Scénarios pratiques | Équipe |
| **MAPBOX_CONFIGURATION.md** | Référence complète | Reference |

---

## ❓ Questions Fréquentes

**Q: Où mettre mon token?**  
A: `bash scripts/setup_mapbox.sh` demande et configure automatiquement

**Q: Mon token est sûr?**  
A: Oui! Il est dans `.env` (pas committée)

**Q: Ça prend combien de temps?**  
A: Setup = 2 min, Deploy = 10 min

**Q: Ça fonctionne en production?**  
A: Oui! App déployée sur https://maslive.web.app

---

## 🎁 Bonus

- ✅ Scripts automatisés
- ✅ Documentation complète
- ✅ GitHub Actions ready
- ✅ Troubleshooting guide
- ✅ Checklist validation

---

## 🚨 Problème?

Voir [MAPBOX_TOKEN_SETUP.md#troubleshooting](./MAPBOX_TOKEN_SETUP.md#troubleshooting)

ou

```bash
bash /workspaces/MASLIVE/mapbox-start.sh
# Option 6: Troubleshoot
```

---

## 📊 Status

✅ **3 pages** utilisant Mapbox (POI, Circuit, Map)  
✅ **6 docs** complètes  
✅ **3 scripts** prêts  
✅ **1 GitHub Actions** workflow  
✅ **Production Ready**

---

## ⏱️ Timeline Estimée

```
Setup:  2 minutes  ✅
Deploy: 10 minutes ✅
Test:   5 minutes  ✅
─────────────────────
Total:  17 minutes
```

---

## 🎬 Résumé des Étapes

1. **Obtenir Token:** https://account.mapbox.com/tokens/
2. **Configurer:** `bash scripts/setup_mapbox.sh`
3. **Déployer:** `bash scripts/deploy_with_mapbox.sh`
4. **Vérifier:** https://maslive.web.app/admin → POI Assistant

---

## 📞 Support

- **Docs:** Voir fichiers `MAPBOX_*.md`
- **Scripts:** Dans `scripts/`
- **Questions:** Lire MAPBOX_TOKEN_SETUP.md#troubleshooting

---

**Prêt?** Commencez:

```bash
bash /workspaces/MASLIVE/scripts/setup_mapbox.sh
```

**ou**

```bash
bash /workspaces/MASLIVE/mapbox-start.sh
```

---

**Status:** ✅ Production Ready  
**Créé:** 2026-01-26
