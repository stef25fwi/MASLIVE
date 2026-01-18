import 'package:flutter/material.dart';
import 'session_controller.dart';

Future<void> requireSignIn(
  BuildContext context, {
  required SessionController session,
  VoidCallback? onSignedIn,
}) async {
  if (session.isSignedIn) {
    onSignedIn?.call();
    return;
  }

  final goLogin = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Créer un compte ?'),
      content: const Text(
        'En mode invité, tu peux consulter la carte et les couches.\n'
        'Connecte-toi pour enregistrer tes favoris et personnaliser ton expérience.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Continuer en invité'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Se connecter'),
        ),
      ],
    ),
  );

  if (goLogin == true && context.mounted) {
    await Navigator.pushNamed(context, '/login');
    if (session.isSignedIn) {
      onSignedIn?.call();
    }
  }
}
