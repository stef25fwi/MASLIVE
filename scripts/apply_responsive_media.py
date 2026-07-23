from __future__ import annotations

import re
from pathlib import Path


MEDIA_SHOP = Path("app/lib/features/shop/pages/media_photo_shop_page.dart")
MEDIA_HOME = Path(
    "app/lib/features/media_marketplace/presentation/pages/media_marketplace_home_page.dart"
)
PRIVATE_GALLERY = Path(
    "app/lib/features/media_marketplace/presentation/pages/private_media_gallery_page.dart"
)
PUBLIC_STOREFRONT = Path(
    "app/lib/features/media_marketplace/presentation/pages/photographer_public_storefront_page.dart"
)


def ensure_import(path: Path, anchor: str, import_line: str) -> None:
    source = path.read_text(encoding="utf-8")
    if import_line in source:
        print(f"Already imported in {path}: {import_line}")
        return
    if anchor not in source:
        raise RuntimeError(f"Import anchor not found in {path}: {anchor}")
    path.write_text(source.replace(anchor, f"{anchor}{import_line}\n", 1), encoding="utf-8")
    print(f"Added responsive import to {path}")


def replace_once_or_applied(
    path: Path,
    old: str,
    new: str,
    marker: str,
    label: str,
) -> None:
    source = path.read_text(encoding="utf-8")
    count = source.count(old)
    if count == 1:
        path.write_text(source.replace(old, new, 1), encoding="utf-8")
        print(f"Applied {label} in {path}")
        return
    if count > 1:
        raise RuntimeError(f"{label}: expected one source match, found {count}")
    if marker in source:
        print(f"Already applied: {label}")
        return
    raise RuntimeError(f"{label}: source and marker are both missing in {path}")


def regex_once_or_applied(
    path: Path,
    pattern: str,
    replacement: str,
    marker: str,
    label: str,
) -> None:
    source = path.read_text(encoding="utf-8")
    updated, count = re.subn(pattern, replacement, source, count=1, flags=re.S)
    if count == 1:
        path.write_text(updated, encoding="utf-8")
        print(f"Applied {label} in {path}")
        return
    if marker in source:
        print(f"Already applied: {label}")
        return
    raise RuntimeError(f"{label}: regex source and marker are both missing in {path}")


def update_media_shop() -> None:
    ensure_import(
        MEDIA_SHOP,
        "import 'package:masslive/ui_kit/tokens/maslive_tokens.dart';\n",
        "import '../../../ui_kit/responsive/responsive.dart';",
    )

    regex_once_or_applied(
        MEDIA_SHOP,
        r"child: Padding\(\s*padding: EdgeInsets\.fromLTRB\(10, widget\.embedded \? 18 : 14, 10, 12\),\s*child: Column\(",
        """child: ResponsivePageContainer(
                maxContentWidth: 1280,
                compactPadding: EdgeInsets.fromLTRB(
                  10,
                  widget.embedded ? 18 : 14,
                  10,
                  12,
                ),
                mediumPadding: EdgeInsets.fromLTRB(
                  20,
                  widget.embedded ? 20 : 18,
                  20,
                  14,
                ),
                expandedPadding: EdgeInsets.fromLTRB(
                  28,
                  widget.embedded ? 22 : 20,
                  28,
                  16,
                ),
                widePadding: EdgeInsets.fromLTRB(
                  36,
                  widget.embedded ? 24 : 22,
                  36,
                  18,
                ),
                child: Column(""",
        "maxContentWidth: 1280,",
        "center and pad media shop header content",
    )

    replace_once_or_applied(
        MEDIA_SHOP,
        """        body: Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
          child: _buildActiveMarketplaceContent(),
        ),""",
        """        body: ResponsivePageContainer(
          maxContentWidth: 1280,
          compactPadding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
          mediumPadding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          expandedPadding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
          widePadding: const EdgeInsets.fromLTRB(36, 0, 36, 0),
          child: _buildActiveMarketplaceContent(),
        ),""",
        "widePadding: const EdgeInsets.fromLTRB(36, 0, 36, 0),",
        "center active media marketplace content",
    )

    regex_once_or_applied(
        MEDIA_SHOP,
        r"(class _HeroCarnavalCard extends StatelessWidget \{.*?child: Container\(\s*)height: 268,",
        r"\1height: responsiveValue<double>(\n              context,\n              compact: 268,\n              medium: 320,\n              expanded: 360,\n              wide: 390,\n            ),",
        "compact: 268,",
        "adapt media hero height",
    )


def update_media_home() -> None:
    ensure_import(
        MEDIA_HOME,
        "import '../../../../utils/country_flag.dart';\n",
        "import '../../../../ui_kit/responsive/responsive.dart';",
    )

    replace_once_or_applied(
        MEDIA_HOME,
        """    final content = Padding(
      padding: const EdgeInsets.fromLTRB(8, 18, 8, 10),
      child: Column(""",
        """    final content = ResponsivePageContainer(
      maxContentWidth: 1280,
      compactPadding: const EdgeInsets.fromLTRB(8, 18, 8, 10),
      mediumPadding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
      expandedPadding: const EdgeInsets.fromLTRB(28, 22, 28, 14),
      widePadding: const EdgeInsets.fromLTRB(36, 24, 36, 16),
      child: Column(""",
        "widePadding: const EdgeInsets.fromLTRB(36, 24, 36, 16),",
        "center media marketplace content",
    )

    regex_once_or_applied(
        MEDIA_HOME,
        r"gridDelegate:\s+const SliverGridDelegateWithFixedCrossAxisCount\(\s*crossAxisCount: 2,\s*mainAxisSpacing: 12,\s*crossAxisSpacing: 12,\s*childAspectRatio: 0\.76,\s*\),",
        """gridDelegate: ResponsiveGridDelegate(
                      context: context,
                      compactCount: 2,
                      mediumCount: 3,
                      expandedCount: 4,
                      wideCount: 5,
                      compactMainAxisSpacing: 12,
                      compactCrossAxisSpacing: 12,
                      mediumMainAxisSpacing: 16,
                      mediumCrossAxisSpacing: 16,
                      childAspectRatio: 0.76,
                    ),""",
        "wideCount: 5,",
        "adapt all-media sheet grid",
    )


def update_private_gallery() -> None:
    ensure_import(
        PRIVATE_GALLERY,
        "import '../../../../ui/widgets/storage_image.dart';\n",
        "import '../../../../ui_kit/responsive/responsive.dart';",
    )

    replace_once_or_applied(
        PRIVATE_GALLERY,
        "padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),",
        """padding: responsiveValue<EdgeInsets>(
                    context,
                    compact: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    medium: const EdgeInsets.fromLTRB(28, 20, 28, 36),
                    expanded: const EdgeInsets.fromLTRB(64, 24, 64, 40),
                    wide: const EdgeInsets.fromLTRB(120, 28, 120, 44),
                  ),""",
        "wide: const EdgeInsets.fromLTRB(120, 28, 120, 44),",
        "adapt private gallery page padding",
    )

    replace_once_or_applied(
        PRIVATE_GALLERY,
        """  Widget build(BuildContext context) {
    return SizedBox(
      width: 310,""",
        """  Widget build(BuildContext context) {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final availableWidth = viewportWidth - 32;
    final cardWidth = availableWidth.clamp(0.0, 310.0).toDouble();

    return SizedBox(
      width: cardWidth,""",
        "final cardWidth = availableWidth.clamp(0.0, 310.0).toDouble();",
        "prevent private pack overflow on 320px screens",
    )


def update_public_storefront() -> None:
    ensure_import(
        PUBLIC_STOREFRONT,
        "import '../../data/repositories/photographer_repository.dart';\n",
        "import '../../../../ui_kit/responsive/responsive.dart';",
    )

    replace_once_or_applied(
        PUBLIC_STOREFRONT,
        """                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Row(""",
        """                  child: ResponsivePageContainer(
                    maxContentWidth: 1280,
                    compactPadding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    mediumPadding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
                    expandedPadding: const EdgeInsets.fromLTRB(32, 16, 32, 18),
                    widePadding: const EdgeInsets.fromLTRB(40, 18, 40, 20),
                    child: Row(""",
        "widePadding: const EdgeInsets.fromLTRB(40, 18, 40, 20),",
        "center photographer storefront header",
    )


def verify() -> None:
    checks = {
        MEDIA_SHOP: (
            "import '../../../ui_kit/responsive/responsive.dart';",
            "compact: 268,",
            "widePadding: const EdgeInsets.fromLTRB(36, 0, 36, 0),",
        ),
        MEDIA_HOME: (
            "import '../../../../ui_kit/responsive/responsive.dart';",
            "maxContentWidth: 1280,",
            "wideCount: 5,",
        ),
        PRIVATE_GALLERY: (
            "import '../../../../ui_kit/responsive/responsive.dart';",
            "wide: const EdgeInsets.fromLTRB(120, 28, 120, 44),",
            "final cardWidth = availableWidth.clamp(0.0, 310.0).toDouble();",
        ),
        PUBLIC_STOREFRONT: (
            "import '../../../../ui_kit/responsive/responsive.dart';",
            "widePadding: const EdgeInsets.fromLTRB(40, 18, 40, 20),",
        ),
    }
    for path, markers in checks.items():
        source = path.read_text(encoding="utf-8")
        missing = [marker for marker in markers if marker not in source]
        if missing:
            raise RuntimeError(f"Responsive media verification failed for {path}: {missing}")
    print("Responsive media conversion verified")


def main() -> None:
    update_media_shop()
    update_media_home()
    update_private_gallery()
    update_public_storefront()
    verify()


if __name__ == "__main__":
    main()
