import 'package:flutter/material.dart';

import '../../../shop/pages/media_photo_shop_page.dart';
import '../../data/models/photographer_profile_model.dart';
import '../../data/repositories/photographer_repository.dart';
import '../../../../ui_kit/responsive/responsive.dart';

class PhotographerPublicStorefrontPage extends StatefulWidget {
  const PhotographerPublicStorefrontPage({
    super.key,
    required this.photographerId,
    this.countryId,
    this.countryName,
    this.eventId,
    this.eventName,
    this.circuitId,
    this.circuitName,
  });

  final String photographerId;
  final String? countryId;
  final String? countryName;
  final String? eventId;
  final String? eventName;
  final String? circuitId;
  final String? circuitName;

  @override
  State<PhotographerPublicStorefrontPage> createState() =>
      _PhotographerPublicStorefrontPageState();
}

class _PhotographerPublicStorefrontPageState
    extends State<PhotographerPublicStorefrontPage> {
  late final Future<PhotographerProfileModel?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = PhotographerRepository().getById(widget.photographerId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PhotographerProfileModel?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final storefront =
            profile?.publicStorefront ?? const <String, dynamic>{};
        final accent = _parseColor(storefront['accentColor']?.toString());
        final headline = storefront['headline']?.toString().trim();
        final description = storefront['description']?.toString().trim();
        final showName = storefront['showPhotographerName'] as bool? ?? true;
        final showEvent = storefront['showEventContext'] as bool? ?? true;
        final brands = (storefront['brands'] as Iterable? ?? const <dynamic>[])
            .whereType<Map>()
            .map((value) => Map<String, dynamic>.from(value))
            .toList(growable: false);

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Column(
            children: <Widget>[
              SafeArea(
                bottom: false,
                child: Material(
                  color: accent ?? Theme.of(context).colorScheme.surface,
                  elevation: 3,
                  child: ResponsivePageContainer(
                    maxContentWidth: 1280,
                    compactPadding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    mediumPadding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
                    expandedPadding: const EdgeInsets.fromLTRB(32, 16, 32, 18),
                    widePadding: const EdgeInsets.fromLTRB(40, 18, 40, 20),
                    child: Row(
                      children: <Widget>[
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back),
                          tooltip: 'Retour',
                        ),
                        if (profile?.avatarUrl?.isNotEmpty == true)
                          CircleAvatar(
                            radius: 27,
                            backgroundImage: NetworkImage(profile!.avatarUrl!),
                          )
                        else
                          const CircleAvatar(
                            radius: 27,
                            child: Icon(Icons.camera_alt_outlined),
                          ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              if (showName)
                                Text(
                                  profile?.brandName ?? 'Boutique photos',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                              if (headline?.isNotEmpty == true)
                                Text(
                                  headline!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (description?.isNotEmpty == true)
                                Text(
                                  description!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              if (showEvent &&
                                  (widget.eventName?.isNotEmpty == true ||
                                      widget.circuitName?.isNotEmpty == true))
                                Text(
                                  <String>[
                                    if (widget.eventName?.isNotEmpty == true)
                                      widget.eventName!,
                                    if (widget.circuitName?.isNotEmpty == true)
                                      widget.circuitName!,
                                  ].join(' • '),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                        if (brands.isNotEmpty)
                          PopupMenuButton<Map<String, dynamic>>(
                            tooltip: 'Marques et boutiques',
                            icon: const Icon(Icons.storefront_outlined),
                            itemBuilder: (context) => brands
                                .map(
                                  (
                                    brand,
                                  ) => PopupMenuItem<Map<String, dynamic>>(
                                    value: brand,
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        brand['name']?.toString() ?? 'Marque',
                                      ),
                                      subtitle: Text(
                                        brand['description']?.toString() ?? '',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                            onSelected: (brand) {
                              final domain = brand['domain']?.toString().trim();
                              if (domain?.isNotEmpty == true) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Boutique ${brand['name']} • $domain',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: MediaPhotoShopPage(
                  countryId: widget.countryId,
                  countryName: widget.countryName,
                  eventId: widget.eventId,
                  eventName: widget.eventName,
                  circuitId: widget.circuitId,
                  circuitName: widget.circuitName,
                  photographerId: widget.photographerId,
                  initialTabIndex: 0,
                  showBottomBar: false,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Color? _parseColor(String? value) {
    final raw = value?.replaceAll('#', '').trim();
    if (raw == null || (raw.length != 6 && raw.length != 8)) return null;
    final parsed = int.tryParse(raw, radix: 16);
    if (parsed == null) return null;
    return Color(raw.length == 6 ? 0xFF000000 | parsed : parsed);
  }
}
