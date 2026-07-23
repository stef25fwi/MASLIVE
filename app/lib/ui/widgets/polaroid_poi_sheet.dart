import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/restaurant_live_tables/widgets/live_table_status_section.dart';
import '../../utils/storage_url_cache.dart';

Future<void> showPolaroidPoiSheet({
  required BuildContext context,
  required String title,
  required String description,
  String? imageUrl,
  Map<String, dynamic>? meta,
  String? hours,
  String? phone,
  String? website,
  String? whatsapp,
  String? email,
  String? address,
  String? mapsUrl,
  double? lat,
  double? lng,
  String? countryId,
  String? eventId,
  String? circuitId,
  String? poiId,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fermer la fiche POI',
    barrierColor: Colors.black.withValues(alpha: .58),
    // Affichage quasi-instantané : fondu très court, sans scale/rebond, pour
    // que la fiche apparaisse immédiatement au tap (pas d'effet d'entrée long).
    // (showGeneralDialog utilise transitionDuration pour l'entrée ET la sortie.)
    transitionDuration: const Duration(milliseconds: 90),
    pageBuilder: (context, animation, secondaryAnimation) => PointerInterceptor(
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: PolaroidPoiSheet(
              title: title,
              description: description,
              imageUrl: imageUrl,
              meta: meta,
              hours: hours,
              phone: phone,
              website: website,
              whatsapp: whatsapp,
              email: email,
              address: address,
              mapsUrl: mapsUrl,
              lat: lat,
              lng: lng,
              countryId: countryId,
              eventId: eventId,
              circuitId: circuitId,
              poiId: poiId,
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      // Simple fondu (pas de scale/rebond) : la fiche est perçue comme
      // s'affichant instantanément.
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

class PolaroidPoiSheet extends StatelessWidget {
  const PolaroidPoiSheet({
    super.key,
    required this.title,
    required this.description,
    this.imageUrl,
    this.meta,
    this.hours,
    this.phone,
    this.website,
    this.whatsapp,
    this.email,
    this.address,
    this.mapsUrl,
    this.lat,
    this.lng,
    this.countryId,
    this.eventId,
    this.circuitId,
    this.poiId,
    this.maxHeightFactor = .86,
  });

  final String title;
  final String description;
  final String? imageUrl;
  final Map<String, dynamic>? meta;
  final String? hours;
  final String? phone;
  final String? website;
  final String? whatsapp;
  final String? email;
  final String? address;
  final String? mapsUrl;
  final double? lat;
  final double? lng;
  final String? countryId;
  final String? eventId;
  final String? circuitId;
  final String? poiId;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 390,
        maxHeight: media.size.height * maxHeightFactor,
      ),
      child: SingleChildScrollView(
        child: PolaroidPoiCard(
          title: title,
          description: description,
          imageUrl: imageUrl,
          meta: meta,
          hours: hours,
          phone: phone,
          website: website,
          whatsapp: whatsapp,
          email: email,
          address: address,
          mapsUrl: mapsUrl,
          lat: lat,
          lng: lng,
          countryId: countryId,
          eventId: eventId,
          circuitId: circuitId,
          poiId: poiId,
        ),
      ),
    );
  }
}

class PolaroidPoiCard extends StatelessWidget {
  const PolaroidPoiCard({
    super.key,
    required this.title,
    required this.description,
    this.imageUrl,
    this.meta,
    this.hours,
    this.phone,
    this.website,
    this.whatsapp,
    this.email,
    this.address,
    this.mapsUrl,
    this.lat,
    this.lng,
    this.countryId,
    this.eventId,
    this.circuitId,
    this.poiId,
  });

  final String title;
  final String description;
  final String? imageUrl;
  final Map<String, dynamic>? meta;
  final String? hours;
  final String? phone;
  final String? website;
  final String? whatsapp;
  final String? email;
  final String? address;
  final String? mapsUrl;
  final double? lat;
  final double? lng;
  final String? countryId;
  final String? eventId;
  final String? circuitId;
  final String? poiId;

  @override
  Widget build(BuildContext context) {
    String? effectiveImageUrl = imageUrl;
    if ((effectiveImageUrl ?? '').trim().isEmpty) {
      final image = meta?['image'];
      if (image is Map) {
        final value = (image['url'] ?? image['downloadUrl'] ?? '')
            .toString()
            .trim();
        if (value.isNotEmpty) effectiveImageUrl = value;
      }
    }
    final polaroid = meta?['polaroid'];
    final angleDeg = polaroid is Map && polaroid['angleDeg'] is num
        ? (polaroid['angleDeg'] as num).toDouble().clamp(-3.0, 3.0)
        : -1.1;

    return Transform.rotate(
      angle: angleDeg * math.pi / 180,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            elevation: 18,
            shadowColor: Colors.black.withValues(alpha: .38),
            color: const Color(0xFFF8F4E9),
            borderRadius: BorderRadius.circular(3),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F4E9),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: const Color(0xFFD8D0C0)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: 1.04,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(1),
                      child: _PhotoArea(imageUrl: effectiveImageUrl),
                    ),
                  ),
                  const SizedBox(height: 13),
                  _InfoArea(
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
                    meta: meta,
                    countryId: countryId,
                    eventId: eventId,
                    circuitId: circuitId,
                    poiId: poiId,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: -13,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Transform.rotate(
                  angle: -.035,
                  child: CustomPaint(
                    size: const Size(112, 34),
                    painter: _TapePainter(),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.white.withValues(alpha: .86),
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).maybePop(),
                child: const SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(Icons.close_rounded, size: 22),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoArea extends StatefulWidget {
  const _PhotoArea({required this.imageUrl});
  final String? imageUrl;

  @override
  State<_PhotoArea> createState() => _PhotoAreaState();
}

class _PhotoAreaState extends State<_PhotoArea> {
  String? _resolvedUrl;
  bool _resolving = false;
  static const _frameAssetPath = 'assets/images/frame_polaroid.webp';

  @override
  void initState() {
    super.initState();
    _resolve(widget.imageUrl);
  }

  @override
  void didUpdateWidget(covariant _PhotoArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) _resolve(widget.imageUrl);
  }

  Future<void> _resolve(String? raw) async {
    final url = (raw ?? '').trim();
    if (url.isEmpty ||
        url.startsWith('http://') ||
        url.startsWith('https://') ||
        url.startsWith('assets/') ||
        url.startsWith('/assets/')) {
      if (mounted) setState(() => _resolvedUrl = url.isEmpty ? null : url);
      return;
    }
    if (!url.startsWith('gs://') || _resolving) {
      if (mounted) setState(() => _resolvedUrl = url);
      return;
    }
    final cached = StorageUrlCache.peek(url);
    if (cached != null) {
      if (mounted) setState(() => _resolvedUrl = cached);
      return;
    }
    _resolving = true;
    try {
      final resolved = await StorageUrlCache.resolve(url);
      if (mounted) setState(() => _resolvedUrl = resolved);
    } catch (error) {
      if (kDebugMode) debugPrint('Polaroid image resolution failed: $error');
    } finally {
      _resolving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = (_resolvedUrl ?? widget.imageUrl ?? '').trim();
    final Widget image = url.isEmpty
        ? const _PhotoFallback()
        : url.startsWith('assets/') || url.startsWith('/assets/')
        ? Image.asset(
            url.startsWith('/') ? url.substring(1) : url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const _PhotoFallback(),
          )
        : Image.network(
            url,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            // Pas de spinner : on affiche le placeholder logo tant que la
            // photo n'est pas prête, puis on la révèle en fondu doux —
            // la fiche est donc complète et sans effet de chargement.
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : const _PhotoFallback(),
            frameBuilder: (_, child, frame, wasSync) {
              if (wasSync) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                child: child,
              );
            },
            errorBuilder: (_, _, _) => const _PhotoFallback(),
          );
    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        IgnorePointer(
          child: Image.asset(
            _frameAssetPath,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF1F1EF),
      child: Center(
        child: Image.asset(
          'assets/images/maslivelogo.png',
          width: 116,
          height: 116,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) =>
              const Icon(Icons.place_rounded, size: 54, color: Colors.black38),
        ),
      ),
    );
  }
}

class _InfoArea extends StatelessWidget {
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
    required this.meta,
    required this.countryId,
    required this.eventId,
    required this.circuitId,
    required this.poiId,
  });

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
  final Map<String, dynamic>? meta;
  final String? countryId;
  final String? eventId;
  final String? circuitId;
  final String? poiId;

  String? _cleanPhone(String? raw) {
    final value = (raw ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
    return value.isEmpty ? null : value;
  }

  String _prettyHours(String raw) {
    final value = raw.trim();
    if (value.isEmpty || !(value.startsWith('{') || value.startsWith('['))) {
      return value;
    }
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        return decoded.entries
            .take(3)
            .map((e) => '${e.key}: ${e.value}')
            .join(' · ');
      }
      if (decoded is List) return decoded.take(3).join(' · ');
    } catch (_) {}
    return '';
  }

  Future<void> _launch(BuildContext context, Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await canLaunchUrl(uri)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir cette action.')),
      );
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _directions(BuildContext context) async {
    final direct = (mapsUrl ?? '').trim();
    if (direct.isNotEmpty) {
      final uri = Uri.tryParse(direct);
      if (uri != null) return _launch(context, uri);
    }
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Coordonnées indisponibles.')),
      );
      return;
    }
    await _launch(
      context,
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final phoneValue = (phone ?? '').trim();
    final cleanedPhone = _cleanPhone(phone);
    final hoursValue = _prettyHours(hours ?? '');
    final descriptionValue = description.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'MASLIVEBrushV2',
                  fontSize: 30,
                  height: 1,
                  color: Color(0xFF161616),
                ),
              ),
            ),
            const Icon(Icons.favorite_border_rounded, size: 26),
          ],
        ),
        Container(
          height: 1,
          margin: const EdgeInsets.only(top: 5, bottom: 9),
          color: Colors.black.withValues(alpha: .24),
        ),
        if (descriptionValue.isNotEmpty) ...[
          Text(
            descriptionValue,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'MASLIVEBrushV2',
              fontSize: 18,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
        ],
        _InfoRow(
          icon: Icons.schedule_rounded,
          text: hoursValue.isEmpty ? 'Horaires non renseignés' : hoursValue,
          muted: hoursValue.isEmpty,
        ),
        const SizedBox(height: 5),
        _InfoRow(
          icon: Icons.phone_rounded,
          text: phoneValue.isEmpty ? 'Téléphone non renseigné' : phoneValue,
          muted: phoneValue.isEmpty,
        ),
        if ((address ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 5),
          _InfoRow(icon: Icons.place_rounded, text: address!.trim()),
        ],
        LiveTableStatusSection(
          meta: meta,
          countryId: countryId,
          eventId: eventId,
          circuitId: circuitId,
          poiId: poiId,
        ),
        const SizedBox(height: 13),
        Row(
          children: [
            Expanded(
              child: _BrushButton(
                icon: Icons.call_rounded,
                label: 'APPELER',
                onPressed: cleanedPhone == null
                    ? null
                    : () => _launch(
                        context,
                        Uri(scheme: 'tel', path: cleanedPhone),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BrushButton(
                icon: Icons.location_on_rounded,
                label: 'ITINÉRAIRE',
                onPressed:
                    (mapsUrl ?? '').trim().isNotEmpty ||
                        (lat != null && lng != null)
                    ? () => _directions(context)
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text, this.muted = false});
  final IconData icon;
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final color = muted ? Colors.black54 : Colors.black87;
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'MASLIVEBrushV2',
              fontSize: 16,
              height: 1.05,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _BrushButton extends StatelessWidget {
  const _BrushButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 45,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _BrushStrokePainter(enabled: onPressed != null)),
          TextButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.circle, size: 0),
            label: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: Colors.black),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
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

class _BrushStrokePainter extends CustomPainter {
  const _BrushStrokePainter({required this.enabled});
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF39AB7).withValues(alpha: enabled ? .9 : .35);
    final path = Path()
      ..moveTo(2, size.height * .28)
      ..quadraticBezierTo(
        size.width * .18,
        1,
        size.width * .43,
        size.height * .16,
      )
      ..quadraticBezierTo(
        size.width * .72,
        2,
        size.width - 2,
        size.height * .24,
      )
      ..lineTo(size.width - 5, size.height * .76)
      ..quadraticBezierTo(
        size.width * .68,
        size.height,
        size.width * .42,
        size.height * .86,
      )
      ..quadraticBezierTo(size.width * .17, size.height, 1, size.height * .73)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BrushStrokePainter oldDelegate) =>
      oldDelegate.enabled != enabled;
}

class _TapePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(3, 5)
      ..lineTo(size.width - 5, 0)
      ..lineTo(size.width - 1, size.height - 6)
      ..lineTo(7, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = const Color(0xFFE7D29E).withValues(alpha: .86),
    );
    final line = Paint()
      ..color = Colors.white.withValues(alpha: .18)
      ..strokeWidth = 1;
    for (double x = 8; x < size.width; x += 12) {
      canvas.drawLine(Offset(x, 4), Offset(x + 5, size.height - 5), line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
