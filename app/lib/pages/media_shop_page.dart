// PHOTO SHOP V2 — Firebase 100%
// Intégré à MASLIVE avec thème et i18n

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../ui/theme/maslive_theme.dart';
import '../ui/widgets/honeycomb_background.dart';
import '../widgets/rainbow_header.dart';
import '../l10n/app_localizations.dart';

/// ------------------------------------------------------------
/// MODELS
/// ------------------------------------------------------------
@immutable
class PhotoDoc {
  final String id;
  final String country;
  final DateTime eventDate;
  final String eventName;
  final String groupName;
  final String photographerName;
  final String? photographerId;
  final int priceCents;
  final String thumbPath;
  final String fullPath;
  final int popularity;

  const PhotoDoc({
    required this.id,
    required this.country,
    required this.eventDate,
    required this.eventName,
    required this.groupName,
    required this.photographerName,
    required this.photographerId,
    required this.priceCents,
    required this.thumbPath,
    required this.fullPath,
    required this.popularity,
  });

  double get price => priceCents / 100.0;

  static PhotoDoc fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    DateTime _ts(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    int _i(dynamic v, [int def = 0]) => (v is int) ? v : def;
    String _s(dynamic v, [String def = '']) => (v is String) ? v : def;

    return PhotoDoc(
      id: d.id,
      country: _s(m['country']),
      eventDate: _ts(m['eventDate']),
      eventName: _s(m['eventName']),
      groupName: _s(m['groupName']),
      photographerName: _s(m['photographerName']),
      photographerId: m['photographerId'] is String ? m['photographerId'] as String : null,
      priceCents: _i(m['priceCents'], 0),
      thumbPath: _s(m['thumbPath']),
      fullPath: _s(m['fullPath']),
      popularity: _i(m['popularity'], 0),
    );
  }
}

@immutable
class FilterState {
  final String? country;
  final DateTimeRange? dateRange;
  final String? eventName;
  final String? groupName;
  final String? photographerName;
  final SortMode sort;
  final bool hidePurchased;

  const FilterState({
    this.country,
    this.dateRange,
    this.eventName,
    this.groupName,
    this.photographerName,
    this.sort = SortMode.recent,
    this.hidePurchased = false,
  });

  FilterState copyWith({
    String? country,
    DateTimeRange? dateRange,
    String? eventName,
    String? groupName,
    String? photographerName,
    SortMode? sort,
    bool? hidePurchased,
    bool clearCountry = false,
    bool clearDate = false,
    bool clearEvent = false,
    bool clearGroup = false,
    bool clearPhotographer = false,
  }) {
    return FilterState(
      country: clearCountry ? null : (country ?? this.country),
      dateRange: clearDate ? null : (dateRange ?? this.dateRange),
      eventName: clearEvent ? null : (eventName ?? this.eventName),
      groupName: clearGroup ? null : (groupName ?? this.groupName),
      photographerName: clearPhotographer ? null : (photographerName ?? this.photographerName),
      sort: sort ?? this.sort,
      hidePurchased: hidePurchased ?? this.hidePurchased,
    );
  }

  bool get isEmpty =>
      country == null &&
      dateRange == null &&
      eventName == null &&
      groupName == null &&
      photographerName == null &&
      sort == SortMode.recent &&
      hidePurchased == false;
}

enum SortMode { recent, popular, priceAsc, priceDesc }

/// ------------------------------------------------------------
/// CART PROVIDER
/// ------------------------------------------------------------
class CartProvider extends ChangeNotifier {
  final Map<String, PhotoDoc> _selected = {};
  final Map<String, PhotoDoc> _cart = {};

  Map<String, PhotoDoc> get selected => _selected;
  Map<String, PhotoDoc> get cart => _cart;

  int get selectedCount => _selected.length;
  int get cartCount => _cart.length;

  int get selectedTotalCents => _selected.values.fold(0, (sum, p) => sum + p.priceCents);
  int get cartTotalCents => _cart.values.fold(0, (sum, p) => sum + p.priceCents);

  double get selectedTotal => selectedTotalCents / 100.0;
  double get cartTotal => cartTotalCents / 100.0;

  bool isSelected(String id) => _selected.containsKey(id);
  bool isInCart(String id) => _cart.containsKey(id);

  void toggleSelected(PhotoDoc item) {
    if (_selected.containsKey(item.id)) {
      _selected.remove(item.id);
    } else {
      _selected[item.id] = item;
    }
    notifyListeners();
  }

  void clearSelected() {
    _selected.clear();
    notifyListeners();
  }

  void addSelectedToCart() {
    for (final e in _selected.entries) {
      _cart[e.key] = e.value;
    }
    _selected.clear();
    notifyListeners();
  }

  void addToCart(PhotoDoc item) {
    _cart[item.id] = item;
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

  Future<String?> createPendingOrder() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    if (_cart.isEmpty) return null;

    final uid = user.uid;
    final now = FieldValue.serverTimestamp();
    final orderRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('orders')
        .doc();

    final items = _cart.values.map((p) {
      return {
        'photoId': p.id,
        'priceCents': p.priceCents,
        'eventName': p.eventName,
        'groupName': p.groupName,
        'photographerName': p.photographerName,
        'photographerId': p.photographerId,
        'thumbPath': p.thumbPath,
        'fullPath': p.fullPath,
        'eventDate': Timestamp.fromDate(p.eventDate),
        'country': p.country,
      };
    }).toList();

    await orderRef.set({
      'status': 'pending',
      'createdAt': now,
      'totalCents': cartTotalCents,
      'items': items,
    });

    return orderRef.id;
  }
}

/// ------------------------------------------------------------
/// CART SCOPE
/// ------------------------------------------------------------
class CartScope extends InheritedNotifier<CartProvider> {
  const CartScope({
    super.key,
    required CartProvider notifier,
    required Widget child,
  }) : super(notifier: notifier, child: child);

  static CartProvider of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CartScope>();
    assert(scope != null, 'CartScope not found');
    return scope!.notifier!;
  }
}

/// ------------------------------------------------------------
/// REPOSITORY
/// ------------------------------------------------------------
class PhotoRepository {
  PhotoRepository._();
  static final PhotoRepository I = PhotoRepository._();

  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  final Map<String, String> _urlCache = {};
  final Map<String, Future<String>> _pending = {};

  Future<String> storageUrl(String path) {
    if (path.isEmpty) return Future.value('');
    final cached = _urlCache[path];
    if (cached != null) return Future.value(cached);

    final pending = _pending[path];
    if (pending != null) return pending;

    final fut = _storage.ref(path).getDownloadURL().then((u) {
      _urlCache[path] = u;
      _pending.remove(path);
      return u;
    }).catchError((_) {
      _pending.remove(path);
      return '';
    });

    _pending[path] = fut;
    return fut;
  }

  Query<Map<String, dynamic>> buildQuery(FilterState f) {
    Query<Map<String, dynamic>> q = _db
        .collection('photos')
        .where('isActive', isEqualTo: true)
        .where('moderationStatus', isEqualTo: 'approved');

    if (f.country != null) {
      q = q.where('country', isEqualTo: f.country);
    }

    if (f.eventName != null) q = q.where('eventName', isEqualTo: f.eventName);
    if (f.groupName != null) q = q.where('groupName', isEqualTo: f.groupName);
    if (f.photographerName != null) q = q.where('photographerName', isEqualTo: f.photographerName);

    if (f.dateRange != null) {
      final start = DateTime(f.dateRange!.start.year, f.dateRange!.start.month, f.dateRange!.start.day);
      final end = DateTime(
        f.dateRange!.end.year,
        f.dateRange!.end.month,
        f.dateRange!.end.day,
        23,
        59,
        59,
        999,
      );
      q = q.where('eventDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start));
      q = q.where('eventDate', isLessThanOrEqualTo: Timestamp.fromDate(end));
    }

    if (f.dateRange != null) {
      q = q.orderBy('eventDate', descending: f.sort == SortMode.recent || f.sort == SortMode.popular);
      if (f.sort == SortMode.priceAsc) q = q.orderBy('priceCents', descending: false);
      if (f.sort == SortMode.priceDesc) q = q.orderBy('priceCents', descending: true);
      if (f.sort == SortMode.popular) q = q.orderBy('popularity', descending: true);
    } else {
      switch (f.sort) {
        case SortMode.recent:
          q = q.orderBy('eventDate', descending: true);
          break;
        case SortMode.popular:
          q = q.orderBy('popularity', descending: true).orderBy('eventDate', descending: true);
          break;
        case SortMode.priceAsc:
          q = q.orderBy('priceCents', descending: false).orderBy('eventDate', descending: true);
          break;
        case SortMode.priceDesc:
          q = q.orderBy('priceCents', descending: true).orderBy('eventDate', descending: true);
          break;
      }
    }

    return q;
  }

  Future<FacetData> loadFacets(FilterState f) async {
    final base = _db
        .collection('photos')
        .where('isActive', isEqualTo: true)
        .where('moderationStatus', isEqualTo: 'approved')
        .orderBy('eventDate', descending: true)
        .limit(250);

    final snap = await base.get();
    final countries = <String>{};
    for (final d in snap.docs) {
      final c = d.data()['country'];
      if (c is String && c.trim().isNotEmpty) countries.add(c.trim());
    }

    Query<Map<String, dynamic>> qEvents = _db
        .collection('photos')
        .where('isActive', isEqualTo: true)
        .where('moderationStatus', isEqualTo: 'approved');

    if (f.country != null) qEvents = qEvents.where('country', isEqualTo: f.country);
    if (f.dateRange != null) {
      final start = DateTime(f.dateRange!.start.year, f.dateRange!.start.month, f.dateRange!.start.day);
      final end = DateTime(f.dateRange!.end.year, f.dateRange!.end.month, f.dateRange!.end.day, 23, 59, 59, 999);
      qEvents = qEvents
          .where('eventDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('eventDate', isLessThanOrEqualTo: Timestamp.fromDate(end));
    }
    qEvents = qEvents.orderBy('eventDate', descending: true).limit(250);
    final eventsSnap = await qEvents.get();
    final events = <String>{};
    for (final d in eventsSnap.docs) {
      final e = d.data()['eventName'];
      if (e is String && e.trim().isNotEmpty) events.add(e.trim());
    }

    Query<Map<String, dynamic>> qGroups = qEvents;
    if (f.eventName != null) qGroups = qGroups.where('eventName', isEqualTo: f.eventName);
    final groupsSnap = await qGroups.limit(250).get();
    final groups = <String>{};
    for (final d in groupsSnap.docs) {
      final g = d.data()['groupName'];
      if (g is String && g.trim().isNotEmpty) groups.add(g.trim());
    }

    Query<Map<String, dynamic>> qPhotogs = qGroups;
    if (f.groupName != null) qPhotogs = qPhotogs.where('groupName', isEqualTo: f.groupName);
    final photogSnap = await qPhotogs.limit(250).get();
    final photographers = <String>{};
    for (final d in photogSnap.docs) {
      final p = d.data()['photographerName'];
      if (p is String && p.trim().isNotEmpty) photographers.add(p.trim());
    }

    return FacetData(
      countries: countries.toList()..sort(),
      events: events.toList()..sort(),
      groups: groups.toList()..sort(),
      photographers: photographers.toList()..sort(),
    );
  }

  Stream<Set<String>> purchasedPhotoIdsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream<Set<String>>.empty();

    final ref = _db.collection('users').doc(user.uid).collection('purchases');
    return ref.snapshots().map((s) => s.docs.map((d) => d.id).toSet());
  }
}

@immutable
class FacetData {
  final List<String> countries;
  final List<String> events;
  final List<String> groups;
  final List<String> photographers;

  const FacetData({
    required this.countries,
    required this.events,
    required this.groups,
    required this.photographers,
  });

  static const empty = FacetData(countries: [], events: [], groups: [], photographers: []);
}

/// ------------------------------------------------------------
/// PAGE PRINCIPALE
/// ------------------------------------------------------------
class MediaShopPage extends StatefulWidget {
  const MediaShopPage({super.key});

  @override
  State<MediaShopPage> createState() => _MediaShopPageState();
}

class _MediaShopPageState extends State<MediaShopPage> {
  final _repo = PhotoRepository.I;

  FilterState _filters = const FilterState();
  FacetData _facets = FacetData.empty;

  Timer? _facetDebounce;

  final ScrollController _scroll = ScrollController();

  static const int _pageSize = 24;
  bool _loadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;

  final List<PhotoDoc> _items = [];
  String? _error;
  bool _initialLoading = true;

  Set<String> _purchased = {};
  StreamSubscription<Set<String>>? _purchasedSub;

  @override
  void initState() {
    super.initState();

    _purchasedSub = _repo.purchasedPhotoIdsStream().listen((set) {
      setState(() => _purchased = set);
    });

    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 600) {
        _loadMore();
      }
    });

    _refreshAll();
  }

  @override
  void dispose() {
    _facetDebounce?.cancel();
    _scroll.dispose();
    _purchasedSub?.cancel();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    setState(() {
      _initialLoading = true;
      _error = null;
      _items.clear();
      _lastDoc = null;
      _hasMore = true;
    });

    await Future.wait([
      _loadFacetsDebounced(immediate: true),
      _loadMore(reset: true),
    ]);

    setState(() => _initialLoading = false);
  }

  Future<void> _loadFacetsDebounced({bool immediate = false}) async {
    _facetDebounce?.cancel();
    if (immediate) {
      final data = await _repo.loadFacets(_filters);
      if (!mounted) return;
      setState(() => _facets = data);
      return;
    }

    _facetDebounce = Timer(const Duration(milliseconds: 250), () async {
      final data = await _repo.loadFacets(_filters);
      if (!mounted) return;
      setState(() => _facets = data);
    });
  }

  Future<void> _loadMore({bool reset = false}) async {
    if (_loadingMore || !_hasMore) return;
    setState(() {
      _loadingMore = true;
      _error = null;
    });

    try {
      var q = _repo.buildQuery(_filters).limit(_pageSize);
      if (!reset && _lastDoc != null) {
        q = q.startAfterDocument(_lastDoc!);
      }

      final snap = await q.get();
      final docs = snap.docs;

      if (docs.isNotEmpty) _lastDoc = docs.last;

      final newItems = docs.map(PhotoDoc.fromDoc).toList();

      setState(() {
        if (reset) _items.clear();
        _items.addAll(newItems);
        _hasMore = newItems.length == _pageSize;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _setFilters(FilterState next) {
    setState(() => _filters = next);
    _loadFacetsDebounced();
    _loadMore(reset: true);
  }

  List<PhotoDoc> get _visibleItems {
    if (!_filters.hidePurchased) return _items;
    return _items.where((p) => !_purchased.contains(p.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return CartScope(
      notifier: CartProvider(),
      child: Builder(
        builder: (context) {
          final cart = CartScope.of(context);

          return Scaffold(
            body: HoneycombBackground(
              child: Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: _refreshAll,
                    child: CustomScrollView(
                      controller: _scroll,
                      slivers: [
                        SliverToBoxAdapter(
                          child: RainbowHeader(
                            title: 'Boutique Photos',
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Panier',
                                  onPressed: () => _openCartSheet(context, cart),
                                  icon: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      const Icon(Icons.shopping_bag_outlined, color: Colors.white),
                                      if (cart.cartCount > 0)
                                        Positioned(
                                          right: -4,
                                          top: -4,
                                          child: _Badge(text: '${cart.cartCount}'),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Rafraîchir',
                                  onPressed: _refreshAll,
                                  icon: const Icon(Icons.refresh, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _StickyHeaderDelegate(
                            minHeight: 182,
                            maxHeight: 182,
                            child: FilterBarSticky(
                              filters: _filters,
                              facets: _facets,
                              onChanged: _setFilters,
                              onReset: () => _setFilters(const FilterState()),
                            ),
                          ),
                        ),

                        if (_initialLoading)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_error != null)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Text('Erreur:\n$_error', textAlign: TextAlign.center),
                              ),
                            ),
                          )
                        else if (_visibleItems.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Text(
                                'Aucune photo trouvée.\nEssaie d\'élargir les filtres.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: MasliveTheme.textSecondary),
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
                            sliver: SliverGrid(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final item = _visibleItems[index];
                                  final purchased = _purchased.contains(item.id);
                                  return SelectablePhotoCard(
                                    item: item,
                                    purchased: purchased,
                                    onOpen: () => _openPreview(context, item, purchased: purchased),
                                  );
                                },
                                childCount: _visibleItems.length,
                              ),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.78,
                              ),
                            ),
                          ),

                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 140),
                            child: _loadingMore
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : (!_hasMore
                                    ? Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Text(
                                            'Fin des résultats',
                                            style: TextStyle(color: MasliveTheme.textSecondary),
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink()),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Positioned(left: 0, right: 0, bottom: 0, child: BottomSelectionBar()),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openPreview(BuildContext context, PhotoDoc item, {required bool purchased}) {
    final cart = CartScope.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PhotoPreviewSheet(item: item, purchased: purchased, cart: cart),
    );
  }

  void _openCartSheet(BuildContext context, CartProvider cart) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CartSheet(cart: cart, purchased: _purchased),
    );
  }
}

/// ------------------------------------------------------------
/// FILTER BAR
/// ------------------------------------------------------------
class FilterBarSticky extends StatelessWidget {
  const FilterBarSticky({
    super.key,
    required this.filters,
    required this.facets,
    required this.onChanged,
    required this.onReset,
  });

  final FilterState filters;
  final FacetData facets;
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
                Expanded(
                  child: _Drop(
                    label: 'Pays',
                    value: filters.country,
                    items: facets.countries,
                    onChanged: (v) {
                      onChanged(filters.copyWith(
                        country: v,
                        clearEvent: true,
                        clearGroup: true,
                        clearPhotographer: true,
                      ));
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateRangeField(
                    label: 'Date',
                    range: filters.dateRange,
                    onPick: (r) {
                      onChanged(filters.copyWith(
                        dateRange: r,
                        clearEvent: true,
                        clearGroup: true,
                        clearPhotographer: true,
                      ));
                    },
                    onClear: () {
                      onChanged(filters.copyWith(
                        clearDate: true,
                        clearEvent: true,
                        clearGroup: true,
                        clearPhotographer: true,
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
                    items: facets.events,
                    onChanged: (v) {
                      onChanged(filters.copyWith(
                        eventName: v,
                        clearGroup: true,
                        clearPhotographer: true,
                      ));
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Drop(
                    label: 'Groupe',
                    value: filters.groupName,
                    items: facets.groups,
                    onChanged: (v) {
                      onChanged(filters.copyWith(
                        groupName: v,
                        clearPhotographer: true,
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
                    items: facets.photographers,
                    onChanged: (v) => onChanged(filters.copyWith(photographerName: v)),
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
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onChanged(filters.copyWith(hidePurchased: !filters.hidePurchased)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: MasliveTheme.divider),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            filters.hidePurchased ? Icons.check_box : Icons.check_box_outline_blank,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(child: Text('Masquer les photos déjà achetées')),
                          TextButton(onPressed: onReset, child: const Text('Réinitialiser')),
                        ],
                      ),
                    ),
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

/// ------------------------------------------------------------
/// PHOTO CARD
/// ------------------------------------------------------------
class SelectablePhotoCard extends StatelessWidget {
  const SelectablePhotoCard({
    super.key,
    required this.item,
    required this.purchased,
    required this.onOpen,
  });

  final PhotoDoc item;
  final bool purchased;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final cart = CartScope.of(context);

    return AnimatedBuilder(
      animation: cart,
      builder: (context, _) {
        final selected = cart.isSelected(item.id);
        final inCart = cart.isInCart(item.id);

        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onOpen,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: MasliveTheme.divider),
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
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                          child: _StorageImage(path: item.thumbPath),
                        ),
                      ),

                      Positioned(
                        top: 10,
                        right: 10,
                        child: GestureDetector(
                          onTap: purchased ? null : () => cart.toggleSelected(item),
                          child: _CheckBadge(isOn: selected, disabled: purchased),
                        ),
                      ),

                      if (inCart)
                        const Positioned(left: 10, top: 10, child: _Pill(text: 'Au panier')),

                      if (purchased)
                        const Positioned(left: 10, bottom: 10, child: _Pill(text: 'Achetée')),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.eventName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.groupName} • ${item.photographerName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: MasliveTheme.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            _money(item.priceCents),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: purchased ? 'Déjà achetée' : 'Ajouter au panier',
                            onPressed: (purchased || inCart) ? null : () => cart.addToCart(item),
                            icon: const Icon(Icons.add_shopping_cart),
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

/// ------------------------------------------------------------
/// BOTTOM SELECTION BAR
/// ------------------------------------------------------------
class BottomSelectionBar extends StatelessWidget {
  const BottomSelectionBar({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = CartScope.of(context);

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
              border: Border(top: BorderSide(color: MasliveTheme.divider)),
              boxShadow: MasliveTheme.floatingShadow,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${cart.selectedCount} sélectionnée(s)\nTotal: ${_money(cart.selectedTotalCents)}',
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
                  icon: const Icon(Icons.shopping_cart_checkout),
                  label: const Text('Ajouter au panier'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// ------------------------------------------------------------
/// PREVIEW SHEET
/// ------------------------------------------------------------
class _PhotoPreviewSheet extends StatefulWidget {
  const _PhotoPreviewSheet({
    required this.item,
    required this.purchased,
    required this.cart,
  });

  final PhotoDoc item;
  final bool purchased;
  final CartProvider cart;

  @override
  State<_PhotoPreviewSheet> createState() => _PhotoPreviewSheetState();
}

class _PhotoPreviewSheetState extends State<_PhotoPreviewSheet> {
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final cart = widget.cart;

    final selected = cart.isSelected(item.id);
    final inCart = cart.isInCart(item.id);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: _StorageImage(path: item.fullPath),
            ),
          ),
          const SizedBox(height: 12),
          Text(item.eventName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            '${item.groupName} • ${item.photographerName}',
            style: TextStyle(color: MasliveTheme.textSecondary),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('Prix: ${_money(item.priceCents)}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(_fmtDate(item.eventDate), style: TextStyle(color: MasliveTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.purchased
                      ? null
                      : () {
                          cart.toggleSelected(item);
                          setState(() {});
                        },
                  icon: Icon(selected ? Icons.check_circle : Icons.circle_outlined),
                  label: Text(widget.purchased ? 'Déjà achetée' : (selected ? 'Sélectionnée' : 'Sélectionner')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (widget.purchased || inCart)
                      ? null
                      : () {
                          cart.addToCart(item);
                          setState(() {});
                        },
                  icon: const Icon(Icons.add_shopping_cart),
                  label: Text(widget.purchased ? 'Achetée' : (inCart ? 'Au panier' : 'Ajouter au panier')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ------------------------------------------------------------
/// CART SHEET
/// ------------------------------------------------------------
class _CartSheet extends StatefulWidget {
  const _CartSheet({required this.cart, required this.purchased});
  final CartProvider cart;
  final Set<String> purchased;

  @override
  State<_CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<_CartSheet> {
  bool _creating = false;
  String? _createdOrderId;

  @override
  Widget build(BuildContext context) {
    final cart = widget.cart;

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
                  const Text('Panier', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  Text(_money(cart.cartTotalCents), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 12),

              if (_createdOrderId != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: MasliveTheme.divider),
                  ),
                  child: Text(
                    'Commande créée (pending):\n$_createdOrderId\n\n'
                    'Branche ton paiement (Stripe / etc.) puis, une fois payé, '
                    'écris /users/{uid}/purchases/{photoId} côté backend.',
                  ),
                ),

              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('Ton panier est vide.', style: TextStyle(color: MasliveTheme.textSecondary)),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 16),
                    itemBuilder: (context, i) {
                      final it = items[i];
                      final bought = widget.purchased.contains(it.id);
                      return Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(width: 64, height: 64, child: _StorageImage(path: it.thumbPath)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  it.eventName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${it.photographerName}${bought ? ' • Déjà achetée' : ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: MasliveTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(_money(it.priceCents), style: const TextStyle(fontWeight: FontWeight.w800)),
                          IconButton(
                            tooltip: 'Retirer',
                            onPressed: () => cart.removeFromCart(it.id),
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
                      onPressed: cart.cart.isEmpty
                          ? null
                          : () {
                              cart.clearCart();
                              setState(() => _createdOrderId = null);
                            },
                      child: const Text('Vider'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (cart.cart.isEmpty || _creating)
                          ? null
                          : () async {
                              setState(() => _creating = true);
                              try {
                                final id = await cart.createPendingOrder();
                                setState(() => _createdOrderId = id);
                              } finally {
                                if (mounted) setState(() => _creating = false);
                              }
                            },
                      child: _creating
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Créer commande'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// ------------------------------------------------------------
/// STORAGE IMAGE
/// ------------------------------------------------------------
class _StorageImage extends StatelessWidget {
  const _StorageImage({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    if (path.trim().isEmpty) {
      return Container(
        color: MasliveTheme.surfaceAlt,
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported_outlined),
      );
    }

    return FutureBuilder<String>(
      future: PhotoRepository.I.storageUrl(path),
      builder: (context, snap) {
        final url = snap.data ?? '';
        if (snap.connectionState != ConnectionState.done) {
          return Container(
            color: MasliveTheme.surfaceAlt,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (url.isEmpty) {
          return Container(
            color: MasliveTheme.surfaceAlt,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined),
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
                      value: p.expectedTotalBytes == null ? null : p.cumulativeBytesLoaded / p.expectedTotalBytes!,
                    ),
                  ),
                ),
          errorBuilder: (_, __, ___) => Container(
            color: MasliveTheme.surfaceAlt,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined),
          ),
        );
      },
    );
  }
}

/// ------------------------------------------------------------
/// UI HELPERS
/// ------------------------------------------------------------
class _CheckBadge extends StatelessWidget {
  const _CheckBadge({required this.isOn, this.disabled = false});
  final bool isOn;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final bg = disabled ? MasliveTheme.surfaceAlt : (isOn ? MasliveTheme.textPrimary : Colors.white);
    final fg = disabled ? MasliveTheme.textSecondary : (isOn ? Colors.white : MasliveTheme.textPrimary);

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: MasliveTheme.divider),
      ),
      alignment: Alignment.center,
      child: Icon(
        isOn ? Icons.check : Icons.circle_outlined,
        size: 18,
        color: fg,
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
        border: Border.all(color: MasliveTheme.divider),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
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
        color: MasliveTheme.textPrimary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
      ),
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
    return SizedBox(
      height: 56,
      child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
        child: InputDecorator(
          decoration: InputDecoration(
            isDense: true,
            labelText: label,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: MasliveTheme.pink, width: 2),
            ),
            contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            filled: true,
            fillColor: Colors.white,
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
        case SortMode.popular:
          return 'Populaires';
        case SortMode.priceAsc:
          return 'Prix ↑';
        case SortMode.priceDesc:
          return 'Prix ↓';
      }
    }

    return SizedBox(
      height: 56,
      child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
        child: InputDecorator(
          decoration: InputDecoration(
            isDense: true,
            labelText: 'Trier',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: MasliveTheme.pink, width: 2),
            ),
            contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            filled: true,
            fillColor: Colors.white,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<SortMode>(
              isExpanded: true,
              value: value,
              items: SortMode.values.map((e) => DropdownMenuItem(value: e, child: Text(label(e)))).toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _DateRangeField extends StatelessWidget {
  const _DateRangeField({
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
    final text = range == null ? 'Toutes' : '${_fmt(range!.start)} → ${_fmt(range!.end)}';

    return SizedBox(
      height: 56,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(now.year - 3),
              lastDate: DateTime(now.year + 3),
              initialDateRange: range ?? DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
            );
            if (picked != null) onPick(picked);
          },
          child: InputDecorator(
            decoration: InputDecoration(
              isDense: true,
              labelText: label,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: MasliveTheme.pink, width: 2),
              ),
              contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              filled: true,
              fillColor: Colors.white,
              suffixIcon: range == null
                  ? const Icon(Icons.date_range)
                  : IconButton(
                      tooltip: 'Effacer',
                      onPressed: onClear,
                      icon: const Icon(Icons.close),
                    ),
            ),
            child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }
}

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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) {
    return minHeight != oldDelegate.minHeight || maxHeight != oldDelegate.maxHeight || child != oldDelegate.child;
  }
}

/// ------------------------------------------------------------
/// UTILS
/// ------------------------------------------------------------
String _money(int cents) {
  final v = cents / 100.0;
  final s = v.toStringAsFixed(2).replaceAll('.', ',');
  return '$s€';
}

String _fmtDate(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}
