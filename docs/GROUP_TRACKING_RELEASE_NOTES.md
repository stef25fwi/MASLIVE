# Release notes — optimisation tracking groupe

Cette branche remplace le suivi GPS très fréquent par une logique adaptative et renforce le calcul du point groupe.

Principaux effets attendus :

- baisse forte de la consommation batterie ;
- baisse des écritures Firestore ;
- point groupe moins instable ;
- exclusion des erreurs GPS et sauts impossibles ;
- point Admin Groupe calculé principalement depuis les trackers ;
- meilleur comportement avec 3 à 10 trackers.
