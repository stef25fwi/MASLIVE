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

    return DefaultTabController(
      length: 4,
      initialIndex: safeInitialTabIndex,
      child: Scaffold(
        backgroundColor: MasliveTheme.surfaceAlt,
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.98),
              border: const Border(top: BorderSide(color: Color(0x1F0F172A))),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 20,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Catalogue (index 0)
                _MediaBottomItem(tabIndex: 0, icon: Icons.photo_library_outlined, activeIcon: Icons.photo_library, label: 'Catalogue'),
                // Photographe (index 3)
                _MediaBottomItem(tabIndex: 3, icon: Icons.camera_alt_outlined, activeIcon: Icons.camera_alt, label: 'Photographe'),
                // Panier (index 1)
                _MediaBottomCartItem(),
                // Téléchargements (index 2)
                _MediaBottomItem(tabIndex: 2, icon: Icons.download_outlined, activeIcon: Icons.download, label: 'Téléchargements'),
              ],
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
                    child: _MarketplacePremiumHeader(onBack: () => Navigator.of(context).pop()),
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
  const _MarketplacePremiumHeader({this.onBack});
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Back button
        if (onBack != null)
          InkResponse(
            radius: 24,
            onTap: onBack,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
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
        // Title (centered)
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                "MAS'LIVE",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                  color: MasliveTheme.textPrimary,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'LA BOUTIQUE PHOTO',
                style: TextStyle(
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
        const SizedBox(width: 12),
        // Right spacer (balance layout)
        const SizedBox(width: 40),
      ],
    );
  }
}

class _MediaBottomItem extends StatelessWidget {
  const _MediaBottomItem({
    required this.tabIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final int tabIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      radius: 28,
      onTap: () => DefaultTabController.of(context).animateTo(tabIndex),
      child: Center(
        child: StatefulBuilder(
          builder: (context, setState) => DefaultTabController(
            initialIndex: tabIndex,
            length: 4,
            child: Builder(
              builder: (ctx) {
                final isActive = DefaultTabController.of(ctx).index == tabIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.all(8),
                  decoration: isActive
                      ? BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFB26A), Color(0xFFFF7BC5), Color(0xFF7CE0FF)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 18,
                              offset: Offset(0, 8),
                            ),
                          ],
                        )
                      : null,
                  child: Icon(
                    isActive ? activeIcon : icon,
                    color: isActive ? Colors.white : const Color(0xFF98A2B3),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaBottomCartItem extends StatelessWidget {
  const _MediaBottomCartItem();

  @override
  Widget build(BuildContext context) {
    final count = context.watch<CartProvider>().totalQuantity;

    return InkResponse(
      radius: 28,
      onTap: () => DefaultTabController.of(context).animateTo(1),
      child: Center(
        child: DefaultTabController(
          initialIndex: 1,
          length: 4,
          child: Builder(
            builder: (ctx) {
              final isActive = DefaultTabController.of(ctx).index == 1;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.all(8),
                    decoration: isActive
                        ? BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFB26A), Color(0xFFFF7BC5), Color(0xFF7CE0FF)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const <BoxShadow>[
                              BoxShadow(
                                color: Color(0x14000000),
                                blurRadius: 18,
                                offset: Offset(0, 8),
                              ),
                            ],
                          )
                        : null,
                    child: Icon(
                      isActive ? Icons.shopping_bag : Icons.shopping_bag_outlined,
                      color: isActive ? Colors.white : const Color(0xFF98A2B3),
                    ),
                  ),
                  if (count > 0)
                    Positioned(
                      right: -10,
                      top: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFB26A), Color(0xFFFF7BC5), Color(0xFF7CE0FF)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

