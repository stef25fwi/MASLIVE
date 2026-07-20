# Pagination de la boutique photos

Le chargement des grandes galeries utilise des pages bornées et un curseur stable composé de la date de création et de l’identifiant photo.

## Invariants

- 30 photos par page par défaut ;
- 60 photos maximum par requête ;
- aucun chargement concurrent ;
- déduplication des photos entre deux pages ;
- remise à zéro complète lors d’un changement de galerie ou de filtre ;
- `hasMore` n’est vrai que lorsqu’un curseur suivant est disponible ;
- reprise Firestore avec `startAfter(createdAt, documentId)` ;
- abandon d’une réponse tardive lorsque la galerie sélectionnée a changé.

## Interface publique

La grille paginée utilise :

- 2 colonnes sur mobile ;
- 3 colonnes à partir de 620 px ;
- 4 colonnes à partir de 900 px ;
- 5 colonnes à partir de 1 180 px ;
- 6 colonnes à partir de 1 500 px ;
- un bouton `Charger plus de photos` désactivé pendant la requête ;
- un indicateur visuel pendant le chargement de la page suivante.

Le composant `PaginatedMediaPhotoGrid` écoute directement le contrôleur de catalogue afin d’afficher les nouvelles photos sans fermer la galerie.
