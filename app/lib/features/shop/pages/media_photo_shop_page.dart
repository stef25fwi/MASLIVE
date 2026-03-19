import 'dart:async';

import 'package:flutter/material.dart';

import '../../media_marketplace/data/repositories/photographer_repository.dart';
import '../../../models/market_circuit.dart';
import '../../../models/market_country.dart';
import '../../../models/market_event.dart';
import '../../../services/market_map_service.dart';
import '../../../widgets/cart/cart_icon_badge.dart';
import '../../../ui/theme/maslive_theme.dart';
import '../../../utils/country_flag.dart';

class MediaPhotoShopPage extends StatefulWidget {
  const MediaPhotoShopPage({super.key});

  @override
  State<MediaPhotoShopPage> createState() => _MediaPhotoShopPageState();
}

class _MediaPhotoShopPageState extends State<MediaPhotoShopPage> {
  final Set<String> _likedPhotoIds = <String>{
    'photo_2',
  };
  final TextEditingController _photographerController = TextEditingController();
  String? _countryId;
  String? _countryName;
  String? _eventId;
  String? _eventName;
  String? _circuitId;
  String? _circuitName;
  bool _didLoadRouteArgs = false;
  bool _catalogMenuExpanded = false;
  bool _updatingPhotographerField = false;
  final MarketMapService _mapService = MarketMapService();
  StreamSubscription<VisibleCircuitsIndex>? _visibleSub;
  VisibleCircuitsIndex? _visibleIndex;
  List<MarketCountry> _mapCountries = <MarketCountry>[];
  List<MarketEvent> _mapEvents = <MarketEvent>[];
  List<MarketCircuit> _mapCircuits = <MarketCircuit>[];

  String? _normalizedOrNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

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

  String _countryFieldLabelFrom(MarketCountry country) {
    return _countryFieldLabelFromValues(country.id, country.name);
  }

  String _countryFieldLabelFromValues(String? countryId, String? countryName) {
    final resolvedId = countryId?.trim();
    final resolvedName = countryName?.trim();
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

  String _eventFieldLabel() {
    if (_eventId == null || _eventId!.trim().isEmpty) {
      return 'SELECTIONNER UN EVENEMENT';
    }
    final selected = _mapEvents.cast<MarketEvent?>().firstWhere(
      (event) => event?.id == _eventId,
      orElse: () => null,
    );
    if (selected != null) return selected.name.toUpperCase();
    return _upperText(_eventName, fallback: _eventId!.toUpperCase());
  }

  String _circuitFieldLabel() {
    if (_circuitId == null || _circuitId!.trim().isEmpty) {
      return 'SELECTIONNER UN CIRCUIT';
    }
    final selected = _mapCircuits.cast<MarketCircuit?>().firstWhere(
      (circuit) => circuit?.id == _circuitId,
      orElse: () => null,
    );
    if (selected != null) return selected.name.toUpperCase();
    return _upperText(_circuitName, fallback: _circuitId!.toUpperCase());
  }

  void _loadCountries() {
    _mapService.watchCountries().first.then((countries) {
      if (!mounted) return;
      setState(() => _mapCountries = countries);
    });
  }

  void _loadEvents(String countryId, [String? thenLoadCircuitsForEvent]) {
    _mapService.watchEvents(countryId: countryId).first.then((events) {
      if (!mounted) return;
      setState(() {
        _mapEvents = events;
        _mapCircuits = <MarketCircuit>[];
      });
      final eventId = _normalizedOrNull(thenLoadCircuitsForEvent);
      if (eventId != null) {
        _loadCircuits(countryId, eventId);
      }
    });
  }

  void _loadCircuits(String countryId, String eventId) {
    _mapService
        .watchCircuits(countryId: countryId, eventId: eventId)
        .first
        .then((circuits) {
      if (!mounted) return;
      setState(() {
        _mapCircuits = circuits.where((c) => c.isVisible).toList();
      });
    });
  }

  Future<void> _openInlineOptionMenu({
    required BuildContext context,
    required GlobalKey anchorKey,
    required List<_InlineFilterOption> options,
    required ValueChanged<String?> onSelected,
  }) async {
    if (options.isEmpty) return;
    final selected = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: options
                    .map(
                      (option) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          onTap: () => Navigator.of(sheetContext).pop(option.value),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: MasliveTheme.divider),
                            ),
                            child: Text(
                              option.label,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: MasliveTheme.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    if (selected != null || options.any((option) => option.value == null)) {
      onSelected(selected);
    }
  }

  @override
  void initState() {
    super.initState();
    _visibleSub = _mapService.watchVisibleCircuitsIndex().listen((index) {
      if (!mounted) return;
      setState(() => _visibleIndex = index);
    });
    _loadCountries();
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
    if (rawArgs is! Map) return;

    _countryId = (rawArgs['countryId'] as String?)?.trim();
    _countryName = (rawArgs['countryName'] as String?)?.trim();
    _eventId = (rawArgs['eventId'] as String?)?.trim();
    _eventName = (rawArgs['eventName'] as String?)?.trim();
    _circuitId = (rawArgs['circuitId'] as String?)?.trim();
    _circuitName = (rawArgs['circuitName'] as String?)?.trim();

    final selectedCountry = _normalizedOrNull(_countryId);
    if (selectedCountry != null) {
      _loadEvents(selectedCountry, _eventId);
    }
  }

  Future<void> _openMarketplace({Object? initialTab}) async {
    final photographerQuery = _photographerController.text.trim();
    String? photographerId;
    String? ownerUid;

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

    Navigator.pushNamed(
      context,
      '/media-marketplace',
      arguments: <String, dynamic>{
        if (initialTab != null) 'initialTab': initialTab,
        if (_countryId != null && _countryId!.isNotEmpty) 'countryId': _countryId,
        if (_countryName != null && _countryName!.isNotEmpty)
          'countryName': _countryName,
        if (_eventId != null && _eventId!.isNotEmpty) 'eventId': _eventId,
        if (_eventName != null && _eventName!.isNotEmpty) 'eventName': _eventName,
        if (_circuitId != null && _circuitId!.isNotEmpty) 'circuitId': _circuitId,
        if (_circuitName != null && _circuitName!.isNotEmpty)
          'circuitName': _circuitName,
        if (photographerId != null && photographerId.isNotEmpty)
          'photographerId': photographerId,
        if (ownerUid != null && ownerUid.isNotEmpty) 'ownerUid': ownerUid,
      },
    );
  }

  void _goHome() {
    Navigator.pushNamed(context, '/');
  }

  void _goAccount() {
    Navigator.pushNamed(context, '/account');
  }

  @override
  void dispose() {
    _visibleSub?.cancel();
    _photographerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleCountryIds = _visibleIndex?.countryIds ?? const <String>{};
    final selectedCountryId = _normalizedOrNull(_countryId);

    final countryOptions = <_InlineFilterOption>[
      const _InlineFilterOption(value: null, label: 'TOUS LES PAYS'),
      ..._mapCountries
          .where((country) => visibleCountryIds.contains(country.id))
          .map(
            (country) => _InlineFilterOption(
              value: country.id,
              label: _countryFieldLabelFrom(country),
            ),
          ),
    ];

    final visibleEventIds = selectedCountryId == null
        ? const <String>{}
        : (_visibleIndex?.eventIdsForCountry(selectedCountryId) ??
              const <String>{});
    final eventOptions = <_InlineFilterOption>[
      const _InlineFilterOption(value: null, label: 'TOUS LES EVENEMENTS'),
      ..._mapEvents
          .where((event) => visibleEventIds.contains(event.id))
          .map(
            (event) => _InlineFilterOption(
              value: event.id,
              label: event.name.toUpperCase(),
            ),
          ),
    ];

    final circuitOptions = <_InlineFilterOption>[
      const _InlineFilterOption(value: null, label: 'TOUS LES CIRCUITS'),
      ..._mapCircuits
          .map(
            (circuit) => _InlineFilterOption(
              value: circuit.id,
              label: circuit.name.toUpperCase(),
            ),
          ),
    ];

    return Scaffold(
      backgroundColor: MasliveTheme.surfaceAlt,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),

                    // ---------------- TOP LOGO AREA ----------------
                    SizedBox(
                      height: 48,
                      child: Stack(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              icon: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: MasliveTheme.surface,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: MasliveTheme.divider,
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: MasliveTheme.textPrimary,
                                    size: 17,
                                  ),
                                ),
                              ),
                              onPressed: () {
                                final navigator = Navigator.of(context);
                                if (navigator.canPop()) {
                                  navigator.maybePop();
                                } else {
                                  navigator.pushNamed('/');
                                }
                              },
                              tooltip: 'Retour',
                            ),
                          ),
                          const Align(
                            alignment: Alignment.center,
                            child: Text(
                              "MAS'LIVE",
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.8,
                                color: MasliveTheme.textPrimary,
                                height: 1,
                              ),
                            ),
                          ),
                          const Align(
                            alignment: Alignment.centerRight,
                            child: CartIconBadge(
                              iconGradient: const LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: <Color>[
                                  Color(0xFFFFB26A),
                                  Color(0xFFFF7BC5),
                                  Color(0xFF7CE0FF),
                                ],
                              ),
                              backgroundColor: MasliveTheme.surface,
                              borderColor: MasliveTheme.divider,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Center(
                      child: Text(
                        'LA BOUTIQUE PHOTO',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 2.2,
                          color: MasliveTheme.textSecondary,
                          height: 1,
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ---------------- HERO CARD ----------------
                    _HeroCarnavalCard(onTap: () => _openMarketplace(initialTab: 0)),

                    const SizedBox(height: 18),

                    // ---------------- MEDIA FILTER ----------------
                    _MediaCatalogFilter(
                      photographerController: _photographerController,
                      countryLabel: _countryFieldLabel(),
                      eventLabel: _eventFieldLabel(),
                      circuitLabel: _circuitFieldLabel(),
                      isExpanded: _catalogMenuExpanded,
                      onToggleExpanded: () {
                        setState(() {
                          _catalogMenuExpanded = !_catalogMenuExpanded;
                        });
                      },
                      onSelectCountry: (anchorKey) => _openInlineOptionMenu(
                        context: context,
                        anchorKey: anchorKey,
                        options: countryOptions,
                        onSelected: (value) {
                          final selected = value == null
                              ? null
                              : _mapCountries.cast<MarketCountry?>().firstWhere(
                                  (country) => country?.id == value,
                                  orElse: () => null,
                                );
                          setState(() {
                            _countryId = value;
                            _countryName = selected?.name;
                            _eventId = null;
                            _eventName = null;
                            _circuitId = null;
                            _circuitName = null;
                            _mapEvents = <MarketEvent>[];
                            _mapCircuits = <MarketCircuit>[];
                          });
                          final countryId = _normalizedOrNull(value);
                          if (countryId != null) {
                            _loadEvents(countryId);
                          }
                        },
                      ),
                      onSelectEvent: (anchorKey) => _openInlineOptionMenu(
                        context: context,
                        anchorKey: anchorKey,
                        options: eventOptions,
                        onSelected: (value) {
                          final selected = value == null
                              ? null
                              : _mapEvents.cast<MarketEvent?>().firstWhere(
                                  (event) => event?.id == value,
                                  orElse: () => null,
                                );
                          setState(() {
                            _eventId = value;
                            _eventName = selected?.name;
                            _circuitId = null;
                            _circuitName = null;
                            _mapCircuits = <MarketCircuit>[];
                          });
                          final countryId = _normalizedOrNull(_countryId);
                          final eventId = _normalizedOrNull(value);
                          if (countryId != null && eventId != null) {
                            _loadCircuits(countryId, eventId);
                          }
                        },
                      ),
                      onSelectCircuit: (anchorKey) => _openInlineOptionMenu(
                        context: context,
                        anchorKey: anchorKey,
                        options: circuitOptions,
                        onSelected: (value) {
                          final selected = value == null
                              ? null
                              : _mapCircuits.cast<MarketCircuit?>().firstWhere(
                                  (circuit) => circuit?.id == value,
                                  orElse: () => null,
                                );
                          setState(() {
                            _circuitId = value;
                            _circuitName = selected?.name;
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ---------------- SECTION HEADER ----------------
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'PHOTOS POPULAIRES',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                            color: MasliveTheme.textPrimary,
                            height: 1.1,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => _openMarketplace(initialTab: 0),
                          borderRadius: BorderRadius.circular(10),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Text(
                              'Voir tout',
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

                    const SizedBox(height: 14),

                    // ---------------- PHOTO MOSAIC ----------------
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
                      onOpenPhoto: () => _openMarketplace(initialTab: 0),
                    ),

                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),

            // ---------------- BOTTOM NAV ----------------
            SafeArea(
              top: false,
              child: Container(
                height: 68,
                decoration: const BoxDecoration(
                  color: _ShopBottomTheme.navBg,
                  border: Border(
                    top: BorderSide(color: _ShopBottomTheme.strokeSoft),
                  ),
                  boxShadow: <BoxShadow>[
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
                    _BottomNavItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home,
                      active: false,
                      onTap: _goHome,
                    ),
                    _BottomNavItem(
                      icon: Icons.photo_camera_outlined,
                      activeIcon: Icons.photo_camera,
                      active: true,
                      onTap: () {},
                    ),
                    _BottomNavItem(
                      icon: Icons.arrow_downward_rounded,
                      activeIcon: Icons.arrow_downward_rounded,
                      active: false,
                      onTap: () => _openMarketplace(initialTab: 'downloads'),
                    ),
                    _BottomNavItem(
                      icon: Icons.person_outline,
                      activeIcon: Icons.person,
                      active: false,
                      onTap: _goAccount,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
  final TextEditingController photographerController;
  final String countryLabel;
  final String eventLabel;
  final String circuitLabel;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<GlobalKey> onSelectCountry;
  final ValueChanged<GlobalKey> onSelectEvent;
  final ValueChanged<GlobalKey> onSelectCircuit;

  const _MediaCatalogFilter({
    required this.photographerController,
    required this.countryLabel,
    required this.eventLabel,
    required this.circuitLabel,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onSelectCountry,
    required this.onSelectEvent,
    required this.onSelectCircuit,
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
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                          color: MasliveTheme.textPrimary,
                        ),
                      ),
                      if (summary.isNotEmpty) ...[
                        const SizedBox(height: 4),
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
                const SizedBox(width: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: onToggleExpanded,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: MasliveTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                children: [
                  _FilterReadOnlyField(
                    label: 'PAYS',
                    value: countryLabel,
                    hintText: 'Selectionner un pays',
                    onTap: onSelectCountry,
                  ),
                  const SizedBox(height: 10),
                  _FilterReadOnlyField(
                    label: 'EVENEMENT',
                    value: eventLabel,
                    hintText: 'Selectionner un evenement',
                    onTap: onSelectEvent,
                  ),
                  const SizedBox(height: 10),
                  _FilterReadOnlyField(
                    label: 'CIRCUIT',
                    value: circuitLabel,
                    hintText: 'Selectionner un circuit',
                    onTap: onSelectCircuit,
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
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onToggleExpanded,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'VALIDER',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
}

class _FilterReadOnlyField extends StatelessWidget {
  const _FilterReadOnlyField({
    required this.label,
    required this.value,
    required this.hintText,
    required this.onTap,
  });

  final String label;
  final String? value;
  final String hintText;
  final ValueChanged<GlobalKey> onTap;

  @override
  Widget build(BuildContext context) {
    final anchorKey = GlobalKey();
    return InkWell(
      key: anchorKey,
      borderRadius: BorderRadius.circular(14),
      onTap: () => onTap(anchorKey),
      child: Container(
        height: 46,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: MasliveTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: MasliveTheme.divider),
        ),
        child: Row(
          children: [
            Expanded(
              child: RichText(
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: const TextStyle(
                    color: MasliveTheme.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                  children: [
                    TextSpan(
                      text: '$label: ',
                      style: const TextStyle(
                        color: MasliveTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: (value?.trim().isNotEmpty == true)
                          ? value!.trim().toUpperCase()
                          : hintText.toUpperCase(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: MasliveTheme.textSecondary,
            ),
          ],
        ),
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

class _InlineFilterOption {
  const _InlineFilterOption({required this.value, required this.label});

  final String? value;
  final String label;
}

class _ShopBottomTheme {
  const _ShopBottomTheme._();

  static const Color navBg = Color(0xF9FFFFFF);
  static const Color strokeSoft = Color(0x1F0F172A);
  static const LinearGradient chipGradient = LinearGradient(
    colors: [Color(0xFFFFB26A), Color(0xFFFF7BC5), Color(0xFF7CE0FF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const BoxShadow cardShadow = BoxShadow(
    color: Color(0x14000000),
    blurRadius: 18,
    offset: Offset(0, 8),
  );
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final bool active;
  final VoidCallback? onTap;

  const _BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.active,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconChild = Icon(
      active ? activeIcon : icon,
      color: active ? Colors.white : const Color(0xFF98A2B3),
      size: 24,
    );

    return InkResponse(
      radius: 28,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(8),
        decoration: active
            ? BoxDecoration(
                gradient: _ShopBottomTheme.chipGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const <BoxShadow>[_ShopBottomTheme.cardShadow],
              )
            : null,
        child: iconChild,
      ),
    );
  }
}
