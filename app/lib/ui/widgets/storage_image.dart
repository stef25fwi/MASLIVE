import 'package:flutter/material.dart';

import '../../utils/storage_url_cache.dart';

/// Image réseau/Storage avec résolution `gs://` mise en cache.
///
/// - `http(s)://`  -> `Image.network` direct.
/// - `assets/...`  -> `Image.asset`.
/// - `gs://...`    -> download URL résolu via [StorageUrlCache] (cache mémoire
///   + déduplication). Un cache-hit s'affiche instantanément, sans requête ni
///   spinner — c'est le même mécanisme que la fiche polaroid, factorisé pour
///   être réutilisé par les galeries / la boutique.
///
/// Fournit `cacheWidth`/`cacheHeight` pour décoder l'image à la taille utile et
/// réduire l'empreinte mémoire (fluidité des listes/grilles).
class StorageImage extends StatefulWidget {
  const StorageImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.low,
    this.width,
    this.height,
    this.cacheWidth,
    this.cacheHeight,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  final String? url;
  final BoxFit fit;
  final Alignment alignment;
  final FilterQuality filterQuality;
  final double? width;
  final double? height;
  final int? cacheWidth;
  final int? cacheHeight;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  @override
  State<StorageImage> createState() => _StorageImageState();
}

class _StorageImageState extends State<StorageImage> {
  String? _resolvedUrl;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    _resolve(widget.url);
  }

  @override
  void didUpdateWidget(covariant StorageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.url ?? '').trim() != (widget.url ?? '').trim()) {
      _resolvedUrl = null;
      _resolve(widget.url);
    }
  }

  Future<void> _resolve(String? raw) async {
    final url = (raw ?? '').trim();
    if (url.isEmpty) {
      if (mounted) setState(() => _resolvedUrl = null);
      return;
    }

    // http(s) et assets: pas de résolution nécessaire.
    if (url.startsWith('http://') ||
        url.startsWith('https://') ||
        url.startsWith('assets/') ||
        url.startsWith('/assets/')) {
      if (mounted) setState(() => _resolvedUrl = url);
      return;
    }

    if (url.startsWith('gs://')) {
      // Cache-hit synchrone => affichage instantané.
      final cached = StorageUrlCache.peek(url);
      if (cached != null) {
        if (mounted) setState(() => _resolvedUrl = cached);
        return;
      }
      if (_resolving) return;
      _resolving = true;
      try {
        final resolved = await StorageUrlCache.resolve(url);
        if (mounted) setState(() => _resolvedUrl = resolved);
      } finally {
        _resolving = false;
      }
      return;
    }

    // Format inconnu: on laisse Image.network gérer/échouer.
    if (mounted) setState(() => _resolvedUrl = url);
  }

  Widget _fallback() =>
      widget.errorWidget ??
      Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey.shade200,
        child: const Icon(Icons.image_not_supported_outlined,
            color: Colors.grey),
      );

  @override
  Widget build(BuildContext context) {
    final url = (_resolvedUrl ?? '').trim();

    Widget child;
    if (url.isEmpty) {
      child = widget.placeholder ?? _fallback();
    } else if (url.startsWith('assets/') || url.startsWith('/assets/')) {
      child = Image.asset(
        url.startsWith('/assets/') ? url.substring(1) : url,
        fit: widget.fit,
        alignment: widget.alignment,
        filterQuality: widget.filterQuality,
        width: widget.width,
        height: widget.height,
        cacheWidth: widget.cacheWidth,
        cacheHeight: widget.cacheHeight,
        errorBuilder: (context, error, stack) => _fallback(),
      );
    } else {
      child = Image.network(
        url,
        fit: widget.fit,
        alignment: widget.alignment,
        filterQuality: widget.filterQuality,
        width: widget.width,
        height: widget.height,
        cacheWidth: widget.cacheWidth,
        cacheHeight: widget.cacheHeight,
        loadingBuilder: (context, c, progress) {
          if (progress == null) return c;
          return widget.placeholder ??
              const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
        },
        errorBuilder: (context, error, stack) => _fallback(),
      );
    }

    if (widget.borderRadius != null) {
      child = ClipRRect(borderRadius: widget.borderRadius!, child: child);
    }
    return child;
  }
}
