import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/honeycomb_background.dart';
import '../widgets/rainbow_header.dart';

/// =============================================================
///  STRUCTURE MEDIA GALLERIES (sélection + checkmark + panier)
///  - FilterBarSticky (filtres cascadés)
///  - GridSelectable (galeries avec checkmarks)
///  - BottomSelectionBar (barre de sélection)
///  - CartProvider (ChangeNotifier)
/// =============================================================

/// -------------------------
/// MODELS
/// -------------------------
@immutable
class PhotoGallery {
  final String id;
  final String title;
  final String subtitle;
  final String? coverUrl;
  final List<String> images;
  final int photoCount;
  
  // Métadonnées de filtrage
  final String country;
  final DateTime date;
  final String eventName;
  final String groupName;
  final String photographerName;
  final double pricePerPhoto;

  const PhotoGallery({
    required this.id,
    required this.title,
    required this.subtitle,
    this.coverUrl,
    required this.images,
    required this.photoCount,
    required this.country,
    required this.date,
    required this.eventName,
    required this.groupName,
    required this.photographerName,
    this.pricePerPhoto = 8.0,
  });

  factory PhotoGallery.fromFirestore(String id, Map<String, dynamic> data) {
    final imagesRaw = data['images'];
    final images = imagesRaw is List 
        ? imagesRaw.whereType<String>().toList() 
        : <String>[];
    
    final photoCount = (data['photoCount'] is int) 
        ? data['photoCount'] as int 
        : images.length;

    return PhotoGallery(
      id: id,
      title: (data['title'] as String?)?.trim().isNotEmpty == true 
          ? data['title'] as String 
          : 'Sans titre',
      subtitle: (data['subtitle'] as String?) ?? '',
      coverUrl: (data['coverUrl'] as String?) ?? 
          (images.isNotEmpty ? images.first : null),
      images: images,
      photoCount: photoCount,
      country: (data['country'] as String?) ?? 'France',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      eventName: (data['eventName'] as String?) ?? 'Événement',
      groupName: (data['groupName'] as String?) ?? 'Groupe',
      photographerName: (data['photographerName'] as String?) ?? 'Photographe',
      pricePerPhoto: (data['pricePerPhoto'] as num?)?.toDouble() ?? 8.0,
    );
  }

  double get totalPrice => photoCount * pricePerPhoto;
}

@immutable
class FilterState {
  final String? country;
  final DateTimeRange? dateRange;
  final String? eventName;
  final String? groupName;
  final String? photographerName;
  final SortMode sort;

  const FilterState({
    this.country,
    this.dateRange,
    this.eventName,
    this.groupName,
    this.photographerName,
    this.sort = SortMode.recent,
  });

  FilterState copyWith({
    String? country,
    DateTimeRange? dateRange,
    String? eventName,
    String? groupName,
    String? photographerName,
    SortMode? sort,
    bool clearCountry = false,
    bool clearDateRange = false,
    bool clearEventName = false,
    bool clearGroupName = false,
    bool clearPhotographerName = false,
  }) {
    return FilterState(
      country: clearCountry ? null : (country ?? this.country),
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
      eventName: clearEventName ? null : (eventName ?? this.eventName),
      groupName: clearGroupName ? null : (groupName ?? this.groupName),
      photographerName: clearPhotographerName 
          ? null 
          : (photographerName ?? this.photographerName),
      sort: sort ?? this.sort,
    );
  }

  bool get isEmpty =>
      country == null &&
      dateRange == null &&
      eventName == null &&
      groupName == null &&
      photographerName == null &&
      sort == SortMode.recent;
}

enum SortMode { recent, photoCount, priceAsc, priceDesc }

/// -------------------------
/// CART PROVIDER (ChangeNotifier)
/// -------------------------
class GalleryCartProvider extends ChangeNotifier {
  final Map<String, PhotoGallery> _selected = {}; // sélection (checkmarks)
  final Map<String, PhotoGallery> _cart = {}; // panier

  Map<String, PhotoGallery> get selected => _selected;
  Map<String, PhotoGallery> get cart => _cart;

  int get selectedCount => _selected.length;
  double get selectedTotal =>
      _selected.values.fold(0.0, (sum, g) => sum + g.totalPrice);

  int get cartCount => _cart.length;
  double get cartTotal => 
      _cart.values.fold(0.0, (sum, g) => sum + g.totalPrice);

  bool isSelected(String id) => _selected.containsKey(id);
  bool isInCart(String id) => _cart.containsKey(id);

  void toggleSelected(PhotoGallery gallery) {
    if (_selected.containsKey(gallery.id)) {
      _selected.remove(gallery.id);
    } else {
      _selected[gallery.id] = gallery;
    }
    notifyListeners();
  }

  void clearSelected() {
    _selected.clear();
    notifyListeners();
  }

  void addSelectedToCart() {
    for (final entry in _selected.entries) {
      _cart[entry.key] = entry.value;
    }
    _selected.clear();
    notifyListeners();
  }

  void removeFromCart(String id) {
    _cart.remove(id);
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }
}

/// -------------------------
/// SIMPLE INHERITED SCOPE (sans packages)
/// -------------------------
class GalleryCartScope extends InheritedNotifier<GalleryCartProvider> {
  const GalleryCartScope({
    super.key,
    required GalleryCartProvider super.notifier,
    required super.child,
  });

  static GalleryCartProvider of(BuildContext context) {
    final scope = 
        context.dependOnInheritedWidgetOfExactType<GalleryCartScope>();
    assert(scope != null, 'GalleryCartScope not found in widget tree');
    return scope!.notifier!;
  }
}

/// -------------------------
/// PAGE
/// -------------------------
class MediaGalleriesPage extends StatefulWidget {
  const MediaGalleriesPage({super.key, required this.groupId});

  final String groupId;

  @override
  State<MediaGalleriesPage> createState() => _MediaGalleriesPageState();
}

class _MediaGalleriesPageState extends State<MediaGalleriesPage> {
  FilterState _filters = const FilterState();
  final ScrollController _scroll = ScrollController();
  
  List<PhotoGallery> _allGalleries = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadGalleries();
  }

  Future<void> _loadGalleries() async {
    setState(() => _isLoading = true);
    
    try {
      final snapshot = await _queryForGroup(widget.groupId).get();
      final galleries = snapshot.docs.map((doc) {
        return PhotoGallery.fromFirestore(doc.id, doc.data());
      }).toList();
      
      setState(() {
        _allGalleries = galleries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Query<Map<String, dynamic>> _queryForGroup(String groupId) {
    Query<Map<String, dynamic>> q = 
        FirebaseFirestore.instance.collection('media_galleries');
    final trimmed = groupId.trim();
    if (trimmed.isNotEmpty && trimmed != 'all') {
      q = q.where('groupId', isEqualTo: trimmed);
    }
    return q.orderBy('createdAt', descending: true);
  }

  List<PhotoGallery> get _filtered {
    Iterable<PhotoGallery> items = _allGalleries;

    if (_filters.country != null) {
      items = items.where((g) => g.country == _filters.country);
    }
    if (_filters.dateRange != null) {
      final r = _filters.dateRange!;
      items = items.where((g) =>
          !g.date.isBefore(r.start) && !g.date.isAfter(r.end));
    }
    if (_filters.eventName != null) {
      items = items.where((g) => g.eventName == _filters.eventName);
    }
    if (_filters.groupName != null) {
      items = items.where((g) => g.groupName == _filters.groupName);
    }
    if (_filters.photographerName != null) {
      items = items.where((g) => 
          g.photographerName == _filters.photographerName);
    }

    final list = items.toList();

    switch (_filters.sort) {
      case SortMode.recent:
        list.sort((a, b) => b.date.compareTo(a.date));
        break;
      case SortMode.photoCount:
        list.sort((a, b) => b.photoCount.compareTo(a.photoCount));
        break;
      case SortMode.priceAsc:
        list.sort((a, b) => a.totalPrice.compareTo(b.totalPrice));
        break;
      case SortMode.priceDesc:
        list.sort((a, b) => b.totalPrice.compareTo(a.totalPrice));
        break;
    }
    return list;
  }

  // Options dépendantes (cascading filters)
  List<String> get _countries =>
      _allGalleries.map((e) => e.country).toSet().toList()..sort();

  List<String> get _events {
    Iterable<PhotoGallery> items = _allGalleries;
    if (_filters.country != null) {
      items = items.where((g) => g.country == _filters.country);
    }
    if (_filters.dateRange != null) {
      final r = _filters.dateRange!;
      items = items.where((g) => 
          !g.date.isBefore(r.start) && !g.date.isAfter(r.end));
    }
    return items.map((e) => e.eventName).toSet().toList()..sort();
  }

  List<String> get _groups {
    Iterable<PhotoGallery> items = _allGalleries;
    if (_filters.country != null) {
      items = items.where((g) => g.country == _filters.country);
    }
    if (_filters.dateRange != null) {
      final r = _filters.dateRange!;
      items = items.where((g) => 
          !g.date.isBefore(r.start) && !g.date.isAfter(r.end));
    }
    if (_filters.eventName != null) {
      items = items.where((g) => g.eventName == _filters.eventName);
    }
    return items.map((e) => e.groupName).toSet().toList()..sort();
  }

  List<String> get _photographers {
    Iterable<PhotoGallery> items = _allGalleries;
    if (_filters.country != null) {
      items = items.where((g) => g.country == _filters.country);
    }
    if (_filters.dateRange != null) {
      final r = _filters.dateRange!;
      items = items.where((g) => 
          !g.date.isBefore(r.start) && !g.date.isAfter(r.end));
    }
    if (_filters.eventName != null) {
      items = items.where((g) => g.eventName == _filters.eventName);
    }
    if (_filters.groupName != null) {
      items = items.where((g) => g.groupName == _filters.groupName);
    }
    return items.map((e) => e.photographerName).toSet().toList()..sort();
  }

  void _resetFilters() => setState(() => _filters = const FilterState());

  @override
  Widget build(BuildContext context) {
    final cart = GalleryCartScope.of(context);
    final results = _filtered;

    return Scaffold(
      body: HoneycombBackground(
        child: Stack(
          children: [
            CustomScrollView(
              controller: _scroll,
              slivers: [
                SliverToBoxAdapter(
                  child: RainbowHeader(
                    title: 'Médias',
                    trailing: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          tooltip: 'Panier',
                          onPressed: () => _openCartSheet(context),
                          icon: const Icon(Icons.shopping_bag_outlined, 
                              color: Colors.white),
                        ),
                        if (cart.cartCount > 0)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: _Badge(text: '${cart.cartCount}'),
                          ),
                      ],
                    ),
                  ),
                ),
                
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyHeaderDelegate(
                    minHeight: 220,
                    maxHeight: 220,
                    child: FilterBarSticky(
                      filters: _filters,
                      countries: _countries,
                      events: _events,
                      groups: _groups,
                      photographers: _photographers,
                      onChanged: (next) => setState(() => _filters = next),
                      onReset: _resetFilters,
                    ),
                  ),
                ),
                
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
                  sliver: _isLoading
                      ? const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : results.isEmpty
                          ? SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.photo_library_outlined,
                                        size: 64,
                                        color: Colors.black.withOpacity(0.3)),
                                    const SizedBox(height: 16),
                                    Text('Aucune galerie trouvée',
                                        style: TextStyle(
                                            color: Colors.black.withOpacity(0.6),
                                            fontSize: 16)),
                                  ],
                                ),
                              ),
                            )
                          : SliverGrid(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final gallery = results[index];
                                  return SelectableGalleryCard(
                                    gallery: gallery,
                                    onOpen: () => _openPreview(context, gallery),
                                  );
                                },
                                childCount: results.length,
                              ),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.78,
                              ),
                            ),
                ),
              ],
            ),

            // BottomSelectionBar (apparaît quand checkmarks > 0)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: BottomSelectionBar(),
            ),
          ],
        ),
      ),
    );
  }

  void _openPreview(BuildContext context, PhotoGallery gallery) {
    final cart = GalleryCartScope.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            final selected = cart.isSelected(gallery.id);
            final inCart = cart.isInCart(gallery.id);

            void sync() => setLocal(() {});
            cart.addListener(sync);

            return WillPopScope(
              onWillPop: () async {
                cart.removeListener(sync);
                return true;
              },
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 16,
                  right: 16,
                  top: 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: _Img(gallery.coverUrl ?? ''),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(gallery.title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text('${gallery.groupName} • ${gallery.photographerName}',
                        style: TextStyle(color: Colors.black.withOpacity(0.7))),
                    const SizedBox(height: 6),
                    Text(
                        '${gallery.photoCount} photos • ${gallery.totalPrice.toStringAsFixed(2)}€',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              cart.toggleSelected(gallery);
                              setLocal(() {});
                            },
                            icon: Icon(selected
                                ? Icons.check_circle
                                : Icons.circle_outlined),
                            label: Text(
                                selected ? 'Sélectionnée' : 'Sélectionner'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: inCart
                                ? null
                                : () {
                                    cart.selected[gallery.id] = gallery;
                                    cart.addSelectedToCart();
                                    setLocal(() {});
                                  },
                            icon: const Icon(Icons.shopping_cart_checkout),
                            label: Text(inCart
                                ? 'Déjà au panier'
                                : 'Ajouter au panier'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openCartSheet(BuildContext context) {
    final cart = GalleryCartScope.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return AnimatedBuilder(
          animation: cart,
          builder: (context, _) {
            final items = cart.cart.values.toList();
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text('Panier',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      const Spacer(),
                      Text('${cart.cartTotal.toStringAsFixed(2)}€',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text('Ton panier est vide.',
                          style: TextStyle(
                              color: Colors.black.withOpacity(0.65))),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: items.length,
                        separatorBuilder: (context, index) => const Divider(height: 16),
                        itemBuilder: (context, i) {
                          final gallery = items[i];
                          return Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: 64,
                                  height: 64,
                                  child: _Img(gallery.coverUrl ?? ''),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(gallery.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text('${gallery.photoCount} photos',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: Colors.black
                                                .withOpacity(0.7))),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('${gallery.totalPrice.toStringAsFixed(2)}€',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              IconButton(
                                tooltip: 'Retirer',
                                onPressed: () =>
                                    cart.removeFromCart(gallery.id),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: cart.cart.isEmpty ? null : cart.clearCart,
                          child: const Text('Vider'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: cart.cart.isEmpty
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Checkout à brancher (Stripe, etc.)')),
                                  );
                                },
                          child: const Text('Payer'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// -------------------------
/// FILTER BAR (sticky)
/// -------------------------
class FilterBarSticky extends StatelessWidget {
  const FilterBarSticky({
    super.key,
    required this.filters,
    required this.countries,
    required this.events,
    required this.groups,
    required this.photographers,
    required this.onChanged,
    required this.onReset,
  });

  final FilterState filters;
  final List<String> countries;
  final List<String> events;
  final List<String> groups;
  final List<String> photographers;
  final ValueChanged<FilterState> onChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          children: [
            Row(
              children: [
                const Text('Filtres',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const Spacer(),
                if (!filters.isEmpty)
                  TextButton.icon(
                    onPressed: onReset,
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Réinitialiser'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _Drop(
                    label: 'Pays',
                    value: filters.country,
                    items: countries,
                    onChanged: (v) {
                      onChanged(filters.copyWith(
                        country: v,
                        clearEventName: true,
                        clearGroupName: true,
                        clearPhotographerName: true,
                      ));
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateRangeChip(
                    label: 'Date',
                    range: filters.dateRange,
                    onPick: (r) {
                      onChanged(filters.copyWith(
                        dateRange: r,
                        clearEventName: true,
                        clearGroupName: true,
                        clearPhotographerName: true,
                      ));
                    },
                    onClear: () {
                      onChanged(filters.copyWith(
                        clearDateRange: true,
                        clearEventName: true,
                        clearGroupName: true,
                        clearPhotographerName: true,
                      ));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _Drop(
                    label: 'Événement',
                    value: filters.eventName,
                    items: events,
                    onChanged: (v) {
                      onChanged(filters.copyWith(
                        eventName: v,
                        clearGroupName: true,
                        clearPhotographerName: true,
                      ));
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Drop(
                    label: 'Groupe',
                    value: filters.groupName,
                    items: groups,
                    onChanged: (v) {
                      onChanged(filters.copyWith(
                        groupName: v,
                        clearPhotographerName: true,
                      ));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _Drop(
                    label: 'Photographe',
                    value: filters.photographerName,
                    items: photographers,
                    onChanged: (v) =>
                        onChanged(filters.copyWith(photographerName: v)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SortDrop(
                    value: filters.sort,
                    onChanged: (m) => onChanged(filters.copyWith(sort: m)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// -------------------------
/// GRID + CARD SELECTABLE
/// -------------------------
class SelectableGalleryCard extends StatelessWidget {
  const SelectableGalleryCard({
    super.key,
    required this.gallery,
    required this.onOpen,
  });

  final PhotoGallery gallery;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final cart = GalleryCartScope.of(context);

    return AnimatedBuilder(
      animation: cart,
      builder: (context, _) {
        final selected = cart.isSelected(gallery.id);
        final inCart = cart.isInCart(gallery.id);

        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onOpen,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.black.withOpacity(0.08)),
              color: Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(18)),
                          child: _Img(gallery.coverUrl ?? ''),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: GestureDetector(
                          onTap: () => cart.toggleSelected(gallery),
                          child: _CheckBadge(isOn: selected),
                        ),
                      ),
                      if (inCart)
                        const Positioned(
                          left: 10,
                          top: 10,
                          child: _Pill(text: 'Au panier'),
                        ),
                      Positioned(
                        left: 10,
                        bottom: 10,
                        child: _Pill(text: '${gallery.photoCount} photos'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gallery.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${gallery.groupName} • ${gallery.photographerName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.black.withOpacity(0.7), fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '${gallery.totalPrice.toStringAsFixed(2)}€',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Ajouter au panier',
                            onPressed: inCart
                                ? null
                                : () {
                                    cart.selected[gallery.id] = gallery;
                                    cart.addSelectedToCart();
                                  },
                            icon: const Icon(Icons.add_shopping_cart, size: 20),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// -------------------------
/// BOTTOM SELECTION BAR
/// -------------------------
class BottomSelectionBar extends StatelessWidget {
  const BottomSelectionBar({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = GalleryCartScope.of(context);

    return AnimatedBuilder(
      animation: cart,
      builder: (context, _) {
        if (cart.selectedCount == 0) return const SizedBox.shrink();

        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                  top: BorderSide(color: Colors.black.withOpacity(0.08))),
              boxShadow: [
                BoxShadow(
                  blurRadius: 18,
                  offset: const Offset(0, -6),
                  color: Colors.black.withOpacity(0.06),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${cart.selectedCount} sélectionnée(s)\nTotal: ${cart.selectedTotal.toStringAsFixed(2)}€',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: cart.clearSelected,
                  child: const Text('Tout décocher'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: cart.addSelectedToCart,
                  icon: const Icon(Icons.shopping_cart_checkout, size: 18),
                  label: const Text('Ajouter'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// -------------------------
/// UI HELPERS
/// -------------------------
class _Img extends StatelessWidget {
  const _Img(this.url);

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Icon(Icons.photo_library, size: 48, color: Colors.grey),
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (c, w, p) => p == null
          ? w
          : Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: p.expectedTotalBytes == null
                      ? null
                      : p.cumulativeBytesLoaded / p.expectedTotalBytes!,
                ),
              ),
            ),
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.black.withOpacity(0.06),
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported_outlined),
      ),
    );
  }
}

class _CheckBadge extends StatelessWidget {
  const _CheckBadge({required this.isOn});
  final bool isOn;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: isOn ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.10)),
      ),
      alignment: Alignment.center,
      child: Icon(
        isOn ? Icons.check : Icons.circle_outlined,
        size: 18,
        color: isOn ? Colors.white : Colors.black,
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.10)),
      ),
      child: Text(text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.pink,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

class _Drop extends StatelessWidget {
  const _Drop({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          hint: const Text('Tout'),
          items: [
            const DropdownMenuItem<String>(value: null, child: Text('Tout')),
            ...items.map((e) => DropdownMenuItem(value: e, child: Text(e))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _SortDrop extends StatelessWidget {
  const _SortDrop({required this.value, required this.onChanged});

  final SortMode value;
  final ValueChanged<SortMode> onChanged;

  @override
  Widget build(BuildContext context) {
    String label(SortMode m) {
      switch (m) {
        case SortMode.recent:
          return 'Plus récentes';
        case SortMode.photoCount:
          return 'Nb photos';
        case SortMode.priceAsc:
          return 'Prix ↑';
        case SortMode.priceDesc:
          return 'Prix ↓';
      }
    }

    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Trier',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<SortMode>(
          isExpanded: true,
          value: value,
          items: SortMode.values
              .map((e) => DropdownMenuItem(value: e, child: Text(label(e))))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _DateRangeChip extends StatelessWidget {
  const _DateRangeChip({
    required this.label,
    required this.range,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final DateTimeRange? range;
  final ValueChanged<DateTimeRange> onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final text = range == null
        ? 'Toutes'
        : '${_fmt(range!.start)} → ${_fmt(range!.end)}';

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(now.year - 2),
          lastDate: DateTime(now.year + 2),
          initialDateRange: range ??
              DateTimeRange(
                  start: now.subtract(const Duration(days: 7)), end: now),
        );
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          suffixIcon: range == null
              ? const Icon(Icons.date_range, size: 18)
              : IconButton(
                  tooltip: 'Effacer',
                  onPressed: onClear,
                  icon: const Icon(Icons.close, size: 18),
                ),
        ),
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  String _fmt(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }
}

/// -------------------------
/// STICKY HEADER DELEGATE
/// -------------------------
class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  _StickyHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  final double minHeight;
  final double maxHeight;
  final Widget child;

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) {
    return minHeight != oldDelegate.minHeight ||
        maxHeight != oldDelegate.maxHeight ||
        child != oldDelegate.child;
  }
}
