import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../ui/widgets/maslive_standard_bottom_bar.dart';
import 'storex_shop_page.dart';

enum UserFacingBottomBarTab { profile, boutique, home, explorer }

class UserFacingBottomBar extends StatelessWidget {
  const UserFacingBottomBar({
    super.key,
    required this.currentTab,
    this.explorerRoute = '/search',
  });

  final UserFacingBottomBarTab currentTab;
  final String explorerRoute;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final pseudo = (user?.displayName ?? user?.email ?? 'Profil').trim();

    return SafeArea(
      top: false,
      child: MasliveStandardBottomBar(
        items: [
          MasliveStandardBottomBarItem(
            icon: Icons.person_outline_rounded,
            activeIcon: Icons.person_rounded,
            label: 'Profil',
            tooltip: pseudo.isEmpty ? 'Profil' : pseudo,
            onTap: () {
              if (currentTab == UserFacingBottomBarTab.profile) return;
              Navigator.of(context).pushReplacementNamed(
                user != null ? '/account-ui' : '/login',
              );
            },
          ),
          MasliveStandardBottomBarItem(
            icon: Icons.dry_cleaning_outlined,
            activeIcon: Icons.dry_cleaning,
            label: 'Boutique',
            tooltip: 'Ouvrir la boutique',
            onTap: () {
              if (currentTab == UserFacingBottomBarTab.boutique) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) =>
                      const StorexShopPage(shopId: 'global', groupId: 'MASLIVE'),
                ),
              );
            },
          ),
          MasliveStandardBottomBarItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            label: 'Home',
            tooltip: 'Revenir à l’accueil',
            onTap: () {
              if (currentTab == UserFacingBottomBarTab.home) return;
              Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
            },
          ),
          MasliveStandardBottomBarItem(
            icon: Icons.search_rounded,
            activeIcon: Icons.search,
            label: 'Explorer',
            tooltip: 'Explorer',
            onTap: () {
              if (currentTab == UserFacingBottomBarTab.explorer) return;
              Navigator.of(context).pushReplacementNamed(explorerRoute);
            },
          ),
        ],
        selectedIndex: UserFacingBottomBarTab.values.indexOf(currentTab),
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}