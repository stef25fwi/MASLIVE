import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/group_repository.dart';
import '../models/product_model.dart';
import 'product_detail_page.dart';

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
                      if (products.isEmpty) {
                        return const Center(child: Text('Aucun produit disponible'));
                      }

                      return GridView.builder(
                        itemCount: products.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.78,
                        ),
                        itemBuilder: (context, i) {
                          final product = products[i];
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
