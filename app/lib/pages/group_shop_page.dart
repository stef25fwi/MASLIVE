import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/group_repository.dart';
import '../services/gallery_counts_service.dart';
import '../models/product_model.dart';
import 'product_detail_page.dart';
import 'media_galleries_page.dart';

class GroupShopPage extends StatefulWidget {
  const GroupShopPage({super.key, required this.groupId});
  final String groupId;

  @override
  State<GroupShopPage> createState() => _GroupShopPageState();
}

class _GroupShopPageState extends State<GroupShopPage> {
  final _repo = GroupRepository();
  String? _selectedCategory;

  final List<String> _categories = const [
    'T-shirts',
    'Casquettes',
    'Stickers',
    'Accessoires',
  ];

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Shop Groupe')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Catégories
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Tous'),
                      selected: _selectedCategory == null,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedCategory = null);
                      },
                    ),
                    const SizedBox(width: 8),
                    ..._categories.map((cat) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: _selectedCategory == cat,
                          onSelected: (selected) {
                            setState(() => _selectedCategory = selected ? cat : null);
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Grid
            Expanded(
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: uid == null
                    ? const Stream.empty()
                    : FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
                builder: (context, userSnap) {
                  final data = userSnap.data?.data();
                  final role = (data?['role'] ?? 'user').toString();
                  final groupId = (data?['groupId'] as String?)?.trim();
                  final isGroupAdmin = role == 'group' && groupId == widget.groupId;

                  return StreamBuilder<List<GroupProduct>>(
                    stream: _repo.watchProductsWithPending(
                      widget.groupId,
                      category: _selectedCategory,
                      includePending: isGroupAdmin,
                    ),
                    builder: (context, productsSnap) {
                      if (!productsSnap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final products = productsSnap.data!;

                      return GridView.builder(
                        itemCount: products.length + 1,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.78,
                        ),
                        itemBuilder: (context, i) {
                          if (i == 0) {
                            return _GalleryTile(
                              groupId: widget.groupId,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MediaGalleriesPage(groupId: widget.groupId),
                                  ),
                                );
                              },
                            );
                          }

                          final product = products[i - 1];
                          return _ProductCard(
                            groupId: widget.groupId,
                            product: product,
                            showPendingBadge: isGroupAdmin,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final String groupId;
  final GroupProduct product;
  final bool showPendingBadge;

  const _ProductCard({
    required this.groupId,
    required this.product,
    required this.showPendingBadge,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = product.isPending;
    final isRejected = product.isRejected;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailPage(groupId: groupId, product: product),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              blurRadius: 18,
              offset: const Offset(0, 10),
              color: Colors.black.withValues(alpha: 0.06),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1.2,
                    child: product.imageUrl.isEmpty
                        ? Container(color: Colors.black.withValues(alpha: 0.06))
                        : Image.network(product.imageUrl, fit: BoxFit.cover),
                  ),
                  if (showPendingBadge && (isPending || isRejected))
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isRejected
                              ? Colors.red.withValues(alpha: 0.78)
                              : Colors.black.withValues(alpha: 0.68),
                          borderRadius: BorderRadius.circular(999),
                        ),
                          child: Text(
                          isRejected ? 'Refusé' : 'En attente',
                            style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  if (showPendingBadge && (isPending || isRejected))
                    Positioned.fill(
                      child: Container(color: Colors.white.withValues(alpha: 0.55)),
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
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.priceLabel,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
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

class _GalleryTile extends StatefulWidget {
  final String groupId;
  final VoidCallback onTap;

  const _GalleryTile({required this.groupId, required this.onTap});

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

        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: widget.onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1F2A37), Color(0xFF3B82F6)],
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                  color: Colors.black.withValues(alpha: 0.10),
                ),
              ],
            ),
            child: Padding(
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
                    'Photos du groupe',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Filtre: ${widget.groupId}',
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
          ),
        );
      },
    );
  }
}
