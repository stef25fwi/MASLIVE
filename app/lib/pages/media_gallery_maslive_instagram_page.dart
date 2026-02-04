
import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/media_permissions_service.dart';

class MediaGalleryMasliveInstagramPage extends StatefulWidget {
  const MediaGalleryMasliveInstagramPage({super.key});

  @override
  State<MediaGalleryMasliveInstagramPage> createState() =>
      _MediaGalleryMasliveInstagramPageState();
}

class _MediaGalleryMasliveInstagramPageState
    extends State<MediaGalleryMasliveInstagramPage> {
  // ------------------------------
  // MAS’LIVE THEME (White + Rainbow)
  // ------------------------------
  static const Color _bg = Colors.white;

  // Très léger (premium), évite l’arc-en-ciel agressif
  // Honeycomb ultra discret (style MAS’LIVE)
  static const double _honeyOpacity = 0.06;

  // ------------------------------
  // Firestore + Pagination
  // ------------------------------
  static const String _collection = 'media';
  static const int _pageSize = 60;

  String? _country;
  String? _event;
  String? _circuit;
  String? _type; // "photo" | "video"

  DocumentSnapshot? _lastDoc;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  final List<MediaDoc> _items = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  final ScrollController _scroll = ScrollController();

  bool _canAddMediaCached = false;
  bool _canAddMediaLoaded = false;

  @override
  void dispose() {
    _sub?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 900) {
      _loadMore();
    }
  }

  bool get _hasActiveFilters =>
      (_country?.trim().isNotEmpty ?? false) ||
      (_event?.trim().isNotEmpty ?? false) ||
      (_circuit?.trim().isNotEmpty ?? false) ||
      (_type?.trim().isNotEmpty ?? false);

  Query<Map<String, dynamic>> _baseQuery() {
    Query<Map<String, dynamic>> q =
        FirebaseFirestore.instance.collection(_collection);

    if (_country != null && _country!.trim().isNotEmpty) {
      q = q.where('country', isEqualTo: _country!.trim());
    }
    if (_event != null && _event!.trim().isNotEmpty) {
      q = q.where('event', isEqualTo: _event!.trim());
    }
    if (_circuit != null && _circuit!.trim().isNotEmpty) {
      q = q.where('circuit', isEqualTo: _circuit!.trim());
    }
    if (_type != null && _type!.trim().isNotEmpty) {
      q = q.where('type', isEqualTo: _type!.trim());
    }

    q = q.orderBy('createdAt', descending: true);
    return q;
  }

  Future<void> _startListening({required bool reset}) async {
    await _sub?.cancel();

    if (reset) {
      setState(() {
        _items.clear();
        _lastDoc = null;
        _hasMore = true;
        _isLoadingMore = false;
      });
    }

    final firstPage = _baseQuery().limit(_pageSize);

    _sub = firstPage.snapshots().listen((snap) {
      final docs = snap.docs;
      final page = docs.map((d) => MediaDoc.fromSnapshot(d)).toList();

      setState(() {
        // Merge sans doublons + tri
        final map = <String, MediaDoc>{};
        for (final m in page) {
          map[m.id] = m;
        }
        for (final m in _items) {
          map[m.id] = m;
        }

        final merged = map.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        _items
          ..clear()
          ..addAll(merged);

        _lastDoc = docs.isNotEmpty ? docs.last : null;
        _hasMore = docs.length >= _pageSize;
      });
    }, onError: (e) {
      _toast('Erreur Firestore: $e');
    });
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _isLoadingMore || _lastDoc == null) return;

    setState(() => _isLoadingMore = true);

    try {
      final next = await _baseQuery()
          .startAfterDocument(_lastDoc!)
          .limit(_pageSize)
          .get();

      final docs = next.docs;
      final page = docs.map((d) => MediaDoc.fromSnapshot(d)).toList();

      setState(() {
        final existing = _items.map((e) => e.id).toSet();
        for (final m in page) {
          if (!existing.contains(m.id)) _items.add(m);
        }
        _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _lastDoc = docs.isNotEmpty ? docs.last : _lastDoc;
        _hasMore = docs.length >= _pageSize;
      });
    } catch (e) {
      _toast('Erreur chargement: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _country = null;
      _event = null;
      _circuit = null;
      _type = null;
    });
    _startListening(reset: true);
  }

  void _openAddMedia() {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _AddMediaSheet(),
    ).then((ok) {
      if (ok == true) {
        _startListening(reset: true);
      }
    });
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<_FilterResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MasliveBottomSheet(
        child: _FiltersSheetMaslive(
          initialCountry: _country,
          initialEvent: _event,
          initialCircuit: _circuit,
          initialType: _type,
        ),
      ),
    );

    if (result == null) return;

    setState(() {
      _country = result.country;
      _event = result.event;
      _circuit = result.circuit;
      _type = result.type;
    });

    _startListening(reset: true);
  }

  void _openViewer(int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _MediaViewerMaslive(
          items: List<MediaDoc>.from(_items),
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _startListening(reset: true);
    // Charger les permissions au démarrage
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final can = await MediaPermissionsService.canUploadMedia();
    if (mounted) {
      setState(() {
        _canAddMediaCached = can;
        _canAddMediaLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final canAddMedia = _canAddMediaLoaded && _canAddMediaCached;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Fond honeycomb discret (MAS’LIVE)
          const Positioned.fill(child: _HoneycombBackground(opacity: _honeyOpacity)),

          Column(
            children: [
              // Header MAS’LIVE (white + rainbow line)
              _MasliveHeader(
                topPadding: top,
                title: 'Galerie',
                hasActiveFilters: _hasActiveFilters,
                onReset: _resetFilters,
                onOpenFilters: _openFilters,
                showAddMedia: canAddMedia,
                onAddMedia: canAddMedia ? _openAddMedia : null,
              ),

              if (_hasActiveFilters)
                _ActiveFiltersBar(
                  country: _country,
                  event: _event,
                  circuit: _circuit,
                  type: _type,
                ),

              Expanded(
                child: _items.isEmpty
                    ? const _EmptyStateMaslive()
                    : RefreshIndicator(
                        onRefresh: () async => _startListening(reset: true),
                        child: CustomScrollView(
                          controller: _scroll,
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.all(1),
                              sliver: SliverGrid(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final m = _items[index];
                                    return _MediaTileMaslive(
                                      item: m,
                                      onTap: () => _openViewer(index),
                                    );
                                  },
                                  childCount: _items.length,
                                ),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 1,
                                  mainAxisSpacing: 1,
                                ),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                child: Center(
                                  child: _isLoadingMore
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : (!_hasMore
                                          ? const Text('Fin',
                                              style: TextStyle(color: Colors.black45))
                                          : const SizedBox.shrink()),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ======================================================
// Header MAS’LIVE (white premium + rainbow line)
// ======================================================
class _MasliveHeader extends StatelessWidget {
  final double topPadding;
  final String title;
  final bool hasActiveFilters;
  final VoidCallback onReset;
  final VoidCallback onOpenFilters;
   final VoidCallback? onAddMedia;
   final bool showAddMedia;

  const _MasliveHeader({
    required this.topPadding,
    required this.title,
    required this.hasActiveFilters,
    required this.onReset,
    required this.onOpenFilters,
    this.onAddMedia,
    this.showAddMedia = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: topPadding),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0x11000000), width: 1)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 56,
            child: Row(
              children: [
                const SizedBox(width: 14),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0D0F12),
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(),

                if (showAddMedia && onAddMedia != null)
                  IconButton(
                    tooltip: 'Ajouter',
                    onPressed: onAddMedia,
                    icon: const Icon(
                      Icons.add_a_photo_outlined,
                      color: Color(0xFF0D0F12),
                    ),
                  ),

                if (hasActiveFilters)
                  TextButton(
                    onPressed: onReset,
                    child: const Text(
                      'Réinitialiser',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0D0F12),
                      ),
                    ),
                  ),

                IconButton(
                  onPressed: onOpenFilters,
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.tune_rounded, color: Color(0xFF0D0F12)),
                      if (hasActiveFilters)
                        const Positioned(
                          right: -2,
                          top: -2,
                          child: _RainbowDotBadge(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),

          // Rainbow line ultra fine (signature MAS’LIVE festival)
          const _RainbowLine(height: 2),
        ],
      ),
    );
  }
}

class _RainbowLine extends StatelessWidget {
  final double height;
  const _RainbowLine({required this.height});

  static const List<Color> _rainbow = [
    Color(0xFFFF4D4D),
    Color(0xFFFFA24D),
    Color(0xFFFFE04D),
    Color(0xFF4DFF88),
    Color(0xFF4DD2FF),
    Color(0xFF4D79FF),
    Color(0xFFA04DFF),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: _rainbow),
        ),
      ),
    );
  }
}

// ======================================================
// Active filters bar
// ======================================================
class _ActiveFiltersBar extends StatelessWidget {
  final String? country;
  final String? event;
  final String? circuit;
  final String? type;

  const _ActiveFiltersBar({
    required this.country,
    required this.event,
    required this.circuit,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    if (country?.trim().isNotEmpty ?? false) {
      chips.add(_MaslivePill(label: 'Pays: ${country!.trim()}'));
    }
    if (event?.trim().isNotEmpty ?? false) {
      chips.add(_MaslivePill(label: 'Événement: ${event!.trim()}'));
    }
    if (circuit?.trim().isNotEmpty ?? false) {
      chips.add(_MaslivePill(label: 'Circuit: ${circuit!.trim()}'));
    }
    if (type?.trim().isNotEmpty ?? false) {
      chips.add(_MaslivePill(label: 'Type: ${type!.trim()}'));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F7F8),
        border: Border(
          bottom: BorderSide(color: Color(0x11000000), width: 1),
        ),
      ),
      child: Wrap(spacing: 8, runSpacing: 8, children: chips),
    );
  }
}

class _MaslivePill extends StatelessWidget {
  final String label;
  const _MaslivePill({required this.label});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(191),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0x11000000)),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2B2F36),
            ),
          ),
        ),
      ),
    );
  }
}

class _RainbowDotBadge extends StatelessWidget {
  const _RainbowDotBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 10,
      width: 10,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            Color(0xFFFF4D4D),
            Color(0xFFFFE04D),
            Color(0xFF4DFF88),
            Color(0xFF4DD2FF),
            Color(0xFFA04DFF),
          ],
        ),
      ),
    );
  }
}

// ======================================================
// Tile MAS’LIVE (instagram grid)
// ======================================================
class _MediaTileMaslive extends StatelessWidget {
  final MediaDoc item;
  final VoidCallback onTap;

  const _MediaTileMaslive({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final thumb = item.thumbnailUrl.isNotEmpty ? item.thumbnailUrl : item.url;

    return InkWell(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Thumb
          Image.network(
            thumb,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const ColoredBox(
              color: Color(0xFFF0F0F2),
              child: Center(
                child: Icon(Icons.broken_image_outlined, color: Colors.black26),
              ),
            ),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const ColoredBox(
                color: Color(0xFFF3F3F4),
                child: Center(
                  child: SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            },
          ),

          // Overlay coin (ultra discret)
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [Color(0x12000000), Color(0x00000000)],
                ),
              ),
            ),
          ),

          // Badge vidéo: play + rainbow ring
          if (item.type == 'video')
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFFF4D4D),
                      Color(0xFFFFE04D),
                      Color(0xFF4DD2FF),
                      Color(0xFFA04DFF),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.play_circle_fill,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ======================================================
// Viewer MAS’LIVE (swipe + zoom)
// ======================================================
class _MediaViewerMaslive extends StatefulWidget {
  final List<MediaDoc> items;
  final int initialIndex;

  const _MediaViewerMaslive({
    required this.items,
    required this.initialIndex,
  });

  @override
  State<_MediaViewerMaslive> createState() => _MediaViewerMasliveState();
}

class _MediaViewerMasliveState extends State<_MediaViewerMaslive> {
  late final PageController _page;

  @override
  void initState() {
    super.initState();
    _page = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _page,
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                final m = widget.items[index];

                // Ici tu peux brancher un player vidéo si m.type == 'video'
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: Image.network(
                      m.url,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(Icons.broken_image_outlined,
                            color: Colors.white38),
                      ),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),

            // Top bar (close + rainbow accent)
            Positioned(
              left: 10,
              top: 10,
              right: 10,
              child: Row(
                children: [
                  _GlassIconButton(
                    icon: Icons.close,
                    onTap: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                ],
              ),
            ),

            // Rainbow line bottom (signature)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _RainbowLine(height: 3),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(26),
              border: Border.all(color: Colors.white.withAlpha(46)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

// ======================================================
// Bottom sheet container MAS’LIVE (glass)
// ======================================================
class _MasliveBottomSheet extends StatelessWidget {
  final Widget child;
  const _MasliveBottomSheet({required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(235),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
                border: const Border(
                  top: BorderSide(color: Color(0x11000000), width: 1),
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

// ======================================================
// Filters sheet MAS’LIVE (tuiles non obligatoires)
// ======================================================
class _FiltersSheetMaslive extends StatefulWidget {
  final String? initialCountry;
  final String? initialEvent;
  final String? initialCircuit;
  final String? initialType;

  const _FiltersSheetMaslive({
    this.initialCountry,
    this.initialEvent,
    this.initialCircuit,
    this.initialType,
  });

  @override
  State<_FiltersSheetMaslive> createState() => _FiltersSheetMasliveState();
}

class _FiltersSheetMasliveState extends State<_FiltersSheetMaslive> {
  late final TextEditingController _country;
  late final TextEditingController _event;
  late final TextEditingController _circuit;
  String? _type; // null | "photo" | "video"

  @override
  void initState() {
    super.initState();
    _country = TextEditingController(text: widget.initialCountry ?? '');
    _event = TextEditingController(text: widget.initialEvent ?? '');
    _circuit = TextEditingController(text: widget.initialCircuit ?? '');
    _type = (widget.initialType != null && widget.initialType!.isNotEmpty)
        ? widget.initialType
        : null;
  }

  @override
  void dispose() {
    _country.dispose();
    _event.dispose();
    _circuit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              width: 52,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 14),

            // Titre + rainbow
            const Row(
              children: [
                Text(
                  'Filtres',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0D0F12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const _RainbowLine(height: 2),
            const SizedBox(height: 14),

            // Champs (optionnels)
            _MasliveField(
              label: 'Pays',
              hint: 'ex: Guadeloupe',
              controller: _country,
            ),
            const SizedBox(height: 10),
            _MasliveField(
              label: 'Événement',
              hint: 'ex: Carnaval 2026',
              controller: _event,
            ),
            const SizedBox(height: 10),
            _MasliveField(
              label: 'Circuit',
              hint: 'ex: Pointe-à-Pitre',
              controller: _circuit,
            ),
            const SizedBox(height: 12),

            // Type chips
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _MasliveChoiceChip(
                    label: 'Tous',
                    selected: _type == null,
                    onTap: () => setState(() => _type = null),
                  ),
                  _MasliveChoiceChip(
                    label: 'Photos',
                    selected: _type == 'photo',
                    onTap: () => setState(() => _type = 'photo'),
                  ),
                  _MasliveChoiceChip(
                    label: 'Vidéos',
                    selected: _type == 'video',
                    onTap: () => setState(() => _type = 'video'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _country.clear();
                      _event.clear();
                      _circuit.clear();
                      setState(() => _type = null);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0x22000000)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Reset',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0D0F12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        _FilterResult(
                          country: _country.text.trim().isEmpty
                              ? null
                              : _country.text.trim(),
                          event: _event.text.trim().isEmpty
                              ? null
                              : _event.text.trim(),
                          circuit: _circuit.text.trim().isEmpty
                              ? null
                              : _circuit.text.trim(),
                          type: _type,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFF0D0F12),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Appliquer',
                      style: TextStyle(fontWeight: FontWeight.w900),
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

class _MasliveField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;

  const _MasliveField({
    required this.label,
    required this.hint,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF2B2F36),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9AA0A8)),
            filled: true,
            fillColor: const Color(0xFFF7F7F8),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _MasliveChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MasliveChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const List<Color> _rainbow = [
    Color(0xFFFF4D4D),
    Color(0xFFFFA24D),
    Color(0xFFFFE04D),
    Color(0xFF4DFF88),
    Color(0xFF4DD2FF),
    Color(0xFF4D79FF),
    Color(0xFFA04DFF),
  ];

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected ? Colors.white : const Color(0xFFF2F2F3),
          border: Border.all(
            color: selected ? const Color(0x00000000) : const Color(0x22000000),
          ),
          gradient: selected
              ? const LinearGradient(
                  colors: _rainbow,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? Colors.white.withAlpha(230) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: selected ? const Color(0xFF0D0F12) : const Color(0xFF2B2F36),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterResult {
  final String? country;
  final String? event;
  final String? circuit;
  final String? type;

  _FilterResult({
    required this.country,
    required this.event,
    required this.circuit,
    required this.type,
  });
}

// ======================================================
// Empty state MAS’LIVE
// ======================================================
class _EmptyStateMaslive extends StatelessWidget {
  const _EmptyStateMaslive();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.photo_library_outlined, size: 46, color: Colors.black26),
            SizedBox(height: 10),
            Text(
              'Aucun média',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Color(0xFF0D0F12),
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Ajoute des documents dans "media"\n(url, thumbnail, type, createdAt...)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================
// Firestore model
// ======================================================
class MediaDoc {
  final String id;
  final String url;
  final String thumbnailUrl;
  final String type; // "photo" | "video"
  final String country;
  final String event;
  final String circuit;
  final DateTime createdAt;

  MediaDoc({
    required this.id,
    required this.url,
    required this.thumbnailUrl,
    required this.type,
    required this.country,
    required this.event,
    required this.circuit,
    required this.createdAt,
  });

  factory MediaDoc.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final d = snap.data();
    final ts = d['createdAt'];
    final created = (ts is Timestamp)
        ? ts.toDate()
        : DateTime.fromMillisecondsSinceEpoch(0);

    return MediaDoc(
      id: snap.id,
      url: (d['url'] ?? '') as String,
      thumbnailUrl: (d['thumbnail'] ?? '') as String,
      type: (d['type'] ?? 'photo') as String,
      country: (d['country'] ?? '') as String,
      event: (d['event'] ?? '') as String,
      circuit: (d['circuit'] ?? '') as String,
      createdAt: created,
    );
  }
}

// ======================================================
// Sheet d’ajout de média (upload + métadonnées)
// ======================================================
class _AddMediaSheet extends StatefulWidget {
  const _AddMediaSheet();

  @override
  State<_AddMediaSheet> createState() => _AddMediaSheetState();
}

class _AddMediaSheetState extends State<_AddMediaSheet> {
  final _countryCtrl = TextEditingController();
  final _eventCtrl = TextEditingController();
  final _circuitCtrl = TextEditingController();

  DateTime? _date;
  XFile? _file;
  bool _saving = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _countryCtrl.dispose();
    _eventCtrl.dispose();
    _circuitCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
      );
      if (picked == null) return;
      setState(() => _file = picked);
    } catch (_) {
      // ignore
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 5);
    final last = DateTime(now.year + 2, 12, 31);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connecte-toi pour ajouter un média.')),
      );
      return;
    }

    if (_file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisis une photo.')),
      );
      return;
    }

    final country = _countryCtrl.text.trim();
    final event = _eventCtrl.text.trim();
    final circuit = _circuitCtrl.text.trim();

    if (country.isEmpty || event.isEmpty || circuit.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pays, événement et circuit sont obligatoires.'),
        ),
      );
      return;
    }

    final createdAt = _date ?? DateTime.now();

    setState(() => _saving = true);

    try {
      // Upload l'image (ImagePicker l'a déjà compressée à qualité 88)
      final bytes = await _file!.readAsBytes();
      final data = bytes;

      final ts = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'media/${user.uid}/$ts.jpg';
      final ref = FirebaseStorage.instance.ref(storagePath);
      final meta = SettableMetadata(contentType: 'image/jpeg');
      await ref.putData(data, meta);
      final url = await ref.getDownloadURL();

      // Récupérer le nom du photographe depuis Firestore
      final photographerName = await MediaPermissionsService.getPhotographerName();

      // Doc Firestore dans `media`
      final col = FirebaseFirestore.instance.collection('media');
      await col.add({
        'url': url,
        'thumbnail': url,
        'type': 'photo',
        'country': country,
        'event': event,
        'circuit': circuit,
        'createdAt': Timestamp.fromDate(createdAt),
        'createdBy': user.uid,
        'photographerName': photographerName,
      });

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur ajout média: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final dateLabel = _date == null
        ? 'Choisir une date'
        : '${_date!.day.toString().padLeft(2, '0')}/'
            '${_date!.month.toString().padLeft(2, '0')}/'
            '${_date!.year}';

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ajouter un média',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _pickImage,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(_file == null ? 'Choisir une photo' : 'Changer la photo'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _countryCtrl,
            decoration: const InputDecoration(
              labelText: 'Pays',
              hintText: 'Ex: Guadeloupe',
            ),
          ),
          const SizedBox(height: 8),

          TextField(
            controller: _eventCtrl,
            decoration: const InputDecoration(
              labelText: 'Événement',
              hintText: "Ex: Carnaval MAS'LIVE 2026",
            ),
          ),
          const SizedBox(height: 8),

          TextField(
            controller: _circuitCtrl,
            decoration: const InputDecoration(
              labelText: 'Circuit',
              hintText: 'Ex: Circuit Principal',
            ),
          ),
          const SizedBox(height: 8),

          TextButton.icon(
            onPressed: _saving ? null : _pickDate,
            icon: const Icon(Icons.event_outlined),
            label: Text(dateLabel),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(_saving ? 'Enregistrement…' : 'Publier le média'),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================
// MAS’LIVE Honeycomb Background (super discret)
// ======================================================
class _HoneycombBackground extends StatelessWidget {
  final double opacity;
  const _HoneycombBackground({required this.opacity});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HoneycombPainter(opacity: opacity),
    );
  }
}

class _HoneycombPainter extends CustomPainter {
  final double opacity;
  _HoneycombPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF0D0F12).withAlpha((opacity * 255).toInt());

    // Hex pattern
    const double r = 16; // rayon
    final double h = r * 1.7320508075688772; // sqrt(3)*r
    final double dx = r * 1.5;

    for (double y = -h; y < size.height + h; y += h) {
      for (double x = -r; x < size.width + r; x += dx) {
        final offsetX = x + ((y / h).round().isEven ? 0 : r * 0.75);
        _drawHex(canvas, paint, Offset(offsetX, y), r);
      }
    }
  }

  void _drawHex(Canvas canvas, Paint paint, Offset c, double r) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = (60.0 * i - 30) * 0.017453292519943295; // deg->rad
      final p = Offset(c.dx + r * cos(a), c.dy + r * sin(a));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  double sin(double x) => Math._sin(x);
  double cos(double x) => Math._cos(x);

  @override
  bool shouldRepaint(covariant _HoneycombPainter oldDelegate) {
    return oldDelegate.opacity != opacity;
  }
}

// Mini math sans import dart:math pour garder le fichier "copilot friendly"
class Math {
  static const double _pi = 3.1415926535897932;

  static double _sin(double x) {
    // approximation rapide (suffit pour motif discret)
    x = _wrapPi(x);
    final x2 = x * x;
    return x *
        (1 -
            x2 / 6 +
            x2 * x2 / 120 -
            x2 * x2 * x2 / 5040);
  }

  static double _cos(double x) => _sin(x + _pi / 2);

  static double _wrapPi(double x) {
    while (x > _pi) {
      x -= 2 * _pi;
    }
    while (x < -_pi) {
      x += 2 * _pi;
    }
    return x;
  }
}