import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/firestore_service.dart';
import '../services/gallery_counts_service.dart';
import '../ui/theme/maslive_theme.dart';
import '../ui/widgets/honeycomb_background.dart';
import '../ui/widgets/maslive_card.dart';
import '../widgets/la_boutique_header.dart';
import 'media_galleries_page.dart';

class ShopUiPage extends StatefulWidget {
  const ShopUiPage({super.key, this.groupId});

  final String? groupId;

  @override
  State<ShopUiPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopUiPage> {
  String _category = 'Tous';
  String? _selectedGroup;
  // ignore: unused_field
  String _searchQuery = '';
  // ignore: unused_field
  final FirestoreService _firestore = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final products = _MockProduct.sample.where((p) {
      if (_category == 'Tous') return true;
      return p.category == _category;
    }).toList();

    final galleryGroupLabel = _selectedGroup ?? 'Tous les groupes';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        body: HoneycombBackground(
          opacity: 0.08,
          child: Column(
            children: [
              LaBoutiqueHeader(
                onBack: () => Navigator.pop(context),
                onSearchIconTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Recherche (mock)')),
                  );
                },
                onQueryChanged: (query) {
                  setState(() => _searchQuery = query);
                },
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: GridView.builder(
                    itemCount: products.length + 1,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.76,
                    ),
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return _GalleryTile(
                          groupId: _selectedGroup,
                          groupLabel: galleryGroupLabel,
                          onTap: () {
                            final gid = _selectedGroup ?? 'all';
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MediaGalleriesPage(groupId: gid),
                              ),
                            );
                          },
                        );
                      }
                      return _ProductCard(product: products[i - 1]);
                    },
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

class _CategoryRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _CategoryRow({
    required this.selected,
    required this.onSelected,
  });

  static const _cats = <String>['Tous', 'T-shirts', 'Casquettes', 'Stickers', 'Accessoires'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _cats.map((c) {
          final isSelected = c == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => onSelected(c),
              borderRadius: BorderRadius.circular(MasliveTheme.rPill),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(MasliveTheme.rPill),
                  color: isSelected ? const Color(0x14FF6BB5) : MasliveTheme.surface,
                  border: Border.all(color: MasliveTheme.divider),
                  boxShadow: isSelected ? MasliveTheme.cardShadow : null,
                ),
                child: Text(
                  c,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: isSelected ? MasliveTheme.textPrimary : MasliveTheme.textSecondary,
                      ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final _MockProduct product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return MasliveCard(
      radius: 22,
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          showModalBottomSheet<void>(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (context) {
              return _ProductSheet(product: product);
            },
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      product.imageAsset,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(color: MasliveTheme.surfaceAlt),
                    ),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.86),
                          borderRadius: BorderRadius.circular(MasliveTheme.rPill),
                          border: Border.all(color: MasliveTheme.divider),
                        ),
                        child: Text(
                          product.category,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: MasliveTheme.textPrimary,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: SizedBox(
                height: 92,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: MasliveTheme.textPrimary,
                          ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Text(
                          product.priceLabel,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const Spacer(),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            gradient: MasliveTheme.actionGradient,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: MasliveTheme.cardShadow,
                          ),
                          child: const Icon(Icons.add_rounded, color: Colors.white),
                        ),
                      ],
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

class _GalleryTile extends StatefulWidget {
  final String groupLabel;
  final String? groupId;
  final VoidCallback onTap;

  const _GalleryTile({required this.groupLabel, required this.groupId, required this.onTap});

  @override
  State<_GalleryTile> createState() => _GalleryTileState();
}

class _GalleryTileState extends State<_GalleryTile> {
  final GalleryCountsService _counts = GalleryCountsService();
  late Future<GalleryCounts> _future;

  @override
  void initState() {
    super.initState();
    _future = _counts.fetch(groupId: widget.groupId);
  }

  @override
  void didUpdateWidget(covariant _GalleryTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupId != widget.groupId) {
      setState(() {
        _future = _counts.fetch(groupId: widget.groupId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GalleryCounts>(
      future: _future,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final photos = snapshot.data?.photos ?? 0;
        final label = isLoading
            ? 'Chargement...'
            : photos == 0
                ? 'Photos à venir'
                : '$photos photos';

        return MasliveCard(
          radius: 22,
          padding: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: widget.onTap,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1F2A37), Color(0xFF3B82F6)],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.photo_library_outlined, color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text('Galerie photos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: const Text(
                          'Photographes only',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Photos par les photographes',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Filtre: ${widget.groupLabel}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w700,
                            ),
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

class _ProductSheet extends StatelessWidget {
  final _MockProduct product;

  const _ProductSheet({required this.product});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(24),
          boxShadow: MasliveTheme.floatingShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    product.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(product.description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: MasliveTheme.textSecondary)),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(product.priceLabel, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                    shape: const StadiumBorder(),
                    backgroundColor: MasliveTheme.pink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ajouté au panier (mock)')),
                    );
                  },
                  child: const Text('Ajouter'),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MockProduct {
  final String name;
  final String category;
  final String priceLabel;
  final String imageAsset;
  final String description;

  const _MockProduct({
    required this.name,
    required this.category,
    required this.priceLabel,
    required this.imageAsset,
    required this.description,
  });

  static const sample = <_MockProduct>[
    _MockProduct(
      name: 'T-shirt MASLIVE Premium',
      category: 'T-shirts',
      priceLabel: '29€',
      imageAsset: 'assets/splash/maslivesmall.png',
      description: 'Coupe oversize, coton doux, logo discret. Edition mock.',
    ),
    _MockProduct(
      name: 'Casquette Pastel',
      category: 'Casquettes',
      priceLabel: '24€',
      imageAsset: 'assets/splash/maslivesmall.png',
      description: 'Visière courbe, broderie premium, look clean.',
    ),
    _MockProduct(
      name: 'Pack Stickers',
      category: 'Stickers',
      priceLabel: '9€',
      imageAsset: 'assets/splash/maslivesmall.png',
      description: 'Stickers résistants, finition mate, 6 pièces.',
    ),
    _MockProduct(
      name: 'Porte-clés Honeycomb',
      category: 'Accessoires',
      priceLabel: '12€',
      imageAsset: 'assets/splash/maslivesmall.png',
      description: 'Texture honeycomb, accroche solide, style premium.',
    ),
  ];
}

class _GroupDropdown extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelected;
  final FirestoreService firestore;

  const _GroupDropdown({
    required this.selected,
    required this.onSelected,
    required this.firestore,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: firestore.getGroupsNamesList(),
      builder: (context, snapshot) {
        final groups = snapshot.data ?? const [];

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MasliveTheme.divider),
          ),
          child: DropdownButton<String?>(
            value: selected,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            hint: Text(
              'Sélectionner un groupe',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: MasliveTheme.textSecondary,
                  ),
            ),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(
                  'Tous les groupes',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: MasliveTheme.textPrimary,
                      ),
                ),
              ),
              ...groups.map((group) {
                return DropdownMenuItem<String?>(
                  value: group,
                  child: Text(
                    group,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: MasliveTheme.textPrimary,
                        ),
                  ),
                );
              }),
            ],
            onChanged: onSelected,
          ),
        );
      },
    );
  }
}