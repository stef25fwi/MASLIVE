import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('le profil reste construit sur le thème global MASLIVE', () {
    final source = File('lib/pages/account_page.dart').readAsStringSync();

    expect(source, contains("import '../ui/theme/maslive_theme.dart';"));
    expect(source, contains("import '../ui/widgets/honeycomb_background.dart';"));
    expect(source, contains("import '../ui/widgets/maslive_card.dart';"));
    expect(source, contains("import '../widgets/rainbow_header.dart';"));

    expect(source, contains('HoneycombBackground('));
    expect(source, contains('RainbowHeader('));
    expect(source, contains('MasliveCard('));
    expect(source, contains('Theme.of(context).textTheme'));
    expect(source, contains('MasliveTheme.surfaceAlt'));
    expect(source, contains('MasliveTheme.textPrimary'));
    expect(
      source,
      anyOf(
        contains('MasliveTheme.textSecondary'),
        contains('MasliveTokens.textMuted'),
        contains('MasliveTokens.text'),
      ),
    );

    // Le dégradé de marque est porté par RainbowHeader. La page ne doit pas le
    // redéfinir ni introduire de couleurs locales hors design system.
    expect(source, isNot(contains('Color(0x')));
  });

  test('les accès du profil sont regroupés en thèmes stables', () {
    final source = File('lib/pages/account_page.dart').readAsStringSync();

    const themes = <String>[
      'Administration MASLIVE',
      'Compte & préférences',
      'Groupes & communauté',
      'Création & activité',
      'Achats & médias',
    ];
    for (final theme in themes) {
      expect(source, contains(theme), reason: 'Thème manquant : $theme');
    }

    const criticalRoutes = <String>[
      "route: '/account-admin'",
      "route: '/account'",
      "route: '/group-admin'",
      "route: '/media-marketplace/photographer'",
      "route: '/bloom-art/dashboard'",
      "route: '/purchase-history'",
    ];
    for (final route in criticalRoutes) {
      expect(source, contains(route), reason: 'Route manquante : $route');
    }

    expect(source, contains('maintainState: true'));
    expect(source, contains("PageStorageKey<String>('account-theme-"));
    expect(
      source.indexOf('_AccountTileTheme.administration'),
      lessThan(source.indexOf('_AccountTileTheme.account')),
      reason: 'L’administration doit rester le premier thème administrateur.',
    );
  });
}
