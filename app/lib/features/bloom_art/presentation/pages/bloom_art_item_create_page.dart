import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/bloom_art_item.dart';
import '../../data/models/bloom_art_seller_profile.dart';
import '../../data/repositories/bloom_art_repository.dart';
import '../widgets/bloom_art_cta_button.dart';
import '../widgets/bloom_art_photo_picker.dart';

class BloomArtItemCreatePage extends StatefulWidget {
  const BloomArtItemCreatePage({
    super.key,
    this.profileType,
  });

  final String? profileType;

  @override
  State<BloomArtItemCreatePage> createState() => _BloomArtItemCreatePageState();
}

class _BloomArtItemCreatePageState extends State<BloomArtItemCreatePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final BloomArtRepository _repository = BloomArtRepository();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _dimensionsController = TextEditingController();
  final TextEditingController _materialsController = TextEditingController();
  final TextEditingController _referencePriceController =
      TextEditingController();
  final TextEditingController _deliveryNotesController =
      TextEditingController();

  String _condition = 'excellent';
  String _deliveryMode = 'delivery_or_pickup';
  bool _publishNow = true;
  bool _loadingProfile = true;
  bool _saving = false;
  BloomArtSellerProfile? _sellerProfile;
  List<XFile> _selectedPhotos = const <XFile>[];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _dimensionsController.dispose();
    _materialsController.dispose();
    _referencePriceController.dispose();
    _deliveryNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _loadingProfile = false;
        });
      }
      return;
    }

    final profile = await _repository.getSellerProfile(user.uid);
    if (!mounted) return;
    setState(() {
      _sellerProfile = profile;
      _loadingProfile = false;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins une photo.')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final profile = _sellerProfile;
    if (user == null) {
      Navigator.of(context).pushNamed('/login');
      return;
    }
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completez d\'abord votre profil vendeur Bloom Art.'),
        ),
      );
      Navigator.of(context).pushReplacementNamed('/bloom-art/sell');
      return;
    }

    final referencePrice = double.tryParse(
      _referencePriceController.text.trim().replaceAll(',', '.'),
    );
    if (referencePrice == null || referencePrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saisissez un prix de reference valide.')),
      );
      return;
    }

    final materials = _materialsController.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    setState(() {
      _saving = true;
    });

    try {
      final draftItem = BloomArtItem(
        id: '',
        sellerId: user.uid,
        sellerProfileType: widget.profileType ?? profile.profileType,
        sellerDisplayName: profile.displayName,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _categoryController.text.trim(),
        condition: _condition,
        materials: materials,
        dimensions: _dimensionsController.text.trim(),
        images: const <String>[],
        currency: 'EUR',
        isPublished: false,
        availabilityStatus: 'draft',
        deliveryMode: _deliveryMode,
        deliveryNotes: _deliveryNotesController.text.trim(),
      );

      final itemId = await _repository.createItem(
        item: draftItem,
        referencePrice: referencePrice,
      );

      final uploadedUrls = await _repository.uploadItemImages(
        itemId: itemId,
        files: _selectedPhotos,
      );

      await _repository.updateItemPublicData(itemId, <String, dynamic>{
        ...draftItem.toMap(includeReferencePrice: false),
        'images': uploadedUrls,
        'isPublished': _publishNow,
        'availabilityStatus': _publishNow ? 'published' : 'draft',
      });

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/bloom-art/item/$itemId');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de publier la creation : $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBF7),
        elevation: 0,
        title: const Text(
          'Depot d\'une creation',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: user == null
          ? Center(
              child: BloomArtCtaButton(
                label: 'Se connecter',
                icon: Icons.login_rounded,
                expanded: false,
                onPressed: () => Navigator.of(context).pushNamed('/login'),
              ),
            )
          : _loadingProfile
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: const Color(0xFFE9DED1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'Decrivez votre piece',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Le prix de reference reste prive. La fiche publique ne montrera que l\'oeuvre, son histoire et le bouton proposer un prix.',
                              style: const TextStyle(
                                color: Color(0xFF6A645E),
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      BloomArtPhotoPicker(
                        onChanged: (files) {
                          setState(() {
                            _selectedPhotos = List<XFile>.from(files);
                          });
                        },
                      ),
                      const SizedBox(height: 18),
                      _BloomArtField(
                        controller: _titleController,
                        label: 'Titre',
                        validator: _requiredValidator,
                      ),
                      const SizedBox(height: 12),
                      _BloomArtField(
                        controller: _descriptionController,
                        label: 'Description artistique',
                        maxLines: 5,
                        validator: _requiredValidator,
                      ),
                      const SizedBox(height: 12),
                      _BloomArtField(
                        controller: _categoryController,
                        label: 'Categorie',
                        validator: _requiredValidator,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _condition,
                        decoration: const InputDecoration(
                          labelText: 'Etat',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                            value: 'excellent',
                            child: Text('Excellent'),
                          ),
                          DropdownMenuItem(value: 'good', child: Text('Bon')),
                          DropdownMenuItem(
                            value: 'patina',
                            child: Text('Patine / piece vecue'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _condition = value ?? 'excellent';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _BloomArtField(
                        controller: _dimensionsController,
                        label: 'Dimensions',
                      ),
                      const SizedBox(height: 12),
                      _BloomArtField(
                        controller: _materialsController,
                        label: 'Materiaux (separes par des virgules)',
                      ),
                      const SizedBox(height: 12),
                      _BloomArtField(
                        controller: _referencePriceController,
                        label: 'Prix de reference prive (EUR)',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: _requiredValidator,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _deliveryMode,
                        decoration: const InputDecoration(
                          labelText: 'Mode de remise / livraison',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                            value: 'delivery_or_pickup',
                            child: Text('Livraison ou remise en main propre'),
                          ),
                          DropdownMenuItem(
                            value: 'delivery_only',
                            child: Text('Livraison uniquement'),
                          ),
                          DropdownMenuItem(
                            value: 'pickup_only',
                            child: Text('Remise en main propre uniquement'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _deliveryMode = value ?? 'delivery_or_pickup';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _BloomArtField(
                        controller: _deliveryNotesController,
                        label: 'Notes de livraison / remise',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        value: _publishNow,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Publier tout de suite'),
                        subtitle: const Text(
                          'Si desactive, la piece reste en brouillon dans votre espace vendeur.',
                        ),
                        onChanged: (value) {
                          setState(() {
                            _publishNow = value;
                          });
                        },
                      ),
                      const SizedBox(height: 18),
                      BloomArtCtaButton(
                        label: _saving
                            ? 'Publication en cours...'
                            : 'Publier ma creation',
                        icon: Icons.check_circle_outline,
                        onPressed: _saving ? null : _submit,
                      ),
                    ],
                  ),
                ),
    );
  }

  String? _requiredValidator(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Champ requis';
    }
    return null;
  }
}

class _BloomArtField extends StatelessWidget {
  const _BloomArtField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}