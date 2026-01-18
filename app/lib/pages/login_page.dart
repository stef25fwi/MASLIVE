import 'package:flutter/material.dart';
import '../session/session_scope.dart';
import 'auth/auth_action_runner.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _run(Future<void> Function() fn) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await fn();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/router');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runProvider(AuthAction action) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AuthActionRunner(action: action)),
      );

      if (!mounted) return;

      final session = SessionScope.of(context);
      if (session.isSignedIn) {
        Navigator.of(context).pushReplacementNamed('/router');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _pass,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mot de passe'),
            ),
            const SizedBox(height: 14),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _loading
                        ? null
                        : () => _run(
                            () => AuthService.instance.signInWithEmailPassword(
                              email: _email.text.trim(),
                              password: _pass.text,
                            ),
                          ),
                    child: _loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Se connecter'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading
                        ? null
                        : () => _run(
                            () => AuthService.instance
                                .createUserWithEmailPassword(
                                  email: _email.text.trim(),
                                  password: _pass.text,
                                ),
                          ),
                    child: const Text('Créer un compte'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading
                    ? null
                    : () => _runProvider(AuthAction.google),
                icon: const Icon(Icons.g_mobiledata_rounded),
                label: const Text('Continuer avec Google'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _loading
                    ? null
                    : () => _runProvider(AuthAction.apple),
                icon: const Icon(Icons.apple),
                label: const Text('Continuer avec Apple'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _loading
                    ? null
                    : () => _runProvider(AuthAction.email),
                icon: const Icon(Icons.alternate_email_rounded),
                label: const Text('Email (popup)'),
              ),
            ),
            const SizedBox(height: 18),
            TextButton(
              onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
              child: const Text('Continuer en invité'),
            ),
          ],
        ),
      ),
    );
  }
}
