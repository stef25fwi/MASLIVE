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
    // medium = rééchantillonnage lissé -> images scalées nettes (qualité Top).
    this.filterQuality = FilterQuality.medium,
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

  /// Placeholder très léger (aucune animation coûteuse): un aplat gris qui peint
  /// instantanément pendant le téléchargement. L'image apparaît ensuite en fondu.
  Widget _loadingPlaceholder() =>
      widget.placeholder ??
      Container(
        width: widget.width,
        height: widget.height,
        color: const Color(0x11000000),
      );

  /// Fondu à l'apparition (décodage). Un cache-hit s'affiche sans animation.
  Widget _fadeIn(
      BuildContext context, Widget child, int? frame, bool wasSync) {
    if (wasSync) return child;
    return AnimatedOpacity(
      opacity: frame == null ? 0 : 1,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = (_resolvedUrl ?? '').trim();

    // Décodage dimensionné à la taille utile: empreinte mémoire réduite,
    // moins d'évictions dans l'ImageCache -> listes/grilles fluides.
    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0;
    int? decodeWidth = widget.cacheWidth;
    if (decodeWidth == null &&
        widget.width != null &&
        widget.width!.isFinite &&
        widget.width! > 0) {
      decodeWidth = (widget.width! * dpr).round();
    }

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
        cacheWidth: decodeWidth,
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
        cacheWidth: decodeWidth,
        cacheHeight: widget.cacheHeight,
        // Évite le flash blanc quand l'URL change (réutilise l'ancienne frame).
        gaplessPlayback: true,
        frameBuilder: _fadeIn,
        loadingBuilder: (context, c, progress) {
          if (progress == null) return c;
          return _loadingPlaceholder();
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
