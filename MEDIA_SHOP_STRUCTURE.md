# 🛍️ Structure Page Médias - Shop Photos

## 📋 Vue d'ensemble

La nouvelle structure de la page médias (`media_galleries_page_v2.dart`) implémente un système complet de boutique photo avec:

- ✅ **Sélection multiple** avec checkmarks
- ✅ **Panier d'achat** persistant
- ✅ **Filtres cascadés** (pays → date → événement → groupe → photographe)
- ✅ **Tri** (récent, nb photos, prix ↑↓)
- ✅ **Barre de sélection** en bas de page
- ✅ **Preview modale** pour chaque galerie
- ✅ **Panier modal** avec checkout

## 🏗️ Architecture

### Composants principaux

```
MediaShopWrapper
└── GalleryCartScope (Provider)
    └── MediaGalleriesPage
        ├── RainbowHeader (avec badge panier)
        ├── FilterBarSticky (filtres sticky)
        ├── SliverGrid (galeries sélectionnables)
        └── BottomSelectionBar (barre sélection)
```

### Models

#### `PhotoGallery`
```dart
PhotoGallery({
  id, title, subtitle,
  coverUrl, images, photoCount,
  country, date, eventName, groupName, photographerName,
  pricePerPhoto,
})
```

#### `FilterState`
```dart
FilterState({
  country?, dateRange?, eventName?, 
  groupName?, photographerName?, sort
})
```

#### `GalleryCartProvider` (ChangeNotifier)
- `selected` - Galeries cochées (checkmarks)
- `cart` - Galeries dans le panier
- `toggleSelected()` - Cocher/décocher
- `addSelectedToCart()` - Ajouter sélection au panier
- `clearSelected()` / `clearCart()` - Vider

## 🚀 Utilisation

### 1. Navigation de base

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => const MediaShopWrapper(groupId: 'all'),
  ),
);
```

### 2. Accès au panier depuis un autre écran

```dart
final cart = GalleryCartScope.of(context);

// Consulter l'état
print('Panier: ${cart.cartCount} galeries');
print('Total: ${cart.cartTotal}€');

// Écouter les changements
AnimatedBuilder(
  animation: cart,
  builder: (context, _) {
    return Text('Panier: ${cart.cartCount}');
  },
)
```

## 🗃️ Structure Firestore requise

### Collection: `media_galleries`

```json
{
  "title": "Carnaval 2026",
  "subtitle": "Défilé principal",
  "coverUrl": "https://...",
  "images": ["url1", "url2", "..."],
  "photoCount": 45,
  
  // Métadonnées de filtrage (OBLIGATOIRES)
  "country": "Guadeloupe",
  "date": Timestamp,
  "eventName": "Défilé Pointe-à-Pitre",
  "groupName": "Akiyo",
  "photographerName": "Kris Photo",
  "pricePerPhoto": 8.0,
  
  // Autres
  "groupId": "akiyo",
  "createdAt": Timestamp
}
```

## 🎨 Fonctionnalités

### Filtres cascadés

Les filtres se réinitialisent intelligemment quand un filtre parent change:

1. **Pays** → reset tout
2. **Date** → reset événement, groupe, photographe
3. **Événement** → reset groupe, photographe
4. **Groupe** → reset photographe

### Sélection & Panier

1. **Checkmark** sur une galerie → ajout à `selected`
2. **Bouton panier** dans card → ajout direct au panier
3. **Barre en bas** (si sélection > 0) → "Ajouter au panier"
4. **Badge** en haut à droite → ouvre modal panier

### Tri

- **Plus récentes** (défaut)
- **Nb photos** (plus de photos en premier)
- **Prix ↑** (croissant)
- **Prix ↓** (décroissant)

## 🔧 Migration depuis l'ancienne version

### Avant (`media_galleries_page.dart`)

```dart
// Ancienne structure simple
MediaGalleriesPage(groupId: 'all')
```

### Après (`media_galleries_page_v2.dart`)

```dart
// Nouvelle structure avec panier
MediaShopWrapper(groupId: 'all')
```

## 📝 Checklist de déploiement

- [ ] Mettre à jour les documents Firestore avec les nouveaux champs:
  - `country`
  - `date`
  - `eventName`
  - `groupName`
  - `photographerName`
  - `pricePerPhoto`

- [ ] Remplacer les appels à `MediaGalleriesPage` par `MediaShopWrapper`

- [ ] Tester les filtres cascadés

- [ ] Tester le panier (ajout, retrait, vider)

- [ ] Implémenter le checkout Stripe dans `_openCartSheet()`

- [ ] Vérifier l'affichage sur mobile (responsive)

## 🎯 Prochaines étapes

1. **Checkout Stripe** - Remplacer le placeholder par l'intégration Stripe
2. **Favoris** - Ajouter système de favoris pour galeries
3. **Partage** - Bouton partage sur preview
4. **Téléchargement** - Après paiement, permettre téléchargement
5. **Watermark** - Afficher preview avec watermark avant achat

## 🐛 Debug

### Le panier ne s'affiche pas
→ Vérifier que vous utilisez `MediaShopWrapper` et non `MediaGalleriesPage` directement

### Les filtres ne fonctionnent pas
→ Vérifier que vos documents Firestore ont les champs `country`, `date`, `eventName`, etc.

### Erreur "GalleryCartScope not found"
→ Utiliser `MediaShopWrapper` qui wrappe automatiquement avec le scope

## 📚 Ressources

- Structure inspirée du modèle shop photos standard
- UI Material Design 3
- Filtres cascadés UX best practices
- Pattern Provider avec InheritedNotifier (sans package)
