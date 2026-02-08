import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';

import 'create_product_dialog.dart';
import '../pages/shop_page_new.dart';
import '../services/storage_service.dart';

/// Page de gestion des produits
class AdminProductsPage extends StatefulWidget {
  const AdminProductsPage({super.key, this.shopId = 'global'});

  final String shopId;

  @override
  State<AdminProductsPage> createState() => _AdminProductsPageState();
}

class _AdminProductsPageState extends State<AdminProductsPage> {
  final _firestore = FirebaseFirestore.instance;
  final _storageService = StorageService.instance;
  String _searchQuery = '';
  String? _filterCategory;

  static const _shopAssets = <Map<String, String>>[
    {
      'path': 'assets/shop/capblack1.png',
      'title': 'Casquette MASLIVE',
      'category': 'Accessoires',
    },
    {
      'path': 'assets/shop/tshirtblack.png',
      'title': 'T-shirt MASLIVE',
      'category': 'Vêtements',
    },
    {
      'path': 'assets/shop/mershblack1.png',
      'title': 'Merch MASLIVE',
      'category': 'Vêtements',
    },
    {
      'path': 'assets/shop/croptopblack1.png',
      'title': 'Crop Top MASLIVE',
      'category': 'Vêtements',
    },
    {
      'path': 'assets/shop/croptopblackfrange1.png',
      'title': 'Crop Top Frange',
      'category': 'Vêtements',
    },
    {
      'path': 'assets/shop/porteclésblack01.png',
      'title': 'Porte-clés MASLIVE',
      'category': 'Accessoires',
    },
    {
      'path': 'assets/shop/modelmaslivewhite.png',
      'title': 'Lookbook MASLIVE',
      'category': 'Souvenirs',
    },
    {
      'path': 'assets/shop/modelmaslivewhite2.png',
      'title': 'Lookbook MASLIVE 2',
      'category': 'Souvenirs',
    },
    {
      'path': 'assets/shop/wom2.png',
      'title': 'Collection Femme',
      'category': 'Vêtements',
    },
    {
      'path': 'assets/shop/logomockup.jpeg',
      'title': 'Logo Mockup',
      'category': 'Souvenirs',
    },
    // Les PNG UUID sont aussi seedés automatiquement (titre dérivé du nom de fichier)
  ];

  static final _shopAssetsByPath = <String, Map<String, String>>{
    for (final item in _shopAssets) item['path']!: item,
  };

  Future<List<String>> _loadAllShopImageAssets() async {
    final manifestJson = await rootBundle.loadString('AssetManifest.json');
    final manifest = json.decode(manifestJson) as Map<String, dynamic>;

    final imageAssets =
        manifest.keys
            .where((path) => path.startsWith('assets/shop/'))
            .where(
              (path) =>
                  path.toLowerCase().endsWith('.png') ||
                  path.toLowerCase().endsWith('.jpg') ||
                  path.toLowerCase().endsWith('.jpeg') ||
                  path.toLowerCase().endsWith('.webp'),
            )
            .toList()
          ..sort();

    return imageAssets;
  }

  String _basename(String path) => path.split('/').last;

  String _basenameNoExt(String path) {
    final filename = _basename(path);
    return filename.replaceFirst(RegExp(r'\.[^.]+$'), '');
  }

  String _seedIdForAsset(String assetPath) {
    final base = _basenameNoExt(assetPath);
    final safe = base.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return 'asset_$safe';
  }

  String _titleCase(String input) {
    final parts = input
        .split(RegExp(r'[ _\-]+'))
        .where((p) => p.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return input;
    return parts
        .map((p) => p[0].toUpperCase() + p.substring(1).toLowerCase())
        .join(' ');
  }

  String _deriveTitle(String assetPath) {
    final known = _shopAssetsByPath[assetPath];
    if (known != null && (known['title'] ?? '').isNotEmpty) {
      return known['title']!;
    }

    final base = _basenameNoExt(assetPath);
    final looksLikeUuid = RegExp(r'^[0-9a-fA-F\-]{16,}$').hasMatch(base);
    if (looksLikeUuid) {
      return 'Produit ${base.substring(0, base.length >= 8 ? 8 : base.length)}';
    }

    return _titleCase(base);
  }

  String _deriveCategory(String assetPath) {
    final known = _shopAssetsByPath[assetPath];
    if (known != null && (known['category'] ?? '').isNotEmpty) {
      return known['category']!;
    }

    final name = _basenameNoExt(assetPath).toLowerCase();
    if (name.contains('cap') ||
        name.contains('casquette') ||
        name.contains('porte') ||
        name.contains('key') ||
        name.contains('portecles') ||
        name.contains('portecl')) {
      return 'Accessoires';
    }
    if (name.contains('tshirt') ||
        name.contains('tee') ||
        name.contains('crop') ||
        name.contains('hood') ||
        name.contains('sweat') ||
        name.contains('shirt') ||
        name.contains('wom') ||
        name.contains('merch')) {
      return 'Vêtements';
    }
    if (name.contains('logo') ||
        name.contains('mockup') ||
        name.contains('model')) {
      return 'Souvenirs';
    }
    return 'Souvenirs';
  }

  String _deriveGroupId(String category) {
    switch (category) {
      case 'Vêtements':
        return 'vetements';
      case 'Accessoires':
        return 'accessoires';
      case 'Souvenirs':
      default:
        return 'souvenirs';
    }
  }

  Future<void> _seedShopAssetsProducts() async {
    late final List<String> assetPaths;
    try {
      assetPaths = await _loadAllShopImageAssets();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de lire AssetManifest.json: $e')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Créer des produits depuis assets/shop ?'),
        content: Text(
          'Cela va créer/mettre à jour ${assetPaths.length} produit(s) (1 par image) (shopId: ${widget.shopId}).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    if (!mounted) return;

    if (confirmed != true) return;

    final now = FieldValue.serverTimestamp();

    int priceCentsForCategory(String category) {
      switch (category) {
        case 'Vêtements':
          return 2900;
        case 'Accessoires':
          return 1500;
        case 'Souvenirs':
          return 1200;
        default:
          return 1000;
      }
    }

    // Firestore batch: max 500 opérations. Ici on fait 2 writes par asset.
    const maxOpsPerBatch = 500;
    const opsPerAsset = 2;
    final maxAssetsPerBatch = maxOpsPerBatch ~/ opsPerAsset;

    int totalUpserted = 0;
    for (var i = 0; i < assetPaths.length; i += maxAssetsPerBatch) {
      final slice = assetPaths.sublist(
        i,
        (i + maxAssetsPerBatch) > assetPaths.length
            ? assetPaths.length
            : (i + maxAssetsPerBatch),
      );

      final batch = _firestore.batch();

      for (final assetPath in slice) {
        final title = _deriveTitle(assetPath);
        final category = _deriveCategory(assetPath);
        final priceCents = priceCentsForCategory(category);
        final groupId = _deriveGroupId(category);
        final id = _seedIdForAsset(assetPath);

        final payload = <String, dynamic>{
          // Champs shop
          'title': title,
          'priceCents': priceCents,
          'category': category,
          'groupId': groupId,
          'imageUrl': assetPath, // NOTE: traité comme asset dans le shop
          'isActive': true,
          'moderationStatus': 'approved',
          'stockByVariant': const {'default|default': 999},
          'availableSizes': const ['Unique'],
          'availableColors': const ['Default'],
          'shopId': widget.shopId,
          'updatedAt': now,
          'createdAt': now,

          // Champs legacy admin
          'name': title,
          'description': 'Produit seedé depuis assets/shop',
          'price': (priceCents / 100.0),
          'stock': 999,
          'isAvailable': true,
        };

        final rootRef = _firestore.collection('products').doc(id);
        final shopRef = _firestore
            .collection('shops')
            .doc(widget.shopId)
            .collection('products')
            .doc(id);

        batch.set(rootRef, payload, SetOptions(merge: true));
        batch.set(shopRef, payload, SetOptions(merge: true));
        totalUpserted += 1;
      }

      await batch.commit();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Produits seedés depuis assets/shop ✅ ($totalUpserted)'),
      ),
    );
  }

  static const _defaultCategories = [
    'Vêtements',
    'Accessoires',
    'Souvenirs',
    'Artisanat',
    'Autre',
  ];

  static const _defaultGroups = [
    'Tous',
    'Officiel',
    'Artisan',
    'Premium',
    'Limité',
  ];

  List<String> _categories = List<String>.from(_defaultCategories);
  final List<String> _groups = List<String>.from(_defaultGroups);
  String _selectedGroup = 'Tous';

  @override
  void initState() {
    super.initState();
    _loadProductCategories();
  }

  Future<void> _loadProductCategories() async {
    try {
      final snap = await _firestore
          .collection('productCategories')
          .orderBy('name')
          .limit(200)
          .get();

      final dynamicCats =
          snap.docs
              .map((d) => (d.data()['name'] ?? '').toString().trim())
              .where((c) => c.isNotEmpty)
              .toSet()
              .toList()
            ..sort();

      if (!mounted) return;
      setState(() {
        final merged = <String>[..._defaultCategories];
        for (final c in dynamicCats) {
          if (!merged.contains(c)) merged.add(c);
        }
        _categories = merged;
      });
    } catch (_) {
      // fallback silencieux sur _defaultCategories
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des produits'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Seeder assets/shop',
            onPressed: _seedShopAssetsProducts,
          ),
          IconButton(
            icon: const Icon(Icons.storefront),
            tooltip: 'Aperçu boutique',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ShopPixelPerfectPage(shopId: widget.shopId),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateProductDialog(),
            tooltip: 'Créer un produit',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche et filtres
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Champ de recherche
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher un produit...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
                const SizedBox(height: 12),

                // Filtre groupe
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Text(
                          'Groupe:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      FilterChip(
                        label: const Text('Tous'),
                        selected: _selectedGroup == 'Tous',
                        onSelected: (_) =>
                            setState(() => _selectedGroup = 'Tous'),
                      ),
                      ..._groups
                          .where((g) => g != 'Tous')
                          .map(
                            (group) => Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: FilterChip(
                                label: Text(group),
                                selected: _selectedGroup == group,
                                onSelected: (_) =>
                                    setState(() => _selectedGroup = group),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Filtre catégorie
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Text(
                          'Catégorie:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      FilterChip(
                        label: const Text('Tous'),
                        selected: _filterCategory == null,
                        onSelected: (_) =>
                            setState(() => _filterCategory = null),
                      ),
                      ..._categories.map(
                        (category) => Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: FilterChip(
                            label: Text(category),
                            selected: _filterCategory == category,
                            onSelected: (_) =>
                                setState(() => _filterCategory = category),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Liste des produits
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('products')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var products = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = data['name'] as String? ?? '';
                  final description = data['description'] as String? ?? '';
                  final category = data['category'] as String?;
                  final groupId = data['groupId'] as String? ?? 'officiel';

                  if (_searchQuery.isNotEmpty &&
                      !name.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ) &&
                      !description.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      )) {
                    return false;
                  }

                  if (_filterCategory != null && category != _filterCategory) {
                    return false;
                  }

                  if (_selectedGroup != 'Tous') {
                    final groupMatch =
                        _selectedGroup.toLowerCase() == groupId.toLowerCase();
                    if (!groupMatch) return false;
                  }

                  return true;
                }).toList();

                if (products.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun produit trouvé',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.data!.docs.length} produit(s) au total',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 1,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final doc = products[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildProductCard(doc.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(String productId, Map<String, dynamic> data) {
    final name = data['name'] as String? ?? 'Sans nom';
    final price = (data['price'] as num?)?.toDouble() ?? 0.0;
    final category = data['category'] as String? ?? 'Autre';
    final imageUrl = data['imageUrl'] as String?;
    final stock = data['stock'] as int? ?? 0;
    final isAvailable = data['isAvailable'] as bool? ?? true;

    Widget imageWidget() {
      if (imageUrl == null || imageUrl.trim().isEmpty) {
        return Container(
          color: Colors.grey[200],
          child: const Icon(Icons.image, size: 50),
        );
      }

      final url = imageUrl.trim();
      if (url.startsWith('assets/')) {
        return Image.asset(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.grey[200],
            child: const Icon(Icons.image, size: 50),
          ),
        );
      }

      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[200],
          child: const Icon(Icons.image, size: 50),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image avec bouton d'édition
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: InkWell(
                  onTap: () => _showEditProductDialog(productId, data),
                  child: imageWidget(),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: FloatingActionButton.small(
                  onPressed: () => _editProductPhoto(productId, data),
                  backgroundColor: Colors.blue.shade700,
                  child: const Icon(Icons.edit, size: 18),
                ),
              ),
            ],
          ),

          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['description'] as String? ?? '',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Text(
                    '${price.toStringAsFixed(2)} €',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: isAvailable ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Stock: $stock',
                        style: TextStyle(
                          fontSize: 12,
                          color: stock > 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: () => _showEditProductDialog(productId, data),
                      child: const Text('Modifier'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateProductDialog() async {
    await showCreateProductDialog(context: context, shopId: widget.shopId);
  }

  /// Édite la photo d'un produit
  /// ✅ Utilise StorageService avec structure organisée: products/{shopId}/{productId}/original/0.jpg
  Future<void> _editProductPhoto(
    String productId,
    Map<String, dynamic> data,
  ) async {
    final picker = ImagePicker();
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Éditer la photo'),
        content: const Text('Sélectionnez la source :'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.photo_camera),
            label: const Text('Caméra'),
            onPressed: () => Navigator.pop(context, ImageSource.camera),
          ),
          TextButton.icon(
            icon: const Icon(Icons.photo_library),
            label: const Text('Galerie'),
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    );

    if (source == null) return;

    try {
      final xfile = await picker.pickImage(source: source);
      if (xfile == null) return;

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Upload en cours...')));

      // Upload via StorageService avec structure organisée
      final shopId = (data['shopId'] as String?) ?? widget.shopId;
      final downloadUrl = await _storageService.uploadProductPhoto(
        productId: productId,
        file: xfile,
        shopId: shopId,
        index: 0, // Photo principale
      );

      // Mise à jour du produit
      await _firestore.collection('products').doc(productId).update({
        'imageUrl': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Mise à jour du miroir shop
      await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('products')
          .doc(productId)
          .update({
            'imageUrl': downloadUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Photo mise à jour ✅')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur upload: $e')));
      }
    }
  }

  void _showEditProductDialog(String productId, Map<String, dynamic> data) {
    final nameController = TextEditingController(text: data['name']);
    final descController = TextEditingController(text: data['description']);
    final priceController = TextEditingController(
      text: data['price']?.toString(),
    );
    final stockController = TextEditingController(
      text: data['stock']?.toString() ?? '0',
    );
    final imageController = TextEditingController(text: data['imageUrl']);
    final shopIdFromDoc = (data['shopId'] as String?) ?? widget.shopId;
    String selectedCategory = (data['category'] ?? '').toString().trim();
    if (selectedCategory.isEmpty || !_categories.contains(selectedCategory)) {
      selectedCategory = _categories.isNotEmpty ? _categories.first : 'Autre';
    }
    String selectedGroup = (data['groupId'] ?? data['group'] ?? 'Officiel')
        .toString()
        .trim();
    if (!_groups.contains(selectedGroup)) {
      selectedGroup = _groups.first;
    }
    bool isAvailable = data['isAvailable'] ?? true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 900,
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: AlertDialog(
              title: const Text('Modifier le produit'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom du produit',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: priceController,
                            decoration: const InputDecoration(
                              labelText: 'Prix (€)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: stockController,
                            decoration: const InputDecoration(
                              labelText: 'Stock',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedCategory,
                            decoration: const InputDecoration(
                              labelText: 'Catégorie',
                              border: OutlineInputBorder(),
                            ),
                            items: _categories
                                .map(
                                  (cat) => DropdownMenuItem(
                                    value: cat,
                                    child: Text(cat),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() => selectedCategory = value);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedGroup,
                            decoration: const InputDecoration(
                              labelText: 'Groupe',
                              border: OutlineInputBorder(),
                            ),
                            items: _groups
                                .map(
                                  (grp) => DropdownMenuItem(
                                    value: grp,
                                    child: Text(grp),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() => selectedGroup = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[50],
                      ),
                      child: imageController.text.isNotEmpty
                          ? (imageController.text.startsWith('assets/')
                              ? Image.asset(
                                  imageController.text,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _buildImageError(
                                    icon: Icons.image,
                                    label: 'Asset non trouvé',
                                  ),
                                )
                              : Image.network(
                                  imageController.text,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _buildImageError(
                                    icon: Icons.broken_image,
                                    label: 'URL invalide',
                                  ),
                                ))
                          : _buildImageError(
                              icon: Icons.image_not_supported,
                              label: 'Aucune image',
                            ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: imageController,
                            decoration: const InputDecoration(
                              labelText: 'URL de l\'image',
                              border: OutlineInputBorder(),
                              hintText: 'assets/... ou https://...',
                            ),
                            onChanged: (value) => setDialogState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          onPressed: () async {
                            Navigator.pop(dialogContext);
                            await _editProductPhoto(productId, data);
                          },
                          child: const Icon(Icons.upload),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Disponible'),
                      value: isAvailable,
                      onChanged: (value) =>
                          setDialogState(() => isAvailable = value),
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () async {
                        Navigator.pop(dialogContext);
                        final productName = ((data['name'] ?? data['title']) ?? '')
                            .toString();
                        await _deleteProduct(
                          productId,
                          productName,
                          shopId: shopIdFromDoc,
                        );
                      },
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text(
                        'Supprimer',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () async {
                    final navigator = Navigator.of(dialogContext);
                    final messenger = ScaffoldMessenger.of(context);

                    try {
                      final price = double.tryParse(priceController.text) ?? 0.0;
                      final stock = int.tryParse(stockController.text) ?? 0;

                      await _firestore.collection('products').doc(productId).update(
                        {
                          'name': nameController.text.trim(),
                          'title': nameController.text.trim(),
                          'description': descController.text.trim(),
                          'price': price,
                          'priceCents': (price * 100).round(),
                          'stock': stock,
                          'stockByVariant': <String, int>{'default|default': stock},
                          'category': selectedCategory,
                          'groupId': selectedGroup.toLowerCase(),
                          'group': selectedGroup,
                          'imageUrl': imageController.text.trim().isNotEmpty
                              ? imageController.text.trim()
                              : null,
                          'isAvailable': isAvailable,
                          'isActive': isAvailable,
                          'moderationStatus': 'approved',
                          'updatedAt': FieldValue.serverTimestamp(),
                        },
                      );

                      try {
                        await _firestore
                            .collection('shops')
                            .doc(shopIdFromDoc)
                            .collection('products')
                            .doc(productId)
                            .set({
                              'shopId': shopIdFromDoc,
                              'name': nameController.text.trim(),
                              'title': nameController.text.trim(),
                              'description': descController.text.trim(),
                              'price': price,
                              'priceCents': (price * 100).round(),
                              'stock': stock,
                              'stockByVariant': <String, int>{
                                'default|default': stock,
                              },
                              'category': selectedCategory,
                              'groupId': selectedGroup.toLowerCase(),
                              'group': selectedGroup,
                              'imageUrl': imageController.text.trim().isNotEmpty
                                  ? imageController.text.trim()
                                  : null,
                              'isAvailable': isAvailable,
                              'isActive': isAvailable,
                              'moderationStatus': 'approved',
                              'updatedAt': FieldValue.serverTimestamp(),
                            }, SetOptions(merge: true));
                      } catch (_) {
                        // ignore
                      }

                      if (!mounted) return;
                      navigator.pop();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Produit modifié avec succès'),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      messenger.showSnackBar(SnackBar(content: Text('Erreur: $e')));
                    }
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageError({required IconData icon, required String label}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Future<void> _deleteProduct(
    String productId,
    String productName, {
    String? shopId,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Voulez-vous vraiment supprimer "$productName" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('products').doc(productId).delete();

        // miroir shop (best-effort)
        await _firestore
            .collection('shops')
            .doc(shopId ?? widget.shopId)
            .collection('products')
            .doc(productId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Produit supprimé')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
        }
      }
    }
  }
}
