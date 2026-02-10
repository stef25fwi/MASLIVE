# 🌐 Guide de Traduction du Shop MASLIVE

## Vue d'ensemble

La boutique MASLIVE est maintenant **100% traduite** en 3 langues:
- 🇫🇷 **Français (FR)** - Langue par défaut
- 🇬🇧 **Anglais (EN)**
- 🇪🇸 **Espagnol (ES)**

## Fichiers Traduits

### Fichiers de Traduction (ARB)

| Fichier | Localisation | Nouvelles clés ajoutées |
|---------|--------------|-------------------------|
| `app/lib/l10n/app_en.arb` | Anglais | 20+ clés shop |
| `app/lib/l10n/app_fr.arb` | Français | 20+ clés shop |
| `app/lib/l10n/app_es.arb` | Espagnol | 20+ clés shop |

### Pages du Shop

| Fichier | Descriptions | Modifications |
|---------|-------------|---------------|
| `cart_page.dart` | Page panier | Import l10n + 15 remplacements |
| `product_detail_page.dart` | Détail produit | 4 remplacements |
| `storex_shop_page.dart` | Page shop | 2 remplacements |

## Nouvelles Clés de Traduction

### Cart & Checkout

```json
{
  "retry": "Réessayer / Retry / Reintentar",
  "reconnectToRetry": "Veuillez vous reconnecter / Please reconnect / Vuelva a conectarse",
  "emptyCart": "Vider / Empty cart / Vaciar",
  "userNotFound": "Utilisateur introuvable / User not found / Usuario no encontrado",
  "placeOrder": "Commander / Place order / Realizar pedido",
  "checkoutMissingUrl": "URL de checkout manquante / Checkout URL missing / URL de pago faltante",
  "cannotOpenPaymentUrl": "Impossible d'ouvrir l'URL / Cannot open URL / No se puede abrir",
  "paymentCreationError": "Erreur paiement / Payment error / Error al crear pago",
  "mustBeLoggedInToOrder": "Connexion requise / Must be logged in / Debe iniciar sesión",
  "accessDeniedCheckPermissions": "Accès refusé / Access denied / Acceso denegado",
  "yourCartIsEmpty": "Panier vide / Cart empty / Carrito vacío",
  "tooManyRequestsRetryLater": "Trop de requêtes / Too many requests / Demasiadas solicitudes",
  "serviceTemporarilyUnavailableRetry": "Service indisponible / Unavailable / No disponible"
}
```

### Product Detail

```json
{
  "reviews": "Avis / Reviews / Reseñas",
  "size": "Taille / Size / Talla",
  "color": "Couleur / Color / Color",
  "productUnavailable": "❌ Produit indisponible / Unavailable / No disponible",
  "insufficientStock": "❌ Stock insuffisant / Insufficient / Insuficiente",
  "addedToCart": "✅ Ajouté / Added / Añadido"
}
```

### Messages avec Placeholders

#### 1. Erreur inconnue
```dart
l10n.AppLocalizations.of(context)!.unknownError.replaceAll('{code}', e.code)
```
- FR: "Erreur inconnue: {code}"
- EN: "Unknown error: {code}"
- ES: "Error desconocido: {code}"

#### 2. Label erreur
```dart
l10n.AppLocalizations.of(context)!.errorLabel.replaceAll('{message}', e.toString())
```
- FR: "Erreur: {message}"
- EN: "Error: {message}"
- ES: "Error: {message}"

#### 3. Stock insuffisant
```dart
l10n.AppLocalizations.of(context)!.insufficientStock.replaceAll('{stock}', stockAvailable.toString())
```
- FR: "❌ Stock insuffisant (disponible: {stock})"
- EN: "❌ Insufficient stock (available: {stock})"
- ES: "❌ Stock insuficiente (disponible: {stock})"

#### 4. Ajout au panier
```dart
l10n.AppLocalizations.of(context)!.addedToCart
  .replaceAll('{quantity}', quantity.toString())
  .replaceAll('{title}', p.title)
  .replaceAll('{size}', size)
  .replaceAll('{color}', color)
```
- FR: "✅ Ajouté: {quantity} x {title} ({size}, {color})"
- EN: "✅ Added: {quantity} x {title} ({size}, {color})"
- ES: "✅ Añadido: {quantity} x {title} ({size}, {color})"

## Utilisation

### Changer la langue

L'utilisateur peut changer la langue depuis 2 endroits:

1. **Header (AppBar)**: Icône 🌐 en haut de chaque page
2. **Drawer (Menu)**: Icône 🌐 dans le menu hamburger

### Exemple de code

```dart
// Utiliser une traduction simple
Text(l10n.AppLocalizations.of(context)!.placeOrder)

// Utiliser une traduction avec placeholder
Text(
  l10n.AppLocalizations.of(context)!.insufficientStock
    .replaceAll('{stock}', stockAvailable.toString())
)
```

## Ajouter une Nouvelle Traduction

### Étape 1: Ajouter la clé dans les 3 fichiers ARB

**app_en.arb:**
```json
"myNewKey": "My new text in English"
```

**app_fr.arb:**
```json
"myNewKey": "Mon nouveau texte en français"
```

**app_es.arb:**
```json
"myNewKey": "Mi nuevo texto en español"
```

### Étape 2: Utiliser dans le code

```dart
import '../l10n/app_localizations.dart' as l10n;

// Dans le widget
Text(l10n.AppLocalizations.of(context)!.myNewKey)
```

### Étape 3: Avec placeholders

**Dans les ARB:**
```json
"greeting": "Hello, {name}!",
"@greeting": {
  "description": "Greeting message",
  "placeholders": {
    "name": {
      "type": "String",
      "example": "John"
    }
  }
}
```

**Dans le code:**
```dart
Text(
  l10n.AppLocalizations.of(context)!.greeting
    .replaceAll('{name}', userName)
)
```

## Tests de Traduction

### Vérifier que tout fonctionne

1. **Lancer l'app**
2. **Naviguer vers le shop**
3. **Changer la langue** (FR → EN → ES)
4. **Vérifier les pages:**
   - Page d'accueil shop
   - Détail produit
   - Panier
   - Messages d'erreur (essayer d'ajouter un produit sans stock)

### Checklist de vérification

- [ ] Header shop traduit
- [ ] Drawer menu traduit
- [ ] Page catégories traduite
- [ ] Détail produit traduit (taille, couleur, avis)
- [ ] Messages stock traduits
- [ ] Page panier traduite
- [ ] Boutons traduits (Vider, Commander)
- [ ] Messages erreur checkout traduits
- [ ] Confirmation ajout panier traduite

## Couverture de Traduction

### Pages 100% traduites

- ✅ **StorexShopPage** - Page principale boutique
- ✅ **CartPage** - Page panier
- ✅ **ProductDetailPage** - Détail produit
- ✅ **MyOrdersPage** - Mes commandes (déjà traduite)

### Composants traduits

- ✅ Headers (AppBar)
- ✅ Drawers (Menu latéral)
- ✅ Boutons d'action
- ✅ Messages d'erreur
- ✅ Messages de confirmation
- ✅ Labels de formulaire
- ✅ Messages de stock

## Support Multi-langue

### Langues supportées

| Code | Langue | Flag | Statut |
|------|--------|------|--------|
| `fr` | Français | 🇫🇷 | ✅ Complet |
| `en` | English | 🇬🇧 | ✅ Complet |
| `es` | Español | 🇪🇸 | ✅ Complet |

### Langue par défaut

La langue par défaut est **Français (FR)** et sera utilisée si:
- L'utilisateur n'a pas encore choisi de langue
- La langue système n'est pas supportée
- Une clé de traduction manque

## Maintenance

### Ajouter une nouvelle langue

Pour ajouter une 4ème langue (ex: Allemand):

1. Créer `app/lib/l10n/app_de.arb`
2. Copier toutes les clés de `app_en.arb`
3. Traduire toutes les valeurs en allemand
4. Ajouter la langue dans `LanguageService`
5. Tester toutes les pages

### Mettre à jour une traduction

1. Modifier la valeur dans les 3 fichiers ARB
2. Sauvegarder
3. Hot reload dans Flutter (r dans le terminal)
4. Vérifier le changement

## Ressources

### Fichiers importants

- `app/lib/l10n/` - Dossier des traductions
- `app/lib/services/language_service.dart` - Service de langue
- `app/lib/widgets/language_switcher.dart` - Widget sélecteur

### Documentation Flutter

- [Internationalization](https://flutter.dev/docs/development/accessibility-and-localization/internationalization)
- [ARB Format](https://github.com/google/app-resource-bundle/wiki/ApplicationResourceBundleSpecification)

---

✅ **La boutique MASLIVE est maintenant 100% multilingue!**
