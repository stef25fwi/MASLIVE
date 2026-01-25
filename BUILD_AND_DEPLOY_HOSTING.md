# 🚀 Build Web + Deploy Hosting

## Exécution rapide

### Avec script (automatique)
```bash
bash /workspaces/MASLIVE/build_and_deploy_hosting.sh
```

### Manuellement (étape par étape)
```bash
cd /workspaces/MASLIVE/app
flutter build web --release

cd ..
firebase deploy --only hosting
```

---

## 📊 Ce que ça fait

| Étape | Commande | Durée | Détail |
|-------|----------|-------|--------|
| **Build** | `flutter build web --release` | 2-5min | Compile l'app Flutter en web statique |
| **Deploy** | `firebase deploy --only hosting` | 30-60s | Envoie les fichiers statiques à Firebase |

---

## ✅ Vérification

```bash
# Vérifier que la build est en cours
ls -lh build/web/

# Voir l'URL live
echo "https://maslive.web.app"

# Vérifier les logs
firebase hosting:channel:list
```

---

## 📈 Durée estimée
- **Build** : 2-5 minutes (première fois peut être plus long)
- **Deploy** : 30-60 secondes
- **Total** : 3-6 minutes

---

## 🔍 Troubleshooting

### La build échoue ?
```bash
flutter clean
flutter pub get
flutter build web --release
```

### Le deploy échoue ?
```bash
# Vérifier l'authentification
firebase login

# Redéployer
firebase deploy --only hosting
```

### Voir l'URL en live
```bash
open https://maslive.web.app
# ou
echo "https://maslive.web.app"
```
