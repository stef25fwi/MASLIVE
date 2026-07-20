# Pagination de la boutique photos

Le chargement des grandes galeries doit utiliser des pages bornées et un curseur stable composé de la date de création et de l’identifiant photo.

## Invariants

- 30 photos par page par défaut ;
- 60 photos maximum par requête ;
- aucun chargement concurrent ;
- déduplication des photos entre deux pages ;
- remise à zéro complète lors d’un changement de galerie ou de filtre ;
- `hasMore` n’est vrai que lorsqu’un curseur suivant est disponible.

Le prochain lot branche ce contrat sur le dépôt Firestore et la grille publique responsive.
