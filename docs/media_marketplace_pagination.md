# Pagination de la boutique photos

Le chargement des grandes galeries utilise désormais des pages bornées et un curseur stable composé de la date de création et de l’identifiant photo.

## Invariants

- 30 photos par page par défaut ;
- 60 photos maximum par requête ;
- requête Firestore `limit(pageSize + 1)` pour détecter la page suivante ;
- tri stable `createdAt DESC`, puis identifiant document `DESC` ;
- reprise avec `startAfter(createdAt, photoId)` ;
- aucun chargement concurrent ;
- déduplication des photos entre deux pages ;
- remise à zéro complète lors d’un changement de galerie ou de filtre ;
- `hasMore` n’est vrai que lorsqu’un curseur suivant est disponible ;
- abandon sécurisé d’une réponse si l’utilisateur a changé de galerie pendant le chargement.

Le contrôleur public expose `hasMorePhotos`, `loadingMorePhotos`, `canLoadMorePhotos` et `loadMorePhotos()` pour permettre un bouton ou un chargement infini côté interface.
