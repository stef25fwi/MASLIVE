import 'package:flutter/material.dart';

class BusinessRequestPage extends StatelessWidget {
  const BusinessRequestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choisir un profil professionnel')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          const Icon(Icons.hub_outlined, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Le Compte Pro générique a été remplacé',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          const Text(
            'MASLIVE attribue désormais des droits précis selon l’activité réelle. '
            'Choisissez le parcours correspondant à ce que vous souhaitez gérer.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _ProfileChoice(
            icon: Icons.palette_outlined,
            title: 'Artisan d’art',
            subtitle: 'Publier des œuvres, recevoir des offres et gérer Bloom Art.',
            onTap: () => Navigator.of(context).pushReplacementNamed(
              '/bloom-art/sell',
              arguments: const <String, dynamic>{'selectedType': 'artisan_art'},
            ),
          ),
          _ProfileChoice(
            icon: Icons.camera_alt_outlined,
            title: 'Créateur digital / photographe',
            subtitle: 'Créer des galeries, vendre des médias et gérer un abonnement photo.',
            onTap: () => Navigator.of(context).pushReplacementNamed(
              '/media-marketplace',
              arguments: const <String, dynamic>{'initialTab': 'photographer'},
            ),
          ),
          _ProfileChoice(
            icon: Icons.groups_2_outlined,
            title: 'Admin Groupe',
            subtitle: 'Demander la gestion d’un groupe, des trackers et de sa boutique.',
            onTap: () => Navigator.of(context).pushReplacementNamed('/group-admin'),
          ),
        ],
      ),
    );
  }
}

class _ProfileChoice extends StatelessWidget {
  const _ProfileChoice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
