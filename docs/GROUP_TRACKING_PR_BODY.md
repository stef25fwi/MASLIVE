## Objectif

Réduire la batterie, le trafic et les coûts Firestore du tracking groupe tout en améliorant la précision du point Admin Groupe.

## Changements

- cadence mobile adaptative 15 / 45 / 60 secondes ;
- filtre distance GPS 15 mètres ;
- historique limité à 60 secondes ou 30 mètres ;
- calcul serveur limité à une fois toutes les 15 secondes ;
- trackers uniquement en fonctionnement normal ;
- Admin Groupe utilisé uniquement comme fallback ;
- poids précision inverse au carré + fraîcheur ;
- filtre médiane/MAD ;
- rejet vitesse impossible ;
- lissage et double confirmation des sauts supérieurs à 150 mètres ;
- publication circuit à partir de 5 mètres ou heartbeat 30 secondes ;
- nettoyage serveur des présences inactives ;
- plafond 10 trackers, idéal 5 ;
- tests unitaires Node ajoutés.
