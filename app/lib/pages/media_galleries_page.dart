import 'package:flutter/material.dart';

import '../widgets/honeycomb_background.dart';
import '../widgets/rainbow_header.dart';

class MediaGalleriesPage extends StatelessWidget {
  const MediaGalleriesPage({super.key, required this.groupId});

  final String groupId;

  static const _demoAsset = 'assets/splash/maslive.png';

  @override
  Widget build(BuildContext context) {
    final galleries = _demoGalleries();

    return Scaffold(
      body: HoneycombBackground(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: RainbowHeader(
                title: 'Médias',
                trailing: Icon(
                  Icons.photo_library_outlined,
                  color: Colors.white,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Galeries photos',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Groupe: $groupId',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.black.withValues(alpha: 0.55),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _TipCard(
                      title: 'Astuce',
                      message:
                          "Ici tu verras les galeries. Plus tard, on pourra brancher ça sur Firestore/Storage.",
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.92,
                ),
                delegate: SliverChildBuilderDelegate((context, i) {
                  final g = galleries[i];
                  return _GalleryCard(
                    title: g.title,
                    subtitle: g.subtitle,
                    count: g.images.length,
                    coverAsset: g.images.first,
                    gradient: g.gradient,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GalleryDetailPage(gallery: g),
                        ),
                      );
                    },
                  );
                }, childCount: galleries.length),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_Gallery> _demoGalleries() {
    // Démo locale (sans dépendances) : on réutilise le logo en attendant de brancher Storage.
    // Remplace _demoAsset par des URLs ou des assets réels plus tard.
    return [
      _Gallery(
        title: 'Backstage',
        subtitle: 'Coulisses & répétitions',
        images: const [_demoAsset, _demoAsset, _demoAsset, _demoAsset],
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE36A), Color(0xFFFF7BC5)],
        ),
      ),
      _Gallery(
        title: 'Live',
        subtitle: 'Concerts & scène',
        images: const [
          _demoAsset,
          _demoAsset,
          _demoAsset,
          _demoAsset,
          _demoAsset,
        ],
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF7BC5), Color(0xFF7CE0FF)],
        ),
      ),
      _Gallery(
        title: 'Team',
        subtitle: 'Moments du crew',
        images: const [_demoAsset, _demoAsset, _demoAsset],
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7CE0FF), Color(0xFFFFE36A)],
        ),
      ),
      _Gallery(
        title: 'Flyers',
        subtitle: 'Affiches & visuels',
        images: const [
          _demoAsset,
          _demoAsset,
          _demoAsset,
          _demoAsset,
          _demoAsset,
          _demoAsset,
        ],
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF171A20), Color(0xFF353B48)],
        ),
      ),
    ];
  }
}

class GalleryDetailPage extends StatelessWidget {
  const GalleryDetailPage({super.key, required this.gallery});

  final _Gallery gallery;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HoneycombBackground(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: RainbowHeader(
                title: gallery.title,
                trailing: IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  gallery.subtitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.black.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                delegate: SliverChildBuilderDelegate((context, i) {
                  final asset = gallery.images[i];
                  final heroTag = '${gallery.title}#$i';
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PhotoViewerPage(
                            title: gallery.title,
                            images: gallery.images,
                            initialIndex: i,
                            heroTagBuilder: (idx) => '${gallery.title}#$idx',
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Hero(
                        tag: heroTag,
                        child: Image.asset(asset, fit: BoxFit.cover),
                      ),
                    ),
                  );
                }, childCount: gallery.images.length),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PhotoViewerPage extends StatefulWidget {
  const PhotoViewerPage({
    super.key,
    required this.title,
    required this.images,
    required this.initialIndex,
    required this.heroTagBuilder,
  });

  final String title;
  final List<String> images;
  final int initialIndex;
  final String Function(int index) heroTagBuilder;

  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final asset = widget.images[i];
              return Center(
                child: Hero(
                  tag: widget.heroTagBuilder(i),
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Image.asset(asset, fit: BoxFit.contain),
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    color: Colors.white,
                  ),
                  Expanded(
                    child: Text(
                      '${widget.title}  (${_index + 1}/${widget.images.length})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
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
}

class _GalleryCard extends StatelessWidget {
  const _GalleryCard({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.coverAsset,
    required this.gradient,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final int count;
  final String coverAsset;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(coverAsset, fit: BoxFit.cover),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.05),
                        Colors.black.withValues(alpha: 0.65),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: gradient,
                      ),
                      child: Text(
                        '$count photos',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
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
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFE36A),
                  Color(0xFFFF7BC5),
                  Color(0xFF7CE0FF),
                ],
              ),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    height: 1.2,
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

class _Gallery {
  const _Gallery({
    required this.title,
    required this.subtitle,
    required this.images,
    required this.gradient,
  });

  final String title;
  final String subtitle;
  final List<String> images;
  final Gradient gradient;
}
