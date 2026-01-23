import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/product_model.dart';
import 'media_galleries_page.dart';
import 'product_detail_page.dart';

class ShopBodyUnderHeader extends StatefulWidget {
  const ShopBodyUnderHeader({
    super.key,
    this.initialChip = 0,
    this.category = 'Tous',
    this.groupId,
  });

  final int initialChip;
  final String category;
  final String? groupId;

  @override
  State<ShopBodyUnderHeader> createState() => _ShopBodyUnderHeaderState();
}

class _ShopBodyUnderHeaderState extends State<ShopBodyUnderHeader> {
  late int selectedChip = widget.initialChip;

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collectionGroup('products')
        .where('isActive', isEqualTo: true)
        .where('moderationStatus', isEqualTo: 'approved');

    // Filter by category
    if (widget.category != 'Tous') {
      q = q.where('category', isEqualTo: widget.category);
    }

    // Filter by group
    if (widget.groupId != null) {
      q = q.where('groupId', isEqualTo: widget.groupId);
    }

    return q.orderBy('updatedAt', descending: true).limit(50);
  }

  // Mock articles (kept for grid header display)
  final List<_ShopItem> items = const [
    _ShopItem(
      category: "T-shirts",
      title: "T-shirt MASLIVE\nPremium",
      price: "29€",
      imageAsset: "assets/images/maslivesmall.png",
    ),
    _ShopItem(
      category: "Casquettes",
      title: "Casquette Pastel",
      price: "24€",
      imageAsset: "assets/images/maslivesmall.png",
    ),
    _ShopItem(
      category: "Stickers",
      title: "Pack Stickers",
      price: "9€",
      imageAsset: "assets/images/maslivesmall.png",
    ),
    _ShopItem(
      category: "Accessoires",
      title: "Bracelet MASLIVE",
      price: "12€",
      imageAsset: "assets/images/maslivesmall.png",
    ),
    _ShopItem(
      category: "T-shirts",
      title: "T-shirt MASLIVE\nEdition Carnaval",
      price: "35€",
      imageAsset: "assets/images/maslivesmall.png",
    ),
  ];

  // ---------- TYPO SCALE (stable, premium) ----------
  double _fs(BuildContext context, double base, {double min = 0.95, double max = 1.10}) {
    final w = MediaQuery.sizeOf(context).width;
    final s = (w / 390.0).clamp(min, max);
    return base * s;
  }

  @override
  Widget build(BuildContext context) {
    final h1 = TextStyle(
      fontSize: _fs(context, 18),
      fontWeight: FontWeight.w900,
      color: const Color(0xFF111827),
    );

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // CHIPS
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _ChipsRow(
              selected: selectedChip,
              onChanged: (i) => setState(() => selectedChip = i),
              fontSize: _fs(context, 16),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 10)),

        // DROPDOWN "Tous les groupes"
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _GroupDropdown(
              label: "Tous les groupes",
              onTap: () {},
              fontSize: _fs(context, 18),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // GRID 2 colonnes (carte bleue + carte produit + 2 produits)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                const gap = 10.0;
                final itemW = (w - gap) / 2;

                // Calibrage tailles (comme ta capture)
                final bigH = itemW * 1.12;
                final smallH = itemW * 0.82;

                return Column(
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: itemW,
                          height: bigH,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => MediaGalleriesPage(
                                    groupId: widget.groupId ?? 'all',
                                  ),
                                ),
                              );
                            },
                            child: _GalleryBlueCard(
                              imageAsset: "assets/images/maslivesmall.png",
                              fsTitle: _fs(context, 26),
                              fsLine: _fs(context, 16),
                              fsPill: _fs(context, 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: gap),
                        SizedBox(
                          width: itemW,
                          height: bigH,
                          child: _ProductTileCard(
                            badge: "T-shirts",
                            title: "T-shirt MASLIVE\nPremium",
                            price: "29€",
                            imageAsset: "assets/images/maslivesmall.png",
                            imageUrl: null,
                            onAdd: () {},
                            fsTitle: _fs(context, 18),
                            fsPrice: _fs(context, 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: gap),
                    Row(
                      children: [
                        SizedBox(
                          width: itemW,
                          height: smallH,
                          child: _ProductTileCard(
                            badge: "Casquettes",
                            title: "Casquette Pastel",
                            price: "24€",
                            imageAsset: "assets/images/maslivesmall.png",
                            imageUrl: null,
                            onAdd: () {},
                            fsTitle: _fs(context, 18),
                            fsPrice: _fs(context, 18),
                          ),
                        ),
                        const SizedBox(width: gap),
                        SizedBox(
                          width: itemW,
                          height: smallH,
                          child: _ProductTileCard(
                            badge: "Stickers",
                            title: "Pack Stickers",
                            price: "9€",
                            imageAsset: "assets/images/maslivesmall.png",
                            imageUrl: null,
                            onAdd: () {},
                            fsTitle: _fs(context, 18),
                            fsPrice: _fs(context, 18),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 18)),

        // LISTE D'ARTICLES (scroll vertical)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Text("Articles", style: h1),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 10)),

        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _buildQuery().snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: const [
                        Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.black26),
                        SizedBox(height: 16),
                        Text(
                          'Aucun produit disponible',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final products = docs.map((doc) => GroupProduct.fromMap(doc.id, doc.data())).toList();

            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.74,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final product = products[i];
                    final thumb = product.imageUrl;

                    final card = _ProductCardImproved(
                      badge: product.category,
                      title: product.title,
                      price: product.priceLabel,
                      imageUrl: thumb,
                      imageAsset: "assets/images/maslivesmall.png",
                      onAdd: () {},
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProductDetailPage(
                              groupId: widget.groupId ?? 'all',
                              product: product,
                            ),
                          ),
                        );
                      },
                      fsTitle: _fs(context, 14),
                      fsPrice: _fs(context, 16),
                    );

                    return card;
                  },
                  childCount: products.length,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// ---------------------
/// CHIPS
/// ---------------------
class _ChipsRow extends StatelessWidget {
  const _ChipsRow({
    required this.selected,
    required this.onChanged,
    required this.fontSize,
  });

  final int selected;
  final ValueChanged<int> onChanged;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _ChipPill(label: "Tous", selected: selected == 0, onTap: () => onChanged(0), fontSize: fontSize),
          const SizedBox(width: 10),
          _ChipPill(label: "T-shirts", selected: selected == 1, onTap: () => onChanged(1), fontSize: fontSize),
          const SizedBox(width: 10),
          _ChipPill(label: "Casquettes", selected: selected == 2, onTap: () => onChanged(2), fontSize: fontSize),
          const SizedBox(width: 10),
          _ChipPill(label: "Stickers", selected: selected == 3, onTap: () => onChanged(3), fontSize: fontSize),
          const SizedBox(width: 18),
        ],
      ),
    );
  }
}

class _ChipPill extends StatelessWidget {
  const _ChipPill({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.fontSize,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFB36A), Color(0xFFFF6FB1)],
          )
        : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          gradient: bg,
          color: selected ? null : Colors.white.withOpacity(0.45),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? Colors.white.withOpacity(0.40) : Colors.white.withOpacity(0.60),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: selected ? const Color(0xFF121826) : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }
}

/// ---------------------
/// DROPDOWN
/// ---------------------
class _GroupDropdown extends StatelessWidget {
  const _GroupDropdown({
    required this.label,
    required this.onTap,
    required this.fontSize,
  });

  final String label;
  final VoidCallback onTap;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.70),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.75), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF121826),
              ),
            ),
            const Spacer(),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 28, color: const Color(0xFF121826).withOpacity(0.55)),
          ],
        ),
      ),
    );
  }
}

/// ---------------------
/// TILE - Galerie bleue
/// ---------------------
class _GalleryBlueCard extends StatelessWidget {
  const _GalleryBlueCard({
    required this.imageAsset,
    required this.fsTitle,
    required this.fsLine,
    required this.fsPill,
  });

  final String imageAsset;
  final double fsTitle;
  final double fsLine;
  final double fsPill;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      radius: 30,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0E2A4A), Color(0xFF2F74FF)],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.7, -0.8),
                    radius: 1.2,
                    colors: [Colors.white10, Colors.transparent],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: Opacity(
                opacity: 0.20,
                child: Image.asset(imageAsset, width: 56, height: 56),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PillDark(icon: Icons.photo_library_outlined, label: "Galerie photos", fontSize: fsPill),
                  const SizedBox(height: 18),
                  _PillDarkPlain(label: "Photographes only", fontSize: fsPill),
                  const SizedBox(height: 14),
                  Text(
                    "Photos par les\nphotographes",
                    style: TextStyle(
                      fontSize: fsTitle,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Filtre: Tous les groupes",
                    style: TextStyle(
                      fontSize: fsLine,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Photos à venir",
                    style: TextStyle(
                      fontSize: fsLine,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.85),
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

/// ---------------------
/// TILE - Produit (dans la grille top)
/// ---------------------
class _ProductTileCard extends StatelessWidget {
  const _ProductTileCard({
    required this.badge,
    required this.title,
    required this.price,
    this.imageAsset,
    this.imageUrl,
    required this.onAdd,
    required this.fsTitle,
    required this.fsPrice,
  });

  final String badge;
  final String title;
  final String price;
  final String? imageAsset;
  final String? imageUrl;
  final VoidCallback onAdd;
  final double fsTitle;
  final double fsPrice;

  Widget _thumbLocal({
    required BuildContext context,
    String? imageUrl,
    String? imageAsset,
  }) {
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => Container(
          color: const Color(0xFFF1F3F8),
          child: const Center(child: Icon(Icons.broken_image_outlined, color: Colors.black26, size: 34)),
        ),
      );
    }
    return Container(
      color: const Color(0xFFF1F3F8),
      child: Center(
        child: Image.asset(
          imageAsset ?? 'assets/images/maslivesmall.png',
          width: 58,
          height: 58,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _SoftCard(
      radius: 30,
      child: Container(
        color: Colors.white.withOpacity(0.82),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  flex: 6,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                    child: Stack(
                      children: [
                        Positioned.fill(child: _thumbLocal(context: context, imageUrl: imageUrl, imageAsset: imageAsset)),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.00),
                                  Colors.black.withOpacity(0.06),
                                  Colors.black.withOpacity(0.10),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 7,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _BadgeLight(label: badge),
                        const Spacer(),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: fsTitle,
                            height: 1.12,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF121826),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          price,
                          style: TextStyle(
                            fontSize: fsPrice,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF121826),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              right: 14,
              bottom: 14,
              child: _AddButton(onTap: onAdd),
            ),
          ],
        ),
      ),
    );
    return content;
  }
}

/// ---------------------
/// CARD - Produit (grille Articles)
/// ---------------------
class _ProductCardImproved extends StatelessWidget {
  const _ProductCardImproved({
    required this.badge,
    required this.title,
    required this.price,
    this.imageAsset,
    this.imageUrl,
    required this.onAdd,
    this.onTap,
    required this.fsTitle,
    required this.fsPrice,
  });

  final String badge;
  final String title;
  final String price;
  final String? imageAsset;
  final String? imageUrl;
  final VoidCallback onAdd;
  final VoidCallback? onTap;
  final double fsTitle;
  final double fsPrice;

  @override
  Widget build(BuildContext context) {
    final card = _SoftCard(
      radius: 20,
      child: Container(
        color: Colors.white.withOpacity(0.86),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // IMAGE: 2/3 de la hauteur
            Expanded(
              flex: 2,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: (imageUrl != null && imageUrl!.trim().isNotEmpty)
                          ? Image.network(
                              imageUrl!,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.high,
                              errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFFF1F3F8),
                                child: const Center(
                                  child: Icon(Icons.broken_image_outlined, color: Colors.black26, size: 34),
                                ),
                              ),
                            )
                          : Container(
                              color: const Color(0xFFF1F3F8),
                              child: Center(
                                child: Image.asset(
                                  imageAsset ?? 'assets/images/maslivelogo.png',
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                            ),
                    ),
                    // BADGE en haut gauche
                    Positioned(
                      left: 8,
                      top: 8,
                      child: _BadgeLightSmall(label: badge),
                    ),
                  ],
                ),
              ),
            ),
            // CONTENU: 1/3 de la hauteur
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.replaceAll("\n", " "),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: fsTitle,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF121826),
                        height: 1.10,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            price,
                            style: TextStyle(
                              fontSize: fsPrice,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF121826),
                              height: 1.0,
                            ),
                          ),
                        ),
                        _AddButton(onTap: onAdd, size: 32),
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

    if (onTap != null) return GestureDetector(onTap: onTap, child: card);
    return card;
  }
}

/// ---------------------
/// UI helpers
/// ---------------------
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap, this.size = 48});
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF7BB7), Color(0xFF74C9FF)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 14,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Icon(Icons.add_rounded, color: Colors.white, size: size >= 40 ? 26 : 20),
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child, this.radius = 26});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );
  }
}

class _PillDark extends StatelessWidget {
  const _PillDark({required this.icon, required this.label, required this.fontSize});

  final IconData icon;
  final String label;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.22), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white.withOpacity(0.95)),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: Colors.white.withOpacity(0.95),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillDarkPlain extends StatelessWidget {
  const _PillDarkPlain({required this.label, required this.fontSize});
  final String label;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.16), width: 1),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: Colors.white.withOpacity(0.92),
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgeLight extends StatelessWidget {
  const _BadgeLight({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F8).withOpacity(0.95),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDDE2EE), width: 1),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w900,
          color: Color(0xFF2B3445),
        ),
      ),
    );
  }
}

class _BadgeLightSmall extends StatelessWidget {
  const _BadgeLightSmall({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F8).withOpacity(0.95),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDDE2EE), width: 1),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Color(0xFF2B3445),
        ),
      ),
    );
  }
}

/// ---------------------
/// Model mock
/// ---------------------
class _ShopItem {
  final String category;
  final String title;
  final String price;
  final String imageAsset;

  const _ShopItem({
    required this.category,
    required this.title,
    required this.price,
    required this.imageAsset,
  });
}
