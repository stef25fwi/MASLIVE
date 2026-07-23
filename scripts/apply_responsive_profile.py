from __future__ import annotations

import re
from pathlib import Path


ACCOUNT = Path("app/lib/pages/account_page.dart")
LOGIN = Path("app/lib/pages/login_page.dart")


def ensure_import(path: Path, anchor: str, import_line: str) -> None:
    source = path.read_text(encoding="utf-8")
    if import_line in source:
        print(f"Already imported in {path}: {import_line}")
        return
    if anchor not in source:
        raise RuntimeError(f"Import anchor missing in {path}: {anchor}")
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
    raise RuntimeError(f"{label}: source and marker missing in {path}")


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
    raise RuntimeError(f"{label}: regex source and marker missing in {path}")


def update_account() -> None:
    ensure_import(
        ACCOUNT,
        "import 'package:masslive/ui_kit/tokens/maslive_tokens.dart';\n",
        "import '../ui_kit/responsive/responsive.dart';",
    )

    replace_once_or_applied(
        ACCOUNT,
        """                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: _AvatarBlock(profile: profile),
                      ),
                    ),""",
        """                    SliverToBoxAdapter(
                      child: ResponsivePageContainer(
                        maxContentWidth: 1200,
                        compactPadding: const EdgeInsets.only(top: 16),
                        mediumPadding: const EdgeInsets.only(top: 20),
                        expandedPadding: const EdgeInsets.only(top: 24),
                        widePadding: const EdgeInsets.only(top: 28),
                        child: _AvatarBlock(profile: profile),
                      ),
                    ),""",
        "maxContentWidth: 1200,",
        "center profile identity block",
    )

    replace_once_or_applied(
        ACCOUNT,
        """                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 14, 10, 0),
                        child: _CapabilitySummaryCard(profile: profile),
                      ),
                    ),""",
        """                    SliverToBoxAdapter(
                      child: ResponsivePageContainer(
                        maxContentWidth: 1200,
                        compactPadding: const EdgeInsets.fromLTRB(10, 14, 10, 0),
                        mediumPadding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                        expandedPadding: const EdgeInsets.fromLTRB(40, 20, 40, 0),
                        widePadding: const EdgeInsets.fromLTRB(56, 22, 56, 0),
                        child: _CapabilitySummaryCard(profile: profile),
                      ),
                    ),""",
        "widePadding: const EdgeInsets.fromLTRB(56, 22, 56, 0),",
        "adapt capability summary width",
    )

    replace_once_or_applied(
        ACCOUNT,
        """                    if (profile.canSubmitCommerce)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                          child: CommerceSectionCard(),
                        ),
                      ),""",
        """                    if (profile.canSubmitCommerce)
                      const SliverToBoxAdapter(
                        child: ResponsivePageContainer(
                          maxContentWidth: 1200,
                          compactPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                          mediumPadding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          expandedPadding: EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 16,
                          ),
                          widePadding: EdgeInsets.symmetric(
                            horizontal: 56,
                            vertical: 18,
                          ),
                          child: CommerceSectionCard(),
                        ),
                      ),""",
        "widePadding: EdgeInsets.symmetric(\n                            horizontal: 56,\n                            vertical: 18,",
        "adapt commerce profile section",
    )

    regex_once_or_applied(
        ACCOUNT,
        r"\s+SliverPadding\(\s+padding: const EdgeInsets\.fromLTRB\(10, 20, 10, 18\),\s+sliver: SliverList\.builder\(\s+itemCount: tiles\.length,\s+itemBuilder: \(context, index\) \{\s+final tile = tiles\[index\];\s+return _AccountTile\(\s+tile: tile,\s+onTap: \(\) => _navigateTo\(tile\),\s+\);\s+\},\s+\),\s+\),",
        """
                    SliverToBoxAdapter(
                      child: ResponsivePageContainer(
                        maxContentWidth: 1200,
                        compactPadding: const EdgeInsets.fromLTRB(10, 20, 10, 18),
                        mediumPadding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                        expandedPadding: const EdgeInsets.fromLTRB(40, 28, 40, 22),
                        widePadding: const EdgeInsets.fromLTRB(56, 32, 56, 24),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: ResponsiveGridDelegate(
                            context: context,
                            compactCount: 1,
                            mediumCount: 2,
                            expandedCount: 3,
                            wideCount: 3,
                            compactMainAxisSpacing: 0,
                            compactCrossAxisSpacing: 0,
                            mediumMainAxisSpacing: 4,
                            mediumCrossAxisSpacing: 12,
                            expandedMainAxisSpacing: 6,
                            expandedCrossAxisSpacing: 14,
                            wideMainAxisSpacing: 8,
                            wideCrossAxisSpacing: 16,
                            mainAxisExtent: responsiveValue<double>(
                              context,
                              compact: 94,
                              medium: 106,
                              expanded: 106,
                              wide: 106,
                            ),
                          ),
                          itemCount: tiles.length,
                          itemBuilder: (context, index) {
                            final tile = tiles[index];
                            return _AccountTile(
                              tile: tile,
                              onTap: () => _navigateTo(tile),
                            );
                          },
                        ),
                      ),
                    ),""",
        "compactCount: 1,",
        "convert profile actions to adaptive grid",
    )

    replace_once_or_applied(
        ACCOUNT,
        """                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                        child: MasliveCard(""",
        """                    SliverToBoxAdapter(
                      child: ResponsivePageContainer(
                        maxContentWidth: 1200,
                        compactPadding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                        mediumPadding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                        expandedPadding: const EdgeInsets.fromLTRB(40, 0, 40, 12),
                        widePadding: const EdgeInsets.fromLTRB(56, 0, 56, 14),
                        child: MasliveCard(""",
        "widePadding: const EdgeInsets.fromLTRB(56, 0, 56, 14),",
        "adapt personal data card",
    )

    replace_once_or_applied(
        ACCOUNT,
        """                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 18),
                        child: SizedBox(""",
        """                    SliverToBoxAdapter(
                      child: ResponsivePageContainer(
                        maxContentWidth: 1200,
                        compactPadding: const EdgeInsets.fromLTRB(10, 0, 10, 18),
                        mediumPadding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
                        expandedPadding: const EdgeInsets.fromLTRB(40, 0, 40, 26),
                        widePadding: const EdgeInsets.fromLTRB(56, 0, 56, 30),
                        child: SizedBox(""",
        "widePadding: const EdgeInsets.fromLTRB(56, 0, 56, 30),",
        "adapt sign-out action width",
    )

    replace_once_or_applied(
        ACCOUNT,
        """          title: Text(
            tile.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(""",
        """          title: Text(
            tile.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(""",
        "maxLines: 2,\n            overflow: TextOverflow.ellipsis,",
        "protect profile tile titles",
    )

    replace_once_or_applied(
        ACCOUNT,
        "          subtitle: Text(tile.subtitle),",
        """          subtitle: Text(
            tile.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),""",
        "tile.subtitle,\n            maxLines: 2,",
        "protect profile tile subtitles",
    )


def update_login() -> None:
    ensure_import(
        LOGIN,
        "import 'package:masslive/ui_kit/tokens/maslive_tokens.dart';\n",
        "import '../ui_kit/responsive/responsive.dart';",
    )

    replace_once_or_applied(
        LOGIN,
        """              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                child: Column(""",
        """              child: SingleChildScrollView(
                child: ResponsivePageContainer(
                  maxContentWidth: 1120,
                  compactPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  mediumPadding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 22,
                  ),
                  expandedPadding: const EdgeInsets.symmetric(
                    horizontal: 36,
                    vertical: 26,
                  ),
                  widePadding: const EdgeInsets.symmetric(
                    horizontal: 44,
                    vertical: 30,
                  ),
                  child: Column(""",
        "maxContentWidth: 1120,",
        "constrain and center login content",
    )

    replace_once_or_applied(
        LOGIN,
        """                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ],""",
        """                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ),
          ],""",
        "widePadding: const EdgeInsets.symmetric(\n                    horizontal: 44,",
        "close responsive login container",
    )


def verify() -> None:
    checks = {
        ACCOUNT: (
            "import '../ui_kit/responsive/responsive.dart';",
            "compactCount: 1,",
            "mediumCount: 2,",
            "expandedCount: 3,",
            "maxContentWidth: 1200,",
            "tile.subtitle,",
        ),
        LOGIN: (
            "import '../ui_kit/responsive/responsive.dart';",
            "maxContentWidth: 1120,",
            "widePadding: const EdgeInsets.symmetric(",
        ),
    }
    for path, markers in checks.items():
        source = path.read_text(encoding="utf-8")
        missing = [marker for marker in markers if marker not in source]
        if missing:
            raise RuntimeError(f"Responsive profile verification failed for {path}: {missing}")
    print("Responsive profile conversion verified")


def main() -> None:
    update_account()
    update_login()
    verify()


if __name__ == "__main__":
    main()
