# Pagination de la boutique photos

Le chargement des grandes galeries utilise des pages bornées et un curseur stable composé de la date de création et de l’identifiant photo.

## Invariants de pagination

- 30 photos par page par défaut ;
- 60 photos maximum par requête ;
- requête Firestore `limit(pageSize + 1)` ;
- tri stable `createdAt DESC`, puis identifiant document ;
- reprise avec `startAfter(createdAt, photoId)` ;
- aucun chargement concurrent ;
- déduplication des photos entre deux pages ;
- remise à zéro complète lors d’un changement de galerie ou de filtre ;
- une réponse tardive est ignorée lorsque la galerie active a changé ;
- `hasMore` n’est vrai que lorsqu’un curseur suivant est disponible.

## Interface

- grille adaptative de 2 à 6 colonnes selon la largeur disponible ;
- bouton « Charger plus de photos » désactivé pendant la requête ;
- indicateur de chargement intégré ;
- le contrôleur reste la source unique de vérité pour les photos visibles.

## Cohérence du profil

La page profil reste construite avec le design system global :

- `HoneycombBackground` pour l’arrière-plan ;
- `RainbowHeader` pour l’en-tête de marque ;
- `MasliveCard` pour les surfaces ;
- `Theme.of(context).textTheme` pour la typographie ;
- `MasliveTheme` et `MasliveTokens` pour les couleurs, gradients et séparateurs.

Un test source dédié empêche la réintroduction de couleurs de marque hexadécimales locales dans `account_page.dart`.
