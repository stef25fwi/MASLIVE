import 'package:flutter/material.dart';
import '../widgets/maslive_bottom_nav_glass.dart';
import 'mapbox_web_map_page.dart';
import 'media_tab_combined_page.dart';
import 'group_profile_page.dart';
import 'search_page.dart';
import '../shop_orders_notifications.dart';

class AppShell extends StatefulWidget {
  final String groupId;
  const AppShell({super.key, required this.groupId});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushService.instance.init(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final bottomNavHeight = MasliveBottomNavGlass.barHeight + bottomInset;

    final pages = <Widget>[
      const MapboxWebMapPage(),
      const SearchPage(),
      MediaTabCombinedPage(groupId: widget.groupId),
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
      bottomNavigationBar: MasliveBottomNavGlass(
        index: _index,
        onTap: (i) => setState(() => _index = i),
        onPlus: () {
          // Action + : à brancher (ex: créer post / ajouter produit / créer event)
        },
      ),
    );
  }
}
