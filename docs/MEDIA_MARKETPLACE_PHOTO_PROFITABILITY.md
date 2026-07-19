# MASLIVE — Boutique photos rentable

## Parcours photographe

L’onglet **Ma boutique photos** du profil photographe centralise :

- la formule active, le quota de photos et le stockage utilisé ;
- la création de galeries rattachées à un pays, un événement et un circuit ;
- l’import multiple avec reprise Firebase Storage et progression visible ;
- la génération serveur des miniatures, aperçus et versions filigranées ;
- la publication, la couverture, l’archivage et les ventes ;
- Stripe Connect, bloquant la publication tant que les reversements ne sont pas actifs.

Chaque galerie reçoit automatiquement les cinq packs acheteurs MASLIVE :

| Pack | Photos | Prix |
|---|---:|---:|
| Souvenir | 1 | 6,90 € |
| Duo | 2 | 10,90 € |
| Essentiel | 5 | 19,90 € |
| Expérience | 10 | 29,90 € |
| Galerie personnelle | 20 | 44,90 € |

Le panier regroupe les photos par photographe et par galerie. Le backend recalcule toujours le prix depuis le catalogue serveur et ignore le prix transmis par Flutter.

## Abonnements photographes

| Formule | Prix/mois | Photos | Stockage | Qualité | Conservation | Commission |
|---|---:|---:|---:|---:|---:|---:|
| Découverte | 0 € | 250 | 3 Go | 12 MP / 8 Mo | 30 j | 30 % |
| Pro | 19,90 € | 3 000 | 30 Go | 24 MP / 20 Mo | 183 j | 25 % |
| Studio | 39,90 € | 10 000 | 120 Go | 40 MP / 40 Mo | 365 j | 20 % |
| Agence | 79,90 € | 30 000 | 400 Go | 60 MP / 60 Mo | 548 j | 15 % |

Les extensions sont :

- +1 000 photos et +10 Go : 5,90 €/mois ;
- +5 000 photos et +50 Go : 19,90 €/mois ;
- événement 30 jours, +5 000 photos et +50 Go : 9,90 €.

À 100 % du quota, les médias déjà publiés restent vendables. Seuls les nouveaux imports sont refusés.

## Stockage

Arborescence :

```text
photographers/{photographerId}/events/{eventId}/galleries/{galleryId}/
  originals/{photoId}.jpg
  previews/{photoId}.webp
  thumbs/{photoId}.webp
  watermarked/{photoId}.webp
```

- Les originaux et previews non filigranées ne sont jamais publics.
- Les miniatures et aperçus filigranés peuvent être affichés dans le catalogue.
- Les fichiers achetés sont remis avec une URL signée de 15 minutes, après contrôle d’un entitlement.
- La grille utilise uniquement les miniatures ; les originaux ne sont jamais chargés dans le catalogue.
- Le backend Sharp génère un thumbnail 480 px, un preview 1 600 px et le watermark MASLIVE.

## Conservation et suppression

Chaque photo possède un champ Firestore `purgeAt` :

- photo non vendue : conservation de la formule + 30 jours de délai de suppression ;
- photo vendue : conservation portée à 730 jours ;
- suppression TTL du document : le trigger `syncMediaPhotoOnDelete` efface l’original et les trois dérivés ;
- imports temporaires : suppression Storage après 1 jour ;
- rejet et corbeille : suppression après 7 jours.

Configuration :

```bash
FIREBASE_PROJECT_ID=maslive \
FIREBASE_STORAGE_BUCKET=maslive.appspot.com \
bash scripts/configure_media_marketplace_lifecycle.sh
```

Le bucket exact doit être fourni lorsque le projet utilise le domaine `firebasestorage.app`.

## Paiement et marge

Le checkout applique :

- prix recalculé serveur ;
- commission selon le plan actif ;
- estimation Stripe France/EEE à 1,5 % + 0,25 € ;
- création d’entitlements immuables ;
- prolongation de conservation des photos vendues ;
- ledger de reversement par photographe ;
- transfert Stripe Connect idempotent après confirmation du paiement.

Un reversement sans compte Stripe payable reste en statut `blocked_connect_required`. Un échec Stripe reste traçable dans `payout_ledger` avec son code et son message.

## Sécurité et droit à l’image

- Les règles Storage interdisent tout accès public aux originaux.
- Les écritures de dérivés sont réservées à l’Admin SDK.
- Les photos passent par la file `admin_moderation_queue` avant publication.
- Le modèle prévoit `moderationStatus`, `lifecycleStatus`, `faceTags`, `bibNumbers` et les informations de circuit pour ajouter ultérieurement les recherches par dossard, créneau et consentement.
- La recherche biométrique n’est pas activée sans audit RGPD dédié.

## Contrôles de production

1. Déployer les règles Firestore et Storage.
2. Déployer les fonctions marketplace et le webhook Stripe.
3. Exécuter le script de TTL/lifecycle.
4. Créer un compte Stripe Connect test puis vérifier `charges_enabled` et `payouts_enabled`.
5. Importer un fichier dépassant le quota et vérifier son rejet.
6. Acheter 5 photos et vérifier un total de 19,90 €.
7. Vérifier l’entitlement, le lien signé et le transfert Connect.
8. Vérifier qu’une photo vendue reçoit un `purgeAt` à 730 jours.
