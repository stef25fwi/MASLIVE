from __future__ import annotations

from pathlib import Path


DASHBOARD = Path(
    "app/lib/features/bloom_art/presentation/pages/bloom_art_seller_dashboard_page.dart"
)
CREATE_PAGE = Path(
    "app/lib/features/bloom_art/presentation/pages/bloom_art_item_create_page.dart"
)
OFFER_DETAIL = Path(
    "app/lib/features/bloom_art/presentation/pages/bloom_art_offer_detail_page.dart"
)
MAKE_OFFER = Path(
    "app/lib/features/bloom_art/presentation/pages/bloom_art_make_offer_sheet.dart"
)

RESPONSIVE_IMPORT = "import '../../../../ui_kit/responsive/responsive.dart';"


def ensure_import(path: Path, anchor: str) -> None:
    source = path.read_text(encoding="utf-8")
    if RESPONSIVE_IMPORT in source:
        return
    if anchor not in source:
        raise RuntimeError(f"Import anchor missing in {path}: {anchor}")
    path.write_text(
        source.replace(anchor, f"{anchor}\n{RESPONSIVE_IMPORT}", 1),
        encoding="utf-8",
    )


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    source = path.read_text(encoding="utf-8")
    count = source.count(old)
    if count != 1:
        raise RuntimeError(
            f"Expected exactly one {label} occurrence in {path}, found {count}"
        )
    path.write_text(source.replace(old, new, 1), encoding="utf-8")


def replace_last(path: Path, old: str, new: str, label: str) -> None:
    source = path.read_text(encoding="utf-8")
    index = source.rfind(old)
    if index < 0:
        raise RuntimeError(f"Missing tail {label} in {path}")
    path.write_text(
        source[:index] + new + source[index + len(old) :], encoding="utf-8"
    )


def transform_dashboard() -> None:
    ensure_import(
        DASHBOARD,
        "import 'package:masslive/ui_kit/tokens/maslive_tokens.dart';",
    )

    replace_once(
        DASHBOARD,
        """          return ListView(
            padding: const EdgeInsets.fromLTRB(10, 16, 10, 28),
            children: <Widget>[
""",
        """          return ResponsivePageContainer(
            maxContentWidth: 1280,
            compactPadding: EdgeInsets.zero,
            mediumPadding: EdgeInsets.zero,
            expandedPadding: EdgeInsets.zero,
            widePadding: EdgeInsets.zero,
            child: ListView(
              padding: responsiveValue<EdgeInsets>(
                context,
                compact: const EdgeInsets.fromLTRB(10, 16, 10, 28),
                medium: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                expanded: const EdgeInsets.fromLTRB(36, 24, 36, 36),
                wide: const EdgeInsets.fromLTRB(44, 28, 44, 40),
              ),
              children: <Widget>[
""",
        "dashboard responsive container start",
    )

    replace_last(
        DASHBOARD,
        """              ],
            ],
          );
""",
        """              ],
              ],
            ),
          );
""",
        "dashboard responsive container end",
    )

    replace_once(
        DASHBOARD,
        """                    return Column(
                      children: items
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: BloomArtItemCard(
                                item: item,
                                showSellerMeta: false,
                                onTap: () => Navigator.of(context).pushNamed(
                                  '/bloom-art/item/${item.id}',
                                ),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    );
""",
        """                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = responsiveValue<int>(
                          context,
                          compact: 1,
                          medium: 2,
                          expanded: 3,
                          wide: 3,
                        );
                        final spacing = responsiveValue<double>(
                          context,
                          compact: 0,
                          medium: 14,
                          expanded: 16,
                          wide: 18,
                        );
                        final cardWidth =
                            (constraints.maxWidth - spacing * (columns - 1)) /
                            columns;
                        return Wrap(
                          spacing: spacing,
                          runSpacing: 14,
                          children: items
                              .map(
                                (item) => SizedBox(
                                  width: cardWidth,
                                  child: BloomArtItemCard(
                                    item: item,
                                    showSellerMeta: false,
                                    onTap: () => Navigator.of(context).pushNamed(
                                      '/bloom-art/item/${item.id}',
                                    ),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        );
                      },
                    );
""",
        "dashboard creations grid",
    )

    replace_once(
        DASHBOARD,
        """                    return Column(
                      children: offers
                          .map(
                            (offer) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _OfferPreviewCard(offer: offer),
                            ),
                          )
                          .toList(growable: false),
                    );
""",
        """                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = responsiveValue<int>(
                          context,
                          compact: 1,
                          medium: 2,
                          expanded: 2,
                          wide: 3,
                        );
                        final spacing = responsiveValue<double>(
                          context,
                          compact: 0,
                          medium: 14,
                          expanded: 16,
                          wide: 18,
                        );
                        final cardWidth =
                            (constraints.maxWidth - spacing * (columns - 1)) /
                            columns;
                        return Wrap(
                          spacing: spacing,
                          runSpacing: 12,
                          children: offers
                              .map(
                                (offer) => SizedBox(
                                  width: cardWidth,
                                  child: _OfferPreviewCard(offer: offer),
                                ),
                              )
                              .toList(growable: false),
                        );
                      },
                    );
""",
        "dashboard offers grid",
    )


def transform_create_page() -> None:
    ensure_import(
        CREATE_PAGE,
        "import '../../../../ui/widgets/maslive_text_field.dart';",
    )

    replace_once(
        CREATE_PAGE,
        """                  : Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(10, 16, 10, 28),
                        children: <Widget>[
""",
        """                  : ResponsivePageContainer(
                      maxContentWidth: 1120,
                      compactPadding: EdgeInsets.zero,
                      mediumPadding: EdgeInsets.zero,
                      expandedPadding: EdgeInsets.zero,
                      widePadding: EdgeInsets.zero,
                      child: Form(
                        key: _formKey,
                        child: ListView(
                          padding: responsiveValue<EdgeInsets>(
                            context,
                            compact: const EdgeInsets.fromLTRB(10, 16, 10, 28),
                            medium: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                            expanded: const EdgeInsets.fromLTRB(36, 24, 36, 36),
                            wide: const EdgeInsets.fromLTRB(44, 28, 44, 40),
                          ),
                          children: <Widget>[
""",
        "create page responsive container start",
    )

    replace_last(
        CREATE_PAGE,
        """                        ],
                      ),
                    ),
    );
""",
        """                          ],
                        ),
                      ),
                    ),
    );
""",
        "create page responsive container end",
    )

    replace_once(
        CREATE_PAGE,
        """                          _BloomArtField(
                            controller: _categoryController,
                            label: 'Type de création / catégorie',
                            validator: _requiredValidator,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _condition,
                            decoration: const InputDecoration(
                              labelText: 'État',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            items: const <DropdownMenuItem<String>>[
                              DropdownMenuItem(value: 'excellent', child: Text('Excellent')),
                              DropdownMenuItem(value: 'good', child: Text('Bon')),
                              DropdownMenuItem(value: 'patina', child: Text('Patine / pièce vécue')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _condition = value ?? 'excellent';
                              });
                            },
                          ),
""",
        """                          _BloomArtResponsivePair(
                            first: _BloomArtField(
                              controller: _categoryController,
                              label: 'Type de création / catégorie',
                              validator: _requiredValidator,
                            ),
                            second: DropdownButtonFormField<String>(
                              initialValue: _condition,
                              decoration: const InputDecoration(
                                labelText: 'État',
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              items: const <DropdownMenuItem<String>>[
                                DropdownMenuItem(
                                  value: 'excellent',
                                  child: Text('Excellent'),
                                ),
                                DropdownMenuItem(
                                  value: 'good',
                                  child: Text('Bon'),
                                ),
                                DropdownMenuItem(
                                  value: 'patina',
                                  child: Text('Patine / pièce vécue'),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _condition = value ?? 'excellent';
                                });
                              },
                            ),
                          ),
""",
        "create category condition pair",
    )

    replace_once(
        CREATE_PAGE,
        """                          _BloomArtField(controller: _dimensionsController, label: 'Dimensions'),
                          const SizedBox(height: 12),
                          _BloomArtField(
                            controller: _materialsController,
                            label: 'Matériaux (séparés par des virgules)',
                          ),
""",
        """                          _BloomArtResponsivePair(
                            first: _BloomArtField(
                              controller: _dimensionsController,
                              label: 'Dimensions',
                            ),
                            second: _BloomArtField(
                              controller: _materialsController,
                              label: 'Matériaux (séparés par des virgules)',
                            ),
                          ),
""",
        "create dimensions materials pair",
    )

    replace_once(
        CREATE_PAGE,
        """                          _BloomArtField(
                            controller: _referencePriceController,
                            label: 'Prix de référence privé (EUR)',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: _requiredValidator,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _deliveryMode,
                            decoration: const InputDecoration(
                              labelText: 'Mode de remise / livraison',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            items: const <DropdownMenuItem<String>>[
                              DropdownMenuItem(
                                value: 'delivery_or_pickup',
                                child: Text('Livraison ou remise en main propre'),
                              ),
                              DropdownMenuItem(value: 'delivery_only', child: Text('Livraison uniquement')),
                              DropdownMenuItem(value: 'pickup_only', child: Text('Remise en main propre uniquement')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _deliveryMode = value ?? 'delivery_or_pickup';
                              });
                            },
                          ),
""",
        """                          _BloomArtResponsivePair(
                            first: _BloomArtField(
                              controller: _referencePriceController,
                              label: 'Prix de référence privé (EUR)',
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              validator: _requiredValidator,
                            ),
                            second: DropdownButtonFormField<String>(
                              initialValue: _deliveryMode,
                              decoration: const InputDecoration(
                                labelText: 'Mode de remise / livraison',
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              items: const <DropdownMenuItem<String>>[
                                DropdownMenuItem(
                                  value: 'delivery_or_pickup',
                                  child: Text(
                                    'Livraison ou remise en main propre',
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'delivery_only',
                                  child: Text('Livraison uniquement'),
                                ),
                                DropdownMenuItem(
                                  value: 'pickup_only',
                                  child: Text(
                                    'Remise en main propre uniquement',
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _deliveryMode = value ?? 'delivery_or_pickup';
                                });
                              },
                            ),
                          ),
""",
        "create price delivery pair",
    )

    replace_once(
        CREATE_PAGE,
        """class _BlockedCreateState extends StatelessWidget {
""",
        """class _BloomArtResponsivePair extends StatelessWidget {
  const _BloomArtResponsivePair({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    if (context.isCompactLayout) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          first,
          const SizedBox(height: 12),
          second,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: first),
        const SizedBox(width: 16),
        Expanded(child: second),
      ],
    );
  }
}

class _BlockedCreateState extends StatelessWidget {
""",
        "create responsive pair helper",
    )


def transform_offer_detail() -> None:
    ensure_import(
        OFFER_DETAIL,
        "import 'package:masslive/ui_kit/tokens/maslive_tokens.dart';",
    )

    replace_once(
        OFFER_DETAIL,
        """              return ListView(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 28),
                children: <Widget>[
                  _OfferSummaryCard(offer: offer, item: item),
                  const SizedBox(height: 18),
                  _ActionPanel(
                    offer: offer,
                    isSeller: currentUser.uid == offer.sellerId,
                    isBuyer: currentUser.uid == offer.buyerId,
                    busy: _busy,
                    onAccept: () => _acceptOffer(offer),
                    onDecline: () => _declineOffer(offer),
                    onCheckout: () => _startCheckout(offer),
                  ),
                ],
              );
""",
        """              return ResponsivePageContainer(
                maxContentWidth: 1120,
                compactPadding: EdgeInsets.zero,
                mediumPadding: EdgeInsets.zero,
                expandedPadding: EdgeInsets.zero,
                widePadding: EdgeInsets.zero,
                child: ListView(
                  padding: responsiveValue<EdgeInsets>(
                    context,
                    compact: const EdgeInsets.fromLTRB(12, 16, 12, 28),
                    medium: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                    expanded: const EdgeInsets.fromLTRB(36, 24, 36, 36),
                    wide: const EdgeInsets.fromLTRB(44, 28, 44, 40),
                  ),
                  children: <Widget>[
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final summary = _OfferSummaryCard(
                          offer: offer,
                          item: item,
                        );
                        final actions = _ActionPanel(
                          offer: offer,
                          isSeller: currentUser.uid == offer.sellerId,
                          isBuyer: currentUser.uid == offer.buyerId,
                          busy: _busy,
                          onAccept: () => _acceptOffer(offer),
                          onDecline: () => _declineOffer(offer),
                          onCheckout: () => _startCheckout(offer),
                        );
                        if (context.isCompactLayout) {
                          return Column(
                            children: <Widget>[
                              summary,
                              const SizedBox(height: 18),
                              actions,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(flex: 3, child: summary),
                            const SizedBox(width: 20),
                            Expanded(flex: 2, child: actions),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              );
""",
        "offer detail responsive layout",
    )


def transform_make_offer() -> None:
    ensure_import(
        MAKE_OFFER,
        "import 'package:masslive/ui_kit/tokens/maslive_tokens.dart';",
    )

    replace_once(
        MAKE_OFFER,
        """      child: Container(
        decoration: const BoxDecoration(
          color: MasliveTokens.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: SingleChildScrollView(
""",
        """      child: ResponsiveOverlayContainer(
        compactHorizontalInset: 0,
        mediumMaxWidth: 620,
        expandedMaxWidth: 680,
        wideMaxWidth: 720,
        alignment: Alignment.bottomCenter,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: MasliveTokens.surface,
            borderRadius: responsiveValue<BorderRadius>(
              context,
              compact: const BorderRadius.vertical(
                top: Radius.circular(34),
              ),
              medium: BorderRadius.circular(34),
              expanded: BorderRadius.circular(34),
              wide: BorderRadius.circular(34),
            ),
          ),
          padding: responsiveValue<EdgeInsets>(
            context,
            compact: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            medium: const EdgeInsets.fromLTRB(28, 22, 28, 28),
            expanded: const EdgeInsets.fromLTRB(32, 24, 32, 30),
            wide: const EdgeInsets.fromLTRB(36, 26, 36, 32),
          ),
          child: SingleChildScrollView(
""",
        "make offer responsive sheet start",
    )

    replace_last(
        MAKE_OFFER,
        """          ),
        ),
      ),
    );
""",
        """            ),
          ),
        ),
      ),
    );
""",
        "make offer responsive sheet end",
    )


def main() -> None:
    transform_dashboard()
    transform_create_page()
    transform_offer_detail()
    transform_make_offer()
    print("Responsive Bloom Art conversion applied successfully.")


if __name__ == "__main__":
    main()
