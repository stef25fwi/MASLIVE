# Tracking groupe — batterie, qualité et coût

## Réglages appliqués

- GPS mobile : précision haute uniquement pendant la session, filtre distance 15 m.
- Envoi live adaptatif : 15 s en mouvement, 45 s lent, 60 s immobile.
- Historique : 60 s ou 30 m, au lieu de chaque position live.
- Profil tracker/admin : mise à jour toutes les 60 s.
- Présence live : TTL 120 s et suppression serveur à l'arrêt.
- Agrégation serveur : maximum une fois toutes les 15 s.
- Publication carte : déplacement supérieur ou égal à 5 m, ou heartbeat 30 s.

## Qualité de calcul

- seuls les trackers sont utilisés en fonctionnement normal ;
- l'Admin Groupe est un secours si moins de deux trackers sont disponibles ;
- précision manquante = 50 m, jamais 0 m ;
- poids = précision inverse au carré × décroissance avec l'âge ;
- poids individuel plafonné à 4 fois le poids médian ;
- filtre robuste par médiane et MAD, seuil entre 80 et 250 m ;
- rejet des sauts impliquant une vitesse supérieure à 25 m/s ;
- lissage 35 % nouvelle position / 65 % ancienne ;
- déplacement supérieur à 150 m confirmé par deux calculs cohérents ;
- maximum 10 trackers pris dans le calcul, les meilleurs points étant retenus.

## Dimensionnement recommandé

- minimum utile : 3 trackers ;
- idéal : 5 trackers ;
- grand groupe : 6 à 8 trackers ;
- plafond de calcul : 10 trackers.

Répartition conseillée pour 5 trackers : avant, arrière, centre, gauche, droite.
