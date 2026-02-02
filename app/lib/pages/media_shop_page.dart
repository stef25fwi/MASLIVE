// PHOTO SHOP V2.1 — Firebase 100% — "10/10 UX" — Intégré MASLIVE
// -----------------------------------------------------------------------------
// Nouveautés V2.1:
// - Recherche textuelle (événement, groupe, photographe, pays)
// - Packs discount: 3 photos (-10%), 5 photos (-20%), 10 photos (-30%)
// - Long press sur photo pour sélection rapide
// - Precache images visibles pour scroll fluide
// - Checkout Stripe via callable (createCheckoutSessionForOrder)
// - Affichage discount dans panier
// - Normalisation tailles tuiles filtres (56px)
// -----------------------------------------------------------------------------

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../ui/theme/maslive_theme.dart';
import '../ui/widgets/honeycomb_background.dart';
import '../widgets/rainbow_header.dart';

/// -----------------------------------------------------------------------------
/// MODELS
/// -----------------------------------------------------------------------------
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
    DateTime parseTimestamp(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    int parseInt(dynamic v, [int def = 0]) => (v is int) ? v : def;
    String parseString(dynamic v, [String def = '']) => (v is String) ? v : def;

    return PhotoDoc(
      id: d.id,
      country: parseString(m['country']),
      eventDate: parseTimestamp(m['eventDate']),
      eventName: parseString(m['eventName']),
      groupName: parseString(m['groupName']),
      photographerName: parseString(m['photographerName']),
      photographerId: m['photographerId'] is String ? m['photographerId'] as String : null,
      priceCents: parseInt(m['priceCents'], 0),
      thumbPath: parseString(m['thumbPath']),
      fullPath: parseString(m['fullPath']),
      popularity: parseInt(m['popularity'], 0),
    );
  }
}

enum SortMode { recent, popular, priceAsc, priceDesc }

@immutable
class FilterState {
  final String? country;
  final DateTimeRange? dateRange;
  final String? eventName;
  final String? groupName;
  final String? photographerName;
  final SortMode sort;
  final bool hidePurchased;
  final String searchText; // V2.1

  const FilterState({
    this.country,
    this.dateRange,
    this.eventName,
    this.groupName,
    this.photographerName,
    this.sort = SortMode.recent,
    this.hidePurchased = false,
    this.searchText = '',
  });

  FilterState copyWith({
    String? country,
    DateTimeRange? dateRange,
    String? eventName,
    String? groupName,
    String? photographerName,
    SortMode? sort,
    bool? hidePurchased,
    String? searchText,
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
      searchText: searchText ?? this.searchText,
    );
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

/// -----------------------------------------------------------------------------
/// DISCOUNT / PACK RULES (V2.1)
/// -----------------------------------------------------------------------------
@immutable
class DiscountResult {
  final int discountCents;
  final String rule; // PACK_3 / PACK_5 / PACK_10 / ""
  final int percent; // 0/10/20/30

  const DiscountResult({required this.discountCents, required this.rule, required this.percent});
}

DiscountResult computePackDiscount({required int itemCount, required int totalCents}) {
  int percent = 0;
  String rule = '';
  if (itemCount >= 10) {
    percent = 30;
    rule = 'PACK_10';
  } else if (itemCount >= 5) {
    percent = 20;
    rule = 'PACK_5';
  } else if (itemCount >= 3) {
    percent = 10;
    rule = 'PACK_3';
  }
  final discount = (totalCents * percent) ~/ 100;
  return DiscountResult(discountCents: discount, rule: rule, percent: percent);
}

/// -----------------------------------------------------------------------------
/// CART PROVIDER (sélection + panier + orders + stripe callable)
/// -----------------------------------------------------------------------------
class CartProvider extends ChangeNotifier {
  final Map<String, PhotoDoc> _selected = {};
  final Map<String, PhotoDoc> _cart = {};

  Map<String, PhotoDoc> get selected => _selected;
  Map<String, PhotoDoc> get cart => _cart;

  int get selectedCount => _selected.length;
  int get cartCount => _cart.length;

  int get selectedTotalCents => _selected.values.fold(0, (total, p) => total + p.priceCents);
  int get cartTotalCentsBeforeDiscount => _cart.values.fold(0, (total, p) => total + p.priceCents);

  DiscountResult get cartDiscount => computePackDiscount(
        itemCount: cartCount,
        totalCents: cartTotalCentsBeforeDiscount,
      );

  int get cartTotalCents => (cartTotalCentsBeforeDiscount - cartDiscount.discountCents).clamp(0, 1 << 30);

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
    if (user == null || _cart.isEmpty) return null;

    final uid = user.uid;
    final now = FieldValue.serverTimestamp();
    final orderRef = FirebaseFirestore.instance.collection('users').doc(uid).collection('orders').doc();

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

    final discount = cartDiscount;

    await orderRef.set({
      'status': 'pending',
      'createdAt': now,
      'totalCentsBeforeDiscount': cartTotalCentsBeforeDiscount,
      'discountCents': discount.discountCents,
      'discountRule': discount.rule,
      'discountPercent': discount.percent,
      'totalCents': cartTotalCents,
      'items': items,
    });

    return orderRef.id;
  }

  Future<String?> createCheckoutSessionUrl({required String orderId}) async {
    final callable = FirebaseFunctions.instance.httpsCallable('createCheckoutSessionForOrder');
    final res = await callable.call(<String, dynamic>{'orderId': orderId});
    final data = res.data;
    if (data is Map && data['checkoutUrl'] is String) return data['checkoutUrl'] as String;
    return null;
  }
}

/// -----------------------------------------------------------------------------
/// CART SCOPE
/// -----------------------------------------------------------------------------
class CartScope extends InheritedNotifier<CartProvider> {
  const CartScope({super.key, required CartProvider super.notifier, required super.child});

  static CartProvider of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CartScope>();
    assert(scope != null, 'CartScope not found');
    return scope!.notifier!;
  }
}

/// -----------------------------------------------------------------------------
/// REPO
/// -----------------------------------------------------------------------------
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

    if (f.country != null) q = q.where('country', isEqualTo: f.country);
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
      if (f.sort == SortMode.popular) q = q.orderBy('popularity', descending: true);
      if (f.sort == SortMode.priceAsc) q = q.orderBy('priceCents', descending: false);
      if (f.sort == SortMode.priceDesc) q = q.orderBy('priceCents', descending: true);
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
        .limit(300);

    final snap = await base.get();
    final countries = <String>{};
    for (final d in snap.docs) {
      final c = d.data()['country'];
      if (c is String && c.trim().isNotEmpty) countries.add(c.trim());
    }

    Query<Map<String, dynamic>> q = _db
        .collection('photos')
        .where('isActive', isEqualTo: true)
        .where('moderationStatus', isEqualTo: 'approved');

    if (f.country != null) q = q.where('country', isEqualTo: f.country);

    if (f.dateRange != null) {
      final start = DateTime(f.dateRange!.start.year, f.dateRange!.start.month, f.dateRange!.start.day);
      final end = DateTime(f.dateRange!.end.year, f.dateRange!.end.month, f.dateRange!.end.day, 23, 59, 59, 999);
      q = q
          .where('eventDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('eventDate', isLessThanOrEqualTo: Timestamp.fromDate(end));
    }

    final eventsSnap = await q.orderBy('eventDate', descending: true).limit(300).get();
    final events = <String>{};
    for (final d in eventsSnap.docs) {
      final e = d.data()['eventName'];
      if (e is String && e.trim().isNotEmpty) events.add(e.trim());
    }

    Query<Map<String, dynamic>> qGroups = q;
    if (f.eventName != null) qGroups = qGroups.where('eventName', isEqualTo: f.eventName);
    final groupsSnap = await qGroups.orderBy('eventDate', descending: true).limit(300).get();
    final groups = <String>{};
    for (final d in groupsSnap.docs) {
      final g = d.data()['groupName'];
      if (g is String && g.trim().isNotEmpty) groups.add(g.trim());
    }

    Query<Map<String, dynamic>> qPhot = qGroups;
    if (f.groupName != null) qPhot = qPhot.where('groupName', isEqualTo: f.groupName);
    final photSnap = await qPhot.orderBy('eventDate', descending: true).limit(300).get();
    final photographers = <String>{};
    for (final d in photSnap.docs) {
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

/// -----------------------------------------------------------------------------
/// PAGE V2.1 (export depuis account_page.dart ou shop_body.dart)
/// -----------------------------------------------------------------------------
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
  Timer? _searchDebounce;
  Timer? _precacheDebounce;

  final ScrollController _scroll = ScrollController();

  static const int _pageSize = 28;
  bool _loadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;

  final List<PhotoDoc> _items = [];
  String? _error;
  bool _initialLoading = true;

  Set<String> _purchased = {};
  StreamSubscription<Set<String>>? _purchasedSub;

  // Cart provider (wrap dans CartScope outside)
  late final CartProvider _cartProvider = CartProvider();

  @override
  void initState() {
    super.initState();

    _purchasedSub = _repo.purchasedPhotoIdsStream().listen((set) {
      if (!mounted) return;
      setState(() => _purchased = set);
    });

    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 700) {
        _loadMore();
      }
      _schedulePrecache();
    });

    _refreshAll();
  }

  @override
  void dispose() {
    _facetDebounce?.cancel();
    _searchDebounce?.cancel();
    _precacheDebounce?.cancel();
    _scroll.dispose();
    _purchasedSub?.cancel();
    _cartProvider.dispose();
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

    if (mounted) setState(() => _initialLoading = false);
    _schedulePrecache(force: true);
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
      if (!reset && _lastDoc != null) q = q.startAfterDocument(_lastDoc!);

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

    _schedulePrecache();
  }

  void _setFilters(FilterState next, {bool resetResults = true}) {
    setState(() => _filters = next);
    _loadFacetsDebounced();
    if (resetResults) _loadMore(reset: true);
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _setFilters(_filters.copyWith(searchText: v), resetResults: false);
    });
  }

  List<PhotoDoc> get _visibleItems {
    Iterable<PhotoDoc> list = _items;

    if (_filters.hidePurchased) {
      list = list.where((p) => !_purchased.contains(p.id));
    }

    final s = _filters.searchText.trim().toLowerCase();
    if (s.isNotEmpty) {
      list = list.where((p) {
        final hay = '${p.eventName} ${p.groupName} ${p.photographerName} ${p.country}'.toLowerCase();
        return hay.contains(s);
      });
    }

    return list.toList();
  }

  void _schedulePrecache({bool force = false}) {
    _precacheDebounce?.cancel();
    _precacheDebounce = Timer(Duration(milliseconds: force ? 50 : 220), () async {
      if (!mounted) return;
      final items = _visibleItems;
      if (items.isEmpty) return;

      final pos = _scroll.hasClients ? _scroll.position.pixels : 0.0;
      final idx = (pos / 320).floor() * 2;
      final start = (idx - 6).clamp(0, items.length - 1);
      final end = (idx + 16).clamp(0, items.length - 1);

      for (int i = start; i <= end; i++) {
        final p = items[i];
        final url = await _repo.storageUrl(p.thumbPath);
        if (!mounted) return;
        if (url.isEmpty) continue;
        // ignore: unawaited_futures
        precacheImage(NetworkImage(url), context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = _visibleItems;

    return CartScope(
      notifier: _cartProvider,
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
                            leading: _GlassHeaderButton(
                              tooltip: 'Retour',
                              onTap: () => Navigator.of(context).maybePop(),
                              child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _GlassHeaderButton(
                                  tooltip: 'Panier',
                                  onTap: () => _openCartSheet(context, cart),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      const Icon(
                                        Icons.shopping_bag_outlined,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                      if (cart.cartCount > 0)
                                        Positioned(
                                          right: -4,
                                          top: -4,
                                          child: _Badge(text: '${cart.cartCount}'),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _GlassHeaderButton(
                                  tooltip: 'Rafraîchir',
                                  onTap: _refreshAll,
                                  child: const Icon(
                                    Icons.refresh,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _StickyHeaderDelegate(
                            minHeight: 244,
                            maxHeight: 244,
                            child: FilterBarStickyV21(
                              filters: _filters,
                              facets: _facets,
                              onChanged: _setFilters,
                              onReset: () => _setFilters(const FilterState()),
                              onSearchChanged: _onSearchChanged,
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
                        else if (results.isEmpty)
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
                            sliver: SliverLayoutBuilder(
                              builder: (context, constraints) {
                                final width = constraints.crossAxisExtent;
                                final crossAxisCount = _gridColumnsForWidth(width);

                                return SliverGrid(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final item = results[index];
                                      final purchased = _purchased.contains(item.id);
                                      return SelectablePhotoCardV21(
                                        item: item,
                                        purchased: purchased,
                                        onOpen: () => _openPreview(
                                          context,
                                          item,
                                          purchased: purchased,
                                          cart: cart,
                                        ),
                                      );
                                    },
                                    childCount: results.length,
                                  ),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: crossAxisCount >= 4 ? 0.80 : 0.78,
                                  ),
                                );
                              },
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

                  const Positioned(left: 0, right: 0, bottom: 0, child: BottomSelectionBarV21()),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openPreview(BuildContext context, PhotoDoc item, {required bool purchased, required CartProvider cart}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PhotoPreviewSheetV21(item: item, purchased: purchased, cart: cart),
    );
  }

  void _openCartSheet(BuildContext context, CartProvider cart) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CartSheetV21(cart: cart, purchased: _purchased),
    );
  }
}

/// -----------------------------------------------------------------------------
/// FILTER BAR V2.1 (sticky + cascade + search + hide purchased)
/// -----------------------------------------------------------------------------
class FilterBarStickyV21 extends StatelessWidget {
  const FilterBarStickyV21({
    super.key,
    required this.filters,
    required this.facets,
    required this.onChanged,
    required this.onReset,
    required this.onSearchChanged,
  });

  final FilterState filters;
  final FacetData facets;
  final void Function(FilterState next, {bool resetResults}) onChanged;
  final VoidCallback onReset;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          children: [
            _SearchField(
              initialValue: filters.searchText,
              onChanged: onSearchChanged,
              onClear: () => onChanged(filters.copyWith(searchText: ''), resetResults: false),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _Drop(
                    label: 'Pays',
                    value: filters.country,
                    items: facets.countries,
                    onChanged: (v) => onChanged(
                      filters.copyWith(
                        country: v,
                        clearEvent: true,
                        clearGroup: true,
                        clearPhotographer: true,
                      ),
                      resetResults: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateRangeField(
                    label: 'Date',
                    range: filters.dateRange,
                    onPick: (r) => onChanged(
                      filters.copyWith(
                        dateRange: r,
                        clearEvent: true,
                        clearGroup: true,
                        clearPhotographer: true,
                      ),
                      resetResults: true,
                    ),
                    onClear: () => onChanged(
                      filters.copyWith(
                        clearDate: true,
                        clearEvent: true,
                        clearGroup: true,
                        clearPhotographer: true,
                      ),
                      resetResults: true,
                    ),
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
                    onChanged: (v) => onChanged(
                      filters.copyWith(eventName: v, clearGroup: true, clearPhotographer: true),
                      resetResults: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Drop(
                    label: 'Groupe',
                    value: filters.groupName,
                    items: facets.groups,
                    onChanged: (v) => onChanged(
                      filters.copyWith(groupName: v, clearPhotographer: true),
                      resetResults: true,
                    ),
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
                    onChanged: (v) => onChanged(filters.copyWith(photographerName: v), resetResults: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SortDrop(
                    value: filters.sort,
                    onChanged: (m) => onChanged(filters.copyWith(sort: m), resetResults: true),
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
                    onTap: () => onChanged(filters.copyWith(hidePurchased: !filters.hidePurchased), resetResults: false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          const Expanded(child: Text('Masquer déjà achetées')),
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

/// -----------------------------------------------------------------------------
/// GRID CARD V2.1 (long press pour sélection)
/// -----------------------------------------------------------------------------
class SelectablePhotoCardV21 extends StatefulWidget {
  const SelectablePhotoCardV21({
    super.key,
    required this.item,
    required this.purchased,
    required this.onOpen,
  });

  final PhotoDoc item;
  final bool purchased;
  final VoidCallback onOpen;

  @override
  State<SelectablePhotoCardV21> createState() => _SelectablePhotoCardV21State();
}

class _SelectablePhotoCardV21State extends State<SelectablePhotoCardV21> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cart = CartScope.of(context);

    return AnimatedBuilder(
      animation: cart,
      builder: (context, _) {
        final selected = cart.isSelected(widget.item.id);
        final inCart = cart.isInCart(widget.item.id);

        final isInteractive = !widget.purchased;
        final shadowOpacity = _hovered ? 0.10 : 0.07;
        final borderOpacity = _hovered ? 0.12 : 0.08;

        return MouseRegion(
          onEnter: (_) {
            if (!mounted) return;
            setState(() => _hovered = true);
          },
          onExit: (_) {
            if (!mounted) return;
            setState(() => _hovered = false);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.black.withOpacity(borderOpacity)),
              boxShadow: [
                BoxShadow(
                  blurRadius: _hovered ? 22 : 16,
                  offset: const Offset(0, 10),
                  color: Colors.black.withOpacity(shadowOpacity),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: widget.onOpen,
                onLongPress: isInteractive ? () => cart.toggleSelected(widget.item) : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                              child: _StorageImage(path: widget.item.thumbPath),
                            ),
                          ),

                          Positioned(
                            top: 10,
                            right: 10,
                            child: GestureDetector(
                              onTap: isInteractive ? () => cart.toggleSelected(widget.item) : null,
                              child: _CheckBadge(isOn: selected, disabled: widget.purchased),
                            ),
                          ),

                          if (inCart)
                            Positioned(
                              left: 10,
                              top: 10,
                              child: _PremiumPill(text: 'Au panier'),
                            ),
                          if (widget.purchased)
                            Positioned(
                              left: 10,
                              bottom: 10,
                              child: _PremiumPill(text: 'Achetée'),
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
                            widget.item.eventName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.item.groupName} • ${widget.item.photographerName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.62),
                              fontSize: 12,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Text(
                                _money(widget.item.priceCents),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: widget.purchased ? 'Déjà achetée' : 'Ajouter au panier',
                                onPressed: (widget.purchased || inCart) ? null : () => cart.addToCart(widget.item),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black.withOpacity(0.05),
                                  padding: const EdgeInsets.all(10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
                              ),
                            ],
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
      },
    );
  }
}

int _gridColumnsForWidth(double width) {
  if (width >= 1400) return 5;
  if (width >= 1100) return 4;
  if (width >= 820) return 3;
  return 2;
}

class _PremiumPill extends StatelessWidget {
  const _PremiumPill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 6),
            color: Colors.black.withOpacity(0.08),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: -0.1),
      ),
    );
  }
}

/// -----------------------------------------------------------------------------
/// Bottom selection bar V2.1
/// -----------------------------------------------------------------------------
class BottomSelectionBarV21 extends StatelessWidget {
  const BottomSelectionBarV21({super.key});

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
              border: Border(top: BorderSide(color: Colors.black.withOpacity(0.08))),
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
                    '${cart.selectedCount} sélectionnée(s)\nTotal: ${_money(cart.selectedTotalCents)}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(onPressed: cart.clearSelected, child: const Text('Décocher')),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: cart.addSelectedToCart,
                  icon: const Icon(Icons.shopping_cart_checkout),
                  label: const Text('Mettre au panier'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// -----------------------------------------------------------------------------
/// PREVIEW SHEET V2.1
/// -----------------------------------------------------------------------------
class _PhotoPreviewSheetV21 extends StatefulWidget {
  const _PhotoPreviewSheetV21({
    required this.item,
    required this.purchased,
    required this.cart,
  });

  final PhotoDoc item;
  final bool purchased;
  final CartProvider cart;

  @override
  State<_PhotoPreviewSheetV21> createState() => _PhotoPreviewSheetV21State();
}

class _PhotoPreviewSheetV21State extends State<_PhotoPreviewSheetV21> {
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
          Text(item.eventName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('${item.groupName} • ${item.photographerName}',
              style: TextStyle(color: Colors.black.withOpacity(0.7))),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('Prix: ${_money(item.priceCents)}', style: const TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              Text(_fmtDate(item.eventDate), style: TextStyle(color: Colors.black.withOpacity(0.6))),
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
                  label: Text(widget.purchased ? 'Achetée' : (inCart ? 'Au panier' : 'Ajouter')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// -----------------------------------------------------------------------------
/// CART SHEET V2.1 (avec packs discount + Stripe checkout)
/// -----------------------------------------------------------------------------
class _CartSheetV21 extends StatefulWidget {
  const _CartSheetV21({required this.cart, required this.purchased});
  final CartProvider cart;
  final Set<String> purchased;

  @override
  State<_CartSheetV21> createState() => _CartSheetV21State();
}

class _CartSheetV21State extends State<_CartSheetV21> {
  bool _creatingOrder = false;
  bool _creatingCheckout = false;
  String? _orderId;
  String? _checkoutUrl;

  @override
  Widget build(BuildContext context) {
    final cart = widget.cart;

    return AnimatedBuilder(
      animation: cart,
      builder: (context, _) {
        final items = cart.cart.values.toList();

        final before = cart.cartTotalCentsBeforeDiscount;
        final disc = cart.cartDiscount;
        final total = cart.cartTotalCents;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFE36A),
                      Color(0xFFFF7BC5),
                      Color(0xFF7CE0FF),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Panier',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    const Spacer(),
                    Text(
                      _money(total),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              if (items.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black.withOpacity(0.10)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _line('Sous-total', _money(before)),
                      if (disc.discountCents > 0)
                        _line('Pack (-${disc.percent}%)', '- ${_money(disc.discountCents)}'),
                      const Divider(height: 16),
                      _line('Total', _money(total), bold: true),
                      const SizedBox(height: 6),
                      Text(
                        disc.discountCents > 0
                            ? 'Pack appliqué: ${disc.rule} • ajoute des photos pour maximiser la réduction.'
                            : 'Astuce: dès 3 photos → -10%, 5 photos → -20%, 10 photos → -30%.',
                        style: TextStyle(color: Colors.black.withOpacity(0.6)),
                      ),
                    ],
                  ),
                ),

              if (_orderId != null || _checkoutUrl != null) const SizedBox(height: 10),

              if (_orderId != null)
                _InfoBox(
                  title: 'Commande créée',
                  body: 'orderId: $_orderId\nstatus: pending\n\n'
                      'Tu peux maintenant créer la Checkout Session (Stripe).',
                ),

              if (_checkoutUrl != null)
                _InfoBox(
                  title: 'Checkout URL',
                  body: _checkoutUrl!,
                  actions: [
                    TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: _checkoutUrl!));
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Lien copié')),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copier'),
                    ),
                  ],
                ),

              const SizedBox(height: 10),

              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('Ton panier est vide.', style: TextStyle(color: Colors.black.withOpacity(0.65))),
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
                                Text(it.eventName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                Text(
                                  '${it.photographerName}${bought ? ' • Déjà achetée' : ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.black.withOpacity(0.7)),
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
                              setState(() {
                                _orderId = null;
                                _checkoutUrl = null;
                              });
                            },
                      child: const Text('Vider'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (cart.cart.isEmpty || _creatingOrder)
                          ? null
                          : () async {
                              setState(() => _creatingOrder = true);
                              try {
                                final id = await cart.createPendingOrder();
                                setState(() => _orderId = id);
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Erreur création commande: $e')),
                                );
                              } finally {
                                if (mounted) setState(() => _creatingOrder = false);
                              }
                            },
                      child: _creatingOrder
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
              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_orderId == null || _creatingCheckout)
                      ? null
                      : () async {
                          setState(() => _creatingCheckout = true);
                          try {
                            final url = await cart.createCheckoutSessionUrl(orderId: _orderId!);
                            if (url == null || url.isEmpty) {
                              throw Exception('checkoutUrl manquant (callable)');
                            }
                            setState(() => _checkoutUrl = url);
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Erreur checkout: $e')),
                            );
                          } finally {
                            if (mounted) setState(() => _creatingCheckout = false);
                          }
                        },
                  icon: _creatingCheckout
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_outline),
                  label: Text(_creatingCheckout ? 'Création checkout...' : 'Créer checkout Stripe'),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Après paiement: ton webhook Stripe doit passer la commande en "paid" '
                'et écrire /users/{uid}/purchases/{photoId}.',
                style: TextStyle(color: Colors.black.withOpacity(0.6), fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _line(String left, String right, {bool bold = false}) {
    final st = TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w700);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(left, style: st)),
          Text(right, style: st),
        ],
      ),
    );
  }
}

/// -----------------------------------------------------------------------------
/// STORAGE IMAGE
/// -----------------------------------------------------------------------------
class _StorageImage extends StatelessWidget {
  const _StorageImage({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    if (path.trim().isEmpty) {
      return Container(
        color: Colors.black.withOpacity(0.06),
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
            color: Colors.black.withOpacity(0.06),
            alignment: Alignment.center,
            child: const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (url.isEmpty) {
          return Container(
            color: Colors.black.withOpacity(0.06),
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
            color: Colors.black.withOpacity(0.06),
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined),
          ),
        );
      },
    );
  }
}

/// -----------------------------------------------------------------------------
/// UI COMPONENTS
/// -----------------------------------------------------------------------------
class _SearchField extends StatefulWidget {
  const _SearchField({
    required this.initialValue,
    required this.onChanged,
    required this.onClear,
  });

  final String initialValue;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _c = TextEditingController(text: widget.initialValue);

  @override
  void didUpdateWidget(covariant _SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue && _c.text != widget.initialValue) {
      _c.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _c.text.trim().isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _c.clear();
                  widget.onClear();
                  widget.onChanged('');
                  setState(() {});
                },
                icon: const Icon(Icons.close),
              ),
        hintText: 'Rechercher (événement, groupe, photographe...)',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.title, required this.body, this.actions});
  final String title;
  final String body;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          SelectableText(body),
          if (actions != null) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: actions!),
          ],
        ],
      ),
    );
  }
}

class _CheckBadge extends StatelessWidget {
  const _CheckBadge({required this.isOn, this.disabled = false});
  final bool isOn;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final bg = disabled ? Colors.black.withOpacity(0.15) : (isOn ? Colors.black : Colors.white);
    final fg = disabled ? Colors.black.withOpacity(0.35) : (isOn ? Colors.white : Colors.black);

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.10)),
      ),
      alignment: Alignment.center,
      child: Icon(isOn ? Icons.check : Icons.circle_outlined, size: 18, color: fg),
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
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
    );
  }
}

class _GlassHeaderButton extends StatelessWidget {
  const _GlassHeaderButton({required this.tooltip, required this.onTap, required this.child});
  final String tooltip;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.22)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _SheetOption<T> {
  const _SheetOption(this.value, this.label);
  final T? value;
  final String label;
}

Future<_SheetOption<T>?> _showSelectSheet<T>(
  BuildContext context, {
  required String title,
  required List<_SheetOption<T>> options,
  required T? selected,
}) {
  return showModalBottomSheet<_SheetOption<T>>(
    context: context,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Row(
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const Spacer(),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (context, i) {
                final opt = options[i];
                final isSelected = opt.value == selected;
                return ListTile(
                  title: Text(opt.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Color(0xFF2563EB), size: 18)
                      : null,
                  onTap: () => Navigator.pop(context, opt),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _Drop extends StatelessWidget {
  const _Drop({required this.label, required this.value, required this.items, required this.onChanged});

  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final display = value ?? 'Tout';
    final options = <_SheetOption<String>>[
      const _SheetOption<String>(null, 'Tout'),
      ...items.map((e) => _SheetOption<String>(e, e)),
    ];

    return SizedBox(
      height: 56,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () async {
            final picked = await _showSelectSheet<String>(
              context,
              title: label,
              options: options,
              selected: value,
            );
            if (picked != null) onChanged(picked.value);
          },
          child: InputDecorator(
            decoration: InputDecoration(
              isDense: true,
              labelText: label,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide(color: MasliveTheme.pink, width: 2),
              ),
              contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              filled: true,
              fillColor: Colors.white,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    display,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded),
              ],
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
          final options = SortMode.values
              .map((m) => _SheetOption<SortMode>(m, label(m)))
              .toList();

        case SortMode.popular:
          return 'Populaires';
        case SortMode.priceAsc:
          return 'Prix ↑';
                borderRadius: BorderRadius.circular(22),
          return 'Prix ↓';
      }
    }

    return SizedBox(
      height: 56,
      child: Container(
        decoration: BoxDecoration(
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () async {
                  final picked = await _showSelectSheet<SortMode>(
                    context,
                    title: 'Trier',
                    options: options,
                    selected: value,
                  );
                  if (picked != null && picked.value != null) onChanged(picked.value!);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'Trier',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(color: MasliveTheme.pink, width: 2),
                    ),
                    contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label(value),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down_rounded),
                    ],
                  ),
                ),
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
  const _DateRangeField({required this.label, required this.range, required this.onPick, required this.onClear});

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
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
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
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide(color: MasliveTheme.pink, width: 2),
              ),
              contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              filled: true,
              fillColor: Colors.white,
              suffixIcon: range == null
                  ? const Icon(Icons.date_range)
                  : IconButton(tooltip: 'Effacer', onPressed: onClear, icon: const Icon(Icons.close)),
            ),
            child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      ),
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  _StickyHeaderDelegate({required this.minHeight, required this.maxHeight, required this.child});
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
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) =>
      minHeight != oldDelegate.minHeight || maxHeight != oldDelegate.maxHeight || child != oldDelegate.child;
}

/// -----------------------------------------------------------------------------
/// UTILS
/// -----------------------------------------------------------------------------
String _money(int cents) {
  final v = cents / 100.0;
  final s = v.toStringAsFixed(2).replaceAll('.', ',');
  return '$s€';
}

String _fmt(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}

String _fmtDate(DateTime d) => _fmt(d);
