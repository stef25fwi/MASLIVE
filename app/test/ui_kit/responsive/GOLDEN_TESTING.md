# Références visuelles responsives

Les références golden couvrent quatre classes d’écran représentatives :

- 320 px : smartphone compact ;
- 600 px : tablette ;
- 1024 px : desktop ;
- 1440 px : grand écran.

La matrice fonctionnelle complémentaire contrôle également 360, 390, 430, 768 et 1280 px, puis répète les neuf largeurs avec un facteur de texte de 150 %.

La génération CI utilise Flutter 3.44.4 sur Ubuntu afin de conserver un rendu reproductible. Elle vérifie les goldens, la matrice et l’accessibilité avant de publier les images ; le Quality Gate général réalise l’analyse Flutter et la suite complète. En cas d’échec, le diagnostic détaillé est conservé dans un artefact CI isolé afin de corriger le viewport concerné sans assouplir les contrôles. La validation finale exige la réussite simultanée des références visuelles, de la matrice et des contrats de production. Les exécutions devenues obsolètes sont annulées automatiquement afin que seul le dernier commit de la PR puisse publier les références.

Les journaux de génération et de matrice sont temporaires : ils ne doivent jamais être conservés dans la branche après une validation réussie. Seules les images PNG de référence sont versionnées. La publication est effectuée après les tests, sur le dernier head synchronisé de la PR.

Les quatre PNG versionnés constituent désormais la référence officielle des classes compact, tablette, desktop et grand écran. Toute évolution ultérieure devra être intentionnelle, vérifiée sur la matrice complète et accompagnée d’une régénération explicite.

Génération contrôlée :

```bash
flutter test test/ui_kit/responsive/responsive_golden_test.dart --update-goldens
```

Vérification :

```bash
flutter test test/ui_kit/responsive/responsive_golden_test.dart
flutter test test/ui_kit/responsive/responsive_viewport_matrix_test.dart
```

Les images doivent être régénérées uniquement lorsque l’évolution visuelle est volontaire et validée.
