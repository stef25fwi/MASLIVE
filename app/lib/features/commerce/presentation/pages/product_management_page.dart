import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/commerce_repository.dart';
import '../../domain/commerce_models.dart';
import '../../domain/commerce_models.dart' as cm show Category;
import '../controllers/product_controller.dart';
import '../widgets/change_notifier_provider_lite.dart';
import '../../../../ui/snack/top_snack_bar.dart';
import '../../../../ui/widgets/storage_image.dart';
import 'shop_media_gallery_page.dart';
import 'package:masslive/ui_kit/tokens/maslive_tokens.dart';
import '../../../../ui/widgets/maslive_text_field.dart';

// ---------------------------------------------------------------------------
// ProductManagementPage — Admin UI
// ---------------------------------------------------------------------------

class ProductManagementPage extends StatefulWidget {
  final String shopId;
  final int cartCountBadge;

  const ProductManagementPage({
    super.key,
    required this.shopId,
    this.cartCountBadge = 0,
  });

  @override
  State<ProductManagementPage> createState() => _ProductManagementPageState();
}

class _ProductManagementPageState extends State<ProductManagementPage> {
  late final ProductController controller;
  final TextEditingController searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller = ProductController(shopId: widget.shopId);
    searchCtrl.addListener(() => controller.setSearch(searchCtrl.text));
    _prepareMediaAccess();
  }

  Future<void> _prepareMediaAccess() async {
    await controller.storageRepo.ensureProductUploadFolder(
      shopId: widget.shopId,
    );
    if (kIsWeb) return;
    try {
      await [Permission.camera, Permission.photos].request();
    } catch (_) {
      // ignore
    }
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return ChangeNotifierProviderLite(
      notifier: controller,
      child: Builder(
        builder: (context) {
          final c = ChangeNotifierProviderLite.of<ProductController>(context);

          return Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              top: false,
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.fromLTRB(10, topPad + 12, 10, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                          color: Colors.black.withAlpha(15),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Gestion Produits',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Galerie photos',
                          icon: const Icon(Icons.photo_library_outlined),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ShopMediaGalleryPage(shopId: widget.shopId),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _AdminCartBadge(count: widget.cartCountBadge),
                        const SizedBox(width: 10),
                        FilledButton(
                          onPressed: () async {
                            final created = await showDialog<Product?>(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => ProductEditDialog(
                                shopId: widget.shopId,
                                existing: null,
                              ),
                            );
                            if (created != null) {
                              await c.createOrUpdate(created, isNew: true);
                              if (context.mounted) {
                                TopSnackBar.show(
                                  context,
                                  const SnackBar(
                                    content: Text('Produit ajouté'),
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text('Ajouter'),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
                    child: TextField(
                      controller: searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Rechercher (nom, tags)…',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: MasliveTokens.bg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                    child: ProductFiltersBar(controller: c),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        StreamBuilder<List<Product>>(
                          stream: c.streamProducts(),
                          builder: (context, snap) {
                            if (snap.hasError) {
                              return Center(
                                child: Text('Erreur: ${snap.error}'),
                              );
                            }
                            if (!snap.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            final products = snap.data!;
                            if (products.isEmpty) {
                              return const Center(child: Text('Aucun produit'));
                            }

                            final w = MediaQuery.of(context).size.width;
                            final cross = w >= 1100
                                ? 4
                                : (w >= 800 ? 3 : (w >= 520 ? 2 : 1));

                            return Padding(
                              padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
                              child: GridView.builder(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: cross,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 0.92,
                                    ),
                                itemCount: products.length,
                                itemBuilder: (_, i) => ProductTileAdmin(
                                  product: products[i],
                                  onEdit: () async {
                                    final updated = await showDialog<Product?>(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (_) => ProductEditDialog(
                                        shopId: widget.shopId,
                                        existing: products[i],
                                      ),
                                    );
                                    if (updated != null) {
                                      await c.createOrUpdate(
                                        updated,
                                        isNew: false,
                                      );
                                      if (context.mounted) {
                                        TopSnackBar.show(
                                          context,
                                          const SnackBar(
                                            content: Text('Produit enregistré'),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  onPhotos: () => showDialog<void>(
                                    context: context,
                                    barrierDismissible: true,
                                    builder: (_) => ProductImagesEditorDialog(
                                      controller: c,
                                      product: products[i],
                                    ),
                                  ),
                                  onStock: () => showDialog<void>(
                                    context: context,
                                    builder: (_) => StockQuickEditorDialog(
                                      controller: c,
                                      product: products[i],
                                    ),
                                  ),
                                  onDuplicate: () => c.duplicate(
                                    products[i],
                                    keepImages: true,
                                  ),
                                  onToggleActive: () =>
                                      c.toggleActive(products[i]),
                                  onDelete: () async {
                                    final ok = await _confirm(
                                      context,
                                      title: 'Supprimer le produit ?',
                                      message: 'Cette action est définitive.',
                                    );
                                    if (ok) await c.deleteProduct(products[i]);
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                        AnimatedBuilder(
                          animation: c,
                          builder: (context, child) {
                            if (!c.busy) return const SizedBox.shrink();
                            return Container(
                              color: Colors.black.withAlpha(20),
                              child: const Center(
                                child: SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ProductFiltersBar
// ---------------------------------------------------------------------------

class ProductFiltersBar extends StatelessWidget {
  final ProductController controller;
  const ProductFiltersBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<cm.Category>>(
      stream: controller.streamCategories(),
      builder: (context, snap) {
        final categories = snap.data ?? const <cm.Category>[];

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              final f = controller.filter;

              return Row(
                children: [
                  _FilterTile(
                    label: f.categoryId == null ? 'Catégorie' : 'Catégorie ✓',
                    active: f.categoryId != null,
                    icon: Icons.category_outlined,
                    onTap: () async {
                      final selected = await _pickFromMenu<String?>(
                        context,
                        title: 'Catégorie',
                        items: [
                          const _MenuItem(value: null, label: 'Toutes'),
                          ...categories.map(
                            (c) => _MenuItem(value: c.id, label: c.name),
                          ),
                        ],
                        initial: f.categoryId,
                      );
                      controller.setFilter(
                        f.copyWith(
                          categoryId: selected,
                          resetCategory: selected == null,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  _FilterTile(
                    label: f.onlyActive == null
                        ? 'Visibilité'
                        : (f.onlyActive == true ? 'Actifs ✓' : 'Inactifs ✓'),
                    active: f.onlyActive != null,
                    icon: Icons.visibility_outlined,
                    onTap: () async {
                      final selected = await _pickFromMenu<bool?>(
                        context,
                        title: 'Visibilité',
                        items: const [
                          _MenuItem(value: null, label: 'Tous'),
                          _MenuItem(value: true, label: 'Actifs'),
                          _MenuItem(value: false, label: 'Inactifs'),
                        ],
                        initial: f.onlyActive,
                      );
                      controller.setFilter(
                        f.copyWith(
                          onlyActive: selected,
                          resetOnlyActive: selected == null,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  _FilterTile(
                    label: f.stockStatus == null
                        ? 'Stock'
                        : (f.stockStatus == 'ok'
                              ? 'OK ✓'
                              : (f.stockStatus == 'low'
                                    ? 'Faible ✓'
                                    : 'Rupture ✓')),
                    active: f.stockStatus != null,
                    icon: Icons.inventory_2_outlined,
                    onTap: () async {
                      final selected = await _pickFromMenu<String?>(
                        context,
                        title: 'Stock',
                        items: const [
                          _MenuItem(value: null, label: 'Tous'),
                          _MenuItem(value: 'ok', label: 'OK'),
                          _MenuItem(value: 'low', label: 'Faible'),
                          _MenuItem(value: 'out', label: 'Rupture'),
                        ],
                        initial: f.stockStatus,
                      );
                      controller.setFilter(
                        f.copyWith(
                          stockStatus: selected,
                          resetStockStatus: selected == null,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  _FilterTile(
                    label: (f.minPrice == null && f.maxPrice == null)
                        ? 'Prix'
                        : 'Prix ✓',
                    active: (f.minPrice != null || f.maxPrice != null),
                    icon: Icons.euro_outlined,
                    onTap: () async {
                      final res = await showDialog<_PriceRange?>(
                        context: context,
                        builder: (_) => _PriceRangeDialog(
                          initialMin: f.minPrice,
                          initialMax: f.maxPrice,
                        ),
                      );
                      if (res == null) return;
                      controller.setFilter(
                        f.copyWith(
                          minPrice: res.min,
                          maxPrice: res.max,
                          resetMinPrice: res.min == null,
                          resetMaxPrice: res.max == null,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  _FilterTile(
                    label: f.tag == null ? 'Tag' : 'Tag ✓',
                    active: f.tag != null,
                    icon: Icons.tag_outlined,
                    onTap: () async {
                      final res = await showDialog<String?>(
                        context: context,
                        builder: (_) => _TextPromptDialog(
                          title: 'Tag',
                          hint: 'ex: promo, artisan, vip…',
                          initial: f.tag ?? '',
                        ),
                      );
                      final val = (res ?? '').trim();
                      controller.setFilter(
                        f.copyWith(
                          tag: val.isEmpty ? null : val,
                          resetTag: val.isEmpty,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  _FilterTile(
                    label: 'Réinitialiser',
                    active: controller.filter.hasAny,
                    icon: Icons.restart_alt,
                    onTap: controller.resetFilters,
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// ProductTileAdmin
// ---------------------------------------------------------------------------

class ProductTileAdmin extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onPhotos;
  final VoidCallback onStock;
  final VoidCallback onDuplicate;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  const ProductTileAdmin({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onPhotos,
    required this.onStock,
    required this.onDuplicate,
    required this.onToggleActive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final badge = _stockBadge(product.stockStatus);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onEdit,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE9ECF3)),
            boxShadow: [
              BoxShadow(
                blurRadius: 18,
                offset: const Offset(0, 10),
                color: Colors.black.withAlpha(13),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  child: Container(
                    color: MasliveTokens.bg,
                    child: product.mainImageUrl == null
                        ? const Center(
                            child: Icon(Icons.photo_outlined, size: 32),
                          )
                        : StorageImage(
                            url: product.mainImageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            cacheWidth: 500,
                            errorWidget: const Center(
                              child: Icon(Icons.broken_image_outlined),
                            ),
                          ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _Pill(
                          text: product.isActive ? 'Actif' : 'Off',
                          filled: product.isActive,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '${product.price.toStringAsFixed(2)} ${product.currency}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 10),
                        _Pill(text: badge.label, filled: badge.filled),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SmallAction(
                          icon: Icons.edit_outlined,
                          label: 'Modifier',
                          onTap: onEdit,
                        ),
                        _SmallAction(
                          icon: Icons.photo_library_outlined,
                          label: 'Photos',
                          onTap: onPhotos,
                        ),
                        _SmallAction(
                          icon: Icons.inventory_outlined,
                          label: 'Stock',
                          onTap: onStock,
                        ),
                        _SmallAction(
                          icon: Icons.copy_outlined,
                          label: 'Dupliquer',
                          onTap: onDuplicate,
                        ),
                        _SmallAction(
                          icon: product.isActive
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          label: product.isActive ? 'Désactiver' : 'Activer',
                          onTap: onToggleActive,
                        ),
                        _SmallAction(
                          icon: Icons.delete_outline,
                          label: 'Supprimer',
                          onTap: onDelete,
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
    );
  }

  _StockBadge _stockBadge(String status) {
    switch (status) {
      case 'out':
        return const _StockBadge(label: 'Rupture', filled: true);
      case 'low':
        return const _StockBadge(label: 'Faible', filled: true);
      default:
        return const _StockBadge(label: 'Stock OK', filled: false);
    }
  }
}

// ---------------------------------------------------------------------------
// ProductEditDialog
// ---------------------------------------------------------------------------

class ProductEditDialog extends StatefulWidget {
  final String shopId;
  final Product? existing;

  const ProductEditDialog({
    super.key,
    required this.shopId,
    required this.existing,
  });

  @override
  State<ProductEditDialog> createState() => _ProductEditDialogState();
}

class _ProductEditDialogState extends State<ProductEditDialog> {
  final formKey = GlobalKey<FormState>();

  late final TextEditingController nameCtrl;
  late final TextEditingController descCtrl;
  late final TextEditingController priceCtrl;
  late final TextEditingController tagsCtrl;
  late final TextEditingController stockCtrl;
  late final TextEditingController alertCtrl;
  late final TextEditingController skuCtrl;
  late final TextEditingController barcodeCtrl;

  bool isActive = true;
  bool isFeatured = false;
  String currency = 'EUR';
  String? categoryId;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    nameCtrl = TextEditingController(text: p?.name ?? '');
    descCtrl = TextEditingController(text: p?.description ?? '');
    priceCtrl = TextEditingController(
      text: p != null ? p.price.toStringAsFixed(2) : '',
    );
    tagsCtrl = TextEditingController(text: p?.tags.join(', ') ?? '');
    stockCtrl = TextEditingController(text: p != null ? '${p.stockQty}' : '0');
    alertCtrl = TextEditingController(
      text: p != null ? '${p.stockAlertQty}' : '3',
    );
    skuCtrl = TextEditingController(text: p?.sku ?? '');
    barcodeCtrl = TextEditingController(text: p?.barcode ?? '');
    isActive = p?.isActive ?? true;
    isFeatured = p?.isFeatured ?? false;
    currency = p?.currency ?? 'EUR';
    categoryId = p?.categoryId;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    descCtrl.dispose();
    priceCtrl.dispose();
    tagsCtrl.dispose();
    stockCtrl.dispose();
    alertCtrl.dispose();
    skuCtrl.dispose();
    barcodeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.all(10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isNew ? 'Ajouter un produit' : 'Modifier le produit',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      children: [
                        _field(
                          label: 'Nom',
                          controller: nameCtrl,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Nom requis'
                              : null,
                        ),
                        const SizedBox(height: 10),
                        _field(
                          label: 'Description',
                          controller: descCtrl,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                label: 'Prix',
                                controller: priceCtrl,
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  final d = double.tryParse(
                                    (v ?? '').replaceAll(',', '.'),
                                  );
                                  if (d == null || d < 0) {
                                    return 'Prix invalide';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 110,
                              child: DropdownButtonFormField<String>(
                                initialValue: currency,
                                decoration: _decor('Devise'),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'EUR',
                                    child: Text('EUR'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'USD',
                                    child: Text('USD'),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => currency = v ?? 'EUR'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _field(
                          label: 'Tags (séparés par virgule)',
                          controller: tagsCtrl,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                label: 'Stock',
                                controller: stockCtrl,
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  final i = int.tryParse((v ?? '').trim());
                                  if (i == null || i < 0) {
                                    return 'Stock invalide';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _field(
                                label: 'Alerte stock',
                                controller: alertCtrl,
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  final i = int.tryParse((v ?? '').trim());
                                  if (i == null || i < 0) {
                                    return 'Valeur invalide';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _field(label: 'SKU', controller: skuCtrl),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _field(
                                label: 'Code barre',
                                controller: barcodeCtrl,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Actif en boutique'),
                                value: isActive,
                                onChanged: (v) => setState(() => isActive = v),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Mis en avant'),
                                value: isFeatured,
                                onChanged: (v) =>
                                    setState(() => isFeatured = v),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                      onPressed: () {
                        if (!(formKey.currentState?.validate() ?? false)) {
                          return;
                        }

                        final price = double.parse(
                          priceCtrl.text.replaceAll(',', '.'),
                        );
                        final parsedTags = tagsCtrl.text
                            .split(',')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toSet()
                            .toList();

                        final stockQty = int.parse(stockCtrl.text.trim());
                        final alertQty = int.parse(alertCtrl.text.trim());
                        final status = CommerceRepository.computeStockStatus(
                          stockQty,
                          alertQty,
                        );

                        final now = DateTime.now();
                        final base = widget.existing;

                        final product = Product(
                          id: base?.id ?? '',
                          name: nameCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          price: price,
                          currency: currency,
                          categoryId: categoryId,
                          tags: parsedTags,
                          isActive: isActive,
                          isFeatured: isFeatured,
                          stockQty: stockQty,
                          stockAlertQty: alertQty,
                          sku: skuCtrl.text.trim().isEmpty
                              ? null
                              : skuCtrl.text.trim(),
                          barcode: barcodeCtrl.text.trim().isEmpty
                              ? null
                              : barcodeCtrl.text.trim(),
                          country: base?.country,
                          event: base?.event,
                          circuit: base?.circuit,
                          placeGeo: base?.placeGeo,
                          mainImageUrl: base?.mainImageUrl,
                          imageCount: base?.imageCount ?? 0,
                          images: base?.images ?? const [],
                          searchTokens: base?.searchTokens ?? const [],
                          createdAt: base?.createdAt ?? now,
                          updatedAt: now,
                          stockStatus: status,
                        );

                        Navigator.pop(context, product);
                      },
                      child: const Text('Enregistrer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return MasliveTextField(
      controller: controller,
      label: label,
      maxLines: maxLines,
      validator: validator,
      keyboardType: keyboardType,
    );
  }

  InputDecoration _decor(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.blueGrey),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.blue.withAlpha(77)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.blue, width: 2),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}

// ---------------------------------------------------------------------------
// ProductImagesEditorDialog
// ---------------------------------------------------------------------------

class ProductImagesEditorDialog extends StatefulWidget {
  final ProductController controller;
  final Product product;

  const ProductImagesEditorDialog({
    super.key,
    required this.controller,
    required this.product,
  });

  @override
  State<ProductImagesEditorDialog> createState() =>
      _ProductImagesEditorDialogState();
}

class _ProductImagesEditorDialogState extends State<ProductImagesEditorDialog> {
  late Product product;
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    product = widget.product;
  }

  Future<void> _pickAndUpload() async {
    final files = await picker.pickMultiImage(imageQuality: 88);
    if (files.isEmpty) return;
    await widget.controller.addImagesToProduct(product, files);
    if (mounted) {
      TopSnackBar.show(
        context,
        SnackBar(content: Text('${files.length} photo(s) ajoutée(s)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final imgs = product.images;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.all(10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Photos — ${product.name}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (imgs.isEmpty)
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Center(child: Text('Aucune photo')),
                )
              else
                SizedBox(
                  height: 190,
                  child: ReorderableListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: imgs.length,
                    onReorderItem: (oldIndex, newIndex) async {
                      final list = List<ProductImage>.from(imgs);
                      final item = list.removeAt(oldIndex);
                      list.insert(newIndex, item);
                      await widget.controller.reorderImages(product, list);
                      setState(() {
                        product = product.copyWith(images: list);
                      });
                    },
                    itemBuilder: (_, i) {
                      final img = imgs[i];
                      return Container(
                        key: ValueKey(img.id),
                        width: 220,
                        margin: const EdgeInsets.only(right: 10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              StorageImage(
                                url: img.url,
                                fit: BoxFit.cover,
                                cacheWidth: 500,
                              ),
                              Positioned(
                                top: 10,
                                right: 10,
                                child: IconButton.filled(
                                  onPressed: () async {
                                    final ok = await _confirm(
                                      context,
                                      title: 'Supprimer cette photo ?',
                                      message:
                                          'Elle sera supprimée du stockage.',
                                    );
                                    if (!ok) return;
                                    await widget.controller.removeImage(
                                      product,
                                      img,
                                    );
                                    setState(() {
                                      final next = List<ProductImage>.from(
                                        product.images,
                                      )..removeWhere((e) => e.id == img.id);
                                      product = product.copyWith(images: next);
                                    });
                                  },
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ),
                              Positioned(
                                left: 10,
                                top: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    i == 0 ? 'Main' : '#${i + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue),
                      ),
                      onPressed: _pickAndUpload,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Ajouter des photos'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Astuce: glisse-dépose horizontalement pour réordonner (photo principale = 1ère).',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// StockQuickEditorDialog
// ---------------------------------------------------------------------------

class StockQuickEditorDialog extends StatefulWidget {
  final ProductController controller;
  final Product product;

  const StockQuickEditorDialog({
    super.key,
    required this.controller,
    required this.product,
  });

  @override
  State<StockQuickEditorDialog> createState() => _StockQuickEditorDialogState();
}

class _StockQuickEditorDialogState extends State<StockQuickEditorDialog> {
  int delta = 1;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Stock — ${p.name}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.blue.withAlpha(77)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Stock actuel: ${p.stockQty}\nAlerte: ${p.stockAlertQty}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    DropdownButton<int>(
                      value: delta,
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1')),
                        DropdownMenuItem(value: 2, child: Text('2')),
                        DropdownMenuItem(value: 5, child: Text('5')),
                        DropdownMenuItem(value: 10, child: Text('10')),
                      ],
                      onChanged: (v) => setState(() => delta = v ?? 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue),
                      ),
                      onPressed: () async {
                        try {
                          await widget.controller.adjustStock(p, -delta);
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (!context.mounted) return;
                          TopSnackBar.show(
                            context,
                            SnackBar(content: Text('Erreur: $e')),
                          );
                        }
                      },
                      icon: const Icon(Icons.remove),
                      label: const Text('Décrémenter'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                      onPressed: () async {
                        try {
                          await widget.controller.adjustStock(p, delta);
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (!context.mounted) return;
                          TopSnackBar.show(
                            context,
                            SnackBar(content: Text('Erreur: $e')),
                          );
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Incrémenter'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private UI helpers (admin-only)
// ---------------------------------------------------------------------------

class _AdminCartBadge extends StatelessWidget {
  final int count;
  const _AdminCartBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const IconButton(
          onPressed: null,
          icon: Icon(Icons.shopping_bag_outlined),
        ),
        if (count > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FilterTile extends StatelessWidget {
  final String label;
  final bool active;
  final IconData icon;
  final VoidCallback onTap;

  const _FilterTile({
    required this.label,
    required this.active,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active ? Colors.black : MasliveTokens.bg;
    final fg = active ? Colors.white : Colors.black87;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? Colors.black : const Color(0xFFE9ECF3),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: fg, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SmallAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: MasliveTokens.bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE9ECF3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final bool filled;
  const _Pill({required this.text, required this.filled});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? Colors.black : MasliveTokens.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: filled ? Colors.black : const Color(0xFFE9ECF3),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: filled ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _StockBadge {
  final String label;
  final bool filled;
  const _StockBadge({required this.label, required this.filled});
}

class _MenuItem<T> {
  final T value;
  final String label;
  const _MenuItem({required this.value, required this.label});
}

Future<T?> _pickFromMenu<T>(
  BuildContext context, {
  required String title,
  required List<_MenuItem<T>> items,
  required T initial,
}) async {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final it = items[i];
                    final selected = it.value == initial;
                    return ListTile(
                      title: Text(
                        it.label,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      trailing: selected ? const Icon(Icons.check) : null,
                      onTap: () => Navigator.pop(context, it.value),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('OK'),
        ),
      ],
    ),
  );
  return res ?? false;
}

class _TextPromptDialog extends StatefulWidget {
  final String title;
  final String hint;
  final String initial;

  const _TextPromptDialog({
    required this.title,
    required this.hint,
    required this.initial,
  });

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController ctrl;

  @override
  void initState() {
    super.initState();
    ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: Text(widget.title),
      content: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          hintText: widget.hint,
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.blue.withValues(alpha: 0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.blue, width: 2),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.blue),
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, ctrl.text),
          child: const Text('Appliquer'),
        ),
      ],
    );
  }
}

class _PriceRange {
  final double? min;
  final double? max;
  const _PriceRange({this.min, this.max});
}

class _PriceRangeDialog extends StatefulWidget {
  final double? initialMin;
  final double? initialMax;
  const _PriceRangeDialog({this.initialMin, this.initialMax});

  @override
  State<_PriceRangeDialog> createState() => _PriceRangeDialogState();
}

class _PriceRangeDialogState extends State<_PriceRangeDialog> {
  late final TextEditingController minCtrl;
  late final TextEditingController maxCtrl;

  @override
  void initState() {
    super.initState();
    minCtrl = TextEditingController(
      text: widget.initialMin?.toStringAsFixed(2) ?? '',
    );
    maxCtrl = TextEditingController(
      text: widget.initialMax?.toStringAsFixed(2) ?? '',
    );
  }

  @override
  void dispose() {
    minCtrl.dispose();
    maxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final decor = InputDecoration(
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.blue.withAlpha(77)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.blue, width: 2),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: const Text('Prix'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: minCtrl,
            keyboardType: TextInputType.number,
            decoration: decor.copyWith(labelText: 'Min'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: maxCtrl,
            keyboardType: TextInputType.number,
            decoration: decor.copyWith(labelText: 'Max'),
          ),
        ],
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.blue),
          onPressed: () => Navigator.pop(context, const _PriceRange()),
          child: const Text('Reset'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            final min = double.tryParse(
              minCtrl.text.replaceAll(',', '.').trim(),
            );
            final max = double.tryParse(
              maxCtrl.text.replaceAll(',', '.').trim(),
            );
            Navigator.pop(context, _PriceRange(min: min, max: max));
          },
          child: const Text('Appliquer'),
        ),
      ],
    );
  }
}
