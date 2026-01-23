# 🎭 Media Shop v2 - Documentation complète

## 📖 Vue d'ensemble

La page **Media Shop v2** est une refonte complète de la page galeries médias avec un système de boutique photo professionnel incluant:

- ✅ Sélection multiple avec checkmarks
- ✅ Panier d'achat avec Provider
- ✅ Filtres cascadés intelligents
- ✅ Tri multi-critères
- ✅ Preview modale
- ✅ Interface moderne et fluide

## 🚀 Quick Start

### Installation en 3 étapes

1. **Migrer les données Firestore**
   ```bash
   node scripts/migrate_media_galleries.js
   ```

2. **Intégrer dans votre app**
   ```dart
   import 'pages/media_shop_wrapper.dart';
   
   // Dans votre navigation:
   Navigator.push(
     context,
     MaterialPageRoute(
       builder: (_) => const MediaShopWrapper(groupId: 'all'),
     ),
   );
   ```

3. **Tester**
   ```bash
   flutter run
   ```

## 📚 Documentation

### Fichiers principaux

| Fichier | Description |
|---------|-------------|
| [media_galleries_page_v2.dart](app/lib/pages/media_galleries_page_v2.dart) | Page principale avec toute la logique |
| [media_shop_wrapper.dart](app/lib/pages/media_shop_wrapper.dart) | Wrapper avec CartProvider |
| [migrate_media_galleries.js](scripts/migrate_media_galleries.js) | Script de migration Firestore |

### Guides

| Guide | Contenu |
|-------|---------|
| [MEDIA_SHOP_STRUCTURE.md](MEDIA_SHOP_STRUCTURE.md) | 📘 Architecture et fonctionnalités détaillées |
| [MEDIA_COMPARISON.md](MEDIA_COMPARISON.md) | 📊 Comparaison ancienne vs nouvelle version |
| [INTEGRATION_EXAMPLES.dart](INTEGRATION_EXAMPLES.dart) | 💡 5 exemples d'intégration |
| [FIRESTORE_EXAMPLES.md](FIRESTORE_EXAMPLES.md) | 🗃️ Exemples de données et requêtes |
| [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) | ✅ Checklist de déploiement complète |

## 🎨 Fonctionnalités

### Filtres cascadés

Les filtres s'adaptent intelligemment:

```
Pays → Date → Événement → Groupe → Photographe
```

Exemple:
1. Sélectionner "Guadeloupe"
2. → Les événements affichés sont uniquement ceux en Guadeloupe
3. Sélectionner "Carnaval 2026"
4. → Les groupes affichés ont participé au Carnaval 2026 en Guadeloupe

### Sélection & Panier

```
Checkmark → Sélection
    ↓
Barre de sélection apparaît
    ↓
"Ajouter au panier" → Panier
    ↓
Badge panier s'incrémente
    ↓
Clic badge → Modal panier
    ↓
Checkout (à implémenter)
```

### Tri

- **Plus récentes** (défaut)
- **Nb photos** (plus → moins)
- **Prix croissant**
- **Prix décroissant**

## 🗃️ Structure Firestore requise

```json
{
  "title": "Carnaval 2026",
  "subtitle": "Défilé principal",
  "coverUrl": "https://...",
  "images": ["url1", "url2"],
  "photoCount": 45,
  
  "country": "Guadeloupe",
  "date": Timestamp,
  "eventName": "Défilé Pointe-à-Pitre",
  "groupName": "Akiyo",
  "photographerName": "Kris Photo",
  "pricePerPhoto": 8.0,
  
  "groupId": "akiyo",
  "createdAt": Timestamp
}
```

## 🔧 Migration depuis v1

### Avant
```dart
import 'pages/media_galleries_page.dart';
MediaGalleriesPage(groupId: 'all')
```

### Après
```dart
import 'pages/media_shop_wrapper.dart';
MediaShopWrapper(groupId: 'all')
```

### Script de migration
```bash
# Mise à jour automatique des documents existants
node scripts/migrate_media_galleries.js

# Créer une galerie de test
node scripts/migrate_media_galleries.js --test
```

## 📱 Compatibilité

- ✅ Android
- ✅ iOS
- ✅ Web
- ✅ Responsive (mobile, tablette, desktop)

## 🎯 Prochaines étapes

### Court terme
- [ ] Implémenter checkout Stripe
- [ ] Ajouter persistance panier
- [ ] Système de favoris

### Moyen terme
- [ ] Téléchargement après achat
- [ ] Watermark sur preview
- [ ] Partage de galeries
- [ ] Recherche textuelle

### Long terme
- [ ] Système de reviews
- [ ] Notifications nouvelles galeries
- [ ] Collections thématiques
- [ ] Recommandations IA

## 🐛 Troubleshooting

### "GalleryCartScope not found"
→ Utilisez `MediaShopWrapper` au lieu de `MediaGalleriesPage` directement

### Filtres ne fonctionnent pas
→ Vérifiez que vos documents Firestore ont les champs requis (`country`, `date`, etc.)

### Panier se vide à la navigation
→ Pour un panier persistant dans toute l'app, wrappez au niveau `MaterialApp` (voir [INTEGRATION_EXAMPLES.dart](INTEGRATION_EXAMPLES.dart) Option 5)

### Images ne chargent pas
→ Vérifiez les URLs dans `coverUrl` et `images[]`

## 📊 Analytics recommandées

```dart
// Vue de galerie
FirebaseAnalytics.instance.logEvent(
  name: 'gallery_view',
  parameters: {'gallery_id': gallery.id},
);

// Ajout au panier
FirebaseAnalytics.instance.logEvent(
  name: 'add_to_cart',
  parameters: {
    'gallery_id': gallery.id,
    'value': gallery.totalPrice,
  },
);

// Achat
FirebaseAnalytics.instance.logEvent(
  name: 'purchase',
  parameters: {
    'value': cart.cartTotal,
    'items': cart.cartCount,
  },
);
```

## 🤝 Contribution

### Structure du code

```
media_galleries_page_v2.dart
├── Models
│   ├── PhotoGallery
│   ├── FilterState
│   └── SortMode
├── Provider
│   ├── GalleryCartProvider
│   └── GalleryCartScope
├── Page
│   └── MediaGalleriesPage
├── Widgets
│   ├── FilterBarSticky
│   ├── SelectableGalleryCard
│   └── BottomSelectionBar
└── UI Helpers
    ├── _Img, _CheckBadge, _Pill
    ├── _Drop, _SortDrop
    └── _DateRangeChip
```

### Conventions

- Widgets privés: `_WidgetName`
- Models: `PascalCase`
- Variables d'état: `_variableName`
- Constantes: `UPPER_CASE` ou `camelCase`

## 📄 Licence

Voir [LICENSE](LICENSE)

## 📞 Support

Pour toute question:
1. Consultez la documentation ci-dessus
2. Vérifiez les exemples d'intégration
3. Testez avec une galerie de test

---

**Version:** 2.0.0  
**Dernière mise à jour:** 23 janvier 2026  
**Statut:** ✅ Production Ready
