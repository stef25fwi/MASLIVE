import 'package:flutter/material.dart';

import '../../data/models/bloom_art_item.dart';
import 'bloom_art_cta_button.dart';

class BloomArtItemCard extends StatelessWidget {
  const BloomArtItemCard({
    super.key,
    required this.item,
    required this.onTap,
    this.showSellerMeta = true,
  });

  final BloomArtItem item;
  final VoidCallback onTap;
  final bool showSellerMeta;

  @override
  Widget build(BuildContext context) {
    final cover = item.images.isNotEmpty ? item.images.first : null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE9DED1)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 24,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: AspectRatio(
                aspectRatio: 1.15,
                child: cover == null
                    ? Container(
                        color: const Color(0xFFF6EEE5),
                        child: const Icon(
                          Icons.palette_outlined,
                          size: 48,
                          color: Color(0xFF9A836D),
                        ),
                      )
                    : Image.network(cover, fit: BoxFit.cover),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.category.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.1,
                      color: Color(0xFF8E6D4F),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF5F564F),
                      height: 1.45,
                    ),
                  ),
                  if (showSellerMeta && item.sellerDisplayName.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(
                      item.sellerDisplayName,
                      style: const TextStyle(
                        color: Color(0xFF6A645E),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  BloomArtCtaButton(
                    label: 'Proposer un prix',
                    icon: Icons.local_offer_outlined,
                    expanded: true,
                    onPressed: onTap,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}