import 'package:flutter/material.dart';
import '../widgets/presto_bottom_nav.dart';
import 'home_map_page.dart';
import 'media_galleries_page.dart';
import 'group_profile_page.dart';
import 'search_page.dart';

class AppShell extends StatefulWidget {
  final String groupId;
  const AppShell({super.key, required this.groupId});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final bottomNavHeight = PrestoBottomNav.barHeight + bottomInset;

    final pages =
        <Widget>[
              const HomeMapPage(),
              const SearchPage(),
              MediaGalleriesPage(groupId: widget.groupId),
              GroupProfilePage(groupId: widget.groupId),
            ]
            .map((page) {
              // Laisse de la place pour la bottom nav (sinon le contenu est masqué).
              return Padding(
                padding: EdgeInsets.only(bottom: bottomNavHeight),
                child: page,
              );
            })
            .toList(growable: false);

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: PrestoBottomNav(
        index: _index,
        onTap: (i) => setState(() => _index = i),
        onPlus: () {
          // Action + : à brancher (ex: créer post / ajouter produit / créer event)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Action + (à brancher)')),
          );
        },
      ),
    );
  }
}
