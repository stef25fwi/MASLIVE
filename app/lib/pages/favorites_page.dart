import 'package:flutter/material.dart';
import '../session/session_scope.dart';
import '../session/require_signin.dart';
import '../services/favorites_service.dart';
import '../l10n/app_localizations.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);

    if (session.isGuest) {
      return Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context)!.myFavorites)),
        body: Center(
          child: FilledButton(
            onPressed: () => requireSignIn(context, session: session),
            child: Text(AppLocalizations.of(context)!.signIn),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.myFavorites)),
      body: StreamBuilder<Set<String>>(
        stream: FavoritesService.instance.favoritesIdsStream(),
        builder: (context, snap) {
          final ids = snap.data ?? {};
          if (ids.isEmpty) {
            return Center(child: Text(AppLocalizations.of(context)!.noFavoritesYet));
          }
          final list = ids.toList()..sort();
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, index) => const Divider(height: 1),
            itemBuilder: (_, i) => ListTile(
              leading: const Icon(Icons.place),
              title: Text('${AppLocalizations.of(context)!.place}: ${list[i]}'),
            ),
          );
        },
      ),
    );
  }
}
