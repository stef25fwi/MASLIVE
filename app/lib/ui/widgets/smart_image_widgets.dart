import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/image_asset.dart';
import 'rainbow_loading_indicator.dart';

/// Widget d'affichage intelligent d'image avec variantes adaptatives
class SmartImage extends StatelessWidget {
  final ImageVariants variants;
  final ImageSize? preferredSize;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;
  final bool enableHeroAnimation;
  final String? heroTag;

  const SmartImage({
    super.key,
    required this.variants,
    this.preferredSize,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
    this.enableHeroAnimation = false,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Déterminer l'URL optimale selon la taille disponible
        final screenWidth = constraints.maxWidth;
        final url = preferredSize != null
            ? variants.getUrl(preferredSize!)
            : variants.getResponsiveUrl(screenWidth);

        Widget imageWidget = CachedNetworkImage(
          imageUrl: url,
          fit: fit,
          width: width,
          height: height,
          placeholder: (context, url) =>
              placeholder ??
              const Center(
                child: RainbowLoadingIndicator(
                  size: 50,
                  showLabel: false,
                ),
              ),
          errorWidget: (context, url, error) =>
              errorWidget ??
              Container(
                color: Colors.grey[200],
                child: const Icon(Icons.error_outline, color: Colors.grey),
              ),
        );

        if (borderRadius != null) {
          imageWidget = ClipRRect(
            borderRadius: borderRadius!,
            child: imageWidget,
          );
        }

        if (enableHeroAnimation && heroTag != null) {
          imageWidget = Hero(
            tag: heroTag!,
            child: imageWidget,
          );
        }

        return imageWidget;
      },
    );
  }
}

/// Widget pour afficher l'image de couverture depuis ImageCollection
class CoverImage extends StatelessWidget {
  final ImageCollection collection;
  final ImageSize preferredSize;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const CoverImage({
    super.key,
    required this.collection,
    this.preferredSize = ImageSize.medium,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final coverImage = collection.coverImage;

    if (coverImage == null) {
      return Container(
        width: width,
        height: height,
        color: Colors.grey[200],
        child: const Icon(Icons.image_not_supported, color: Colors.grey),
      );
    }

    final imageWidget = SmartImage(
      variants: coverImage.variants,
      preferredSize: preferredSize,
      fit: fit,
      width: width,
      height: height,
      borderRadius: borderRadius,
      enableHeroAnimation: true,
      heroTag: 'cover_${coverImage.id}',
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}

/// Widget de galerie d'images avec navigation
class ImageGallery extends StatefulWidget {
  final ImageCollection collection;
  final double height;
  final bool showThumbnails;
  final bool enableFullscreen;

  const ImageGallery({
    super.key,
    required this.collection,
    this.height = 400,
    this.showThumbnails = true,
    this.enableFullscreen = true,
  });

  @override
  State<ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<ImageGallery> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.collection.images;

    if (images.isEmpty) {
      return Container(
        height: widget.height,
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
        ),
      );
    }

    return Column(
      children: [
        // Galerie principale
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final image = images[index];
              return GestureDetector(
                onTap: widget.enableFullscreen
                    ? () => _openFullscreen(context, image, index)
                    : null,
                child: SmartImage(
                  variants: image.variants,
                  preferredSize: ImageSize.large,
                  fit: BoxFit.contain,
                  heroTag: 'gallery_${image.id}',
                  enableHeroAnimation: true,
                ),
              );
            },
          ),
        ),

        // Indicateur de position
        if (images.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentIndex > 0
                    ? () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    : null,
              ),
              Text(
                '${_currentIndex + 1} / ${images.length}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentIndex < images.length - 1
                    ? () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    : null,
              ),
            ],
          ),
        ],

        // Thumbnails
        if (widget.showThumbnails && images.length > 1) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              itemBuilder: (context, index) {
                final image = images[index];
                final isSelected = index == _currentIndex;

                return GestureDetector(
                  onTap: () {
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SmartImage(
                      variants: image.variants,
                      preferredSize: ImageSize.thumbnail,
                      width: 80,
                      height: 80,
                      borderRadius: BorderRadius.circular(6),
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

  void _openFullscreen(BuildContext context, ImageAsset image, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullscreenGallery(
          collection: widget.collection,
          initialIndex: index,
        ),
      ),
    );
  }
}

/// Widget plein écran pour visualisation d'images
class _FullscreenGallery extends StatefulWidget {
  final ImageCollection collection;
  final int initialIndex;

  const _FullscreenGallery({
    required this.collection,
    this.initialIndex = 0,
  });

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
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
    final images = widget.collection.images;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} / ${images.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: images.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final image = images[index];
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: SmartImage(
                variants: image.variants,
                preferredSize: ImageSize.xlarge,
                fit: BoxFit.contain,
                heroTag: 'gallery_${image.id}',
                enableHeroAnimation: true,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Widget grid de thumbnails cliquables
class ImageGrid extends StatelessWidget {
  final ImageCollection collection;
  final int crossAxisCount;
  final double aspectRatio;
  final double spacing;
  final VoidCallback? onAddImage;

  const ImageGrid({
    super.key,
    required this.collection,
    this.crossAxisCount = 3,
    this.aspectRatio = 1.0,
    this.spacing = 8.0,
    this.onAddImage,
  });

  @override
  Widget build(BuildContext context) {
    final images = collection.images;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: aspectRatio,
      ),
      itemCount: images.length + (onAddImage != null ? 1 : 0),
      itemBuilder: (context, index) {
        // Bouton d'ajout
        if (index == images.length && onAddImage != null) {
          return GestureDetector(
            onTap: onAddImage,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[400]!, width: 2),
              ),
              child: const Icon(Icons.add_photo_alternate,
                  size: 48, color: Colors.grey),
            ),
          );
        }

        // Thumbnail image
        final image = images[index];
        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => _FullscreenGallery(
                  collection: collection,
                  initialIndex: index,
                ),
              ),
            );
          },
          child: SmartImage(
            variants: image.variants,
            preferredSize: ImageSize.small,
            borderRadius: BorderRadius.circular(8),
            heroTag: 'grid_${image.id}',
            enableHeroAnimation: true,
          ),
        );
      },
    );
  }
}

/// Widget avatar avec fallback
class SmartAvatar extends StatelessWidget {
  final ImageVariants? variants;
  final double size;
  final String? fallbackText;
  final Color? fallbackColor;

  const SmartAvatar({
    super.key,
    this.variants,
    this.size = 40,
    this.fallbackText,
    this.fallbackColor,
  });

  @override
  Widget build(BuildContext context) {
    if (variants == null) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: fallbackColor ?? Colors.grey[300],
        child: fallbackText != null
            ? Text(
                fallbackText!.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              )
            : Icon(Icons.person, size: size * 0.6, color: Colors.white),
      );
    }

    return ClipOval(
      child: SmartImage(
        variants: variants!,
        preferredSize: ImageSize.small,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}
