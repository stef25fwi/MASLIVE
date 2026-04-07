import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../services/auth_service.dart';
import '../../services/premium_service.dart';
import 'google_sign_in_web_button_stub.dart'
    if (dart.library.js_interop) 'google_sign_in_web_button_web.dart'
    as google_sign_in_web_button;

enum AuthAction { apple, google, email }

class AuthActionRunner extends StatefulWidget {
  const AuthActionRunner({super.key, required this.action});
  final AuthAction action;

  @override
  State<AuthActionRunner> createState() => _AuthActionRunnerState();
}

class _AuthActionRunnerState extends State<AuthActionRunner> {
  String? _error;
  bool _running = true;
  bool _googleWebReady = false;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _googleAuthSub;

  Future<void> _syncPremiumAfterLogin() async {
    if (kIsWeb) return;

    final uid = AuthService.instance.currentUser?.uid;
    if (uid != null) {
      await PremiumService.instance.logIn(uid);
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.action == AuthAction.google && kIsWeb) {
      _prepareGoogleWeb();
      return;
    }
    _run();
  }

  @override
  void dispose() {
    _googleAuthSub?.cancel();
    super.dispose();
  }

  Future<void> _prepareGoogleWeb() async {
    setState(() {
      _running = true;
      _error = null;
      _googleWebReady = false;
    });

    try {
      await AuthService.instance.ensureGoogleSignInInitialized();
      await _googleAuthSub?.cancel();
      _googleAuthSub = GoogleSignIn.instance.authenticationEvents.listen(
        (event) async {
          switch (event) {
            case GoogleSignInAuthenticationEventSignIn():
              await _completeGoogleWebSignIn(event.user);
            case GoogleSignInAuthenticationEventSignOut():
              break;
          }
        },
        onError: (Object error) {
          if (!mounted) return;
          setState(() {
            _error = error.toString();
            _running = false;
            _googleWebReady = true;
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _running = false;
        _googleWebReady = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _running = false;
        _googleWebReady = false;
      });
    }
  }

  Future<void> _completeGoogleWebSignIn(GoogleSignInAccount googleUser) async {
    if (!mounted) return;

    setState(() {
      _running = true;
      _error = null;
    });

    try {
      await AuthService.instance.signInWithGoogleAccount(googleUser);
      await _syncPremiumAfterLogin();

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _running = false;
      });
    }
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _error = null;
    });

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
      await _syncPremiumAfterLogin();

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _running = false;
      });
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
    if (widget.action == AuthAction.google && kIsWeb) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B0B10),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Connexion Google',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Utilisez le bouton Google securise pour continuer.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),
                if (_running && !_googleWebReady) ...const [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text(
                    'Preparation de Google Sign-In…',
                    style: TextStyle(color: Colors.white70),
                  ),
                ] else ...[
                  google_sign_in_web_button.buildGoogleSignInButton(),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: _prepareGoogleWeb,
                        child: const Text('Recharger'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Retour'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B10),
      body: Center(
        child: (_running && _error == null)
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error ?? 'Erreur de connexion',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        OutlinedButton(
                          onPressed: _run,
                          child: const Text('Réessayer'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Retour'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
