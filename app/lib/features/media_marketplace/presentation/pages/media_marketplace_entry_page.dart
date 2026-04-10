import 'package:flutter/material.dart';

import '../../../../models/market_circuit.dart';
import '../../../../models/market_country.dart';
import '../../../../models/market_event.dart';
import '../../../../pages/cart/unified_cart_page.dart';
import '../../../../ui/theme/maslive_theme.dart';
import '../../../../ui/widgets/marketmap_poi_selector_sheet.dart';
import 'media_downloads_page.dart';
import 'media_marketplace_home_page.dart';
import 'photographer_dashboard_page.dart';
import '../widgets/media_marketplace_shell.dart';

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

    return DefaultTabController(
      length: 4,
      initialIndex: safeInitialTabIndex,
      child: Scaffold(
        backgroundColor: MasliveTheme.surfaceAlt,
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: MasliveTheme.backgroundWash),
          child: SafeArea(
            child: Stack(
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(left: embedded ? 0 : 84),
                  child: Column(
                    children: <Widget>[
                      if (!embedded) ...<Widget>[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
                          child: MediaMarketplaceBrandHeader(
                            subtitle: 'LA BOUTIQUE PHOTO',
                            onBack: () => Navigator.of(context).pop(),
                          ),
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
                if (!embedded)
                  _MediaMarketplaceEntryNav(
                    onOpenCatalog: () => DefaultTabController.of(context).animateTo(0),
                    onOpenCart: () => DefaultTabController.of(context).animateTo(1),
                    onOpenDownloads: () => DefaultTabController.of(context).animateTo(2),
                    onOpenPhotographer: () => DefaultTabController.of(context).animateTo(3),
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

class _MediaMarketplaceEntryNav extends StatefulWidget {
  const _MediaMarketplaceEntryNav({
    required this.onOpenCatalog,
    required this.onOpenPhotographer,
    required this.onOpenCart,
    required this.onOpenDownloads,
  });

  final VoidCallback onOpenCatalog;
  final VoidCallback onOpenPhotographer;
  final VoidCallback onOpenCart;
  final VoidCallback onOpenDownloads;

  @override
  State<_MediaMarketplaceEntryNav> createState() => _MediaMarketplaceEntryNavState();
}

class _MediaMarketplaceEntryNavState extends State<_MediaMarketplaceEntryNav> {
  TabController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller?.removeListener(_handleTabChange);
    _controller = DefaultTabController.of(context);
    _controller?.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleTabChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = _controller?.index ?? 0;
    final selected = switch (index) {
      1 => MediaMarketplaceNavSection.cart,
      2 => MediaMarketplaceNavSection.downloads,
      3 => MediaMarketplaceNavSection.photographer,
      _ => MediaMarketplaceNavSection.catalog,
    };

    return MediaMarketplaceVerticalNav(
      selected: selected,
      onOpenCatalog: widget.onOpenCatalog,
      onOpenPhotographer: widget.onOpenPhotographer,
      onOpenCart: widget.onOpenCart,
      onOpenDownloads: widget.onOpenDownloads,
    );
  }
}

