# Plan A — allègement du tracking groupe

Configuration de production :

- live tracker : 15 s en mouvement, 45 s lent, 60 s immobile ;
- calcul du centre groupe : 30 s maximum ;
- mise à jour du profil tracker : 5 minutes ;
- historique : 120 s ou 60 mètres ;
- heartbeat historique immobile : 5 minutes ;
- publication circuit : déplacement d’au moins 5 mètres ou heartbeat de 60 s ;
- le document parent de session n’est plus réécrit à chaque point historique ; il est finalisé à l’arrêt.

Objectif : conserver la précision du point groupe tout en réduisant les écritures Firestore permanentes et les mises à jour non indispensables.
