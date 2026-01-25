import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cart_page.dart';

class ShopPixelPerfectPage extends StatefulWidget {
  const ShopPixelPerfectPage({super.key});

  @override
  State<ShopPixelPerfectPage> createState() => _ShopPixelPerfectPageState();
}

class _ShopPixelPerfectPageState extends State<ShopPixelPerfectPage> {
  int catIndex = 0;
  String selectedGroup = "Tous les groupes";

  static const _bg = Color(0xFFF6F7FB);

  // Compact (comme ton mockup)
  static const double _pageHPad = 16;
  static const double _gridGap = 12;

  static const double _headerH = 178;          // hauteur header
  static const double _filtersPinnedH = 78;    // chips + dropdown plus bas
  static const double _chipsH = 34;            // chips plus bas
  static const double _dropdownH = 40;         // dropdown plus bas

  static const double _cardRadius = 24;
  static const double _innerRadius = 18;

  static const double _addSize = 44;
  static const double _addRadius = 16;

  final cats = const ["Tous", "T-shirts", "Casquettes", "Stickers"];
  final groups = const ["Tous les groupes", "Akiyo", "Kassav", "MasK"];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final contentW = size.width - (_pageHPad * 2);
    final tileW = (contentW - _gridGap) / 2;

    // ✅ Hauteurs qui matchent mieux ta capture (A54)
    final bigTileH = tileW * 0.78;      // plus haut => image plus grande
    final smallTileH = tileW * 0.46;    // bandanas plus bas

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _Header(
              height: _headerH,
              onCartTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CartPage()),
                );
              },
            ),

            // ✅ PINNED : ne scroll pas
            SliverPersistentHeader(
              pinned: true,
              delegate: _PinnedDelegate(
                height: _filtersPinnedH,
                child: _FiltersBar(
                  cats: cats,
                  selectedIndex: catIndex,
                  onCatChanged: (i) => setState(() => catIndex = i),
                  groups: groups,
                  selectedGroup: selectedGroup,
                  onGroupChanged: (v) => setState(() => selectedGroup = v),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(_pageHPad, 12, _pageHPad, 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: tileW,
                          height: bigTileH,
                          child: _PhotoTile(
                            title: "Boutique photos",
                            subtitle: "Photographes only",
                            onTap: () {},
                          ),
                        ),
                        const SizedBox(width: _gridGap),
                        SizedBox(
                          width: tileW,
                          height: bigTileH,
                          child: _ProductTile(
                            title: "Casquette\nMASLIVE",
                            price: "25,00 €",
                            image: const _AssetOrFallback(
                              assetPath: "assets/shop/casquette.jpg",
                              fallbackIcon: Icons.checkroom_outlined,
                            ),
                            onAdd: () {},
                            onTap: () {},
                            compact: false,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: _gridGap),
                    Row(
                      children: [
                        SizedBox(
                          width: tileW,
                          height: bigTileH,
                          child: _ProductTile(
                            title: "T-shirt\nMASLIVE",
                            price: "25,00 €",
                            image: const _AssetOrFallback(
                              assetPath: "assets/shop/tshirt.jpg",
                              fallbackIcon: Icons.checkroom_outlined,
                            ),
                            onAdd: () {},
                            onTap: () {},
                            compact: false,
                          ),
                        ),
                        const SizedBox(width: _gridGap),
                        SizedBox(
                          width: tileW,
                          height: bigTileH,
                          child: _ProductTile(
                            title: "Porte-clé\nMASLIVE",
                            price: "8,00 €",
                            image: const _AssetOrFallback(
                              assetPath: "assets/shop/porte_cle.jpg",
                              fallbackIcon: Icons.key_outlined,
                            ),
                            onAdd: () {},
                            onTap: () {},
                            compact: false,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: _gridGap),
                    Row(
                      children: [
                        SizedBox(
                          width: tileW,
                          height: smallTileH,
                          child: _ProductTile(
                            title: "Bandana\nMASLIVE",
                            price: "20,00 €",
                            image: const _AssetOrFallback(
                              assetPath: "assets/shop/bandana.jpg",
                              fallbackIcon: Icons.auto_awesome_outlined,
                            ),
                            onAdd: () {},
                            onTap: () {},
                            compact: true,
                          ),
                        ),
                        const SizedBox(width: _gridGap),
                        SizedBox(
                          width: tileW,
                          height: smallTileH,
                          child: _ProductTile(
                            title: "Bandana\nMASLIVE",
                            price: "10,00 €",
                            image: const _AssetOrFallback(
                              assetPath: "assets/shop/bandana2.jpg",
                              fallbackIcon: Icons.auto_awesome_outlined,
                            ),
                            onAdd: () {},
                            onTap: () {},
                            compact: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(_pageHPad, 0, _pageHPad, 10),
                child: const Text(
                  "Articles",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(_pageHPad, 0, _pageHPad, 18),
                child: const _EmptyStateCard(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

/// -------------------- HEADER --------------------
class _Header extends StatelessWidget {
  const _Header({required this.height, required this.onCartTap});
  final double height;
  final VoidCallback onCartTap;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: height,
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFFC36A),
                    Color(0xFFFF7BA7),
                    Color(0xFF7CCBFF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Spacer(),
                        _CartButton(onTap: onCartTap),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "La Boutique",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 46,
                        height: 1.0,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white.withOpacity(0.22)),
                          ),
                          child: const Text(
                            "Trouve des produits officiels et des photos\nd'événements.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ),
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

class _CartButton extends StatelessWidget {
  const _CartButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.16),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.22)),
          ),
          child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 34),
        ),
      ),
    );
  }
}

/// -------------------- PINNED FILTERS --------------------
class _PinnedDelegate extends SliverPersistentHeaderDelegate {
  _PinnedDelegate({required this.height, required this.child});
  final double height;
  final Widget child;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  bool shouldRebuild(covariant _PinnedDelegate oldDelegate) =>
      oldDelegate.height != height || oldDelegate.child != child;
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.cats,
    required this.selectedIndex,
    required this.onCatChanged,
    required this.groups,
    required this.selectedGroup,
    required this.onGroupChanged,
  });

  final List<String> cats;
  final int selectedIndex;
  final ValueChanged<int> onCatChanged;

  final List<String> groups;
  final String selectedGroup;
  final ValueChanged<String> onGroupChanged;

  static const double chipsH = 34;
  static const double dropdownH = 40;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F7FB),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          SizedBox(
            height: chipsH,
            child: Row(
              children: [
                _SelectedChip(
                  label: cats[0],
                  selected: selectedIndex == 0,
                  onTap: () => onCatChanged(0),
                ),
                const SizedBox(width: 18),
                _TabText(label: cats[1], onTap: () => onCatChanged(1)),
                const SizedBox(width: 18),
                _TabText(label: cats[2], onTap: () => onCatChanged(2)),
                const SizedBox(width: 18),
                _TabText(label: cats[3], onTap: () => onCatChanged(3)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: dropdownH,
            child: _GroupDropdown(
              value: selectedGroup,
              items: groups,
              onChanged: onGroupChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedChip extends StatelessWidget {
  const _SelectedChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFFFFC36A), Color(0xFFFF7BA7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF111827)),
        ),
      ),
    );
  }
}

class _TabText extends StatelessWidget {
  const _TabText({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Color(0xFF111827),
        ),
      ),
    );
  }
}

class _GroupDropdown extends StatelessWidget {
  const _GroupDropdown({required this.value, required this.items, required this.onChanged});
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
            items: items
                .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ),
    );
  }
}

/// -------------------- TILES --------------------
class _BaseCard extends StatelessWidget {
  const _BaseCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_ShopPixelPerfectPageState._cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_ShopPixelPerfectPageState._cardRadius),
        child: child,
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.title, required this.subtitle, required this.onTap});
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            // bandeau bleu haut
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 70,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4E7CCB), Color(0xFF7AA6F3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(color: Colors.white.withOpacity(0.92), fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),

            // contenu bas
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 82, 14, 14),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  "Boutique\nphotos",
                  style: const TextStyle(
                    fontSize: 28,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.title,
    required this.price,
    required this.image,
    required this.onAdd,
    required this.onTap,
    required this.compact,
  });

  final String title;
  final String price;
  final Widget image;
  final VoidCallback onAdd;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(_ShopPixelPerfectPageState._innerRadius),
                    child: SizedBox(
                      height: compact ? 54 : 96, // ✅ image plus grande sur grandes tuiles
                      width: double.infinity,
                      child: image,
                    ),
                  ),
                  SizedBox(height: compact ? 8 : 10),
                  Text(
                    title,
                    maxLines: compact ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 18 : 26,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    price,
                    style: TextStyle(
                      fontSize: compact ? 16 : 18,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),

            // ✅ Bouton + overlay (fini le "+" dans l'image)
            Positioned(
              right: 12,
              bottom: 12,
              child: _AddButton(onTap: onAdd),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_ShopPixelPerfectPageState._addRadius),
      child: Ink(
        width: _ShopPixelPerfectPageState._addSize,
        height: _ShopPixelPerfectPageState._addSize,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF7BA7), Color(0xFF7CCBFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(_ShopPixelPerfectPageState._addRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.16),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

/// -------------------- EMPTY STATE --------------------
class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard();

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
        child: Column(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(Icons.shopping_bag_outlined, size: 42, color: Colors.black.withOpacity(0.35)),
            ),
            const SizedBox(height: 16),
            const Text(
              "Aucun produit disponible",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
            ),
            const SizedBox(height: 10),
            Text(
              "Reviens plus tard ou change de catégorie.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black.withOpacity(0.55)),
            ),
          ],
        ),
      ),
    );
  }
}

/// -------------------- IMAGE helper --------------------
/// Mets tes vraies images dans assets/shop/*.jpg
/// Si absent => fallback propre (pas de + fantôme)
class _AssetOrFallback extends StatelessWidget {
  const _AssetOrFallback({
    required this.assetPath,
    required this.fallbackIcon,
  });

  final String assetPath;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF1F2F6), Color(0xFFE9ECF5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Image.asset(
        assetPath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Center(
            child: Icon(fallbackIcon, size: 34, color: Colors.black.withOpacity(0.35)),
          );
        },
      ),
    );
  }
}

class _ShopPixelPerfectPageState extends State<ShopPixelPerfectPage> {
  int catIndex = 0;
  String selectedGroup = "Tous les groupes";

  // --- Ajustements pixel-perfect (tuning) ---
  static const double pageHPad = 16;
  static const double gap12 = 12;

  // Hauteurs (tu peux micro-ajuster si besoin)
  static const double headerExpandedH = 170; // header
  static const double filterPinnedH = 86; // chips + dropdown (réduit)

  // Bouton +
  static const double addBtnSize = 44;
  static const double addBtnRadius = 16;

  // Cards
  static const double cardRadius = 22;
  static const double cardInnerRadius = 18;

  final cats = const ["Tous", "T-shirts", "Casquettes", "Stickers"];
  final groups = const ["Tous les groupes", "Akiyo", "Kassav", "MasK"];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final contentW = size.width - (pageHPad * 2);
    final tileW = (contentW - gap12) / 2;
    final bigTileH = (tileW * 0.74).roundToDouble();
    final compactTileH = (tileW * 0.44).roundToDouble();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _ShopHeaderSliver(
              expandedHeight: headerExpandedH,
              onCartTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CartPage()),
                );
              },
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _PinnedFilterHeaderDelegate(
                height: filterPinnedH,
                child: _PinnedFilterBar(
                  cats: cats,
                  selectedIndex: catIndex,
                  onCatChanged: (i) => setState(() => catIndex = i),
                  groups: groups,
                  selectedGroup: selectedGroup,
                  onGroupChanged: (v) => setState(() => selectedGroup = v),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(pageHPad, 12, pageHPad, 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: tileW,
                          height: bigTileH,
                          child: _PhotoShopTile(
                            title: "Boutique photos",
                            subtitle: "Photographes only",
                            priceText: "20,000 €",
                            onTap: () {},
                          ),
                        ),
                        SizedBox(width: gap12),
                        SizedBox(
                          width: tileW,
                          height: bigTileH,
                          child: _ProductTile(
                            category: "Casquettes",
                            title: "Casquette\nMASLIVE",
                            price: "25,00 €",
                            image: const _MockImage(kind: _MockKind.cap),
                            compact: false,
                            onAdd: () {},
                            onTap: () {},
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: gap12),
                    Row(
                      children: [
                        SizedBox(
                          width: tileW,
                          height: bigTileH,
                          child: _ProductTile(
                            category: "T-shirts",
                            title: "T-shirt\nMASLIVE",
                            price: "25,00 €",
                            image: const _MockImage(kind: _MockKind.tshirt),
                            compact: false,
                            onAdd: () {},
                            onTap: () {},
                          ),
                        ),
                        SizedBox(width: gap12),
                        SizedBox(
                          width: tileW,
                          height: bigTileH,
                          child: _ProductTile(
                            category: "Accessoires",
                            title: "Porte-clé\nMASLIVE",
                            price: "8,00 €",
                            image: const _MockImage(kind: _MockKind.keychain),
                            compact: false,
                            onAdd: () {},
                            onTap: () {},
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: gap12),
                    Row(
                      children: [
                        SizedBox(
                          width: tileW,
                          height: compactTileH,
                          child: _ProductTile(
                            category: "Bandana",
                            title: "Bandana\nMASLIVE",
                            price: "20,00 €",
                            image: const _MockImage(kind: _MockKind.bandana),
                            compact: true,
                            onAdd: () {},
                            onTap: () {},
                          ),
                        ),
                        SizedBox(width: gap12),
                        SizedBox(
                          width: tileW,
                          height: compactTileH,
                          child: _ProductTile(
                            category: "Bandana",
                            title: "Bandana\nMASLIVE",
                            price: "10,00 €",
                            image: const _MockImage(kind: _MockKind.bandana2),
                            compact: true,
                            onAdd: () {},
                            onTap: () {},
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Titre "Articles"
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(pageHPad, 0, pageHPad, 10),
                child: Text(
                  "Articles",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ),

            // Empty state card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(pageHPad, 0, pageHPad, 18),
                child: _EmptyStateCard(
                  title: "Aucun produit disponible",
                  subtitle: "Reviens plus tard ou change de catégorie.",
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}
/// --------------------------------------------
/// HEADER (dégradé + titre + gros panier)
/// --------------------------------------------
class _ShopHeaderSliver extends StatelessWidget {
  const _ShopHeaderSliver({required this.expandedHeight, required this.onCartTap});

  final double expandedHeight;
  final VoidCallback onCartTap;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: false,
      floating: false,
      snap: false,
      expandedHeight: expandedHeight,
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFFC36A), Color(0xFFFF7BA7), Color(0xFF7CCBFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Opacity(
              opacity: 0.06,
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(image: AssetImage("assets/honeycomb.png"), fit: BoxFit.cover),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(children: [const Spacer(), _HeaderCartButton(onTap: onCartTap)]),
                    const SizedBox(height: 4),
                    const Text(
                      "La Boutique",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 44,
                        height: 1.0,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                            ),
                            child: const Text(
                              "Trouve des produits officiels et des photos\nd'événements.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16, height: 1.15),
                            ),
                          ),
                        ),
                      ),
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

class _HeaderCartButton extends StatelessWidget {
  const _HeaderCartButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: const Icon(Icons.shopping_bag_outlined, size: 30, color: Colors.white),
        ),
      ),
    );
  }
}

class _PinnedFilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  _PinnedFilterHeaderDelegate({required this.height, required this.child});
  final double height;
  final Widget child;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override
  bool shouldRebuild(covariant _PinnedFilterHeaderDelegate oldDelegate) =>
      oldDelegate.height != height || oldDelegate.child != child;
}

class _PinnedFilterBar extends StatelessWidget {
  const _PinnedFilterBar({
    required this.cats,
    required this.selectedIndex,
    required this.onCatChanged,
    required this.groups,
    required this.selectedGroup,
    required this.onGroupChanged,
  });

  final List<String> cats;
  final int selectedIndex;
  final ValueChanged<int> onCatChanged;
  final List<String> groups;
  final String selectedGroup;
  final ValueChanged<String> onGroupChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F7FB),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          children: [
            SizedBox(
              height: 36,
              child: Row(
                children: [
                  _ChipSelected(label: cats[0], selected: selectedIndex == 0, onTap: () => onCatChanged(0)),
                  const SizedBox(width: 16),
                  _ChipText(label: cats[1], onTap: () => onCatChanged(1)),
                  const SizedBox(width: 16),
                  _ChipText(label: cats[2], onTap: () => onCatChanged(2)),
                  const SizedBox(width: 16),
                  _ChipText(label: cats[3], onTap: () => onCatChanged(3)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 42,
              child: _GroupDropdown(value: selectedGroup, items: groups, onChanged: onGroupChanged),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipSelected extends StatelessWidget {
  const _ChipSelected({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFFFFC36A), Color(0xFFFF7BA7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: selected ? null : Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF111827)),
          ),
        ),
      ),
    );
  }
}

class _ChipText extends StatelessWidget {
  const _ChipText({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
    );
  }
}

class _GroupDropdown extends StatelessWidget {
  const _GroupDropdown({required this.value, required this.items, required this.onChanged});

  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 26),
            items: items
                .map((e) => DropdownMenuItem<String>(
                      value: e,
                      child: Text(e, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ),
    );
  }
}

class _PhotoShopTile extends StatelessWidget {
  const _PhotoShopTile({required this.title, required this.subtitle, required this.priceText, required this.onTap});

  final String title;
  final String subtitle;
  final String priceText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_ShopPixelPerfectPageState.cardRadius),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 62,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4E7CCB), Color(0xFF7AA6F3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.photo_camera_outlined, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 74, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  Text(
                    "Boutique\nphotos",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, height: 1.05, color: Color(0xFF111827)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    priceText,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
                  ),
                ],
              ),
            ),
            Positioned(right: 12, bottom: 12, child: _AddButton(onTap: () {})),
          ],
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.category,
    required this.title,
    required this.price,
    required this.image,
    required this.compact,
    required this.onAdd,
    required this.onTap,
  });

  final String category;
  final String title;
  final String price;
  final Widget image;
  final bool compact;
  final VoidCallback onAdd;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_ShopPixelPerfectPageState.cardRadius),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(_ShopPixelPerfectPageState.cardInnerRadius),
                    child: SizedBox(
                      height: compact ? 56 : 86,
                      width: double.infinity,
                      child: image,
                    ),
                  ),
                  SizedBox(height: compact ? 8 : 10),
                  Text(
                    title,
                    maxLines: compact ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 16 : 22,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    price,
                    style: TextStyle(fontSize: compact ? 16 : 18, fontWeight: FontWeight.w900, color: const Color(0xFF111827)),
                  ),
                ],
              ),
            ),
            Positioned(right: 12, bottom: 12, child: _AddButton(onTap: onAdd)),
          ],
        ),
      ),
    );
  }
}

class _BaseCard extends StatelessWidget {
  const _BaseCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_ShopPixelPerfectPageState.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_ShopPixelPerfectPageState.cardRadius),
        child: child,
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_ShopPixelPerfectPageState.addBtnRadius),
      child: Ink(
        width: _ShopPixelPerfectPageState.addBtnSize,
        height: _ShopPixelPerfectPageState.addBtnSize,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF7BA7), Color(0xFF7CCBFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(_ShopPixelPerfectPageState.addBtnRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          children: [
            const SizedBox(height: 6),
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.shopping_bag_outlined, size: 40, color: Colors.black.withValues(alpha: 0.35)),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black.withValues(alpha: 0.55)),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

enum _MockKind { cap, tshirt, keychain, bandana, bandana2 }

class _MockImage extends StatelessWidget {
  const _MockImage({required this.kind});
  final _MockKind kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF1F2F6),
            const Color(0xFFE9ECF5),
            if (kind == _MockKind.cap) const Color(0xFFE6F0FF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          switch (kind) {
            _MockKind.cap => Icons.local_mall_outlined,
            _MockKind.tshirt => Icons.checkroom_outlined,
            _MockKind.keychain => Icons.key_outlined,
            _MockKind.bandana => Icons.auto_awesome_outlined,
            _MockKind.bandana2 => Icons.auto_awesome_outlined,
          },
          size: 32,
          color: Colors.black.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}
