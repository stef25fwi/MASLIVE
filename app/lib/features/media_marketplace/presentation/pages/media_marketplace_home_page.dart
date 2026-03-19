import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/enums/media_asset_type.dart';
import '../../data/models/media_gallery_model.dart';
import '../../data/models/media_pack_model.dart';
import '../../data/models/media_photo_model.dart';
import '../../data/repositories/photographer_repository.dart';
import '../../presentation/controllers/media_marketplace_catalog_controller.dart';
import '../../../../models/cart_item_model.dart' as unified_cart;
import '../../../../providers/cart_provider.dart';
import '../../../../ui/theme/maslive_theme.dart';
import '../../../../ui/snack/top_snack_bar.dart';
import '../../../../utils/country_flag.dart';
import '../../../../models/market_circuit.dart';
import '../../../../models/market_country.dart';
import '../../../../models/market_event.dart';
import '../../../../services/market_map_service.dart';
import '../widgets/media_marketplace_context_chips.dart';
import '../widgets/media_marketplace_message_card.dart';

class MediaMarketplaceHomePage extends StatelessWidget {
  const MediaMarketplaceHomePage({
    super.key,
    this.countryId,
    this.countryName,
    this.eventId,
    this.eventName,
    this.circuitId,
    this.circuitName,
    this.photographerId,
    this.showContextHeader = true,
    this.embedded = false,
    this.showBranding = true,
    this.onOpenFilters,
  });

  final String? countryId;
  final String? countryName;
  final String? eventId;
  final String? eventName;
  final String? circuitId;
  final String? circuitName;
  final String? photographerId;
  final bool showContextHeader;
  final bool embedded;
  final bool showBranding;
  final VoidCallback? onOpenFilters;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MediaMarketplaceCatalogController>(
      create: (_) {
        final controller = MediaMarketplaceCatalogController();
        Future<void>.microtask(() async {
          if (eventId != null && eventId!.isNotEmpty) {
            await controller.loadEventGalleries(
              eventId!,
              countryId: countryId,
              circuitId: circuitId,
            );
          } else if (photographerId != null && photographerId!.isNotEmpty) {
            await controller.loadPhotographerGalleries(photographerId!);
          }
        });
        return controller;
      },
      child: _MediaMarketplaceHomeView(
        embedded: embedded,
        countryId: countryId,
        countryName: countryName,
        eventId: eventId,
        eventName: eventName,
        circuitId: circuitId,
        circuitName: circuitName,
        showContextHeader: showContextHeader,
        showBranding: showBranding,
        onOpenFilters: onOpenFilters,
      ),
    );
  }
}

class _MediaMarketplaceHomeView extends StatefulWidget {
  const _MediaMarketplaceHomeView({
    required this.embedded,
    required this.countryId,
    required this.countryName,
    required this.eventId,
    required this.eventName,
    required this.circuitId,
    required this.circuitName,
    required this.showContextHeader,
    required this.showBranding,
    required this.onOpenFilters,
  });

  final bool embedded;
  final String? countryId;
  final String? countryName;
  final String? eventId;
  final String? eventName;
  final String? circuitId;
  final String? circuitName;
  final bool showContextHeader;
  final bool showBranding;
  final VoidCallback? onOpenFilters;

  @override
  State<_MediaMarketplaceHomeView> createState() =>
      _MediaMarketplaceHomeViewState();
}

class _MediaMarketplaceHomeViewState extends State<_MediaMarketplaceHomeView> {
  bool _catalogMenuExpanded = false;
  final TextEditingController _photographerController =
      TextEditingController();
  final PhotographerRepository _photographerRepository =
      PhotographerRepository();
  final Map<String, String> _photographerNamesById = <String, String>{};

  String? _selectedCountryId;
  String? _selectedEventId;
  String? _selectedCircuitId;
  String _loadedPhotographerSignature = '';
  bool _updatingPhotographerField = false;

  final MarketMapService _mapService = MarketMapService();
  StreamSubscription<VisibleCircuitsIndex>? _visibleSub;
  VisibleCircuitsIndex? _visibleIndex;
  List<MarketCountry> _mapCountries = <MarketCountry>[];
  List<MarketEvent> _mapEvents = <MarketEvent>[];
  List<MarketCircuit> _mapCircuits = <MarketCircuit>[];

  @override
  void initState() {
    super.initState();
    _syncFiltersFromWidget();
    _visibleSub = _mapService.watchVisibleCircuitsIndex().listen((index) {
      if (!mounted) return;
      setState(() => _visibleIndex = index);
    });
    _mapService.watchCountries().first.then((countries) {
      if (!mounted) return;
      setState(() => _mapCountries = countries);
    });
    _photographerController.addListener(() {
      if (_updatingPhotographerField) return;
      final uppercase = _photographerController.text.toUpperCase();
      if (uppercase == _photographerController.text) {
        setState(() {});
        return;
      }
      _updatingPhotographerField = true;
      _photographerController.value = _photographerController.value.copyWith(
        text: uppercase,
        selection: TextSelection.collapsed(offset: uppercase.length),
      );
      _updatingPhotographerField = false;
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant _MediaMarketplaceHomeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.countryId != widget.countryId ||
        oldWidget.eventId != widget.eventId ||
        oldWidget.circuitId != widget.circuitId) {
      _syncFiltersFromWidget();
    }
  }

  void _syncFiltersFromWidget() {
    _selectedCountryId = _normalizedOrNull(widget.countryId);
    _selectedEventId = _normalizedOrNull(widget.eventId);
    _selectedCircuitId = _normalizedOrNull(widget.circuitId);
    if (_selectedCountryId != null) {
      _loadMapEvents(_selectedCountryId!, _selectedEventId);
    }
  }

  String? _normalizedOrNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String _upperText(String? value, {String fallback = '--'}) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return fallback;
    return trimmed.toUpperCase();
  }

  String _countryFieldLabel(String? countryId, String? countryName) {
    final resolvedId = _normalizedOrNull(countryId);
    final resolvedName = _normalizedOrNull(countryName);
    if (resolvedId == null && resolvedName == null) {
      return 'SELECTIONNER UN PAYS';
    }
    final iso2 = guessIso2FromMarketMapCountry(
      id: resolvedId ?? '',
      slug: resolvedId ?? '',
      name: resolvedName ?? resolvedId ?? '',
    );
    final flag = countryFlagEmojiFromIso2(iso2);
    final code = iso2.isNotEmpty ? iso2 : _upperText(resolvedId, fallback: '');
    final name = resolvedName != null ? resolvedName.toUpperCase() : '';
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

  Future<void> _ensurePhotographerNames(List<MediaGalleryModel> galleries) async {
    final ids = galleries
        .map((gallery) => gallery.photographerId.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final signature = ids.join('|');
    if (signature == _loadedPhotographerSignature) return;
    _loadedPhotographerSignature = signature;
    if (ids.isEmpty) {
      if (!mounted) return;
      setState(() => _photographerNamesById.clear());
      return;
    }
    final resolved = await Future.wait(
      ids.map((id) async {
        final profile = await _photographerRepository.getById(id);
        final label = profile?.brandName.trim().isNotEmpty == true
            ? profile!.brandName.trim()
            : id;
        return MapEntry(id, label);
      }),
    );
    if (!mounted) return;
    setState(() {
      _photographerNamesById
        ..clear()
        ..addEntries(resolved);
    });
  }

  void _loadMapEvents(String countryId, [String? thenLoadCircuitsForEvent]) {
    _mapService.watchEvents(countryId: countryId).first.then((events) {
      if (!mounted) return;
      setState(() {
        _mapEvents = events;
        _mapCircuits = <MarketCircuit>[];
      });
      if (thenLoadCircuitsForEvent != null) {
        _loadMapCircuits(countryId, thenLoadCircuitsForEvent);
      }
    });
  }

  void _loadMapCircuits(String countryId, String eventId) {
    _mapService
        .watchCircuits(countryId: countryId, eventId: eventId)
        .first
        .then((circuits) {
      if (!mounted) return;
      setState(() => _mapCircuits = circuits.where((c) => c.isVisible).toList());
    });
  }

  String _eventNameLabel(String? eventId) {
    if (eventId == null) return 'SELECTIONNER UN EVENEMENT';
    final event = _mapEvents.cast<MarketEvent?>().firstWhere(
      (e) => e?.id == eventId,
      orElse: () => null,
    );
    if (event != null) return event.name.toUpperCase();
    if (eventId == widget.eventId && widget.eventName?.trim().isNotEmpty == true) {
      return widget.eventName!.trim().toUpperCase();
    }
    return eventId.toUpperCase();
  }

  String _circuitNameLabel(String? circuitId) {
    if (circuitId == null) return 'SELECTIONNER UN CIRCUIT';
    final circuit = _mapCircuits.cast<MarketCircuit?>().firstWhere(
      (c) => c?.id == circuitId,
      orElse: () => null,
    );
    if (circuit != null) return circuit.name.toUpperCase();
    if (circuitId == widget.circuitId && widget.circuitName?.trim().isNotEmpty == true) {
      return widget.circuitName!.trim().toUpperCase();
    }
    return circuitId.toUpperCase();
  }

  Future<void> _openInlineOptionMenu({
    required BuildContext context,
    required GlobalKey anchorKey,
    required List<_InlineFilterOption> options,
    required ValueChanged<String?> onSelected,
  }) async {
    final currentContext = anchorKey.currentContext;
    if (currentContext == null || options.isEmpty) return;
    final box = currentContext.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(Offset.zero, ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    final selected = await showMenu<String?>(
      context: context,
      position: position,
      items: options
          .map(
            (option) => PopupMenuItem<String?>(
              value: option.value,
              child: Text(option.label),
            ),
          )
          .toList(growable: false),
    );
    if (!mounted) return;
    if (selected != null || options.any((option) => option.value == null)) {
      onSelected(selected);
    }
  }

  @override
  void dispose() {
    _visibleSub?.cancel();
    _photographerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<MediaMarketplaceCatalogController>();
    final cart = context.watch<CartProvider>();

    if (!catalog.loading && catalog.galleries.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensurePhotographerNames(catalog.galleries);
      });
    }

    final photographerQuery = _photographerController.text.trim().toLowerCase();
    final filteredGalleries = catalog.galleries.where((gallery) {
      if (_selectedCountryId != null &&
          gallery.linkedCountry?.trim() != _selectedCountryId) {
        return false;
      }
      if (_selectedEventId != null && gallery.eventId.trim() != _selectedEventId) {
        return false;
      }
      if (_selectedCircuitId != null &&
          gallery.linkedCircuitId?.trim() != _selectedCircuitId) {
        return false;
      }
      if (photographerQuery.isNotEmpty) {
        final photographerId = gallery.photographerId.trim().toLowerCase();
        final photographerName =
            (_photographerNamesById[gallery.photographerId] ?? '')
                .trim()
                .toLowerCase();
        if (!photographerId.contains(photographerQuery) &&
            !photographerName.contains(photographerQuery)) {
          return false;
        }
      }
      return true;
    }).toList(growable: false);

    if (!catalog.loading &&
        catalog.error == null &&
        filteredGalleries.isNotEmpty &&
        (catalog.selectedGalleryId == null ||
            !filteredGalleries.any(
              (gallery) => gallery.galleryId == catalog.selectedGalleryId,
            ))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final controller = context.read<MediaMarketplaceCatalogController>();
        if (!filteredGalleries.any(
          (gallery) => gallery.galleryId == controller.selectedGalleryId,
        )) {
          controller.selectGallery(filteredGalleries.first.galleryId);
        }
      });
    }

    final MediaGalleryModel? selectedGallery = catalog.selectedGalleryId == null
        ? null
        : filteredGalleries.cast<MediaGalleryModel?>().firstWhere(
            (g) => g?.galleryId == catalog.selectedGalleryId,
            orElse: () => null,
          );

    final visibleCountryIds = _visibleIndex?.countryIds ?? const <String>{};
    final countryOptions = <_InlineFilterOption>[
      const _InlineFilterOption(value: null, label: 'TOUS LES PAYS'),
      ..._mapCountries
          .where((c) => visibleCountryIds.isEmpty || visibleCountryIds.contains(c.id))
          .map((c) => _InlineFilterOption(value: c.id, label: _countryFieldLabel(c.id, c.name))),
    ];

    final visibleEventIds =
        _visibleIndex?.eventIdsForCountry(_selectedCountryId ?? '') ?? const <String>{};
    final eventOptions = <_InlineFilterOption>[
      const _InlineFilterOption(value: null, label: 'TOUS LES EVENEMENTS'),
      ..._mapEvents
          .where((e) => visibleEventIds.isEmpty || visibleEventIds.contains(e.id))
          .map((e) => _InlineFilterOption(value: e.id, label: e.name.toUpperCase())),
    ];

    final circuitOptions = <_InlineFilterOption>[
      const _InlineFilterOption(value: null, label: 'TOUS LES CIRCUITS'),
      ..._mapCircuits.map((c) => _InlineFilterOption(value: c.id, label: c.name.toUpperCase())),
    ];

    final String? heroImageUrl =
        selectedGallery?.coverUrl?.trim().isNotEmpty == true
        ? selectedGallery!.coverUrl!.trim()
        : (catalog.photos.isNotEmpty
              ? catalog.photos.first.thumbnailPath
              : (catalog.packs.isNotEmpty
                    ? catalog.packs.first.coverUrl
                    : null));

    final body = DecoratedBox(
      decoration: const BoxDecoration(color: MasliveTheme.surfaceAlt),
      child: Column(
        children: <Widget>[
          if (catalog.loading) const LinearProgressIndicator(minHeight: 2),
          if (catalog.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
              child: MediaMarketplaceMessageCard.error(catalog.error!),
            ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(8, 18, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: 4),
                  if (widget.showBranding) ...<Widget>[
                    Center(
                      child: Text(
                        'MASLIVE',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                          color: MasliveTheme.textPrimary,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
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
                    const SizedBox(height: 14),
                  ],
                  _CatalogFilterTrigger(
                    countryFieldLabel: _countryFieldLabel(
                      _selectedCountryId,
                      _selectedCountryId == widget.countryId
                          ? widget.countryName
                          : null,
                    ),
                    eventFieldLabel: _eventNameLabel(_selectedEventId),
                    circuitFieldLabel: _circuitNameLabel(_selectedCircuitId),
                    photographerController: _photographerController,
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
                        setState(() {
                          _selectedCountryId = value;
                          _selectedEventId = null;
                          _selectedCircuitId = null;
                          _mapEvents = <MarketEvent>[];
                          _mapCircuits = <MarketCircuit>[];
                        });
                        if (value != null) _loadMapEvents(value);
                      },
                    ),
                    onSelectEvent: (anchorKey) => _openInlineOptionMenu(
                      context: context,
                      anchorKey: anchorKey,
                      options: eventOptions,
                      onSelected: (value) {
                        setState(() {
                          _selectedEventId = value;
                          _selectedCircuitId = null;
                          _mapCircuits = <MarketCircuit>[];
                        });
                        if (_selectedCountryId != null && value != null) {
                          _loadMapCircuits(_selectedCountryId!, value);
                        }
                      },
                    ),
                    onSelectCircuit: (anchorKey) => _openInlineOptionMenu(
                      context: context,
                      anchorKey: anchorKey,
                      options: circuitOptions,
                      onSelected: (value) {
                        setState(() {
                          _selectedCircuitId = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (widget.showContextHeader &&
                      catalog.currentEventId != null) ...<Widget>[
                    MediaMarketplaceContextChips(
                      eventId: catalog.currentEventId!,
                      circuitName: widget.circuitName,
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (!(catalog.galleries.isEmpty && !catalog.loading))
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: filteredGalleries
                            .map(
                              (MediaGalleryModel gallery) => Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: _CategoryChip(
                                  label: gallery.title.isEmpty
                                      ? 'GALERIE'
                                      : gallery.title.toUpperCase(),
                                  selected:
                                      catalog.selectedGalleryId ==
                                      gallery.galleryId,
                                  onTap: () =>
                                      catalog.selectGallery(gallery.galleryId),
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                  const SizedBox(height: 20),
                  _HeroGalleryCard(
                    title: selectedGallery?.title.trim().isNotEmpty == true
                        ? selectedGallery!.title.trim().toUpperCase()
                      : (widget.eventName?.trim().isNotEmpty == true
                        ? widget.eventName!.trim().toUpperCase()
                              : 'GALERIE'),
                    imageUrl: heroImageUrl,
                    onTap: catalog.selectedGalleryId == null ? null : () {},
                  ),
                  const SizedBox(height: 22),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: const <Widget>[
                      Text(
                        'PHOTOS POPULAIRES',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                          color: MasliveTheme.textPrimary,
                          height: 1.1,
                        ),
                      ),
                      Spacer(),
                      Text(
                        'Voir tout',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: MasliveTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (selectedGallery == null)
                    MediaMarketplaceMessageCard.empty(
                      title: filteredGalleries.isEmpty
                          ? 'Aucun resultat'
                          : 'Sélectionne une galerie',
                      message: filteredGalleries.isEmpty
                          ? 'Aucune galerie ne correspond aux filtres actifs.'
                          : 'Choisis une catégorie ci-dessus pour afficher les médias disponibles.',
                      icon: Icons.photo_library_outlined,
                    )
                  else
                    _PhotosMosaic(
                      photos: catalog.photos,
                      packs: catalog.packs,
                      cart: cart,
                      onAddPhoto: (photo) =>
                          _openMediaPhotoDetails(context, photo),
                      onAddPack: (pack) => _addMediaPack(context, pack),
                    ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Marché des médias'),
        actions: <Widget>[
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text('Panier ${cart.mediaItems.length}'),
            ),
          ),
        ],
      ),
      body: body,
    );
  }

  Future<void> _addMediaPhoto(
    BuildContext context,
    MediaPhotoModel photo,
  ) async {
    await context.read<CartProvider>().addCartItem(
      unified_cart.CartItemModel(
        id: '',
        itemType: unified_cart.CartItemType.media,
        productId: photo.photoId,
        sellerId: photo.photographerId,
        eventId: photo.eventId,
        title: photo.downloadFileName,
        subtitle: photo.galleryId.isEmpty ? null : 'Galerie ${photo.galleryId}',
        imageUrl: photo.thumbnailPath,
        unitPrice: photo.unitPrice,
        quantity: 1,
        currency: photo.currency,
        isDigital: true,
        requiresShipping: false,
        sourceType: 'media_marketplace',
        metadata: <String, dynamic>{
          'assetType': MediaAssetType.photo.firestoreValue,
          'galleryId': photo.galleryId,
        },
      ),
    );
    if (!context.mounted) return;
    TopSnackBar.show(
      context,
      SnackBar(content: Text('${photo.downloadFileName} ajoute au panier')),
    );
  }

  Future<void> _openMediaPhotoDetails(
    BuildContext context,
    MediaPhotoModel photo,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext modalContext) {
        return _MediaPhotoDetailsSheet(
          photo: photo,
          onAddToCart: () async {
            Navigator.of(modalContext).pop();
            await _addMediaPhoto(context, photo);
          },
        );
      },
    );
  }

  Future<void> _addMediaPack(BuildContext context, MediaPackModel pack) async {
    await context.read<CartProvider>().addCartItem(
      unified_cart.CartItemModel(
        id: '',
        itemType: unified_cart.CartItemType.media,
        productId: pack.packId,
        sellerId: pack.photographerId,
        eventId: pack.eventId,
        title: pack.title,
        subtitle: pack.galleryId.isEmpty
            ? null
            : 'Pack galerie ${pack.galleryId}',
        imageUrl: pack.coverUrl ?? '',
        unitPrice: pack.price,
        quantity: 1,
        currency: pack.currency,
        isDigital: true,
        requiresShipping: false,
        sourceType: 'media_marketplace',
        metadata: <String, dynamic>{
          'assetType': MediaAssetType.pack.firestoreValue,
          'galleryId': pack.galleryId,
          'photoIds': pack.photoIds,
          'photoCount': pack.photoIds.length,
        },
      ),
    );
    if (!context.mounted) return;
    TopSnackBar.show(
      context,
      SnackBar(content: Text('${pack.title} ajoute au panier')),
    );
  }
}

class _MediaPhotoDetailsSheet extends StatelessWidget {
  const _MediaPhotoDetailsSheet({
    required this.photo,
    required this.onAddToCart,
  });

  final MediaPhotoModel photo;
  final Future<void> Function() onAddToCart;

  String get _formattedPrice =>
      '${photo.unitPrice.toStringAsFixed(2)} ${photo.currency}';

  @override
  Widget build(BuildContext context) {
    final String imageUrl = photo.previewPath.trim().isNotEmpty
        ? photo.previewPath.trim()
        : photo.thumbnailPath.trim();

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Center(
                child: Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: imageUrl.isNotEmpty
                      ? Image.network(imageUrl, fit: BoxFit.cover)
                      : Container(
                          color: MasliveTheme.surface,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.image_outlined,
                            size: 42,
                            color: MasliveTheme.textSecondary,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                photo.downloadFileName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: MasliveTheme.textPrimary,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),
              _PhotoDetailMetaRow(
                label: 'Prix',
                value: _formattedPrice,
                emphasize: true,
              ),
              if (photo.countryName != null && photo.countryName!.isNotEmpty)
                _PhotoDetailMetaRow(
                  label: 'Pays',
                  value: photo.countryName ?? '--',
                ),
              if (photo.eventName != null && photo.eventName!.isNotEmpty)
                _PhotoDetailMetaRow(
                  label: 'Événement',
                  value: photo.eventName ?? '--',
                ),
              if (photo.circuitName != null && photo.circuitName!.isNotEmpty)
                _PhotoDetailMetaRow(
                  label: 'Circuit',
                  value: photo.circuitName ?? '--',
                ),
              _PhotoDetailMetaRow(
                label: 'Galerie',
                value: photo.galleryId.isEmpty ? '--' : photo.galleryId,
              ),
              _PhotoDetailMetaRow(
                label: 'Statut vente',
                value: photo.isForSale ? 'Disponible' : 'Indisponible',
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: photo.isForSale ? () => onAddToCart() : null,
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  label: const Text('Ajouter au panier'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoDetailMetaRow extends StatelessWidget {
  const _PhotoDetailMetaRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 94,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: MasliveTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: emphasize ? 16 : 13.5,
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
                color: MasliveTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogFilterTrigger extends StatelessWidget {
  const _CatalogFilterTrigger({
    required this.countryFieldLabel,
    required this.eventFieldLabel,
    required this.circuitFieldLabel,
    required this.photographerController,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onSelectCountry,
    required this.onSelectEvent,
    required this.onSelectCircuit,
  });

  final String countryFieldLabel;
  final String eventFieldLabel;
  final String circuitFieldLabel;
  final TextEditingController photographerController;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<GlobalKey> onSelectCountry;
  final ValueChanged<GlobalKey> onSelectEvent;
  final ValueChanged<GlobalKey> onSelectCircuit;

  @override
  Widget build(BuildContext context) {
    final summary = <String>[
      if (countryFieldLabel.trim().isNotEmpty &&
          countryFieldLabel != 'SELECTIONNER UN PAYS')
        countryFieldLabel,
      if (eventFieldLabel.trim().isNotEmpty &&
          eventFieldLabel != 'SELECTIONNER UN EVENEMENT')
        eventFieldLabel,
      if (circuitFieldLabel.trim().isNotEmpty &&
          circuitFieldLabel != 'SELECTIONNER UN CIRCUIT')
        circuitFieldLabel,
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
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
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
                      if (summary.isNotEmpty) ...<Widget>[
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
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                children: <Widget>[
                  _CatalogReadOnlyField(
                    label: 'PAYS',
                    value: countryFieldLabel,
                    hintText: 'Selectionner un pays',
                    onTap: onSelectCountry,
                  ),
                  const SizedBox(height: 10),
                  _CatalogReadOnlyField(
                    label: 'EVENEMENT',
                    value: eventFieldLabel,
                    hintText: 'Selectionner un evenement',
                    onTap: onSelectEvent,
                  ),
                  const SizedBox(height: 10),
                  _CatalogReadOnlyField(
                    label: 'CIRCUIT',
                    value: circuitFieldLabel,
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
                ],
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }
}

class _CatalogReadOnlyField extends StatelessWidget {
  const _CatalogReadOnlyField({
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
    final resolvedValue = value?.trim();
    final anchorKey = GlobalKey();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: anchorKey,
        onTap: () => onTap(anchorKey),
        borderRadius: BorderRadius.circular(14),
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
            children: <Widget>[
              Expanded(
                child: RichText(
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(
                      color: MasliveTheme.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                    children: <InlineSpan>[
                      TextSpan(
                        text: '$label  ',
                        style: const TextStyle(
                          color: MasliveTheme.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                      TextSpan(
                        text: resolvedValue != null && resolvedValue.isNotEmpty
                            ? resolvedValue.toUpperCase()
                            : hintText.toUpperCase(),
                        style: TextStyle(
                          color: resolvedValue != null && resolvedValue.isNotEmpty
                              ? MasliveTheme.textPrimary
                              : MasliveTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: MasliveTheme.textSecondary,
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

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: selected
              ? Border.all(
                  color: MasliveTheme.textPrimary.withValues(alpha: 0.22),
                  width: 1,
                )
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: MasliveTheme.textPrimary,
            letterSpacing: 0.1,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _HeroGalleryCard extends StatelessWidget {
  const _HeroGalleryCard({
    required this.title,
    required this.imageUrl,
    required this.onTap,
  });

  final String title;
  final String? imageUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: 240,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: MasliveTheme.surface,
          boxShadow: MasliveTheme.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (imageUrl?.trim().isNotEmpty == true)
              Image.network(imageUrl!.trim(), fit: BoxFit.cover)
            else
              Image.asset('assets/images/maslivesmall.png', fit: BoxFit.cover),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: <Color>[
                    MasliveTheme.textPrimary.withValues(alpha: 0.50),
                    MasliveTheme.textPrimary.withValues(alpha: 0.14),
                    MasliveTheme.textPrimary.withValues(alpha: 0.10),
                  ],
                  stops: const <double>[0.0, 0.38, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 18,
              bottom: 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.6,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
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
    );
  }
}

class _PhotosMosaic extends StatelessWidget {
  const _PhotosMosaic({
    required this.photos,
    required this.packs,
    required this.cart,
    required this.onAddPhoto,
    required this.onAddPack,
  });

  final List<MediaPhotoModel> photos;
  final List<MediaPackModel> packs;
  final CartProvider cart;
  final ValueChanged<MediaPhotoModel> onAddPhoto;
  final ValueChanged<MediaPackModel> onAddPack;

  @override
  Widget build(BuildContext context) {
    final List<_MosaicItem> items = <_MosaicItem>[];

    for (final photo in photos) {
      if (items.length >= 7) break;
      items.add(
        _MosaicItem(
          imageUrl: photo.thumbnailPath,
          showHeart: true,
          filledHeart: cart.mediaItems.any((i) => i.productId == photo.photoId),
          heartSmall: items.length == 6,
          onTap: () => onAddPhoto(photo),
        ),
      );
    }

    for (final pack in packs) {
      if (items.length >= 7) break;
      final String? url = pack.coverUrl?.trim().isNotEmpty == true
          ? pack.coverUrl!.trim()
          : null;
      items.add(
        _MosaicItem(
          imageUrl: url,
          showHeart: false,
          filledHeart: false,
          heartSmall: items.length == 6,
          onTap: () => onAddPack(pack),
        ),
      );
    }

    if (items.isEmpty) {
      return MediaMarketplaceMessageCard.empty(
        title: 'Aucun média',
        message:
            'Cette galerie ne contient pas encore de photos ou packs vendables.',
        icon: Icons.collections_outlined,
      );
    }

    while (items.length < 7) {
      items.add(const _MosaicItem.placeholder());
    }

    return SizedBox(
      height: 434,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              children: <Widget>[
                Expanded(flex: 11, child: _PhotoCard(item: items[0])),
                const SizedBox(height: 10),
                Expanded(flex: 9, child: _PhotoCard(item: items[1])),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 1,
            child: Column(
              children: <Widget>[
                Expanded(flex: 9, child: _PhotoCard(item: items[2])),
                const SizedBox(height: 10),
                Expanded(
                  flex: 8,
                  child: Row(
                    children: <Widget>[
                      Expanded(child: _PhotoCard(item: items[3])),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          children: <Widget>[
                            Expanded(child: _PhotoCard(item: items[4])),
                            const SizedBox(height: 10),
                            Expanded(child: _PhotoCard(item: items[5])),
                            const SizedBox(height: 10),
                            Expanded(child: _PhotoCard(item: items[6])),
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

class _MosaicItem {
  const _MosaicItem({
    required this.imageUrl,
    required this.showHeart,
    required this.filledHeart,
    required this.heartSmall,
    required this.onTap,
  });

  const _MosaicItem.placeholder()
    : imageUrl = null,
      showHeart = false,
      filledHeart = false,
      heartSmall = false,
      onTap = null;

  final String? imageUrl;
  final bool showHeart;
  final bool filledHeart;
  final bool heartSmall;
  final VoidCallback? onTap;
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.item});

  final _MosaicItem item;

  @override
  Widget build(BuildContext context) {
    final double heartBoxSize = item.heartSmall ? 22 : 34;
    final double heartIconSize = item.heartSmall ? 14 : 20;

    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: MasliveTheme.surface,
          boxShadow: MasliveTheme.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (item.imageUrl?.trim().isNotEmpty == true)
              Image.network(item.imageUrl!.trim(), fit: BoxFit.cover)
            else
              Container(
                color: MasliveTheme.surface,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.image_outlined,
                  size: 34,
                  color: MasliveTheme.textSecondary,
                ),
              ),
            if (item.showHeart)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: heartBoxSize,
                  height: heartBoxSize,
                  decoration: BoxDecoration(
                    color: item.filledHeart
                        ? MasliveTheme.pink
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    item.filledHeart ? Icons.favorite : Icons.favorite_border,
                    size: heartIconSize,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
