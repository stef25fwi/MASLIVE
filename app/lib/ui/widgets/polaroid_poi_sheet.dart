import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../ui_kit/tokens/maslive_tokens.dart';

Future<void> showPolaroidPoiSheet({
  required BuildContext context,
  required String title,
  required String description,
  String? imageUrl,
  String? hours,
  String? phone,
  String? website,
  String? whatsapp,
  String? email,
  String? address,
  String? mapsUrl,
  double? lat,
  double? lng,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => PolaroidPoiSheet(
      title: title,
      description: description,
      imageUrl: imageUrl,
      hours: hours,
      phone: phone,
      website: website,
      whatsapp: whatsapp,
      email: email,
      address: address,
      mapsUrl: mapsUrl,
      lat: lat,
      lng: lng,
    ),
  );
}

class PolaroidPoiSheet extends StatelessWidget {
  final String title;
  final String description;
  final String? imageUrl;
  final String? hours;
  final String? phone;
  final String? website;
  final String? whatsapp;
  final String? email;
  final String? address;
  final String? mapsUrl;
  final double? lat;
  final double? lng;

  /// Hauteur max du bottom sheet (0.0 - 1.0)
  final double maxHeightFactor;

  const PolaroidPoiSheet({
    super.key,
    required this.title,
    required this.description,
    this.imageUrl,
    this.hours,
    this.phone,
    this.website,
    this.whatsapp,
    this.email,
    this.address,
    this.mapsUrl,
    this.lat,
    this.lng,
    this.maxHeightFactor = 0.78,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: MasliveTokens.m,
          right: MasliveTokens.m,
          bottom: MasliveTokens.m + media.viewInsets.bottom,
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: media.size.height * maxHeightFactor,
              maxWidth: 520,
            ),
            child: Material(
              elevation: 10,
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(MasliveTokens.rL),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(MasliveTokens.rL),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: MasliveTokens.surface.withValues(alpha: 0.92),
                    border: Border.all(color: MasliveTokens.borderSoft),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SheetHeader(
                        title: 'Fiche POI',
                        onClose: () => Navigator.of(context).maybePop(),
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                            MasliveTokens.m,
                            MasliveTokens.s,
                            MasliveTokens.m,
                            MasliveTokens.m,
                          ),
                          child: PolaroidPoiCard(
                            title: title,
                            description: description,
                            imageUrl: imageUrl,
                            hours: hours,
                            phone: phone,
                            website: website,
                            whatsapp: whatsapp,
                            email: email,
                            address: address,
                            mapsUrl: mapsUrl,
                            lat: lat,
                            lng: lng,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PolaroidPoiCard extends StatelessWidget {
  final String title;
  final String description;
  final String? imageUrl;
  final String? hours;
  final String? phone;
  final String? website;
  final String? whatsapp;
  final String? email;
  final String? address;
  final String? mapsUrl;
  final double? lat;
  final double? lng;

  const PolaroidPoiCard({
    super.key,
    required this.title,
    required this.description,
    this.imageUrl,
    this.hours,
    this.phone,
    this.website,
    this.whatsapp,
    this.email,
    this.address,
    this.mapsUrl,
    this.lat,
    this.lng,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: 1 / 1.18,
        child: Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MasliveTokens.rM),
            side: BorderSide(color: MasliveTokens.borderSoft),
          ),
          elevation: 0,
          color: MasliveTokens.surface,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(MasliveTokens.rM),
            child: Column(
              children: [
                Expanded(
                  flex: 72,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      MasliveTokens.s,
                      MasliveTokens.s,
                      MasliveTokens.s,
                      MasliveTokens.xs,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(MasliveTokens.rS),
                      child: _PhotoArea(imageUrl: imageUrl),
                    ),
                  ),
                ),
                Expanded(
                  flex: 46,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(
                      MasliveTokens.m,
                      MasliveTokens.s,
                      MasliveTokens.m,
                      MasliveTokens.s,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: MasliveTokens.borderSoft),
                      ),
                    ),
                    child: _InfoArea(
                      title: title,
                      description: description,
                      hours: hours,
                      phone: phone,
                      website: website,
                      whatsapp: whatsapp,
                      email: email,
                      address: address,
                      mapsUrl: mapsUrl,
                      lat: lat,
                      lng: lng,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoArea extends StatelessWidget {
  final String? imageUrl;
  const _PhotoArea({required this.imageUrl});

  static const String _frameAssetWebpPath = 'assets/images/frame_polaroid.webp';

  Widget _frameAsset(
    String assetPath, {
    required Widget fallback,
  }) {
    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }

  Widget _buildFrameOverlay() {
    final borderFallback = DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: MasliveTokens.borderSoft),
        borderRadius: BorderRadius.circular(MasliveTokens.rS),
      ),
    );

    return IgnorePointer(
      child: _frameAsset(
        _frameAssetWebpPath,
        fallback: borderFallback,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = (imageUrl ?? '').trim();
    if (url.isEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          const _PhotoFallback(),
          _buildFrameOverlay(),
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) => const _PhotoFallback(),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return DecoratedBox(
              decoration: BoxDecoration(
                color: MasliveTokens.bg,
              ),
              child: const Center(
                child: SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
        ),
        _buildFrameOverlay(),
      ],
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MasliveTokens.bg,
      ),
      child: Center(
        child: Image.asset(
          'assets/images/maslivesmall.png',
          width: 56,
          height: 56,
        ),
      ),
    );
  }
}

class _InfoArea extends StatelessWidget {
  final String title;
  final String description;
  final String? hours;
  final String? phone;
  final String? website;
  final String? whatsapp;
  final String? email;
  final String? address;
  final String? mapsUrl;
  final double? lat;
  final double? lng;

  const _InfoArea({
    required this.title,
    required this.description,
    required this.hours,
    required this.phone,
    required this.website,
    required this.whatsapp,
    required this.email,
    required this.address,
    required this.mapsUrl,
    required this.lat,
    required this.lng,
  });

  String? _cleanPhone(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return null;
    final cleaned = s.replaceAll(RegExp(r'[^0-9\+]'), '');
    return cleaned.isEmpty ? null : cleaned;
  }

  Future<void> _launchTel(BuildContext context, String phone) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await canLaunchUrl(uri)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'ouvrir l\'appel téléphonique.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await launchUrl(uri);
  }

  Future<void> _openDirections(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final direct = (mapsUrl ?? '').trim();
    if (direct.isNotEmpty) {
      final uri = Uri.tryParse(direct);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    final la = lat;
    final ln = lng;
    if (la == null || ln == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Coordonnées indisponibles.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$la,$ln',
    );

    if (!await canLaunchUrl(uri)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'ouvrir l\'itinéraire.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openWebsite(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final raw = url.trim();
    final withScheme = raw.contains('://') ? raw : 'https://$raw';
    final uri = Uri.tryParse(withScheme);
    if (uri == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Lien invalide.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!await canLaunchUrl(uri)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'ouvrir le site.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final desc = description.trim();
    final hrs = (hours ?? '').trim();
    final telRaw = (phone ?? '').trim();
    final site = (website ?? '').trim();
    final wa = (whatsapp ?? '').trim();
    final mail = (email ?? '').trim();
    final addr = (address ?? '').trim();

    final telClean = _cleanPhone(telRaw);
    final canCall = telClean != null;
    final canDirections = (mapsUrl ?? '').trim().isNotEmpty || (lat != null && lng != null);
    final canWebsite = site.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            height: 1.1,
            color: MasliveTokens.text,
          ),
        ),
        const SizedBox(height: 6),
        if (desc.isNotEmpty)
          Text(
            desc,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.25,
              color: MasliveTokens.text.withValues(alpha: 0.70),
              fontWeight: FontWeight.w600,
            ),
          )
        else
          Text(
            'Aucune description',
            style: TextStyle(
              fontSize: 13,
              color: MasliveTokens.textSoft,
              fontWeight: FontWeight.w600,
            ),
          ),
        const SizedBox(height: 10),
        _InfoRow(
          icon: Icons.access_time,
          text: hrs.isNotEmpty ? hrs : 'Horaires non renseignés',
          muted: hrs.isEmpty,
        ),
        const SizedBox(height: 6),
        _InfoRow(
          icon: Icons.phone,
          text: telRaw.isNotEmpty ? telRaw : 'Téléphone non renseigné',
          muted: telRaw.isEmpty,
        ),
        if (site.isNotEmpty) ...[
          const SizedBox(height: 6),
          _InfoRow(icon: Icons.public, text: site),
        ],
        if (wa.isNotEmpty) ...[
          const SizedBox(height: 6),
          _InfoRow(icon: Icons.chat_bubble_outline, text: wa),
        ],
        if (mail.isNotEmpty) ...[
          const SizedBox(height: 6),
          _InfoRow(icon: Icons.email_outlined, text: mail),
        ],
        if (addr.isNotEmpty) ...[
          const SizedBox(height: 6),
          _InfoRow(icon: Icons.place, text: addr),
        ],
        const Spacer(),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: canCall ? () => _launchTel(context, telClean) : null,
                icon: const Icon(Icons.call),
                label: const Text('Appeler'),
              ),
            ),
            const SizedBox(width: MasliveTokens.s),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: canDirections ? () => _openDirections(context) : null,
                icon: const Icon(Icons.directions),
                label: const Text('Itinéraire'),
              ),
            ),
            const SizedBox(width: MasliveTokens.s),
            if (canWebsite) ...[
              IconButton(
                onPressed: () => _openWebsite(context, site),
                icon: const Icon(Icons.public),
                tooltip: 'Site',
              ),
            ],
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Fermer',
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool muted;

  const _InfoRow({
    required this.icon,
    required this.text,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = muted ? MasliveTokens.textSoft : MasliveTokens.text.withValues(alpha: 0.75);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 1.15,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final String title;
  final VoidCallback onClose;

  const _SheetHeader({
    required this.title,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        MasliveTokens.m,
        MasliveTokens.s,
        MasliveTokens.xs,
        MasliveTokens.xs,
      ),
      decoration: BoxDecoration(
        color: MasliveTokens.surface.withValues(alpha: 0.75),
        border: Border(
          bottom: BorderSide(color: MasliveTokens.borderSoft),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14.5,
                color: MasliveTokens.text,
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}

