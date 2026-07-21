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
    expect(source, contains('MasliveTheme.actionGradient'));

    // Les couleurs de marque ne doivent pas être redéfinies localement dans
    // cette page : elles restent centralisées dans MasliveTheme/MasliveTokens.
    expect(source, isNot(contains('Color(0x')));
  });
}
