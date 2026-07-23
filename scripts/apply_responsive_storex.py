from __future__ import annotations

from pathlib import Path


STOREX_PATH = Path("app/lib/pages/storex_shop_page.dart")
DEFAULT_MAP_PATH = Path("app/lib/pages/default_map_page.dart")
HOME_MAP_PATH = Path("app/lib/pages/home_map_page_3d.dart")
POI_STYLE_PATH = Path("app/lib/ui/map/maslive_poi_style.dart")


def replace_once_or_applied(
    path: Path,
    old: str,
    new: str,
    label: str,
) -> None:
    source = path.read_text(encoding="utf-8")
    old_count = source.count(old)
    if old_count == 1:
        path.write_text(source.replace(old, new, 1), encoding="utf-8")
        print(f"Applied {label} in {path}")
        return
    if old_count > 1:
        raise RuntimeError(f"{label}: expected one match, found {old_count}")
    if new in source:
        print(f"Already applied: {label}")
        return
    raise RuntimeError(f"{label}: neither source nor target form was found")


def verify_storex_conversion() -> None:
    source = STOREX_PATH.read_text(encoding="utf-8")
    required_markers = (
        "import '../ui_kit/responsive/responsive.dart';",
        "final stackContent = constraints.maxWidth < 560;",
        "height: 38,",
        "mediumCount: 3,",
        "expandedCount: 4,",
        "wideCount: 5,",
    )
    missing = [marker for marker in required_markers if marker not in source]
    if missing:
        raise RuntimeError(
            "Storex responsive conversion is incomplete; missing: "
            + ", ".join(missing)
        )
    print("Storex responsive conversion already applied and verified")


def main() -> None:
    verify_storex_conversion()

    replace_once_or_applied(
        DEFAULT_MAP_PATH,
        "          ?kPoiPictoIconIdProperty: pictoIconId,",
        "          kPoiPictoIconIdProperty: ?pictoIconId,",
        "default map null-aware POI value",
    )
    replace_once_or_applied(
        HOME_MAP_PATH,
        "          ?kPoiPictoIconIdProperty: pictoIconId,",
        "          kPoiPictoIconIdProperty: ?pictoIconId,",
        "3D map null-aware POI value",
    )
    replace_once_or_applied(
        POI_STYLE_PATH,
        "@immutable\n/// Construit un peintre vectoriel personnalisé",
        "/// Construit un peintre vectoriel personnalisé",
        "remove invalid typedef annotation",
    )


if __name__ == "__main__":
    main()
