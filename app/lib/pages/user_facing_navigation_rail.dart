import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../ui_kit/responsive/responsive.dart';
import 'user_facing_bottom_bar.dart';
import 'package:masslive/ui_kit/tokens/maslive_tokens.dart';

/// Tablet and desktop counterpart of [UserFacingBottomBar].
///
/// The bottom bar remains untouched on compact screens. This rail is only
/// introduced from the medium breakpoint onward.
class UserFacingNavigationRail extends StatelessWidget {
  const UserFacingNavigationRail({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
  });

  final UserFacingBottomBarTab currentTab;
  final ValueChanged<UserFacingBottomBarTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final extended = context.isExpandedLayout || context.isWideLayout;

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        return SafeArea(
          right: false,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                right: BorderSide(color: Color(0x1F0F172A)),
              ),
            ),
            child: NavigationRail(
              extended: extended,
              minWidth: 72,
              minExtendedWidth: 216,
              backgroundColor: Colors.white,
              groupAlignment: -0.82,
              selectedIndex: UserFacingBottomBarTab.values.indexOf(currentTab),
              onDestinationSelected: (index) {
                onTabSelected(UserFacingBottomBarTab.values[index]);
              },
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.selected,
              indicatorColor: const Color(0xFFFFE4F1),
              selectedIconTheme: const IconThemeData(
                color: MasliveTokens.text,
                size: 25,
              ),
              unselectedIconTheme: const IconThemeData(
                color: Color(0xFF667085),
                size: 24,
              ),
              selectedLabelTextStyle: const TextStyle(
                color: MasliveTokens.text,
                fontWeight: FontWeight.w800,
              ),
              unselectedLabelTextStyle: const TextStyle(
                color: Color(0xFF667085),
                fontWeight: FontWeight.w600,
              ),
              leading: Padding(
                padding: EdgeInsets.fromLTRB(
                  extended ? 20 : 12,
                  12,
                  extended ? 20 : 12,
                  28,
                ),
                child: extended
                    ? const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "MAS'LIVE",
                          maxLines: 1,
                          style: TextStyle(
                            color: MasliveTokens.text,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.auto_awesome_rounded,
                        color: MasliveTokens.text,
                      ),
              ),
              destinations: <NavigationRailDestination>[
                const NavigationRailDestination(
                  icon: Icon(Icons.storefront_outlined),
                  selectedIcon: Icon(Icons.storefront),
                  label: Text('Boutique'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.photo_library_outlined),
                  selectedIcon: Icon(Icons.photo_library),
                  label: Text('Media'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: Text('Home'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.search_rounded),
                  selectedIcon: Icon(Icons.search),
                  label: Text('Explorer'),
                ),
                NavigationRailDestination(
                  icon: _ProfileRailIcon(
                    active: false,
                    isConnected: snapshot.data != null,
                  ),
                  selectedIcon: _ProfileRailIcon(
                    active: true,
                    isConnected: snapshot.data != null,
                  ),
                  label: const Text('Profil'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfileRailIcon extends StatelessWidget {
  const _ProfileRailIcon({
    required this.active,
    required this.isConnected,
  });

  final bool active;
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(active ? Icons.person_rounded : Icons.person_outline_rounded),
        if (isConnected)
          Positioned(
            right: -2,
            top: -2,
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
