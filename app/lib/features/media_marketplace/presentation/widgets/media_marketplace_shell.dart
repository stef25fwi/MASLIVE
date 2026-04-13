import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../pages/home_vertical_nav.dart';
import '../../../../providers/cart_provider.dart';
import '../../../../ui/theme/maslive_theme.dart';
import '../../../../widgets/cart/cart_icon_badge.dart';

enum MediaMarketplaceNavSection {
  catalog,
  photographer,
  cart,
  downloads,
}

class MediaMarketplaceBrandHeader extends StatelessWidget {
  const MediaMarketplaceBrandHeader({
    super.key,
    required this.subtitle,
    this.onBack,
    this.trailing,
  });

  final String subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (onBack != null)
          InkResponse(
            radius: 24,
            onTap: onBack,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.74),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x1F0F172A)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: MasliveTheme.textPrimary,
              ),
            ),
          )
        else
          const SizedBox(width: 40),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              children: <InlineSpan>[
                const TextSpan(
                  text: "MAS'LIVE ",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                    color: MasliveTheme.textPrimary,
                    height: 1,
                  ),
                ),
                TextSpan(
                  text: subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: MasliveTheme.textSecondary,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 40,
          child: trailing == null ? const SizedBox.shrink() : Center(child: trailing),
        ),
      ],
    );
  }
}

class MediaMarketplaceVerticalNav extends StatelessWidget {
  const MediaMarketplaceVerticalNav({
    super.key,
    required this.selected,
    required this.onOpenCatalog,
    required this.onOpenPhotographer,
    required this.onOpenCart,
    required this.onOpenDownloads,
  });

  final MediaMarketplaceNavSection selected;
  final VoidCallback onOpenCatalog;
  final VoidCallback onOpenPhotographer;
  final VoidCallback onOpenCart;
  final VoidCallback onOpenDownloads;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: HomeVerticalNavMenu(
            items: <HomeVerticalNavItem>[
              HomeVerticalNavItem(
                label: '',
                icon: selected == MediaMarketplaceNavSection.catalog
                    ? Icons.photo_library
                    : Icons.photo_library_outlined,
                selected: selected == MediaMarketplaceNavSection.catalog,
                onTap: onOpenCatalog,
              ),
              HomeVerticalNavItem(
                label: '',
                icon: selected == MediaMarketplaceNavSection.photographer
                    ? Icons.camera_alt
                    : Icons.camera_alt_outlined,
                selected: selected == MediaMarketplaceNavSection.photographer,
                onTap: onOpenPhotographer,
              ),
              HomeVerticalNavItem(
                label: '',
                iconWidget: _MediaMarketplaceCartNavIcon(
                  selected: selected == MediaMarketplaceNavSection.cart,
                ),
                selected: selected == MediaMarketplaceNavSection.cart,
                showBorder: false,
                onTap: onOpenCart,
              ),
              HomeVerticalNavItem(
                label: '',
                icon: selected == MediaMarketplaceNavSection.downloads
                    ? Icons.download
                    : Icons.download_outlined,
                selected: selected == MediaMarketplaceNavSection.downloads,
                onTap: onOpenDownloads,
              ),
            ],
            margin: EdgeInsets.zero,
            horizontalPadding: 6,
            verticalPadding: 10,
            backgroundAlpha: 0.82,
            blurSigma: 14,
            borderColor: const Color(0x1F0F172A),
            boxShadow: MasliveTheme.floatingShadowStrong,
          ),
        ),
      ),
    );
  }
}

class _MediaMarketplaceCartNavIcon extends StatelessWidget {
  const _MediaMarketplaceCartNavIcon({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final count = context.watch<CartProvider>().totalQuantity;
    return CartBadgeGlyph(
      count: count,
      iconColor: selected ? Colors.white : MasliveTheme.textPrimary,
      iconSize: 30,
      containerSize: 30,
      showContainer: false,
      badgeRight: -8,
      badgeTop: -8,
    );
  }
}