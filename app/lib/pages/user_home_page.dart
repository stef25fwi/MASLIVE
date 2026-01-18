import 'package:flutter/material.dart';

class UserHomePage extends StatelessWidget {
  const UserHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accueil utilisateur'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bienvenue !',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const Text(
              'Accédez à la carte, à votre profil et aux groupes ouverts.',
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/'),
              icon: const Icon(Icons.map),
              label: const Text('Ouvrir la carte'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/account'),
              icon: const Icon(Icons.person),
              label: const Text('Mon compte'),
            ),
          ],
        ),
      ),
    );
  }
}
