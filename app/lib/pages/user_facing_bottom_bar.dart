import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../ui/widgets/maslive_standard_bottom_bar.dart';

enum UserFacingBottomBarTab { profile, boutique, home, media, explorer }

class UserFacingBottomBar extends StatelessWidget {
  const UserFacingBottomBar({
    super.key,
    required this.currentTab,
    this.onTabSelected,
    this.onExplorerTap,
  });

  final UserFacingBottomBarTab currentTab;
  final ValueChanged<UserFacingBottomBarTab>? onTabSelected;
  final VoidCallback? onExplorerTap;

  void _openShellTab(BuildContext context, UserFacingBottomBarTab tab) {
    if (onTabSelected != null) {
      onTabSelected!(tab);
      return;
    }

    Navigator.of(context).pushReplacementNamed(
      '/user-shell',
      arguments: <String, dynamic>{'tab': tab.name},
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        final pseudo = (user?.displayName ?? user?.email ?? 'Profil').trim();

        return SafeArea(
          top: false,
          child: MasliveStandardBottomBar(
            items: [
              MasliveStandardBottomBarItem(
                iconBuilder: (context, active) => _ProfileBottomBarIcon(
                  active: active,
                  isConnected: user != null,
                ),
                label: 'Profil',
                tooltip: pseudo.isEmpty ? 'Profil' : pseudo,
                onTap: () {
                  if (currentTab == UserFacingBottomBarTab.profile) return;
                  _openShellTab(context, UserFacingBottomBarTab.profile);
                },
              ),
              MasliveStandardBottomBarItem(
                icon: Icons.storefront_outlined,
                activeIcon: Icons.storefront,
                label: 'Boutique',
                tooltip: 'Ouvrir la boutique',
                onTap: () {
                  if (currentTab == UserFacingBottomBarTab.boutique) return;
                  _openShellTab(context, UserFacingBottomBarTab.boutique);
                },
              ),
              MasliveStandardBottomBarItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home',
                tooltip: 'Revenir à l’accueil',
                onTap: () {
                  if (currentTab == UserFacingBottomBarTab.home) return;
                  _openShellTab(context, UserFacingBottomBarTab.home);
                },
              ),
              MasliveStandardBottomBarItem(
                icon: Icons.photo_library_outlined,
                activeIcon: Icons.photo_library,
                label: 'Media',
                tooltip: 'Ouvrir les médias',
                onTap: () {
                  if (currentTab == UserFacingBottomBarTab.media) return;
                  _openShellTab(context, UserFacingBottomBarTab.media);
                },
              ),
              MasliveStandardBottomBarItem(
                icon: Icons.search_rounded,
                activeIcon: Icons.search,
                label: 'Explorer',
                tooltip: 'Explorer',
                onTap: () {
                  if (onExplorerTap != null) {
                    onExplorerTap!();
                    return;
                  }
                  if (currentTab == UserFacingBottomBarTab.explorer) return;
                  _openShellTab(context, UserFacingBottomBarTab.explorer);
                },
              ),
            ],
            selectedIndex: UserFacingBottomBarTab.values.indexOf(currentTab),
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        );
      },
    );
  }
}

class _ProfileBottomBarIcon extends StatelessWidget {
  const _ProfileBottomBarIcon({
    required this.active,
    required this.isConnected,
  });

  final bool active;
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    final iconColor = active ? Colors.white : const Color(0xFF98A2B3);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          active ? Icons.person_rounded : Icons.person_outline_rounded,
          color: iconColor,
          size: 22,
        ),
        if (isConnected)
          Positioned(
            right: -1,
            top: -1,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.4),
              ),
            ),
          ),
      ],
    );
  }
}