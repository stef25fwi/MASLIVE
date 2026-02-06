import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/image_models.dart';
import '../services/advanced_image_upload_service.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Widget d'upload d'images avec preview et progression
class ImageUploadWidget extends StatefulWidget {
  final String basePath;
  final String imageId;
  final ImageUploadConfig config;
  final Function(ManagedImage image) onUploaded;
  final Function(String error)? onError;
  final String? initialImageUrl;
  final String buttonText;
  final IconData buttonIcon;
  final bool allowCamera;
  final bool allowGallery;

  const ImageUploadWidget({
    super.key,
    required this.basePath,
    required this.imageId,
    required this.onUploaded,
    this.config = ImageUploadConfig.article,
    this.onError,
    this.initialImageUrl,
    this.buttonText = 'Choisir une image',
    this.buttonIcon = Icons.add_photo_alternate,
    this.allowCamera = true,
    this.allowGallery = true,
  });

  @override
  State<ImageUploadWidget> createState() => _ImageUploadWidgetState();
}

class _ImageUploadWidgetState extends State<ImageUploadWidget> {
  final _uploader = AdvancedImageUploadService.instance;
  final _picker = ImagePicker();

  XFile? _selectedFile;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadStep = '';
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _imageUrl = widget.initialImageUrl;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 100, // Max qualité, on compresse après
      );

      if (file != null && mounted) {
        setState(() {
          _selectedFile = file;
          _imageUrl = null; // Reset preview
        });
      }
    } catch (e) {
      widget.onError?.call('Erreur sélection: $e');
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedFile == null) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final result = await _uploader.uploadImage(
        file: _selectedFile!,
        basePath: widget.basePath,
        imageId: widget.imageId,
        config: widget.config,
        onProgress: (progress, step) {
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
              _uploadStep = step;
            });
          }
        },
      );

      if (result.isSuccess && mounted) {
        setState(() {
          _imageUrl = result.image.variants.medium;
          _selectedFile = null;
        });
        widget.onUploaded(result.image);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Image uploadée (${result.uploadDuration.inSeconds}s)'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        widget.onError?.call(result.error ?? 'Erreur inconnue');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${result.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      widget.onError?.call(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _showSourcePicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            if (widget.allowGallery)
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galerie'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            if (widget.allowCamera && !kIsWeb)
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Appareil photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Preview de l'image
        if (_selectedFile != null || _imageUrl != null)
          Container(
            height: 200,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _selectedFile != null
                  ? (kIsWeb
                      ? FutureBuilder<Uint8List>(
                          future: _selectedFile!.readAsBytes(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Image.memory(
                                snapshot.data!,
                                fit: BoxFit.cover,
                              );
                            }
                            return const Center(child: CircularProgressIndicator());
                          },
                        )
                      : Image.file(
                          File(_selectedFile!.path),
                          fit: BoxFit.cover,
                        ))
                  : Image.network(
                      _imageUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stack) {
                        return const Center(
                          child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                        );
                      },
                    ),
            ),
          ),

        // Progression upload
        if (_isUploading) ...[
          LinearProgressIndicator(value: _uploadProgress),
          const SizedBox(height: 8),
          Text(
            '$_uploadStep (${(_uploadProgress * 100).toStringAsFixed(0)}%)',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
        ],

        // Boutons d'action
        if (!_isUploading)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showSourcePicker,
                  icon: Icon(widget.buttonIcon),
                  label: Text(widget.buttonText),
                ),
              ),
              if (_selectedFile != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _uploadImage,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Upload'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

/// Widget de galerie d'images uploadables
class ImageGalleryUploadWidget extends StatefulWidget {
  final String basePath;
  final ImageUploadConfig config;
  final Function(ImageCollection collection) onUploaded;
  final int maxImages;
  final bool showCover;

  const ImageGalleryUploadWidget({
    super.key,
    required this.basePath,
    required this.onUploaded,
    this.config = ImageUploadConfig.article,
    this.maxImages = 10,
    this.showCover = true,
  });

  @override
  State<ImageGalleryUploadWidget> createState() => _ImageGalleryUploadWidgetState();
}

class _ImageGalleryUploadWidgetState extends State<ImageGalleryUploadWidget> {
  final _uploader = AdvancedImageUploadService.instance;
  final _picker = ImagePicker();

  final List<XFile> _selectedFiles = [];
  XFile? _coverFile;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _currentFile = '';

  Future<void> _pickImages() async {
    try {
      final files = await _picker.pickMultiImage(imageQuality: 100);

      if (files.isNotEmpty && mounted) {
        setState(() {
          _selectedFiles.addAll(files);
          if (_selectedFiles.length > widget.maxImages) {
            _selectedFiles.removeRange(widget.maxImages, _selectedFiles.length);
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _uploadGallery() async {
    if (_selectedFiles.isEmpty) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final collection = await _uploader.uploadImageCollection(
        files: _selectedFiles,
        basePath: widget.basePath,
        config: widget.config,
        coverFile: _coverFile,
        onProgress: (progress, currentFile) {
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
              _currentFile = currentFile;
            });
          }
        },
      );

      if (mounted) {
        widget.onUploaded(collection);
        setState(() {
          _selectedFiles.clear();
          _coverFile = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${collection.totalCount} images uploadées'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _removeFile(int index) {
    setState(() => _selectedFiles.removeAt(index));
  }

  void _setCover(int index) {
    setState(() => _coverFile = _selectedFiles[index]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Grille de preview
        if (_selectedFiles.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _selectedFiles.length,
            itemBuilder: (context, index) {
              final file = _selectedFiles[index];
              final isCover = _coverFile == file;

              return Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCover ? Colors.green : Colors.grey.shade300,
                        width: isCover ? 3 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: kIsWeb
                          ? FutureBuilder<Uint8List>(
                              future: file.readAsBytes(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return Image.memory(snapshot.data!, fit: BoxFit.cover);
                                }
                                return const CircularProgressIndicator();
                              },
                            )
                          : Image.file(File(file.path), fit: BoxFit.cover),
                    ),
                  ),
                  // Badge cover
                  if (isCover)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'COVER',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ),
                  // Boutons d'action
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.showCover && !isCover)
                          IconButton(
                            onPressed: () => _setCover(index),
                            icon: const Icon(Icons.star_border, size: 20),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.all(4),
                            ),
                          ),
                        IconButton(
                          onPressed: () => _removeFile(index),
                          icon: const Icon(Icons.close, size: 20),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

        const SizedBox(height: 16),

        // Progression
        if (_isUploading) ...[
          LinearProgressIndicator(value: _uploadProgress),
          const SizedBox(height: 8),
          Text(
            '$_currentFile (${(_uploadProgress * 100).toStringAsFixed(0)}%)',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
        ],

        // Boutons
        if (!_isUploading)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _selectedFiles.length < widget.maxImages ? _pickImages : null,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: Text('Ajouter (${_selectedFiles.length}/${widget.maxImages})'),
                ),
              ),
              if (_selectedFiles.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _uploadGallery,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Upload tout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

/// Widget d'affichage d'une galerie d'images
class ImageGalleryViewer extends StatefulWidget {
  final ImageCollection collection;
  final bool showThumbnails;
  final bool enableZoom;

  const ImageGalleryViewer({
    super.key,
    required this.collection,
    this.showThumbnails = true,
    this.enableZoom = true,
  });

  @override
  State<ImageGalleryViewer> createState() => _ImageGalleryViewerState();
}

class _ImageGalleryViewerState extends State<ImageGalleryViewer> {
  int _currentIndex = 0;

  ManagedImage get _currentImage {
    final images = widget.collection.allImages;
    return images[_currentIndex];
  }

  void _showFullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => _FullscreenImageViewer(
          images: widget.collection.allImages,
          initialIndex: _currentIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.collection.allImages;

    if (images.isEmpty) {
      return const Center(
        child: Text('Aucune image'),
      );
    }

    return Column(
      children: [
        // Image principale
        GestureDetector(
          onTap: widget.enableZoom ? _showFullscreen : null,
          child: Container(
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade100,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _currentImage.getUrl(ImageSize.large),
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
              ),
            ),
          ),
        ),

        // Miniatures
        if (widget.showThumbnails && images.length > 1) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              itemBuilder: (context, index) {
                final image = images[index];
                final isSelected = index == _currentIndex;

                return GestureDetector(
                  onTap: () => setState(() => _currentIndex = index),
                  child: Container(
                    width: 80,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey.shade300,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        image.getUrl(ImageSize.thumbnail),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

/// Viewer plein écran avec zoom
class _FullscreenImageViewer extends StatefulWidget {
  final List<ManagedImage> images;
  final int initialIndex;

  const _FullscreenImageViewer({
    required this.images,
    this.initialIndex = 0,
  });

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1}/${widget.images.length}'),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          final image = widget.images[index];
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                image.getUrl(ImageSize.original),
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
  }
}
