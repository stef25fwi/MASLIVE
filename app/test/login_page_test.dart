import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masslive/l10n/app_localizations.dart';
import 'package:masslive/pages/login_page.dart';

void main() {
  Widget buildPage() {
    return MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const LoginPage(),
    );
  }

  testWidgets('shows forgot password in sign in mode', (tester) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    expect(find.text('Mot de passe oublié?'), findsOneWidget);
    expect(find.text('Confirmer le mot de passe'), findsNothing);
  });

  testWidgets('switches to sign up mode with confirmation field', (
    tester,
  ) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Créer un compte avec email').first);
    await tester.pumpAndSettle();

    expect(find.text('Confirmer le mot de passe'), findsOneWidget);
    expect(find.text('Mot de passe oublié?'), findsNothing);
  });

  testWidgets('opens reset password dialog from sign in mode', (tester) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mot de passe oublié?'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Mot de passe oublié?'), findsWidgets);
  });
}
