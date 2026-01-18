import 'package:flutter/material.dart';
import '../session/session_scope.dart';
import '../session/require_signin.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);

    if (session.isGuest) {
      // écran "connexion requise"
      return Scaffold(
        appBar: AppBar(title: const Text('Mon compte')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 44),
                const SizedBox(height: 10),
                const Text(
                  'Connexion requise',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'En mode invité, tu peux consulter la carte et les couches.\n'
                  'Connecte-toi pour accéder à ton compte et à tes favoris.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () => requireSignIn(context, session: session),
                  child: const Text('Se connecter'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon compte'),
        actions: [
          IconButton(
            onPressed: () async {
              await session.signOut();
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const CircleAvatar(radius: 44, child: Icon(Icons.person, size: 44)),
          const SizedBox(height: 12),
          Center(
            child: Text(
              session.user?.email ?? 'Utilisateur',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: ListTile(
              leading: const Icon(Icons.favorite_border),
              title: const Text('Mes favoris'),
              onTap: () => Navigator.pushNamed(context, '/favorites'),
            ),
          ),
        ],
      ),
    );
  }
}
