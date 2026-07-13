import 'package:flutter/widgets.dart';

import 'user_facing_bottom_bar.dart';

/// Pont léger entre la bottom bar (chargée eager) et le shell utilisateur
/// (bibliothèque différée). La bar ne doit PAS importer la page shell: cela
/// embarquerait le shell et ses onglets dans le bundle JS initial et
/// annulerait le découpage deferred du démarrage.
///
/// `UserFacingShellPage` installe ce callback quand un shell est vivant et le
/// retire à sa destruction. La bar l'appelle pour revenir instantanément au
/// shell existant (onglets et carte conservés) au lieu d'en reconstruire un.
bool Function(BuildContext context, UserFacingBottomBarTab tab)?
    activeShellTabSwitcher;
