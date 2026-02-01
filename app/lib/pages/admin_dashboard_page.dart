import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'legacy_stubs/route_drawing_page_legacy_stub.dart';
import 'add_place_page.dart';
import '../ui/map_access_labels.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final mapLabels = mapAccessLabels();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin - Gestion carte'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Outils admin',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _tile(
            context,
            icon: Icons.alt_route,
            title: 'Tracer un parcours',
            subtitle: 'Enregistrer un itinéraire prédéfini pour les groupes',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RouteDrawingPageLegacy()),
            ),
          ),
          _tile(
            context,
            icon: Icons.layers,
            title: 'Points par couche',
            subtitle: 'Ajouter des points pour chaque onglet (Visiter, Food, etc.)',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddPlacePage()),
            ),
          ),
          _tile(
            context,
            icon: Icons.group,
            title: 'Groupes en live',
            subtitle: 'Voir la position actuelle des groupes sur la carte',
            onTap: () => Navigator.pushNamed(context, '/tracking'),
          ),
          _tile(
            context,
            icon: Icons.route,
            title: 'Éditer circuit (Track Editor)',
            subtitle: 'Pays → périmètre → circuit → habillage → validation',
            onTap: () => Navigator.pushNamed(context, '/admin/track-editor'),
          ),
          _tile(
            context,
            icon: Icons.folder_copy_outlined,
            title: 'Bibliothèque de cartes',
            subtitle: 'Classement: année / pays / commune',
            onTap: () => Navigator.pushNamed(context, '/admin/map-library'),
          ),
          _tile(
            context,
            icon: Icons.map,
            title: 'Carte principale',
            subtitle: 'Accéder à la carte avec tous les points',
            onTap: () => Navigator.pushNamed(context, '/'),
          ),
          _tile(
            context,
            icon: Icons.edit,
            title: 'Éditeur de cartes',
            subtitle: 'Créer / éditer une carte (presets, couches, éléments)',
            onTap: () => Navigator.pushNamed(context, '/map-admin'),
          ),
          _tile(
            context,
            icon: Icons.map_outlined,
            title: mapLabels.title,
            subtitle: mapLabels.subtitle,
            onTap: () => Navigator.pushNamed(context, '/mapbox-google-light'),
          ),
          _tile(
            context,
            icon: Icons.person,
            title: 'Mon compte',
            subtitle: 'Gérer mon profil et mes paramètres',
            onTap: () {
              final isSignedIn = FirebaseAuth.instance.currentUser != null;
              Navigator.pushNamed(context, isSignedIn ? '/account' : '/login');
            },
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
