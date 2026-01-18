
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/premium_service.dart';

enum AuthAction { apple, google, email }

class AuthActionRunner extends StatefulWidget {
  const AuthActionRunner({super.key, required this.action});
  final AuthAction action;

  @override
  State<AuthActionRunner> createState() => _AuthActionRunnerState();
}

class _AuthActionRunnerState extends State<AuthActionRunner> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      switch (widget.action) {
        case AuthAction.apple:
          await AuthService.instance.signInWithApple();
          break;
        case AuthAction.google:
          await AuthService.instance.signInWithGoogle();
          break;
        case AuthAction.email:
          await _emailDialog();
          break;
      }

      // Une fois loggué, sync premium
      final uid = AuthService.instance.currentUser?.uid;
      if (uid != null) {
        await PremiumService.instance.logIn(uid);
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _emailDialog() async {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool isSignup = false;

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(isSignup ? 'Créer un compte' : 'Connexion'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: passCtrl,
                decoration: const InputDecoration(labelText: 'Mot de passe'),
                obscureText: true,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setLocal(() => isSignup = !isSignup),
                child: Text(
                  isSignup ? 'J’ai déjà un compte' : 'Créer un compte',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (isSignup) {
                  await AuthService.instance.createUserWithEmailPassword(
                    email: emailCtrl.text.trim(),
                    password: passCtrl.text,
                  );
                } else {
                  await AuthService.instance.signInWithEmailPassword(
                    email: emailCtrl.text.trim(),
                    password: passCtrl.text,
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(isSignup ? 'Créer' : 'Se connecter'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B10),
      body: Center(
        child: _error == null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Connexion…', style: TextStyle(color: Colors.white70)),
                ],
              )
            : Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
      ),
    );
  }
}
