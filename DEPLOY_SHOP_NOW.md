# 🚀 COMMANDE DE DÉPLOIEMENT RAPIDE

Exécutez cette commande dans le terminal :

```bash
bash /workspaces/MASLIVE/deploy_shop.sh
```

Ou avec un message personnalisé :

```bash
bash /workspaces/MASLIVE/deploy_shop.sh "feat: mes modifications"
```

## Ce que fait le script :

1. ✅ **Stage** : Ajoute tous les fichiers modifiés
2. ✅ **Commit** : Crée un commit avec votre message
3. ✅ **Push** : Envoie vers GitHub (branche actuelle)
4. ✅ **Build** : Compile Flutter Web en release
5. ✅ **Deploy** : Déploie sur Firebase Hosting

## Fichiers modifiés aujourd'hui :

- `app/lib/models/cart_item.dart` - Support imagePath
- `app/lib/models/product_model.dart` - Gestion stock
- `app/lib/services/cart_service.dart` - Sync Firestore
- `app/lib/pages/cart_page.dart` - Affichage assets
- `app/lib/pages/product_detail_page.dart` - Stock & quantité
- `app/lib/admin/admin_main_dashboard.dart` - Section Commerce
- `app/pubspec.yaml` - Assets shop
- `app/assets/images/*.svg` - Nouvelles icônes
- `app/assets/shop/*` - Images produits

---

**Alternative : Tâches VS Code**

Dans VS Code, appuyez sur `Ctrl+Shift+P` puis tapez "Run Task" et choisissez :
- "MASLIVE: 🚀 Commit + Push + Build + Deploy"
