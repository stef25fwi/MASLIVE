# AUDIT UX/UI BOUTIQUE STOREX — MASLIVE

Date: 2026-02-11

## Périmètre
Audit UX/UI du module Boutique (Storex) avec focus sur :
- Traduction i18n
- Normalisation prix Stripe
- Images miniatures panier
- Détails articles (ligne premium)
- Header couleur rainbow
- Menu burger (design et couleurs)

---

## ✅ Points validés (déjà bien implémentés)

### 1. Images miniatures dans le panier
**Statut** : ✅ **EXCELLENT**
- Miniatures 64x64 avec ClipRRect (bordures arrondies 12px)
- Support assets locaux (`imagePath`) ET images web (`imageUrl`)
- Fallback icon si pas d'image
- Code : `app/lib/pages/cart_page.dart` lignes 101-123

### 2. Normalisation prix Stripe
**Statut** : ✅ **PARFAIT**
- Tous les prix en `priceCents` (centimes) → compatible Stripe
- Format affiché : `20,00 €` (virgule européenne + symbole €)
- Méthode `priceLabel` dans `GroupProduct` model
- Backend `createStorexPaymentIntent` calcule correctement en cents
- Code : `app/lib/models/product_model.dart` lignes 42-47

### 3. Traduction i18n
**Statut** : ✅ **COMPLET**
- Toutes les clés de la boutique traduites en FR/EN/ES
- Fichiers `.arb` à jour : `app/lib/l10n/app_{fr,en,es}.arb`
- Clés présentes :
  - `shopBestSeller`, `shopSeeMore`
  - `myOrders`, `orders`, `orderNo`
  - `itemsLabel`, `addToCart`
  - `noProductsFound`, `noResults`, `noFavoritesYet`
  - `categories`, `home`, `search`, `profile`, `signIn`, `logout`

---

## 🔨 Points à améliorer

### 1. Header page boutique (gradient rainbow)
**Statut** : ⚠️ **À AMÉLIORER**

**Problème** :
- Header actuel (page d'accueil boutique) : AppBar blanc basique, monotone
- Fichier : `app/lib/pages/storex_shop_page.dart` lignes 203-220

**Référence existante** :
- Le panier (`cart_page.dart`) a déjà un beau header gradient rainbow :
  ```dart
  static const _headerGradient = LinearGradient(
    colors: [Color(0xFFFFE36A), Color(0xFFFF7BC5), Color(0xFF7CE0FF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  ```

**Recommandation** :
- Appliquer le même gradient dans l'AppBar de `_StorexHome`, `_StorexCategory`, `_SearchPage`
- Utiliser un `Container` avec `decoration: BoxDecoration(gradient: ...)` plutôt que `backgroundColor: Colors.white`
- Changer la couleur des icônes/texte en blanc pour contraste

**Exemple de code** :
```dart
appBar: AppBar(
  flexibleSpace: Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFFFE36A), Color(0xFFFF7BC5), Color(0xFF7CE0FF)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
    ),
  ),
  elevation: 0,
  iconTheme: const IconThemeData(color: Colors.white),
  // ... reste du code
)
```

---

### 2. Menu burger (design et couleurs)
**Statut** : ⚠️ **À AMÉLIORER**

**Problème actuel** :
- Design basique : blanc transparent avec BackdropFilter blur
- Pas de hiérarchie visuelle claire
- Fichier : `app/lib/pages/storex_shop_page.dart` lignes 432-533

**Points à améliorer** :
1. **Couleur de fond** : Remplacer `Colors.white.withAlpha(230)` par un gradient subtil ou couleur de marque
2. **Séparateurs visuels** : Divider entre sections (Home/Search/Profile vs Catégories)
3. **Hover states** : Ajouter feedback visuel sur tap (InkWell effet)
4. **Logo** : Agrandir légèrement (actuellement 34px)

**Recommandations design** :
```dart
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [
        Colors.white,
        const Color(0xFFF8F9FA),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  // OU couleur unie moderne :
  color: const Color(0xFFFAFAFA),
)
```

**Amélioration `_DrawerItem`** :
- Ajouter padding vertical/horizontal plus généreux
- Utiliser InkWell avec borderRadius pour effet ripple
- Ajouter icône devant chaque item (home, search, profile...)

---

### 3. Ligne articles détaillée (premium)
**Statut** : ⚠️ **BASIQUE, À ENRICHIR**

**Problème** :
- Affichage produit actuel : titre + prix + image uniquement
- Manque informations utiles :
  - Description courte (si disponible)
  - Variantes disponibles (tailles/couleurs)
  - Stock restant (si bas)
  - Badge "Premium" (si applicable)
  - Note/reviews (si implémentées)

**Zones concernées** :
1. **_ProductTile** (grille/liste produits) : lignes 334-395
2. **Page détail produit** : `product_detail_page.dart`

**Recommandations** :

#### A) Affichage liste/grille
Ajouter sous le prix :
- Ligne description (max 2 lignes, ellipsis)
- Badge stock si bas (`< 10` items) : "Plus que X en stock !"
- Badge premium si `tags.contains('premium')`

```dart
// Après le Text(p.priceLabel)
if (p.tags?.contains('premium') == true)
  Container(
    margin: const EdgeInsets.only(top: 4),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
      ),
      borderRadius: BorderRadius.circular(4),
    ),
    child: const Text(
      'PREMIUM',
      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
    ),
  ),
```

#### B) Page détail produit
Afficher :
- Tableau variantes (tailles × couleurs) avec stock par variante
- Description complète (si disponible dans Firestore)
- Section reviews (si activée)
- Badge modération status (pour admins)

---

## 🎨 Palette couleurs suggérée

### Gradient Rainbow (déjà utilisé dans cart)
```dart
colors: [
  Color(0xFFFFE36A), // Jaune soleil
  Color(0xFFFF7BC5), // Rose bonbon
  Color(0xFF7CE0FF), // Cyan ciel
]
```

### Couleurs complémentaires
- **Fond clair** : `Color(0xFFFAFAFA)` (gris très clair)
- **Texte principal** : `Colors.black87`
- **Texte secondaire** : `Colors.black54`
- **Accent** : `Color(0xFFFF7BC5)` (rose du gradient)
- **Succès** : `Color(0xFF4CAF50)` (vert)
- **Premium** : `Color(0xFFFFD700)` (or)

---

## 📋 Checklist implémentation

### Phase 1 : Header rainbow
- [ ] Ajouter gradient dans AppBar de `_StorexHome`
- [ ] Ajouter gradient dans AppBar de `_StorexCategory`
- [ ] Ajouter gradient dans AppBar de `_SearchPage`
- [ ] Changer icônes en blanc (contraste)

### Phase 2 : Menu burger
- [ ] Refaire design Drawer (gradient ou couleur moderne)
- [ ] Ajouter icônes devant items menu
- [ ] Améliorer padding/spacing
- [ ] Ajouter InkWell avec ripple effect

### Phase 3 : Détails articles
- [ ] Ajouter badges (premium, stock bas)
- [ ] Afficher description courte dans grille
- [ ] Enrichir page détail produit (variantes, stock, reviews)
- [ ] Ajouter tooltip survol (desktop)

---

## Priorité recommandée

1. **Header rainbow** (impact visuel immédiat, code simple)
2. **Menu burger** (amélioration UX navigation)
3. **Détails articles** (valeur ajoutée pour utilisateurs)

---

**Note** : Toutes les améliorations doivent conserver la compatibilité avec le système actuel (Firestore schema, modèles, routes).
