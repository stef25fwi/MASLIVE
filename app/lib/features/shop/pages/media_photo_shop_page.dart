import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/market_circuit.dart';
import '../../../models/market_country.dart';
import '../../../models/market_event.dart';
import '../../../providers/cart_provider.dart';
import '../../../services/market_map_service.dart';
import '../../media_marketplace/data/repositories/photographer_repository.dart';
import '../../media_marketplace/presentation/pages/media_downloads_page.dart';
import '../../media_marketplace/presentation/pages/media_marketplace_home_page.dart';
import '../../media_marketplace/presentation/pages/photographer_dashboard_page.dart';
import '../../../shop/widgets/storex_page_header.dart';
import '../../../shop/widgets/shop_drawer.dart';
import '../../../pages/user_facing_bottom_bar.dart';
import '../../../pages/cart/unified_cart_page.dart';
import '../../../ui/theme/maslive_theme.dart';
import '../../../ui/widgets/marketmap_poi_selector_sheet.dart';
import '../../../utils/country_flag.dart';

class MediaPhotoShopPage extends StatefulWidget {
  const MediaPhotoShopPage({
    super.key,
    this.countryId,
    this.countryName,
    this.eventId,
    this.eventName,
    this.circuitId,
    this.circuitName,
    this.photographerId,
    this.ownerUid,
    this.initialTabIndex,
    this.embedded = false,
    this.showBottomBar = true,
  });

  final String? countryId;
  final String? countryName;
  final String? eventId;
  final String? eventName;
  final String? circuitId;
  final String? circuitName;
  final String? photographerId;
  final String? ownerUid;
  final int? initialTabIndex;
  final bool embedded;
  final bool showBottomBar;

  @override
  State<MediaPhotoShopPage> createState() => _MediaPhotoShopPageState();
}

class _MediaPhotoShopPageState extends State<MediaPhotoShopPage> {
  final Set<String> _likedPhotoIds = <String>{
    'photo_2',
  };
  final MarketMapService _marketMapService = MarketMapService();
  final TextEditingController _photographerController = TextEditingController();
  String? _countryId;
  String? _countryName;
  String? _eventId;
  String? _eventName;
  String? _circuitId;
  String? _circuitName;
  String? _photographerId;
  String? _ownerUid;
  int _activeTabIndex = 0;
  bool _didLoadRouteArgs = false;
  bool _catalogMenuExpanded = false;
  bool _updatingPhotographerField = false;

  static const List<String> _tabTitles = <String>[
    'PHOTOS POPULAIRES',
    'VOTRE PANIER',
    'VOS TELECHARGEMENTS',
    'ESPACE PHOTOGRAPHE',
  ];

  String _upperText(String? value, {String fallback = '--'}) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return fallback;
    return trimmed.toUpperCase();
  }

  String _countryFieldLabel() {
    final resolvedId = _countryId?.trim();
    final resolvedName = _countryName?.trim();
    if ((resolvedId == null || resolvedId.isEmpty) &&
        (resolvedName == null || resolvedName.isEmpty)) {
      return 'SELECTIONNER UN PAYS';
    }

    final iso2 = guessIso2FromMarketMapCountry(
      id: resolvedId ?? '',
      slug: resolvedId ?? '',
      name: resolvedName ?? resolvedId ?? '',
    );
    final flag = countryFlagEmojiFromIso2(iso2);
    final code = iso2.isNotEmpty ? iso2 : _upperText(resolvedId, fallback: '');
    final name = resolvedName != null && resolvedName.isNotEmpty
        ? resolvedName.toUpperCase()
        : '';

    final buffer = StringBuffer();
    if (flag.isNotEmpty) {
      buffer.write(flag);
      buffer.write(' ');
    }
    if (name.isNotEmpty) {
      buffer.write(name);
      if (code.isNotEmpty) {
        buffer.write(' (');
        buffer.write(code);
        buffer.write(')');
      }
      return buffer.toString();
    }
    if (code.isNotEmpty) {
      buffer.write(code);
    }
    return buffer.isEmpty ? 'SELECTIONNER UN PAYS' : buffer.toString();
  }

  @override
  void initState() {
    super.initState();
    _photographerController.addListener(() {
      if (_updatingPhotographerField) return;
      final uppercase = _photographerController.text.toUpperCase();
      if (uppercase == _photographerController.text) return;
      _updatingPhotographerField = true;
      _photographerController.value = _photographerController.value.copyWith(
        text: uppercase,
        selection: TextSelection.collapsed(offset: uppercase.length),
      );
      _updatingPhotographerField = false;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadRouteArgs) return;
    _didLoadRouteArgs = true;

    final rawArgs = ModalRoute.of(context)?.settings.arguments;
    final args = rawArgs is Map ? rawArgs : const <String, dynamic>{};

    _countryId = widget.countryId?.trim() ?? (args['countryId'] as String?)?.trim();
    _countryName = widget.countryName?.trim() ?? (args['countryName'] as String?)?.trim();
    _eventId = widget.eventId?.trim() ?? (args['eventId'] as String?)?.trim();
    _eventName = widget.eventName?.trim() ?? (args['eventName'] as String?)?.trim();
    _circuitId = widget.circuitId?.trim() ?? (args['circuitId'] as String?)?.trim();
    _circuitName = widget.circuitName?.trim() ?? (args['circuitName'] as String?)?.trim();
    _photographerId = widget.photographerId?.trim() ?? (args['photographerId'] as String?)?.trim();
    _ownerUid = widget.ownerUid?.trim() ?? (args['ownerUid'] as String?)?.trim();

    final initialTab = widget.initialTabIndex ?? args['initialTab'];
    _activeTabIndex = _resolveInitialTabIndex(initialTab);
  }

  Future<void> _openMarketplace({Object? initialTab}) async {
    final photographerQuery = _photographerController.text.trim();
    String? photographerId = _photographerId;
    String? ownerUid = _ownerUid;

    if (photographerQuery.isNotEmpty) {
      final profile = await PhotographerRepository().findByQuery(photographerQuery);
      if (!mounted) return;

      if (profile != null) {
        photographerId = profile.photographerId;
        ownerUid = profile.ownerUid;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucun photographe trouve. Ouverture du catalogue complet.'),
          ),
        );
      }
    }

    setState(() {
      _photographerId = photographerId;
      _ownerUid = ownerUid;
      _activeTabIndex = _resolveInitialTabIndex(initialTab);
    });
  }

  void _goHome() {
    Navigator.pushNamed(context, '/');
  }

  void _goAccount() {
    Navigator.pushNamed(context, '/account');
  }

  int _resolveInitialTabIndex(Object? initialTab) {
    if (initialTab is int) {
      return initialTab.clamp(0, 3);
    }
    if (initialTab is String) {
      switch (initialTab) {
        case 'cart':
          return 1;
        case 'downloads':
          return 2;
        case 'photographer':
          return 3;
      }
    }
    return 0;
  }

  Future<void> _openCatalogFilters() async {
    final initial = _buildInitialSelection();
    final selection = await showMarketMapCircuitSelectorSheet(
      context,
      initial: initial,
      disableKeyboardInput: true,
    );
    if (selection == null || !mounted) return;

    setState(() {
      _countryId = selection.country?.id;
      _countryName = selection.country?.name;
      _eventId = selection.event?.id;
      _eventName = selection.event?.name;
      _circuitId = selection.circuit?.id;
      _circuitName = selection.circuit?.name;
      _activeTabIndex = 0;
    });
  }

  void _handleCountryChanged(MarketCountry? country) {
    setState(() {
      _countryId = country?.id;
      _countryName = country?.name;
      _eventId = null;
      _eventName = null;
      _circuitId = null;
      _circuitName = null;
      _activeTabIndex = 0;
    });
  }

  void _handleEventChanged(MarketEvent? event) {
    setState(() {
      _eventId = event?.id;
      _eventName = event?.name;
      _circuitId = null;
      _circuitName = null;
      _activeTabIndex = 0;
    });
  }

  void _handleCircuitChanged(MarketCircuit? circuit) {
    setState(() {
      _circuitId = circuit?.id;
      _circuitName = circuit?.name;
      _activeTabIndex = 0;
    });
  }

  Future<void> _handleBottomBarExplorerTap() async {
    if (_activeTabIndex != 0) {
      setState(() {
        _activeTabIndex = 0;
        _catalogMenuExpanded = true;
      });
    }
    await _openCatalogFilters();
  }

  MarketMapPoiSelection? _buildInitialSelection() {
    final resolvedCountryId = _countryId?.trim();
    final resolvedEventId = _eventId?.trim();
    final resolvedCircuitId = _circuitId?.trim();
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
        name: (_countryName?.trim().isNotEmpty == true)
            ? _countryName!.trim()
            : resolvedCountryId,
        slug: resolvedCountryId,
      ),
      event: MarketEvent(
        id: resolvedEventId,
        countryId: resolvedCountryId,
        name: (_eventName?.trim().isNotEmpty == true)
            ? _eventName!.trim()
            : resolvedEventId,
        slug: resolvedEventId,
      ),
      circuit: MarketCircuit(
        id: resolvedCircuitId,
        countryId: resolvedCountryId,
        eventId: resolvedEventId,
        name: (_circuitName?.trim().isNotEmpty == true)
            ? _circuitName!.trim()
            : resolvedCircuitId,
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

  @override
  void dispose() {
    _photographerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartProvider>().totalQuantity;

    return Scaffold(
      backgroundColor: MasliveTheme.surfaceAlt,
      drawer: widget.embedded
          ? null
          : ShopDrawer(
              onNavigateHome: _goHome,
              onNavigateSearch: () => _openMarketplace(initialTab: 0),
              onNavigateProfile: _goAccount,
              onNavigateCategory: (categoryId, title) => _openMarketplace(initialTab: 0),
            ),
      appBar: widget.embedded
          ? null
          : AppBar(
              backgroundColor: const Color(0xFFF6F7FB),
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
              scrolledUnderElevation: 0,
              elevation: 0,
              toolbarHeight: 88,
              iconTheme: const IconThemeData(color: Color(0xFF101828)),
              leading: Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
              centerTitle: true,
              title: const StorexPageHeaderTitle(subtitle: 'LA BOUTIQUE PHOTO'),
              actions: [
                IconButton(
                  icon: StorexHeaderCartIcon(
                    badgeCount: cartCount,
                    selected: false,
                  ),
                  onPressed: () => setState(() => _activeTabIndex = 1),
                ),
                const SizedBox(width: 4),
              ],
            ),
      body: NestedScrollView(
        physics: const BouncingScrollPhysics(),
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(18, widget.embedded ? 18 : 14, 18, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroCarnavalCard(onTap: () => _openMarketplace(initialTab: 0)),
                    const SizedBox(height: 18),
                    _MediaCatalogFilter(
                      marketMapService: _marketMapService,
                      selectedCountryId: _countryId,
                      selectedEventId: _eventId,
                      selectedCircuitId: _circuitId,
                      photographerController: _photographerController,
                      countryLabel: _countryFieldLabel(),
                      eventLabel: _upperText(
                        _eventName,
                        fallback: 'SELECTIONNER UN EVENEMENT',
                      ),
                      circuitLabel: _upperText(
                        _circuitName,
                        fallback: 'SELECTIONNER UN CIRCUIT',
                      ),
                      isExpanded: _catalogMenuExpanded,
                      onToggleExpanded: () {
                        setState(() {
                          _catalogMenuExpanded = !_catalogMenuExpanded;
                        });
                      },
                      onCountryChanged: _handleCountryChanged,
                      onEventChanged: _handleEventChanged,
                      onCircuitChanged: _handleCircuitChanged,
                    ),
                    const SizedBox(height: 22),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          _tabTitles[_activeTabIndex],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                            color: MasliveTheme.textPrimary,
                            height: 1.1,
                          ),
                        ),
                        const Spacer(),
                        if (_activeTabIndex == 0)
                          InkWell(
                            onTap: () => setState(() => _activeTabIndex = 0),
                            borderRadius: BorderRadius.circular(10),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: Text(
                                'Catalogue complet',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: MasliveTheme.textSecondary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _MediaSectionTabs(
                      activeIndex: _activeTabIndex,
                      onChanged: (index) => setState(() => _activeTabIndex = index),
                    ),
                    if (_activeTabIndex == 0) ...[
                      const SizedBox(height: 14),
                      _PhotosMosaic(
                        likedPhotoIds: _likedPhotoIds,
                        onToggleLike: (photoId) {
                          setState(() {
                            if (_likedPhotoIds.contains(photoId)) {
                              _likedPhotoIds.remove(photoId);
                            } else {
                              _likedPhotoIds.add(photoId);
                            }
                          });
                        },
                        onOpenPhoto: () => setState(() => _activeTabIndex = 0),
                      ),
                      const SizedBox(height: 18),
                    ],
                  ],
                ),
              ),
            ),
          ];
        },
        body: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
          child: _buildActiveMarketplaceContent(),
        ),
      ),
      bottomNavigationBar: widget.embedded || !widget.showBottomBar
          ? null
          : UserFacingBottomBar(
              currentTab: UserFacingBottomBarTab.media,
              onExplorerTap: _handleBottomBarExplorerTap,
            ),
    );
  }

  Widget _buildActiveMarketplaceContent() {
    return IndexedStack(
      index: _activeTabIndex,
      children: <Widget>[
        MediaMarketplaceHomePage(
          key: ValueKey<String>(
            '${_countryId ?? ''}|${_eventId ?? ''}|${_circuitId ?? ''}|${_photographerId ?? ''}',
          ),
          countryId: _countryId,
          countryName: _countryName,
          eventId: _eventId,
          eventName: _eventName,
          circuitId: _circuitId,
          circuitName: _circuitName,
          photographerId: _photographerId,
          showContextHeader: false,
          embedded: true,
          showBranding: false,
          showCatalogFilter: false,
          showHeroCard: false,
          onOpenFilters: _openCatalogFilters,
        ),
        const UnifiedCartPage(embedded: true),
        MediaDownloadsPage(
          eventId: _eventId,
          eventName: _eventName,
          circuitName: _circuitName,
          showContextHeader: false,
          embedded: true,
        ),
        PhotographerDashboardPage(
          ownerUid: _ownerUid,
          eventId: _eventId,
          eventName: _eventName,
          circuitName: _circuitName,
          showContextHeader: false,
          embedded: true,
        ),
      ],
    );
  }
}

class _HeroCarnavalCard extends StatelessWidget {
  final VoidCallback? onTap;

  const _HeroCarnavalCard({
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFFFFB26A),
            Color(0xFFFF7BC5),
            Color(0xFF7CE0FF),
          ],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            height: 268,
            width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/shop/hero2.webp',
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),

              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.50),
                      Colors.black.withValues(alpha: 0.14),
                      Colors.black.withValues(alpha: 0.10),
                    ],
                    stops: const [0.0, 0.38, 1.0],
                  ),
                ),
              ),

              const Positioned(
                left: 18,
                bottom: 22,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CARNAVAL 2024',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.6,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'DÉCOUVRIR  >',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.2,
                        height: 1,
                      ),
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

class _MediaCatalogFilter extends StatelessWidget {
  final MarketMapService marketMapService;
  final String? selectedCountryId;
  final String? selectedEventId;
  final String? selectedCircuitId;
  final TextEditingController photographerController;
  final String countryLabel;
  final String eventLabel;
  final String circuitLabel;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<MarketCountry?> onCountryChanged;
  final ValueChanged<MarketEvent?> onEventChanged;
  final ValueChanged<MarketCircuit?> onCircuitChanged;

  const _MediaCatalogFilter({
    required this.marketMapService,
    required this.selectedCountryId,
    required this.selectedEventId,
    required this.selectedCircuitId,
    required this.photographerController,
    required this.countryLabel,
    required this.eventLabel,
    required this.circuitLabel,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onCountryChanged,
    required this.onEventChanged,
    required this.onCircuitChanged,
  });

  @override
  Widget build(BuildContext context) {
    final summary = <String>[
      if (countryLabel.trim().isNotEmpty && countryLabel != 'SELECTIONNER UN PAYS')
        countryLabel,
      if (eventLabel.trim().isNotEmpty && eventLabel != 'SELECTIONNER UN EVENEMENT')
        eventLabel,
      if (circuitLabel.trim().isNotEmpty &&
          circuitLabel != 'SELECTIONNER UN CIRCUIT')
        circuitLabel,
    ].join(' / ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MasliveTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MasliveTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CATALOGUE DES MEDIAS',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: MasliveTheme.textPrimary,
                          letterSpacing: 0.2,
                          height: 1,
                        ),
                      ),
                      if (summary.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: MasliveTheme.textSecondary,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: onToggleExpanded,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: MasliveTheme.textPrimary,
                      size: 26,
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: StreamBuilder<VisibleCircuitsIndex>(
              stream: marketMapService.watchVisibleCircuitsIndex(),
              builder: (context, visibleSnapshot) {
                final hasVisibleIndex = visibleSnapshot.hasData;
                final visibleIndex = visibleSnapshot.data;
                final visibleCountryIds = hasVisibleIndex
                    ? visibleIndex?.countryIds ?? const <String>{}
                    : const <String>{};

                if (hasVisibleIndex &&
                    selectedCountryId != null &&
                    !visibleCountryIds.contains(selectedCountryId)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    onCountryChanged(null);
                  });
                }

                final visibleEventIds = hasVisibleIndex &&
                        selectedCountryId != null &&
                        visibleCountryIds.contains(selectedCountryId)
                    ? visibleIndex?.eventIdsForCountry(selectedCountryId!) ??
                        const <String>{}
                    : const <String>{};

                if (hasVisibleIndex &&
                    selectedEventId != null &&
                    !visibleEventIds.contains(selectedEventId)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    onEventChanged(null);
                  });
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    children: [
                      if (!hasVisibleIndex)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      StreamBuilder<List<MarketCountry>>(
                        stream: marketMapService.watchCountries(),
                        builder: (context, snapshot) {
                          final countries = (snapshot.data ?? const <MarketCountry>[])
                              .where((country) => visibleCountryIds.contains(country.id))
                              .toList(growable: false);
                          return _FilterDropdownField<String>(
                            label: 'PAYS',
                            value: countries.any((country) => country.id == selectedCountryId)
                                ? selectedCountryId
                                : null,
                            hintText: 'Selectionner un pays',
                            enabled: hasVisibleIndex,
                            items: countries
                                .map(
                                  (country) => DropdownMenuItem<String>(
                                    value: country.id,
                                    child: Text(_countryDropdownLabel(country)),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (value) {
                              MarketCountry? country;
                              for (final item in countries) {
                                if (item.id == value) {
                                  country = item;
                                  break;
                                }
                              }
                              onCountryChanged(country);
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      StreamBuilder<List<MarketEvent>>(
                        stream: selectedCountryId == null ||
                                selectedCountryId!.isEmpty ||
                                !visibleCountryIds.contains(selectedCountryId)
                            ? const Stream<List<MarketEvent>>.empty()
                            : marketMapService.watchEvents(countryId: selectedCountryId!),
                        builder: (context, snapshot) {
                          final events = (snapshot.data ?? const <MarketEvent>[])
                              .where((event) => visibleEventIds.contains(event.id))
                              .toList(growable: false);
                          return _FilterDropdownField<String>(
                            label: 'EVENEMENT',
                            value: events.any((event) => event.id == selectedEventId)
                                ? selectedEventId
                                : null,
                            hintText: 'Selectionner un evenement',
                            enabled: hasVisibleIndex &&
                                selectedCountryId != null &&
                                visibleCountryIds.contains(selectedCountryId),
                            items: events
                                .map(
                                  (event) => DropdownMenuItem<String>(
                                    value: event.id,
                                    child: Text(event.name.trim().isEmpty
                                        ? event.id.toUpperCase()
                                        : event.name.trim().toUpperCase()),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (value) {
                              MarketEvent? event;
                              for (final item in events) {
                                if (item.id == value) {
                                  event = item;
                                  break;
                                }
                              }
                              onEventChanged(event);
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      StreamBuilder<List<MarketCircuit>>(
                        stream: selectedCountryId == null ||
                                selectedCountryId!.isEmpty ||
                                selectedEventId == null ||
                                selectedEventId!.isEmpty ||
                                !visibleCountryIds.contains(selectedCountryId) ||
                                !visibleEventIds.contains(selectedEventId)
                            ? const Stream<List<MarketCircuit>>.empty()
                            : marketMapService.watchCircuits(
                                countryId: selectedCountryId!,
                                eventId: selectedEventId!,
                              ),
                        builder: (context, snapshot) {
                          final circuits = (snapshot.data ?? const <MarketCircuit>[])
                              .where((circuit) => circuit.isVisible)
                              .toList(growable: false);

                          if (selectedCircuitId != null &&
                              !circuits.any((circuit) => circuit.id == selectedCircuitId)) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              onCircuitChanged(null);
                            });
                          }

                          return _FilterDropdownField<String>(
                            label: 'CIRCUIT',
                            value: circuits.any((circuit) => circuit.id == selectedCircuitId)
                                ? selectedCircuitId
                                : null,
                            hintText: 'Selectionner un circuit',
                            enabled: hasVisibleIndex &&
                                selectedCountryId != null &&
                                selectedEventId != null &&
                                visibleCountryIds.contains(selectedCountryId) &&
                                visibleEventIds.contains(selectedEventId),
                            items: circuits
                                .map(
                                  (circuit) => DropdownMenuItem<String>(
                                    value: circuit.id,
                                    child: Text(circuit.name.trim().isEmpty
                                        ? circuit.id.toUpperCase()
                                        : circuit.name.trim().toUpperCase()),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (value) {
                              MarketCircuit? circuit;
                              for (final item in circuits) {
                                if (item.id == value) {
                                  circuit = item;
                                  break;
                                }
                              }
                              onCircuitChanged(circuit);
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: MasliveTheme.surfaceAlt,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: MasliveTheme.divider),
                        ),
                        child: TextField(
                          controller: photographerController,
                          textInputAction: TextInputAction.search,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'PHOTOGRAPHE (optionnel)',
                            labelStyle: TextStyle(
                              color: MasliveTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            prefixIcon: Icon(
                              Icons.person_search_rounded,
                              size: 20,
                              color: MasliveTheme.textSecondary,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  String _countryDropdownLabel(MarketCountry country) {
    final iso2 = guessIso2FromMarketMapCountry(
      id: country.id,
      slug: country.slug,
      name: country.name,
    );
    final flag = countryFlagEmojiFromIso2(iso2);
    final name = country.name.trim().isEmpty
        ? country.id.toUpperCase()
        : country.name.trim().toUpperCase();
    return flag.isEmpty ? name : '$flag $name';
  }
}

class _FilterDropdownField<T> extends StatelessWidget {
  const _FilterDropdownField({
    required this.label,
    required this.hintText,
    required this.items,
    this.value,
    this.onChanged,
    this.enabled = true,
  });

  final String label;
  final T? value;
  final String hintText;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: enabled ? MasliveTheme.surfaceAlt : MasliveTheme.surfaceAlt.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MasliveTheme.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Text(
            '$label: ${hintText.toUpperCase()}',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: MasliveTheme.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          borderRadius: BorderRadius.circular(14),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: MasliveTheme.textPrimary,
          ),
          style: const TextStyle(
            color: MasliveTheme.textPrimary,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          items: items,
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}

class _MediaSectionTabs extends StatelessWidget {
  const _MediaSectionTabs({
    required this.activeIndex,
    required this.onChanged,
  });

  final int activeIndex;
  final ValueChanged<int> onChanged;

  static const List<String> _labels = <String>[
    'Catalogue',
    'Panier',
    'Downloads',
    'Photographe',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List<Widget>.generate(_labels.length, (index) {
          final isActive = index == activeIndex;
          return Padding(
            padding: EdgeInsets.only(right: index == _labels.length - 1 ? 0 : 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? MasliveTheme.textPrimary : MasliveTheme.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: MasliveTheme.divider),
                ),
                child: Text(
                  _labels[index],
                  style: TextStyle(
                    color: isActive ? Colors.white : MasliveTheme.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _PhotosMosaic extends StatelessWidget {
  final Set<String> likedPhotoIds;
  final ValueChanged<String> onToggleLike;
  final VoidCallback onOpenPhoto;

  const _PhotosMosaic({
    required this.likedPhotoIds,
    required this.onToggleLike,
    required this.onOpenPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 434,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT COLUMN
          Expanded(
            child: Column(
              children: [
                Expanded(
                  flex: 11,
                  child: _PhotoCard(
                    photoId: 'photo_1',
                    imageUrl:
                        'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?auto=format&fit=crop&w=900&q=80',
                    showHeart: true,
                    filledHeart: likedPhotoIds.contains('photo_1'),
                    onTap: onOpenPhoto,
                    onToggleLike: () => onToggleLike('photo_1'),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  flex: 9,
                  child: _PhotoCard(
                    photoId: 'photo_2',
                    imageUrl:
                        'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?auto=format&fit=crop&w=900&q=80',
                    showHeart: true,
                    filledHeart: likedPhotoIds.contains('photo_2'),
                    onTap: onOpenPhoto,
                    onToggleLike: () => onToggleLike('photo_2'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // RIGHT COLUMN
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(
                  flex: 9,
                  child: _PhotoCard(
                    photoId: 'photo_3',
                    imageUrl:
                        'https://images.unsplash.com/photo-1516280440614-37939bbacd81?auto=format&fit=crop&w=900&q=80',
                    showHeart: true,
                    filledHeart: likedPhotoIds.contains('photo_3'),
                    onTap: onOpenPhoto,
                    onToggleLike: () => onToggleLike('photo_3'),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  flex: 8,
                  child: Row(
                    children: [
                      Expanded(
                        child: _PhotoCard(
                          photoId: 'photo_4',
                          imageUrl:
                              'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=900&q=80',
                          showHeart: false,
                          filledHeart: false,
                          onTap: onOpenPhoto,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: _PhotoCard(
                                photoId: 'photo_5',
                                imageUrl:
                                    'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=900&q=80',
                                showHeart: false,
                                filledHeart: false,
                                onTap: onOpenPhoto,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: _PhotoCard(
                                photoId: 'photo_6',
                                imageUrl:
                                    'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=900&q=80',
                                showHeart: false,
                                filledHeart: false,
                                onTap: onOpenPhoto,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: _PhotoCard(
                                photoId: 'photo_7',
                                imageUrl:
                                    'https://images.unsplash.com/photo-1506157786151-b8491531f063?auto=format&fit=crop&w=900&q=80',
                                showHeart: true,
                                filledHeart: likedPhotoIds.contains('photo_7'),
                                heartSmall: true,
                                onTap: onOpenPhoto,
                                onToggleLike: () => onToggleLike('photo_7'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final String photoId;
  final String imageUrl;
  final bool showHeart;
  final bool filledHeart;
  final bool heartSmall;
  final VoidCallback? onTap;
  final VoidCallback? onToggleLike;

  const _PhotoCard({
    required this.photoId,
    required this.imageUrl,
    required this.showHeart,
    required this.filledHeart,
    this.heartSmall = false,
    this.onTap,
    this.onToggleLike,
  });

  @override
  Widget build(BuildContext context) {
    final double heartBoxSize = heartSmall ? 22 : 34;
    final double heartIconSize = heartSmall ? 14 : 20;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
              ),
              if (showHeart)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Material(
                    color: Colors.transparent,
                    child: InkResponse(
                      onTap: onToggleLike,
                      radius: heartBoxSize,
                      child: Container(
                        width: heartBoxSize,
                        height: heartBoxSize,
                        decoration: BoxDecoration(
                          color: filledHeart
                              ? MasliveTheme.pink
                              : Colors.black.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          filledHeart ? Icons.favorite : Icons.favorite_border,
                          size: heartIconSize,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

