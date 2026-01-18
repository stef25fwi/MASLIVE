import 'package:flutter/material.dart';
import '../theme/maslive_theme.dart';
import 'maslive_fab.dart';

class MasliveBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onPlus;

  const MasliveBottomNav({
    super.key,
    required this.index,
    required this.onTap,
    required this.onPlus,
  });

  static const _barHeight = 78.0;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return SizedBox(
      height: _barHeight + bottomPad,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              padding: EdgeInsets.only(bottom: bottomPad),
              decoration: BoxDecoration(
                color: MasliveTheme.surface,
                border: Border(top: BorderSide(color: MasliveTheme.divider)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavIcon(
                    icon: Icons.near_me_rounded,
                    selected: index == 0,
                    onTap: () => onTap(0),
                  ),
                  _NavIcon(
                    icon: Icons.search_rounded,
                    selected: index == 1,
                    onTap: () => onTap(1),
                  ),
                  _NavIcon(
                    icon: Icons.storefront_rounded,
                    selected: index == 2,
                    onTap: () => onTap(2),
                  ),
                  _NavIcon(
                    icon: Icons.person_rounded,
                    selected: index == 3,
                    onTap: () => onTap(3),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 14 + bottomPad,
            child: MasliveFab(onTap: onPlus),
          ),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _NavIcon({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? MasliveTheme.textPrimary : MasliveTheme.textSecondary;
    return InkResponse(
      onTap: onTap,
      radius: 28,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}
