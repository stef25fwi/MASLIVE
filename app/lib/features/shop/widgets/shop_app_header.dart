import 'package:flutter/material.dart';

class ShopAppHeader extends StatelessWidget {
  const ShopAppHeader({
    super.key,
    this.title,
    this.centeredLogoText,
    this.showMenu = false,
    this.showSearch = false,
    this.showBag = false,
    this.subtitle,
    this.darkMode = false,
    this.compact = false,
  });

  final String? title;
  final String? centeredLogoText;
  final bool showMenu;
  final bool showSearch;
  final bool showBag;
  final String? subtitle;
  final bool darkMode;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = darkMode ? Colors.white : const Color(0xFF0E0E0E);
    final Color titleColor = darkMode ? Colors.white : const Color(0xFF101010);
    final String effectiveTitle = centeredLogoText ?? title ?? "MAS'LIVE";
    final double sideWidth = showSearch && showBag ? 76 : 40;

    return Padding(
      padding: EdgeInsets.fromLTRB(18, compact ? 6 : 8, 18, 4),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 42,
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: sideWidth,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: showMenu
                        ? _HeaderIconButton(
                            icon: Icons.menu_rounded,
                            color: iconColor,
                          )
                        : null,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      effectiveTitle,
                      style: TextStyle(
                        fontSize: subtitle == null ? 23 : 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.85,
                        color: titleColor,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: sideWidth,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      if (showSearch)
                        _HeaderIconButton(
                          icon: Icons.search_rounded,
                          color: iconColor,
                        ),
                      if (showSearch && showBag) const SizedBox(width: 8),
                      if (showBag)
                        _HeaderIconButton(
                          icon: Icons.shopping_bag_outlined,
                          color: iconColor,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: darkMode
                    ? Colors.white.withValues(alpha: 0.9)
                    : const Color(0xFF5D5D5D),
                letterSpacing: 1.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: Center(
        child: Icon(
          icon,
          size: 22,
          color: color,
        ),
      ),
    );
  }
}

class MerchBottomNav extends StatelessWidget {
  const MerchBottomNav({
    super.key,
    this.currentIndex = 1,
  });

  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(0xFFE8E8EA),
            width: 1,
          ),
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.only(bottom: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _BottomNavItem(icon: Icons.home_outlined, label: 'Accueil', active: false),
            _BottomNavItem(icon: Icons.shopping_bag, label: 'Shop', active: true),
            _BottomNavItem(icon: Icons.photo_camera_outlined, label: 'Photos', active: false),
            _BottomNavItem(icon: Icons.shopping_bag_outlined, label: 'Panier', active: false),
            _BottomNavItem(icon: Icons.person_outline, label: 'Compte', active: false),
          ],
        ),
      ),
    );
  }
}

class MediaBottomNav extends StatelessWidget {
  const MediaBottomNav({
    super.key,
    this.currentIndex = 1,
  });

  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(0xFFECECEC),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: const <Widget>[
          _BottomNavItem(icon: Icons.home_outlined, label: 'Accueil', active: false),
          _BottomNavItem(icon: Icons.photo_library_outlined, label: 'Photos', active: true),
          _BottomNavItem(icon: Icons.file_download_outlined, label: 'Téléchargements', active: false),
          _BottomNavItem(icon: Icons.person_outline, label: 'Profil', active: false),
        ],
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.active,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final Color color = active ? const Color(0xFF111111) : const Color(0xFF808086);

    return SizedBox(
      width: 68,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 29, color: color),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.8,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: color,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
