import 'package:flutter/material.dart';
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
              child: StreamBuilder<List<GroupProduct>>(
                stream: _repo.watchProducts(widget.groupId, category: _selectedCategory),
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

  const _ProductCard({required this.groupId, required this.product});

  @override
  Widget build(BuildContext context) {
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
              child: AspectRatio(
                aspectRatio: 1.2,
                child: product.imageUrl.isEmpty
                    ? Container(color: Colors.black.withValues(alpha: 0.06))
                    : Image.network(product.imageUrl, fit: BoxFit.cover),
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
