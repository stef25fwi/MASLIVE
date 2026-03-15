import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../pages/cart/unified_cart_page.dart';
import '../../../../providers/cart_provider.dart';
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
  });

  final String? eventId;
  final String? eventName;
  final String? circuitName;
  final String? photographerId;
  final String? ownerUid;
  final int initialTabIndex;

  @override
  Widget build(BuildContext context) {
    final safeInitialTabIndex = initialTabIndex.clamp(0, 3);

    return DefaultTabController(
      length: 4,
      initialIndex: safeInitialTabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Marché des médias'),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(
              eventId?.trim().isNotEmpty == true ? 118 : 48,
            ),
            child: Column(
              children: <Widget>[
                if (eventId?.trim().isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _SharedMarketplaceContextBanner(
                      eventId: eventId!.trim(),
                      eventName: eventName,
                      circuitName: circuitName,
                    ),
                  ),
                const TabBar(
                  isScrollable: true,
                  tabs: <Widget>[
                    Tab(text: 'Catalogue', icon: Icon(Icons.photo_library_outlined)),
                    _MarketplaceCartTab(),
                    Tab(text: 'Téléchargements', icon: Icon(Icons.download_outlined)),
                    Tab(text: 'Photographe', icon: Icon(Icons.camera_alt_outlined)),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
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
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            eventName?.trim().isNotEmpty == true
                ? eventName!.trim()
                : 'Contexte de navigation',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
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
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.34),
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