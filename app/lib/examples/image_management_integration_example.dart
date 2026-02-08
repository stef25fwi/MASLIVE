/// EXEMPLE D'INTÉGRATION - Gestion d'images dans Create Product Page
/// Ce fichier montre comment migrer une page existante vers le nouveau système
library;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/image_management_service.dart';
import '../models/image_asset.dart';
import '../ui/widgets/smart_image_widgets.dart';
import '../ui/widgets/rainbow_loading_indicator.dart';

/// Page de création de produit avec nouveau système d'images
class CreateProductPageExample extends StatefulWidget {
  final String? productId;

  const CreateProductPageExample({super.key, this.productId});

  @override
  State<CreateProductPageExample> createState() =>
      _CreateProductPageExampleState();
}

class _CreateProductPageExampleState extends State<CreateProductPageExample> {
  final _imageService = ImageManagementService.instance;
  final _picker = ImagePicker();

  bool _isUploading = false;
  double _uploadProgress = 0.0;

  // Collection d'images du produit
  ImageCollection? _imageCollection;

  @override
  void initState() {
    super.initState();
    if (widget.productId != null) {
      _loadExistingImages();
    }
  }

  /// Charger images existantes
  Future<void> _loadExistingImages() async {
    if (widget.productId == null) return;

    try {
      final collection =
          await _imageService.getImageCollection(widget.productId!);
      setState(() {
        _imageCollection = collection;
      });
    } catch (e) {
      debugPrint('Erreur chargement images: $e');
    }
  }

  /// Ajouter une nouvelle image
  Future<void> _addImage() async {
    try {
      // 1. Sélectionner image
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100, // Max qualité, optimisation se fait automatiquement
      );

      if (file == null) return;

      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
      });

      // 2. Upload avec optimisation automatique
      await _imageService.uploadImage(
        file: file,
        contentType: ImageContentType.productPhoto,
        parentId: widget.productId ?? 'draft_${DateTime.now().millisecondsSinceEpoch}',
        order: _imageCollection?.totalImages ?? 0,
        altText: 'Photo de produit',
        onProgress: (progress) {
          setState(() {
            _uploadProgress = progress;
          });
        },
      );

      // 3. Recharger collection
      await _loadExistingImages();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Image ajoutée')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  /// Ajouter plusieurs images (galerie)
  Future<void> _addMultipleImages() async {
    try {
      // 1. Sélectionner plusieurs images
      final files = await _picker.pickMultiImage(imageQuality: 100);

      if (files.isEmpty) return;

      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
      });

      // 2. Upload collection
      await _imageService.uploadImageCollection(
        files: files,
        contentType: ImageContentType.productPhoto,
        parentId: widget.productId ?? 'draft_${DateTime.now().millisecondsSinceEpoch}',
        onProgress: (progress) {
          setState(() {
            _uploadProgress = progress;
          });
        },
      );

      // 3. Recharger
      await _loadExistingImages();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ ${files.length} images ajoutées')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  /// Supprimer une image
  Future<void> _deleteImage(String imageId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'image'),
        content: const Text('Confirmer la suppression ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _imageService.deleteImage(imageId);
      await _loadExistingImages();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Image supprimée')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer un Produit'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section Images
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Photos du produit',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (_imageCollection != null)
                        Text(
                          '${_imageCollection!.totalImages} image(s)',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Affichage images
                  if (_imageCollection != null &&
                      _imageCollection!.hasImages) ...[
                    // Image de couverture (grande)
                    CoverImage(
                      collection: _imageCollection!,
                      preferredSize: ImageSize.large,
                      height: 300,
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        // Ouvrir galerie plein écran
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Scaffold(
                              appBar: AppBar(
                                title: const Text('Galerie'),
                              ),
                              body: ImageGallery(
                                collection: _imageCollection!,
                                height: MediaQuery.of(context).size.height - 100,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Grille de thumbnails
                    if (_imageCollection!.hasGallery) ...[
                      Text(
                        'Galerie (${_imageCollection!.galleryImages.length} photos)',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _imageCollection!.images.length,
                        itemBuilder: (context, index) {
                          final image = _imageCollection!.images[index];
                          return Stack(
                            children: [
                              // Thumbnail
                              SmartImage(
                                variants: image.variants,
                                preferredSize: ImageSize.thumbnail,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              // Bouton supprimer
                              Positioned(
                                top: 4,
                                right: 4,
                                child: IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.white),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.black54,
                                    padding: const EdgeInsets.all(4),
                                  ),
                                  onPressed: () => _deleteImage(image.id),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ] else ...[
                    // Placeholder si pas d'images
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[400]!),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_not_supported,
                                size: 64, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Aucune photo'),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Indicateur upload
                  if (_isUploading) ...[
                    RainbowProgressIndicator(
                      progress: _uploadProgress,
                      label: 'Upload en cours...',
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Boutons ajout
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isUploading ? null : _addImage,
                          icon: const Icon(Icons.add_photo_alternate),
                          label: const Text('Ajouter 1 photo'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isUploading ? null : _addMultipleImages,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Galerie'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Autres champs du formulaire...
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Nom du produit'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Prix'),
                    keyboardType: TextInputType.number,
                  ),
                  // ...
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Bouton soumettre
          ElevatedButton(
            onPressed: _isUploading ? null : () {
              // Logique de soumission
              debugPrint(
                'Produit créé avec ${_imageCollection?.totalImages ?? 0} images',
              );
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
            ),
            child: const Text('Créer le produit'),
          ),
        ],
      ),
    );
  }
}

/// Exemple 2: Affichage simple d'une image de produit dans une carte
class ProductCard extends StatelessWidget {
  final String productId;
  final String productName;
  final double price;

  const ProductCard({
    super.key,
    required this.productId,
    required this.productName,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image avec StreamBuilder
          StreamBuilder<ImageCollection>(
            stream: ImageManagementService.instance
                .streamImageCollection(productId),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.hasImages) {
                // Placeholder si pas d'image
                return Container(
                  height: 200,
                  color: Colors.grey[200],
                  child: const Icon(Icons.image, size: 64, color: Colors.grey),
                );
              }

              // Afficher cover avec SmartImage
              return CoverImage(
                collection: snapshot.data!,
                preferredSize: ImageSize.medium,
                height: 200,
                fit: BoxFit.cover,
              );
            },
          ),

          // Infos produit
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${price.toStringAsFixed(2)} €',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Exemple 3: Avatar utilisateur
class UserAvatar extends StatelessWidget {
  final String userId;
  final String userName;
  final double size;

  const UserAvatar({
    super.key,
    required this.userId,
    required this.userName,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ImageCollection>(
      future: ImageManagementService.instance.getImageCollection(userId),
      builder: (context, snapshot) {
        ImageVariants? variants;

        if (snapshot.hasData && snapshot.data!.hasImages) {
          variants = snapshot.data!.coverImage?.variants;
        }

        return SmartAvatar(
          variants: variants,
          size: size,
          fallbackText: userName,
          fallbackColor: Colors.blue[700],
        );
      },
    );
  }
}
