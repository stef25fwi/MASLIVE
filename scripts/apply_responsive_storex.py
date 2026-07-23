from __future__ import annotations

import re
from pathlib import Path


STOREX_PATH = Path("app/lib/pages/storex_shop_page.dart")


def replace_once(source: str, old: str, new: str, label: str) -> str:
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one match, found {count}")
    return source.replace(old, new, 1)


def regex_replace_once(
    source: str,
    pattern: str,
    replacement: str,
    label: str,
) -> str:
    updated, count = re.subn(pattern, replacement, source, count=1, flags=re.S)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one match, found {count}")
    return updated


def main() -> None:
    source = STOREX_PATH.read_text(encoding="utf-8")

    if "../ui_kit/responsive/responsive.dart" not in source:
        source = replace_once(
            source,
            "import '../ui/widgets/maslive_button.dart';\n",
            "import '../ui/widgets/maslive_button.dart';\n"
            "import '../ui_kit/responsive/responsive.dart';\n",
            "responsive import",
        )

    source = replace_once(
        source,
        """                      const SizedBox(height: 16),
                      SizedBox(
                        height: 46,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: cats.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 12),
""",
        """                      const SizedBox(height: 12),
                      SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: cats.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 8),
""",
        "compact category strip",
    )

    source = replace_once(
        source,
        """                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.735,
                          ),
""",
        """                      gridDelegate: ResponsiveGridDelegate(
                        context: context,
                        compactCount: 2,
                        mediumCount: 3,
                        expandedCount: 4,
                        wideCount: 5,
                        compactMainAxisSpacing: 14,
                        compactCrossAxisSpacing: 14,
                        mediumMainAxisSpacing: 18,
                        mediumCrossAxisSpacing: 18,
                        childAspectRatio: 0.735,
                      ),
""",
        "home product grid",
    )

    source = replace_once(
        source,
        """            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.05,
            ),
""",
        """            gridDelegate: ResponsiveGridDelegate(
              context: context,
              compactCount: 2,
              mediumCount: 3,
              expandedCount: 4,
              wideCount: 5,
              compactCrossAxisSpacing: 10,
              compactMainAxisSpacing: 10,
              mediumCrossAxisSpacing: 14,
              mediumMainAxisSpacing: 14,
              childAspectRatio: 1.05,
            ),
""",
        "category grid",
    )

    source = replace_once(
        source,
        """                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.82,
                  ),
""",
        """                  gridDelegate: ResponsiveGridDelegate(
                    context: context,
                    compactCount: 2,
                    mediumCount: 3,
                    expandedCount: 4,
                    wideCount: 5,
                    compactCrossAxisSpacing: 10,
                    compactMainAxisSpacing: 10,
                    mediumCrossAxisSpacing: 14,
                    mediumMainAxisSpacing: 14,
                    childAspectRatio: 0.82,
                  ),
""",
        "listing grid",
    )

    source = regex_replace_once(
        source,
        r"(class _StorexHeroBanner extends StatelessWidget \{.*?return Container\(\n\s+padding: const EdgeInsets\.all\(2\),\n\s+)height: 188,",
        r"\1height: responsiveValue<double>(\n        context,\n        compact: 188,\n        medium: 220,\n        expanded: 250,\n        wide: 280,\n      ),",
        "responsive hero height",
    )

    bloom_banner = r"""class _StorexBloomArtBanner extends StatelessWidget {
  const _StorexBloomArtBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackContent = constraints.maxWidth < 560;
        final textContent = const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Galerie BLoOmOod Art',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: _ShopUi.textMain,
                height: 1.15,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Exposez une création, recevez des offres et basculez vers le checkout Stripe centralisé.',
              style: TextStyle(
                color: _ShopUi.textMuted,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ],
        );

        final openButton = FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            minimumSize: const Size(104, 48),
            backgroundColor: _ShopUi.textMain,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: const Text('Ouvrir'),
        );

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(stackContent ? 18 : 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE7DCCF)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x11000000),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: stackContent
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    textContent,
                    const SizedBox(height: 14),
                    Align(alignment: Alignment.centerRight, child: openButton),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: textContent),
                    const SizedBox(width: 24),
                    openButton,
                  ],
                ),
        );
      },
    );
  }
}

"""
    source = regex_replace_once(
        source,
        r"class _StorexBloomArtBanner extends StatelessWidget \{.*?\n\}\n\n(?=// ─── _StorexCategoryChip)",
        bloom_banner,
        "Bloom Art banner",
    )

    category_chip = r"""class _StorexCategoryChip extends StatelessWidget {
  const _StorexCategoryChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: _ShopUi.textMain,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.15,
            height: 1,
          ),
        ),
      ),
    );
  }
}

"""
    source = regex_replace_once(
        source,
        r"class _StorexCategoryChip extends StatelessWidget \{.*?\n\}\n\n(?=// ─── _StorexPremiumProductCard)",
        category_chip,
        "category chip",
    )

    STOREX_PATH.write_text(source, encoding="utf-8")
    print(f"Updated {STOREX_PATH}")


if __name__ == "__main__":
    main()
