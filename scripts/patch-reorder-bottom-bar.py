from pathlib import Path

p = Path('app/lib/pages/default_map_page.dart')
s = p.read_text()

s = s.replace(
"""  int? get _activeBottomBarIndex =>
      _showActionsMenu ? 4 : (_selectedBottomBarIndex ?? 2);
""",
"""  int? get _activeBottomBarIndex =>
      _showActionsMenu ? 3 : (_selectedBottomBarIndex ?? 2);
""",
1,
)

old = """    return [
      MasliveStandardBottomBarItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Profil',
        tooltip: pseudo.isEmpty ? localizations.profile : pseudo,
        onTap: () {
          _selectBottomBarIndex(0);
          if (user != null) {
            Navigator.pushNamed(context, '/account-ui');
          } else {
            Navigator.pushNamed(context, '/login');
          }
        },
      ),
      MasliveStandardBottomBarItem(
        icon: Icons.storefront_outlined,
        activeIcon: Icons.storefront,
        label: 'Boutique',
        tooltip: localizations.shop,
        onTap: () {
          _selectBottomBarIndex(1);
          Navigator.of(context).push(
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
        tooltip: 'Home',
        onTap: () {
          _selectBottomBarIndex(2);
          if (_showActionsMenu) {
            _dismissActionsMenu();
          }
        },
      ),
      MasliveStandardBottomBarItem(
        icon: Icons.photo_library_outlined,
        activeIcon: Icons.photo_library,
        label: 'Media',
        tooltip: 'Media',
        onTap: () {
          _selectBottomBarIndex(3);
          Navigator.pushNamed(context, '/media-marketplace');
        },
      ),
      MasliveStandardBottomBarItem(
        icon: Icons.search_rounded,
        activeIcon: Icons.search,
        label: 'Explorer',
        tooltip: 'Explorer',
        onTap: () {
          _selectBottomBarIndex(4);
          _toggleActionsMenu();
        },
      ),
    ];
"""

new = """    return [
      MasliveStandardBottomBarItem(
        icon: Icons.storefront_outlined,
        activeIcon: Icons.storefront,
        label: 'Boutique',
        tooltip: localizations.shop,
        onTap: () {
          _selectBottomBarIndex(0);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  const StorexShopPage(shopId: 'global', groupId: 'MASLIVE'),
            ),
          );
        },
      ),
      MasliveStandardBottomBarItem(
        icon: Icons.photo_library_outlined,
        activeIcon: Icons.photo_library,
        label: 'Media',
        tooltip: 'Media',
        onTap: () {
          _selectBottomBarIndex(1);
          Navigator.pushNamed(context, '/media-marketplace');
        },
      ),
      MasliveStandardBottomBarItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: 'Home',
        tooltip: 'Home',
        onTap: () {
          _selectBottomBarIndex(2);
          if (_showActionsMenu) {
            _dismissActionsMenu();
          }
        },
      ),
      MasliveStandardBottomBarItem(
        icon: Icons.search_rounded,
        activeIcon: Icons.search,
        label: 'Explorer',
        tooltip: 'Explorer',
        onTap: () {
          _selectBottomBarIndex(3);
          _toggleActionsMenu();
        },
      ),
      MasliveStandardBottomBarItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Profil',
        tooltip: pseudo.isEmpty ? localizations.profile : pseudo,
        onTap: () {
          _selectBottomBarIndex(4);
          if (user != null) {
            Navigator.pushNamed(context, '/account-ui');
          } else {
            Navigator.pushNamed(context, '/login');
          }
        },
      ),
    ];
"""

if old not in s:
    raise SystemExit('bottom bar block not found')

p.write_text(s.replace(old, new, 1))
