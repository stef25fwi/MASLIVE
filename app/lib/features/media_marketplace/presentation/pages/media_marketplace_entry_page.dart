import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../pages/cart/unified_cart_page.dart';
import '../../../../providers/cart_provider.dart';
import '../../../../ui/theme/maslive_theme.dart';
import 'media_downloads_page.dart';
import 'media_marketplace_home_page.dart';
import 'photographer_dashboard_page.dart';
import '../widgets/media_marketplace_context_chips.dart';

class MediaMarketplaceEntryPage extends StatelessWidget {
  const MediaMarketplaceEntryPage({
    super.key,
    this.eventId,
    this.eventName,
    this.circuitName,
    this.photographerId,
    this.ownerUid,
    this.initialTabIndex = 0,
    this.embedded = false,
  });

  final String? eventId;
  final String? eventName;
  final String? circuitName;
  final String? photographerId;
  final String? ownerUid;
  final int initialTabIndex;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final safeInitialTabIndex = initialTabIndex.clamp(0, 3);
    final cartCount = context.watch<CartProvider>().totalQuantity;

    final tabBar = TabBar(
      isScrollable: true,
      labelColor: MasliveTheme.textPrimary,
      unselectedLabelColor: MasliveTheme.textSecondary,
      indicatorColor: MasliveTheme.textPrimary,
      tabs: const <Widget>[
        Tab(text: 'Catalogue', icon: Icon(Icons.photo_library_outlined)),
        _MarketplaceCartTab(),
        Tab(text: 'Téléchargements', icon: Icon(Icons.download_outlined)),
        Tab(text: 'Photographe', icon: Icon(Icons.camera_alt_outlined)),
      ],
    );

    final contextBanner = eventId?.trim().isNotEmpty == true
        ? Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: _SharedMarketplaceContextBanner(
              eventId: eventId!.trim(),
              eventName: eventName,
              circuitName: circuitName,
            ),
          )
        : const SizedBox.shrink();

    return DefaultTabController(
      length: 4,
      initialIndex: safeInitialTabIndex,
      child: Scaffold(
        backgroundColor: MasliveTheme.surfaceAlt,
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: MasliveTheme.backgroundWash),
          child: SafeArea(
            child: Column(
              children: <Widget>[
                if (!embedded) ...<Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                    child: _MarketplacePremiumHeader(cartCount: cartCount),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                    child: _MarketplacePremiumHeroBanner(
                      title: eventName?.trim().isNotEmpty == true
                          ? eventName!.trim()
                          : 'Marché des médias',
                      subtitle: circuitName?.trim().isNotEmpty == true ? circuitName!.trim() : null,
                    ),
                  ),
                ] else ...<Widget>[
                  const SizedBox(height: 6),
                ],
                contextBanner,
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: MasliveTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: MasliveTheme.divider),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: tabBar,
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: <Widget>[
                      MediaMarketplaceHomePage(
                        eventId: eventId,
                        eventName: eventName,
                        circuitName: circuitName,
                        photographerId: photographerId,
                        showContextHeader: false,
                        embedded: true,
                      ),
                      const UnifiedCartPage(embedded: true),
                      MediaDownloadsPage(
                        eventId: eventId,
                        eventName: eventName,
                        circuitName: circuitName,
                        showContextHeader: false,
                        embedded: true,
                      ),
                      PhotographerDashboardPage(
                        ownerUid: ownerUid,
                        eventId: eventId,
                        eventName: eventName,
                        circuitName: circuitName,
                        showContextHeader: false,
                        embedded: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MarketplacePremiumHeader extends StatelessWidget {
  const _MarketplacePremiumHeader({required this.cartCount});

  final int cartCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.menu,
            size: 28,
            color: MasliveTheme.textPrimary,
          ),
          const Spacer(),
          const Text(
            'MASLIVE',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              color: MasliveTheme.textPrimary,
              height: 1,
            ),
          ),
          const Spacer(),
          const Icon(
            Icons.search,
            size: 24,
            color: MasliveTheme.textPrimary,
          ),
          const SizedBox(width: 14),
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              const Icon(
                Icons.shopping_bag_outlined,
                size: 23,
                color: MasliveTheme.textPrimary,
              ),
              if (cartCount > 0)
                Positioned(
                  right: -10,
                  top: -8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: MasliveTheme.textPrimary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      cartCount > 99 ? '99+' : '$cartCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MarketplacePremiumHeroBanner extends StatelessWidget {
  const _MarketplacePremiumHeroBanner({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: MasliveTheme.headerGradient,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: <Color>[
                  MasliveTheme.textPrimary.withValues(alpha: 0.26),
                  MasliveTheme.textPrimary.withValues(alpha: 0.10),
                  MasliveTheme.textPrimary.withValues(alpha: 0.06),
                ],
                stops: const <double>[0.0, 0.45, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 18,
            top: 16,
            bottom: 16,
            right: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Spacer(),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.8,
                    height: 1,
                  ),
                ),
                if (subtitle?.trim().isNotEmpty == true) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketplaceCartTab extends StatelessWidget {
  const _MarketplaceCartTab();

  @override
  Widget build(BuildContext context) {
    final count = context.watch<CartProvider>().totalQuantity;

    return Tab(
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.shopping_cart_outlined),
              SizedBox(width: 8),
              Text('Panier'),
            ],
          ),
          if (count > 0)
            Positioned(
              right: -14,
              top: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SharedMarketplaceContextBanner extends StatelessWidget {
  const _SharedMarketplaceContextBanner({
    required this.eventId,
    required this.eventName,
    required this.circuitName,
  });

  final String eventId;
  final String? eventName;
  final String? circuitName;

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.maybeOf(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: MasliveTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MasliveTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            eventName?.trim().isNotEmpty == true
                ? eventName!.trim()
                : 'Contexte de navigation',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: MasliveTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          MediaMarketplaceContextChips(
            eventId: eventId,
            circuitName: circuitName,
          ),
          if (controller != null) ...<Widget>[
            const SizedBox(height: 10),
            AnimatedBuilder(
              animation: controller.animation!,
              builder: (context, _) {
                if (controller.index == 0) {
                  return const SizedBox.shrink();
                }
                return Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => controller.animateTo(0),
                    icon: const Icon(Icons.arrow_back_outlined),
                    label: const Text('Retour au catalogue'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MasliveTheme.textPrimary,
                      side: BorderSide(
                        color: MasliveTheme.divider,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}