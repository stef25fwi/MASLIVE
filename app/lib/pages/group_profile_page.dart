import 'package:flutter/material.dart';
import '../session/session_scope.dart';
import '../session/require_signin.dart';
import '../services/follow_service.dart';
import '../services/group_repository.dart';
import '../models/group_model.dart';
import '../models/product_model.dart';
import '../widgets/honeycomb_background.dart';
import '../widgets/rainbow_header.dart';
import 'product_detail_page.dart';

class GroupProfilePage extends StatefulWidget {
  const GroupProfilePage({super.key, required this.groupId});
  final String groupId;

  @override
  State<GroupProfilePage> createState() => _GroupProfilePageState();
}

class _GroupProfilePageState extends State<GroupProfilePage> {
  final _repo = GroupRepository();
  String? _selectedCategory;

  final List<String> _categories = [
    'T-shirts',
    'Casquettes',
    'Stickers',
    'Accessoires',
  ];

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);

    return Scaffold(
      body: HoneycombBackground(
        child: StreamBuilder<Group>(
          stream: _repo.watchGroup(widget.groupId),
          builder: (context, groupSnap) {
            if (!groupSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final group = groupSnap.data!;

            return CustomScrollView(
              slivers: [
                // ✅ Header arc-en-ciel
                SliverToBoxAdapter(
                  child: RainbowHeader(
                    title: group.name,
                    trailing: IconButton(
                      icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white),
                      onPressed: () {
                        Navigator.pushNamed(context, '/shop', arguments: widget.groupId);
                      },
                    ),
                  ),
                ),

                // ✅ Bannière + infos groupe
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      // Bannière
                      if (group.bannerUrl != null)
                        Image.network(
                          group.bannerUrl!,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            height: 180,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image, size: 60),
                          ),
                        )
                      else
                        Container(
                          height: 180,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image, size: 60),
                        ),

                      // Infos groupe
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        group.subtitle,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (group.city.isNotEmpty)
                                        Text(
                                          group.city,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                FilledButton.icon(
                                  onPressed: () => requireSignIn(
                                    context,
                                    session: session,
                                    onSignedIn: () async {
                                      await FollowService.instance.toggleFollowGroup(
                                        widget.groupId,
                                        payload: {'name': group.name},
                                      );
                                    },
                                  ),
                                  icon: const Icon(Icons.favorite_border, size: 18),
                                  label: const Text('Suivre'),
                                ),
                              ],
                            ),
                            if (group.description.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                group.description,
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () {},
                                  icon: const Icon(Icons.message_outlined, size: 18),
                                  label: const Text('Contacter'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () {},
                                  icon: const Icon(Icons.calendar_month, size: 18),
                                  label: const Text('Planning'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () {},
                                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                                  label: const Text('Médias'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const Divider(height: 32),

                      // ✅ Filtres catégories
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ChoiceChip(
                                label: const Text('Tous'),
                                selected: _selectedCategory == null,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() => _selectedCategory = null);
                                  }
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
                      const SizedBox(height: 16),
                    ],
                  ),
                ),

                // ✅ Grille de produits
                StreamBuilder<List<GroupProduct>>(
                  stream: _repo.watchProducts(widget.groupId, category: _selectedCategory),
                  builder: (context, productsSnap) {
                    if (!productsSnap.hasData) {
                      return const SliverToBoxAdapter(
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final products = productsSnap.data!;

                    if (products.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  'Aucun produit disponible',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final product = products[index];
                            return _ProductCard(groupId: widget.groupId, product: product);
                          },
                          childCount: products.length,
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.groupId, required this.product});
  final String groupId;
  final GroupProduct product;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(groupId: groupId, product: product),
          ),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: Colors.grey.shade100,
                child: product.imageUrl.isNotEmpty
                    ? Image.network(
                        product.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.image, size: 48);
                        },
                      )
                    : const Icon(Icons.image, size: 48),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.priceLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF7A00),
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
