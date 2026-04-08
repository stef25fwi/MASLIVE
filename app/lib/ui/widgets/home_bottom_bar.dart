import 'package:flutter/material.dart';

import '../theme/maslive_theme.dart';
import 'floating_glass_dock.dart';

class MasliveHomeBottomBar extends StatelessWidget {
  const MasliveHomeBottomBar({
    super.key,
    required this.width,
    required this.profileIcon,
    required this.onProfileTap,
    required this.onShopTap,
    required this.onPhotoTap,
    required this.onMenuTap,
    this.height = 84,
    this.profileLabel = 'Profil',
    this.shopLabel = 'Boutique',
    this.photoLabel = 'Boutique\nphotos',
    this.menuLabel = 'Menu',
    this.profileTooltip,
    this.shopTooltip,
    this.photoTooltip,
    this.menuTooltip,
  });

  final double width;
  final double height;
  final Widget profileIcon;
  final VoidCallback onProfileTap;
  final VoidCallback onShopTap;
  final VoidCallback onPhotoTap;
  final VoidCallback onMenuTap;
  final String profileLabel;
  final String shopLabel;
  final String photoLabel;
  final String menuLabel;
  final String? profileTooltip;
  final String? shopTooltip;
  final String? photoTooltip;
  final String? menuTooltip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: MasliveFloatingGlassDock(
        height: height,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(
          children: [
            Expanded(
              child: _MasliveHomeBottomBarAction(
                label: profileLabel,
                tooltip: profileTooltip,
                onTap: onProfileTap,
                iconWidget: profileIcon,
              ),
            ),
            Expanded(
              child: _MasliveHomeBottomBarAction(
                label: shopLabel,
                tooltip: shopTooltip,
                onTap: onShopTap,
                icon: Icons.checkroom_rounded,
              ),
            ),
            Expanded(
              child: _MasliveHomeBottomBarAction(
                label: photoLabel,
                tooltip: photoTooltip,
                onTap: onPhotoTap,
                icon: Icons.photo_library_outlined,
              ),
            ),
            Expanded(
              child: _MasliveHomeBottomBarAction(
                label: menuLabel,
                tooltip: menuTooltip,
                onTap: onMenuTap,
                icon: Icons.menu_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MasliveHomeBottomBarAction extends StatelessWidget {
  const _MasliveHomeBottomBarAction({
    required this.label,
    required this.onTap,
    this.tooltip,
    this.icon,
    this.iconWidget,
  }) : assert(icon != null || iconWidget != null);

  final String label;
  final String? tooltip;
  final VoidCallback onTap;
  final IconData? icon;
  final Widget? iconWidget;

  @override
  Widget build(BuildContext context) {
    final Widget action = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 42,
              height: 42,
              child: Center(
                child: iconWidget ?? _GradientIconBubble(icon: icon!),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: MasliveTheme.textPrimary,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                height: 1.05,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );

    if (tooltip == null || tooltip!.trim().isEmpty) {
      return action;
    }

    return Tooltip(message: tooltip!, child: action);
  }
}

class _GradientIconBubble extends StatelessWidget {
  const _GradientIconBubble({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: MasliveTheme.actionGradient,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9B6BFF).withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 6,
            right: 6,
            top: 4,
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(
            width: 40,
            height: 38,
          ),
          Positioned.fill(
            child: Center(
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}