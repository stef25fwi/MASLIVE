# Références visuelles responsives

Les références golden couvrent quatre classes d’écran représentatives :

- 320 px : smartphone compact ;
- 600 px : tablette ;
- 1024 px : desktop ;
- 1440 px : grand écran.

La matrice fonctionnelle complémentaire contrôle également 360, 390, 430, 768 et 1280 px, puis répète les neuf largeurs avec un facteur de texte de 150 %.

La génération CI utilise Flutter 3.44.4 sur Ubuntu afin de conserver un rendu reproductible. Elle vérifie les goldens, la matrice, l’accessibilité puis l’analyse Flutter avant de publier les images. En cas d’échec, le diagnostic détaillé est conservé dans un artefact CI isolé afin de corriger le viewport concerné sans assouplir les contrôles. Les corrections de test ciblées doivent repasser la matrice complète avant publication.

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
