# Parcours prioritaires MASLIVE

Ce document définit les trois parcours à considérer comme des chaînes produit uniques. Une évolution d'écran ne doit pas casser la continuité de la chaîne, les données déjà saisies ni la possibilité de reprendre après une interruption.

## 1. Acheteur

`Découvrir → Carte / Explorer → Fiche → Panier ou offre → Authentification si nécessaire → Paiement → Confirmation`

### Règles de continuité

- la consultation et l'ajout au panier restent possibles sans compte ;
- le panier anonyme est conservé pendant l'authentification puis fusionné avec le panier du compte ;
- la connexion revient au panier et reprend le checkout, sans renvoi vers l'accueil ou le profil ;
- l'annulation Stripe revient au panier ;
- le succès Stripe arrive sur une confirmation contenant la commande et une action de continuation ;
- les retours arrière conservent la carte, les filtres, la fiche consultée et le panier.

### Critères d'acceptation

- un visiteur ajoute un article, se connecte et retrouve le même article et la même quantité ;
- un panier déjà présent sur le compte fusionne sans doublon logique ;
- aucune authentification ne vide le panier ;
- un paiement annulé ne vide pas le panier ;
- seul un paiement confirmé déclenche la finalisation de commande.

## 2. Vendeur

`Profil → Identité / SIRET → Stripe Connect → Publication → Vente → Livraison → Reversement`

### États obligatoires avant publication

- profil vendeur existant ;
- identité et SIRET validés pour un compte professionnel ;
- profil créateur validé pour un créateur digital ;
- compte Stripe Connect créé ;
- dossier Stripe complété ;
- encaissements activés ;
- virements activés.

Les brouillons restent autorisés pendant l'onboarding. La soumission à la modération et la publication sont bloquées lorsque le vendeur ne peut pas recevoir son reversement. Le message doit indiquer précisément l'étape manquante et proposer l'accès au bon écran.

### Critères d'acceptation

- un vendeur non payable peut préparer et sauvegarder un brouillon ;
- il ne peut pas soumettre ce brouillon comme publication vendable ;
- après validation SIRET et activation Stripe, le même brouillon peut être soumis ;
- une vente affiche son état de livraison et son état de reversement ;
- un compte devenu payable après une vente déclenche une réconciliation automatique des reversements en attente.

## 3. Groupe et tracking

`Créer le groupe → Associer les trackers → Consentement → Démarrer → Suivre → Arrêter → Historique`

### Règles de consentement

- le tracker connaît le groupe destinataire avant de démarrer ;
- la cadence, l'impact batterie et la création d'un historique sont expliqués ;
- une case d'accord explicite est requise avant chaque démarrage ;
- l'accord est daté et versionné dans l'espace privé de l'utilisateur ;
- le bouton d'arrêt reste visible pendant toute la session ;
- l'arrêt ferme la session, coupe la position live et propose immédiatement l'historique.

### Cadence actuelle

- environ 15 secondes en mouvement ;
- environ 45 secondes à faible vitesse ;
- environ 60 secondes à l'arrêt ;
- historique environ toutes les 2 minutes ou après un déplacement significatif.

### Critères d'acceptation

- aucun tracking ne démarre sans accord explicite et permission GPS ;
- l'administrateur ne voit que les trackers rattachés à son groupe ;
- l'arrêt retire rapidement la position live ;
- la session terminée apparaît dans l'historique avec son résumé ;
- une nouvelle session demande un nouveau consentement.

## Validation transversale

Chaque parcours doit disposer de tests couvrant : succès, annulation, absence d'authentification, erreur réseau, reprise après interruption, double clic/idempotence et autorisations Firestore.
