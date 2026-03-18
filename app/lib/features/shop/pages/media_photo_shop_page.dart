import 'package:flutter/material.dart';

import '../../media_marketplace/data/repositories/photographer_repository.dart';
import '../../../models/market_circuit.dart';
import '../../../models/market_country.dart';
import '../../../models/market_event.dart';
import '../../../ui/widgets/marketmap_poi_selector_sheet.dart';
import '../../../ui/theme/maslive_theme.dart';

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
  }

  Future<void> _openCatalogFilterMenu() async {
    final selection = await showMarketMapCircuitSelectorSheet(
      context,
      initial: _buildInitialSelection(),
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
    });
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
    _photographerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    const SizedBox(height: 4),

                    // ---------------- TOP LOGO AREA ----------------
                    const Center(
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
                    const SizedBox(height: 8),
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
                      countryName: _countryName,
                      eventName: _eventName,
                      circuitName: _circuitName,
                      onOpenFilterMenu: _openCatalogFilterMenu,
                      onOpenEvents: _openCatalogFilterMenu,
                      onOpenPhotos: () => _openMarketplace(initialTab: 0),
                      onOpenPacks: () => _openMarketplace(initialTab: 0),
                      onOpenArtists: () => _openMarketplace(initialTab: 3),
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
            Container(
              height: 88,
              decoration: const BoxDecoration(
                color: MasliveTheme.surface,
                border: Border(
                  top: BorderSide(
                    color: MasliveTheme.divider,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _BottomNavItem(
                    icon: Icons.home_outlined,
                    label: 'Accueil',
                    active: false,
                    onTap: _goHome,
                  ),
                  _BottomNavItem(
                    icon: Icons.photo_camera_outlined,
                    label: 'Photos',
                    active: true,
                    onTap: () {},
                  ),
                  _BottomNavItem(
                    icon: Icons.arrow_downward_rounded,
                    label: 'Téléchargements',
                    active: false,
                    onTap: () => _openMarketplace(initialTab: 'downloads'),
                  ),
                  _BottomNavItem(
                    icon: Icons.person_outline,
                    label: 'Profil',
                    active: false,
                    onTap: _goAccount,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _CategoryChip({
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: MasliveTheme.surface,
            borderRadius: BorderRadius.circular(22),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: MasliveTheme.textPrimary,
              letterSpacing: 0.1,
            ),
          ),
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
  final String? countryName;
  final String? eventName;
  final String? circuitName;
  final VoidCallback onOpenFilterMenu;
  final VoidCallback onOpenEvents;
  final VoidCallback onOpenPhotos;
  final VoidCallback onOpenPacks;
  final VoidCallback onOpenArtists;

  const _MediaCatalogFilter({
    required this.photographerController,
    required this.countryName,
    required this.eventName,
    required this.circuitName,
    required this.onOpenFilterMenu,
    required this.onOpenEvents,
    required this.onOpenPhotos,
    required this.onOpenPacks,
    required this.onOpenArtists,
  });

  @override
  Widget build(BuildContext context) {
    final summary = <String>[
      if (countryName?.trim().isNotEmpty == true) countryName!.trim(),
      if (eventName?.trim().isNotEmpty == true) eventName!.trim(),
      if (circuitName?.trim().isNotEmpty == true) circuitName!.trim(),
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
          InkWell(
            onTap: onOpenFilterMenu,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
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
                  const Icon(
                    Icons.tune_rounded,
                    size: 20,
                    color: MasliveTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _CategoryChip(label: 'ÉVÉNEMENTS', onTap: onOpenEvents),
                const SizedBox(width: 10),
                _CategoryChip(label: 'PHOTOS', onTap: onOpenPhotos),
                const SizedBox(width: 10),
                _CategoryChip(label: 'PACKS', onTap: onOpenPacks),
                const SizedBox(width: 10),
                _CategoryChip(label: 'ARTISTES', onTap: onOpenArtists),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
              onSubmitted: (_) => onOpenPhotos(),
              decoration: const InputDecoration(
                hintText: 'Photographe (optionnel)',
                hintStyle: TextStyle(
                  color: MasliveTheme.textSecondary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
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

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.active,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const Color activeColor = MasliveTheme.textPrimary;
    const Color inactiveColor = MasliveTheme.textSecondary;

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 86,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 29,
              color: active ? activeColor : inactiveColor,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.8,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? activeColor : inactiveColor,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
