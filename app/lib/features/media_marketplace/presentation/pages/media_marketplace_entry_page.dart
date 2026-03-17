import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../models/market_circuit.dart';
import '../../../../models/market_country.dart';
import '../../../../models/market_event.dart';
import '../../../../pages/cart/unified_cart_page.dart';
import '../../../../providers/cart_provider.dart';
import '../../../../ui/theme/maslive_theme.dart';
import '../../../../ui/widgets/marketmap_poi_selector_sheet.dart';
import 'media_downloads_page.dart';
import 'media_marketplace_home_page.dart';
import 'photographer_dashboard_page.dart';

class MediaMarketplaceEntryPage extends StatelessWidget {
  const MediaMarketplaceEntryPage({
    super.key,
    this.countryId,
    this.countryName,
    this.eventId,
    this.eventName,
    this.circuitId,
    this.circuitName,
    this.photographerId,
    this.ownerUid,
    this.initialTabIndex = 0,
    this.embedded = false,
  });

  final String? countryId;
  final String? countryName;
  final String? eventId;
  final String? eventName;
  final String? circuitId;
  final String? circuitName;
  final String? photographerId;
  final String? ownerUid;
  final int initialTabIndex;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final safeInitialTabIndex = initialTabIndex.clamp(0, 3);

    final tabBar = TabBar(
      isScrollable: false,
      labelColor: MasliveTheme.textPrimary,
      unselectedLabelColor: MasliveTheme.textSecondary,
      indicatorColor: MasliveTheme.textPrimary,
      indicatorSize: TabBarIndicatorSize.label,
      tabs: const <Widget>[
        Tab(text: 'Catalogue', icon: Icon(Icons.photo_library_outlined)),
        _MarketplaceCartTab(),
        Tab(text: 'Téléchargements', icon: Icon(Icons.download_outlined)),
        Tab(text: 'Photographe', icon: Icon(Icons.camera_alt_outlined)),
      ],
    );

    return DefaultTabController(
      length: 4,
      initialIndex: safeInitialTabIndex,
      child: Scaffold(
        backgroundColor: MasliveTheme.surfaceAlt,
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: MasliveTheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: MasliveTheme.divider),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                child: tabBar,
              ),
            ),
          ),
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: MasliveTheme.backgroundWash),
          child: SafeArea(
            child: Column(
              children: <Widget>[
                if (!embedded) ...<Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
                    child: const _MarketplacePremiumHeader(),
                  ),
                ] else ...<Widget>[
                  const SizedBox(height: 6),
                ],
                Expanded(
                  child: TabBarView(
                    children: <Widget>[
                      MediaMarketplaceHomePage(
                        key: ValueKey<String>(
                          '${countryId ?? ''}|${eventId ?? ''}|${circuitId ?? ''}|${photographerId ?? ''}',
                        ),
                        countryId: countryId,
                        countryName: countryName,
                        eventId: eventId,
                        eventName: eventName,
                        circuitId: circuitId,
                        circuitName: circuitName,
                        photographerId: photographerId,
                        showContextHeader: false,
                        embedded: true,
                        showBranding: embedded,
                        onOpenFilters: () => _openCatalogFilters(context),
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

  Future<void> _openCatalogFilters(BuildContext context) async {
    final initial = _buildInitialSelection();
    final selection = await showMarketMapCircuitSelectorSheet(
      context,
      initial: initial,
      disableKeyboardInput: true,
    );
    if (selection == null || !context.mounted) return;

    final args = <String, dynamic>{
      'countryId': selection.country?.id,
      'countryName': selection.country?.name,
      'eventId': selection.event?.id,
      'eventName': selection.event?.name,
      'circuitId': selection.circuit?.id,
      'circuitName': selection.circuit?.name,
      'initialTab': 0,
    };

    if (embedded) {
      Navigator.pushNamed(context, '/media-marketplace', arguments: args);
      return;
    }

    Navigator.pushReplacementNamed(context, '/media-marketplace', arguments: args);
  }

  MarketMapPoiSelection? _buildInitialSelection() {
    final resolvedCountryId = countryId?.trim();
    final resolvedEventId = eventId?.trim();
    final resolvedCircuitId = circuitId?.trim();
    if (resolvedCountryId == null ||
        resolvedCountryId.isEmpty ||
        resolvedEventId == null ||
        resolvedEventId.isEmpty ||
        resolvedCircuitId == null ||
        resolvedCircuitId.isEmpty) {
      return null;
    }

    return MarketMapPoiSelection.enabled(
      country: MarketCountry(
        id: resolvedCountryId,
        name: (countryName?.trim().isNotEmpty == true) ? countryName!.trim() : resolvedCountryId,
        slug: resolvedCountryId,
      ),
      event: MarketEvent(
        id: resolvedEventId,
        countryId: resolvedCountryId,
        name: (eventName?.trim().isNotEmpty == true) ? eventName!.trim() : resolvedEventId,
        slug: resolvedEventId,
      ),
      circuit: MarketCircuit(
        id: resolvedCircuitId,
        countryId: resolvedCountryId,
        eventId: resolvedEventId,
        name: (circuitName?.trim().isNotEmpty == true) ? circuitName!.trim() : resolvedCircuitId,
        slug: resolvedCircuitId,
        status: 'published',
        createdByUid: '',
        perimeterLocked: false,
        zoomLocked: false,
        center: const <String, double>{'lat': 0, 'lng': 0},
        initialZoom: 14,
        isVisible: true,
        wizardState: const <String, dynamic>{},
      ),
      layerIds: const <String>{},
    );
  }
}

class _MarketplacePremiumHeader extends StatelessWidget {
  const _MarketplacePremiumHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          "MAS'LIVE",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.9,
            color: MasliveTheme.textPrimary,
            height: 1,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Text(
          'LA BOUTIQUE PHOTO',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            letterSpacing: 2.2,
            color: MasliveTheme.textSecondary,
            height: 1,
          ),
          textAlign: TextAlign.center,
        ),
      ],
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