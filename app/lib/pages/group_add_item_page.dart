import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class GroupAddItemPage extends StatefulWidget {
  const GroupAddItemPage({super.key, required this.groupId});
  final String groupId;

  @override
  State<GroupAddItemPage> createState() => _GroupAddItemPageState();
}

class _GroupAddItemPageState extends State<GroupAddItemPage> with SingleTickerProviderStateMixin {
  final _titleCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  final _picker = ImagePicker();

  bool _saving = false;
  String _category = 'T-shirts';

  // Nouvelles variables pour variantes et stock
  final List<String> _selectedSizes = [];
  final List<String> _selectedColors = [];
  final Map<String, int> _stockByVariant = {}; // "taille|couleur" -> quantité

  Uint8List? _photo1;
  String? _photo1Name;
  Uint8List? _photo2;
  String? _photo2Name;

  final List<String> _categories = const [
    'T-shirts',
    'Casquettes',
    'Stickers',
    'Accessoires',
  ];

  final List<String> _availableSizes = const ['XS', 'S', 'M', 'L', 'XL', 'XXL'];
  final List<String> _availableColors = const ['Noir', 'Blanc', 'Gris', 'Bleu', 'Rouge', 'Vert'];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(int which) async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1800,
    );
    if (x == null) return;

    final bytes = await x.readAsBytes();
    setState(() {
      if (which == 1) {
        _photo1 = bytes;
        _photo1Name = x.name;
      } else {
        _photo2 = bytes;
        _photo2Name = x.name;
      }
    });
  }

  int? _parsePriceCents() {
    final raw = _priceCtrl.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;

    // accepte: "12" => 12€ ; "12.50" => 12.50€
    final value = double.tryParse(raw);
    if (value == null) return null;
    if (value < 0) return null;

    return (value * 100).round();
  }

  Future<String> _uploadBytes({
    required String path,
    required Uint8List bytes,
  }) async {
    final ref = FirebaseStorage.instance.ref(path);
    final meta = SettableMetadata(contentType: 'image/jpeg');
    await ref.putData(bytes, meta);
    return ref.getDownloadURL();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final priceCents = _parsePriceCents();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Titre requis')),
      );
      return;
    }

    if (priceCents == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prix invalide (ex: 12 ou 12.50)')),
      );
      return;
    }

    if (_photo1 == null || _photo2 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoute les 2 photos avant de publier')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final db = FirebaseFirestore.instance;
      
      // Créer dans la collection globale 'products'
      final productRef = db.collection('products').doc();

      // Upload Storage (2 photos)
      final base = 'groups/${widget.groupId}/products/${productRef.id}';
      final url1 = await _uploadBytes(path: '$base/1.jpg', bytes: _photo1!);
      final url2 = await _uploadBytes(path: '$base/2.jpg', bytes: _photo2!);

      await productRef.set({
        'groupId': widget.groupId, // IMPORTANT: lier au groupe
        'title': title,
        'priceCents': priceCents,
        'category': _category,
        // Modération: créé en attente, l'admin master valide ensuite.
        'isActive': false,
        'moderationStatus': 'pending',
        'imageUrl': url1,
        'imageUrl2': url2,
        'photo1Name': _photo1Name,
        'photo2Name': _photo2Name,
        // Ajout des variantes et stock
        'availableSizes': _selectedSizes.isNotEmpty ? _selectedSizes : null,
        'availableColors': _selectedColors.isNotEmpty ? _selectedColors : null,
        'stockByVariant': _stockByVariant.isNotEmpty ? _stockByVariant : null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⏳ Article envoyé en validation')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erreur: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ajouter un article'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Infos'),
              Tab(text: 'Photos'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _infosTab(),
            _photosTab(),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.publish),
              label: Text(_saving ? 'Publication…' : 'Publier'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infosTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _titleCtrl,
          decoration: const InputDecoration(
            labelText: 'Nom de l’article',
            prefixIcon: Icon(Icons.label),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _priceCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Prix (€)',
            hintText: 'ex: 12.50',
            prefixIcon: Icon(Icons.euro),
          ),
        ),
        const SizedBox(height: 12),
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Catégorie',
            prefixIcon: Icon(Icons.category),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _category,
              isExpanded: true,
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: _saving ? null : (v) => setState(() => _category = v ?? _category),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Variantes et stock',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Tailles disponibles',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableSizes.map((size) {
            final isSelected = _selectedSizes.contains(size);
            return FilterChip(
              label: Text(size),
              selected: isSelected,
              onSelected: _saving ? null : (selected) {
                setState(() {
                  if (selected) {
                    _selectedSizes.add(size);
                  } else {
                    _selectedSizes.remove(size);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Text(
          'Couleurs disponibles',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableColors.map((color) {
            final isSelected = _selectedColors.contains(color);
            return FilterChip(
              label: Text(color),
              selected: isSelected,
              onSelected: _saving ? null : (selected) {
                setState(() {
                  if (selected) {
                    _selectedColors.add(color);
                  } else {
                    _selectedColors.remove(color);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        if (_selectedSizes.isNotEmpty && _selectedColors.isNotEmpty) ...[
          Text(
            'Stock par variante',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ..._selectedSizes.expand((size) {
            return _selectedColors.map((color) {
              final key = '$size|$color';
              final stock = _stockByVariant[key] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        '$size - $color',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Stock',
                          hintText: '0',
                          isDense: true,
                        ),
                        controller: TextEditingController(text: stock.toString())
                          ..selection = TextSelection.fromPosition(
                            TextPosition(offset: stock.toString().length),
                          ),
                        onChanged: (value) {
                          final qty = int.tryParse(value) ?? 0;
                          _stockByVariant[key] = qty;
                        },
                      ),
                    ),
                  ],
                ),
              );
            });
          }),
        ],
        const SizedBox(height: 12),
        Text(
          'Ce produit sera visible dans la boutique après validation par un admin master.\n'
          'Astuce: la tuile shop utilise la photo #1.',
          style: TextStyle(color: Colors.black.withValues(alpha: 0.6), fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _photosTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _photoPickerCard(
          title: 'Photo 1 (tuile boutique)',
          bytes: _photo1,
          onPick: () => _pickPhoto(1),
          onClear: _saving ? null : () => setState(() {
            _photo1 = null;
            _photo1Name = null;
          }),
        ),
        const SizedBox(height: 12),
        _photoPickerCard(
          title: 'Photo 2 (détail produit)',
          bytes: _photo2,
          onPick: () => _pickPhoto(2),
          onClear: _saving ? null : () => setState(() {
            _photo2 = null;
            _photo2Name = null;
          }),
        ),
      ],
    );
  }

  Widget _photoPickerCard({
    required String title,
    required Uint8List? bytes,
    required VoidCallback onPick,
    required VoidCallback? onClear,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          AspectRatio(
            aspectRatio: 1.6,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: bytes == null
                  ? Container(
                      color: Colors.black.withValues(alpha: 0.06),
                      child: const Center(child: Text('Aucune photo')),
                    )
                  : Image.memory(bytes, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : onPick,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Choisir'),
                ),
              ),
              const SizedBox(width: 10),
              if (bytes != null)
                Expanded(
                  child: TextButton.icon(
                    onPressed: onClear,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Retirer'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
