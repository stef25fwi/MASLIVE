import 'package:flutter/material.dart';
import '../session/session_scope.dart';
import '../session/require_signin.dart';
import '../services/favorites_service.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);

    if (session.isGuest) {
      return Scaffold(
        appBar: AppBar(title: const Text('Favoris')),
        body: Center(
          child: FilledButton(
            onPressed: () => requireSignIn(context, session: session),
            child: const Text('Se connecter'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Favoris')),
      body: StreamBuilder<Set<String>>(
        stream: FavoritesService.instance.favoritesIdsStream(),
        builder: (context, snap) {
          final ids = snap.data ?? {};
          if (ids.isEmpty) {
            return const Center(child: Text('Aucun favori pour le moment.'));
          }
          final list = ids.toList()..sort();
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, index) => const Divider(height: 1),
            itemBuilder: (_, i) => ListTile(
              leading: const Icon(Icons.place),
              title: Text('Place: ${list[i]}'),
            ),
          );
        },
      ),
    );
  }
}
