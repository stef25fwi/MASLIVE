
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Popup 10/10 "Créer un produit" : UI premium + validation + photos (galerie/caméra)
Future<void> showCreateProductDialog({
  required BuildContext context,
  required String shopId,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CreateProductDialog(shopId: shopId),
  );

  if (result == true && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Produit créé ✅')));
  }
}

class _CreateProductDialog extends StatefulWidget {
  const _CreateProductDialog({required this.shopId});

  final String shopId;

  @override
  State<_CreateProductDialog> createState() => _CreateProductDialogState();
}

class _CreateProductDialogState extends State<_CreateProductDialog> {
  static const int _maxPhotos = 6;

  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController(text: '0');

  // State
  bool _isAvailable = true;
  bool _isSaving = false;

  String _category = 'Vêtements';
  final List<String> _categories = const [
    'Vêtements',
    'Accessoires',
    'Casquettes',
    'T-Shirts',
    'Bandanas',
    'Souvenirs',
    'Autres',
  ];

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _photos = [];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  // ---------- UI helpers ----------
  InputDecoration _decoration(String label, {String? hint, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
      filled: true,
      fillColor: const Color(0xFFF7F7FB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.45),
          width: 1.4,
        ),
      ),
    );
  }

  double _parsePrice(String s) {
    final cleaned = s.trim().replaceAll(',', '.');
    return double.tryParse(cleaned) ?? -1;
  }

  int _parseInt(String s) => int.tryParse(s.trim()) ?? -1;

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------- Photos ----------
  Future<void> _pickFromGallery() async {
    try {
      final remaining = _maxPhotos - _photos.length;
      if (remaining <= 0) {
        _toast('Maximum $_maxPhotos photos');
        return;
      }

      final files = await _picker.pickMultiImage(imageQuality: 82);
      if (files.isEmpty) return;

      final toAdd = files.take(remaining).toList();
      if (toAdd.length < files.length) {
        _toast('Limité à $_maxPhotos photos');
      }
      setState(() => _photos.addAll(toAdd));
    } catch (_) {
      // ignore
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      if (_photos.length >= _maxPhotos) {
        _toast('Maximum $_maxPhotos photos');
        return;
      }

      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 82,
      );
      if (file == null) return;
      setState(() => _photos.add(file));
    } catch (_) {
      // ignore
    }
  }

  void _removePhotoAt(int index) {
    setState(() => _photos.removeAt(index));
  }

  // ---------- Save ----------
  Future<List<String>> _uploadPhotosToStorage({
    required String shopId,
    required String productId,
    required List<XFile> photos,
  }) async {
    if (photos.isEmpty) return [];

    final storage = FirebaseStorage.instance;
    final List<String> urls = [];

    for (int i = 0; i < photos.length; i++) {
      final x = photos[i];
      final ext = (x.name.contains('.')) ? x.name.split('.').last : 'jpg';
      final bytes = await x.readAsBytes();

      final ref = storage
          .ref()
          .child('shops')
          .child(shopId)
          .child('products')
          .child(productId)
          .child('img_${DateTime.now().millisecondsSinceEpoch}_$i.$ext');

      final metadata = SettableMetadata(contentType: _guessContentType(ext));

      final uploadTask = ref.putData(bytes, metadata);
      await uploadTask;
      final url = await ref.getDownloadURL();
      urls.add(url);
    }

    return urls;
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _isSaving = true);

    try {
      final name = _nameCtrl.text.trim();
      final desc = _descCtrl.text.trim();
      final price = _parsePrice(_priceCtrl.text);
      final stock = _parseInt(_stockCtrl.text);

      // 1) Create doc id (garde compat admin + permet miroir shop)
      final rootRef = FirebaseFirestore.instance.collection('products').doc();
      final productId = rootRef.id;

      final shopRef = FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .collection('products')
          .doc(productId);

      // 2) Upload photos
      final imageUrls = await _uploadPhotosToStorage(
        shopId: widget.shopId,
        productId: productId,
        photos: List<XFile>.from(_photos),
      );

      // 3) Save firestore
      final main = imageUrls.isNotEmpty ? imageUrls.first : null;

      final payload = <String, dynamic>{
        // Identité boutique
        'shopId': widget.shopId,

        // Champs admin legacy
        'name': name,
        'description': desc,
        'price': price,
        'stock': stock,
        'category': _category,
        'isAvailable': _isAvailable,

        // Champs shop (GroupProduct)
        'title': name,
        'priceCents': (price * 100).round(),
        'isActive': _isAvailable,
        'moderationStatus': 'approved',
        if (stock >= 0)
          'stockByVariant': <String, int>{'default|default': stock},

        // Images
        'imageUrls': imageUrls,
        'mainImageUrl': main,
        // compat UI actuelle (AdminProductsPage utilise imageUrl)
        'imageUrl': main,

        // Timestamps
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Source de vérité: collection racine `products` (utilisée par AdminStockPage, etc.)
      // Miroir shop: pour compat / navigation boutique.
      final batch = FirebaseFirestore.instance.batch();
      batch.set(rootRef, payload);
      batch.set(shopRef, payload);
      await batch.commit();

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // ✅ Largeur premium responsive (mobile + tablette)
    final w = MediaQuery.of(context).size.width;
    final dialogWidth = w < 800 ? w * 0.94 : 800.0;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth, maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Material(
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: cs.primary.withAlpha(26),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.add_box_rounded, color: cs.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Créer un produit',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Fermer',
                          onPressed: _isSaving
                              ? null
                              : () => Navigator.of(context).pop(false),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Photos picker (10/10)
                    _PhotosPickerStrip(
                      photos: _photos,
                      onAddCamera: _pickFromCamera,
                      onAddGallery: _pickFromGallery,
                      onRemoveAt: _removePhotoAt,
                    ),
                    const SizedBox(height: 12),

                    // Form
                    Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextFormField(
                              controller: _nameCtrl,
                              textInputAction: TextInputAction.next,
                              decoration: _decoration(
                                'Nom du produit',
                                hint: 'Ex: T-shirt MAS\'LIVE',
                                icon: Icons.shopping_bag_rounded,
                              ),
                              validator: (v) {
                                final s = (v ?? '').trim();
                                if (s.isEmpty) return 'Le nom est obligatoire';
                                if (s.length < 2) return 'Nom trop court';
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),

                            TextFormField(
                              controller: _descCtrl,
                              minLines: 2,
                              maxLines: 4,
                              decoration: _decoration(
                                'Description',
                                hint: 'Détails, matière, coupe, etc.',
                                icon: Icons.subject_rounded,
                              ),
                            ),
                            const SizedBox(height: 10),

                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _priceCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: _decoration(
                                      'Prix (€)',
                                      hint: 'Ex: 25.00',
                                      icon: Icons.euro_rounded,
                                    ),
                                    validator: (v) {
                                      final p = _parsePrice(v ?? '');
                                      if (p < 0) return 'Prix invalide';
                                      if (p == 0) return 'Prix = 0 ?';
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _stockCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: _decoration(
                                      'Stock',
                                      hint: 'Ex: 10',
                                      icon: Icons.inventory_2_rounded,
                                    ),
                                    validator: (v) {
                                      final s = _parseInt(v ?? '');
                                      if (s < 0) return 'Stock invalide';
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Category dropdown premium
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7F7FB),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _category,
                                  isExpanded: true,
                                  icon: const Icon(Icons.expand_more_rounded),
                                  items: _categories
                                      .map(
                                        (c) => DropdownMenuItem(
                                          value: c,
                                          child: Text(c),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: _isSaving
                                      ? null
                                      : (v) => setState(
                                          () => _category = v ?? _category,
                                        ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7F7FB),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: SwitchListTile(
                                value: _isAvailable,
                                onChanged: _isSaving
                                    ? null
                                    : (v) => setState(() => _isAvailable = v),
                                title: const Text('Disponible'),
                                subtitle: Text(
                                  _isAvailable
                                      ? 'Visible et achetable'
                                      : 'Masqué / indisponible',
                                ),
                                secondary: Icon(
                                  _isAvailable
                                      ? Icons.check_circle_rounded
                                      : Icons.pause_circle_filled_rounded,
                                  color: _isAvailable
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSaving
                                ? null
                                : () => Navigator.of(context).pop(false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text('Annuler'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _save,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Créer'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotosPickerStrip extends StatelessWidget {
  const _PhotosPickerStrip({
    required this.photos,
    required this.onAddCamera,
    required this.onAddGallery,
    required this.onRemoveAt,
  });

  final List<XFile> photos;
  final VoidCallback onAddCamera;
  final VoidCallback onAddGallery;
  final void Function(int index) onRemoveAt;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.primary.withAlpha(31)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Photos du produit',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: onAddGallery,
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Galerie'),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                onPressed: onAddCamera,
                icon: const Icon(Icons.photo_camera_rounded),
                label: const Text('Caméra'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 78,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.isEmpty ? 1 : photos.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                if (photos.isEmpty) {
                  return Container(
                    width: 160,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black.withAlpha(15)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text('Ajoute 1 à 6 photos (recommandé)'),
                        ),
                      ],
                    ),
                  );
                }

                final x = photos[i];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _XFileThumb(x: x),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: InkWell(
                        onTap: () => onRemoveAt(i),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(140),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _XFileThumb extends StatelessWidget {
  const _XFileThumb({required this.x});

  final XFile x;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Image.network(
        x.path,
        width: 78,
        height: 78,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 78,
            height: 78,
            color: Colors.black.withAlpha(10),
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined, size: 20),
          );
        },
      );
    }

    return FutureBuilder<Uint8List>(
      future: x.readAsBytes(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Container(
            width: 78,
            height: 78,
            color: Colors.black.withAlpha(10),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        return Image.memory(
          snap.data!,
          width: 78,
          height: 78,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
        );
      },
    );
  }
}

String _guessContentType(String ext) {
  switch (ext.toLowerCase()) {
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
    case 'jpeg':
    case 'jpg':
    default:
      return 'image/jpeg';
  }
}
