import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/honeycomb_background.dart';
import '../widgets/rainbow_header.dart';

class MediaGalleriesPage extends StatelessWidget {
  const MediaGalleriesPage({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
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
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _queryForGroup(groupId).snapshots(),
              builder: (context, snapshot) {
                final isLoading = snapshot.connectionState == ConnectionState.waiting;
                final docs = snapshot.data?.docs ?? const [];
                final galleries = docs.asMap().entries.map((entry) {
                  final data = entry.value.data();
                  final imagesRaw = data['images'];
                  final images = imagesRaw is List ? imagesRaw.whereType<String>().toList() : <String>[];
                  final photoCount = (data['photoCount'] is int) ? data['photoCount'] as int : images.length;
                  return Gallery(
                    id: entry.value.id,
                    title: (data['title'] as String?)?.trim().isNotEmpty == true ? data['title'] as String : 'Sans titre',
                    subtitle: (data['subtitle'] as String?) ?? '',
                    images: images,
                    coverUrl: (data['coverUrl'] as String?) ?? (images.isNotEmpty ? images.first : null),
                    gradient: _palette[entry.key % _palette.length],
                    photoCount: photoCount,
                  );
                }).toList();

                return SliverList.list(children: [
                  Padding(
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
                          groupId == 'all' ? 'Toutes les galeries' : 'Groupe: $groupId',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.black.withValues(alpha: 0.55),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 12),
                        if (isLoading) const _TipCard(title: 'Chargement', message: 'Récupération des galeries...') else if (galleries.isEmpty)
                          const _TipCard(title: 'Aucune galerie', message: 'Ajoute des galeries depuis Firestore (collection: media_galleries).'),
                      ],
                    ),
                  ),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (galleries.isEmpty)
                    const SizedBox.shrink()
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: galleries.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.92,
                        ),
                        itemBuilder: (context, i) {
                          final g = galleries[i];
                          return _GalleryCard(
                            title: g.title,
                            subtitle: g.subtitle,
                            count: g.photoCount,
                            cover: g.coverUrl,
                            fallbackAsset: _demoAsset,
                            gradient: g.gradient,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => GalleryDetailPage(gallery: g),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }

  Query<Map<String, dynamic>> _queryForGroup(String groupId) {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection('media_galleries');
    final trimmed = groupId.trim();
    if (trimmed.isNotEmpty && trimmed != 'all') {
      q = q.where('groupId', isEqualTo: trimmed);
    }
    return q.orderBy('createdAt', descending: true);
  }
}

class GalleryDetailPage extends StatelessWidget {
  const GalleryDetailPage({super.key, required this.gallery});

  final Gallery gallery;

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
                  final heroTag = '${gallery.id}#$i';
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PhotoViewerPage(
                            title: gallery.title,
                            images: gallery.images,
                            initialIndex: i,
                            heroTagBuilder: (idx) => '${gallery.id}#$idx',
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Hero(
                        tag: heroTag,
                        child: _GalleryImage(src: asset, fit: BoxFit.cover),
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
                    child: _GalleryImage(src: asset, fit: BoxFit.contain),
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
    required this.cover,
    required this.fallbackAsset,
    required this.gradient,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final int count;
  final String? cover;
  final String fallbackAsset;
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
                child: _GalleryImage(
                  src: cover ?? fallbackAsset,
                  fit: BoxFit.cover,
                ),
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

class Gallery {
  const Gallery({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.images,
    required this.gradient,
    required this.photoCount,
    this.coverUrl,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<String> images;
  final Gradient gradient;
  final String? coverUrl;
  final int photoCount;
}

class _GalleryImage extends StatelessWidget {
  const _GalleryImage({required this.src, this.fit = BoxFit.cover});

  final String src;
  final BoxFit fit;

  bool get _isNetwork => src.startsWith('http');

  @override
  Widget build(BuildContext context) {
    if (_isNetwork) {
      return Image.network(
        src,
        fit: fit,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    return Image.asset(src, fit: fit, errorBuilder: (_, __, ___) => _fallback());
  }

  Widget _fallback() {
    return Container(
      color: Colors.black.withValues(alpha: 0.06),
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported_outlined, color: Colors.white70),
    );
  }
}

const _demoAsset = 'assets/splash/maslive.png';

const _palette = [
  LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFE36A), Color(0xFFFF7BC5)],
  ),
  LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF7BC5), Color(0xFF7CE0FF)],
  ),
  LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7CE0FF), Color(0xFFFFE36A)],
  ),
  LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF171A20), Color(0xFF353B48)],
  ),
];
