from __future__ import annotations

from pathlib import Path


DEFAULT_MAP = Path("app/lib/pages/default_map_page.dart")
HOME_MAP_3D = Path("app/lib/pages/home_map_page_3d.dart")
RESPONSIVE_EXPORT = Path("app/lib/ui_kit/responsive/responsive.dart")


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


def update_export() -> None:
    source = RESPONSIVE_EXPORT.read_text(encoding="utf-8")
    export_line = "export 'responsive_overlay_container.dart';\n"
    if export_line in source:
        print("Responsive overlay export already present")
        return
    anchor = "export 'responsive_layout.dart';\n"
    if anchor not in source:
        raise RuntimeError("Responsive export anchor missing")
    RESPONSIVE_EXPORT.write_text(
        source.replace(anchor, f"{anchor}{export_line}", 1),
        encoding="utf-8",
    )
    print("Exported responsive overlay container")


def update_default_map() -> None:
    ensure_import(
        DEFAULT_MAP,
        "import 'package:masslive/ui_kit/tokens/maslive_tokens.dart';\n",
        "import '../ui_kit/responsive/responsive.dart';",
    )

    replace_once_or_applied(
        DEFAULT_MAP,
        """            final menuTopOffset = topInset + 104;
            const navMenuRightOffset = -6.0;""",
        """            final menuTopOffset = topInset + responsiveValue<double>(
              context,
              compact: 104,
              medium: 24,
              expanded: 24,
              wide: 24,
            );
            final navMenuRightOffset = responsiveValue<double>(
              context,
              compact: -6,
              medium: -14,
              expanded: -20,
              wide: -24,
            );""",
        "medium: -14,",
        "adapt default map exploration menu position",
    )

    replace_once_or_applied(
        DEFAULT_MAP,
        """                if (activeCircuitName != null)
                  Positioned(
                    top: topInset + 10,
                    left: 88,
                    right: 88,
                    child: IgnorePointer(
                      child: Center(
                        child: ActiveCircuitHeaderBanner(
                          circuitName: activeCircuitName,
                        ),
                      ),
                    ),
                  ),""",
        """                if (activeCircuitName != null)
                  Positioned(
                    top: topInset + 10,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: ResponsiveOverlayContainer(
                        compactHorizontalInset: 88,
                        mediumMaxWidth: 520,
                        expandedMaxWidth: 640,
                        wideMaxWidth: 720,
                        child: ActiveCircuitHeaderBanner(
                          circuitName: activeCircuitName,
                        ),
                      ),
                    ),
                  ),""",
        "compactHorizontalInset: 88,",
        "constrain default map circuit banner",
    )

    replace_once_or_applied(
        DEFAULT_MAP,
        """                if (_isTracking)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: bottomInset + bottomBarHeight + 12,
                    child: PointerInterceptor(
                      child: _TrackingPill(
                        isTracking: _isTracking,
                        onToggle: _toggleTracking,
                      ),
                    ),
                  ),""",
        """                if (_isTracking)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: bottomInset + bottomBarHeight + 12,
                    child: PointerInterceptor(
                      child: ResponsiveOverlayContainer(
                        compactHorizontalInset: 16,
                        mediumMaxWidth: 560,
                        expandedMaxWidth: 600,
                        wideMaxWidth: 640,
                        child: _TrackingPill(
                          isTracking: _isTracking,
                          onToggle: _toggleTracking,
                        ),
                      ),
                    ),
                  ),""",
        "mediumMaxWidth: 560,",
        "constrain default map tracking overlay",
    )


def update_home_map_3d() -> None:
    ensure_import(
        HOME_MAP_3D,
        "import '../ui/widgets/maslive_empty_state.dart';\n",
        "import '../ui_kit/responsive/responsive.dart';",
    )

    replace_once_or_applied(
        HOME_MAP_3D,
        """  Widget _buildActionsMenuOverlay(BuildContext context) {
    final items = _buildVerticalNavItems(context);
    final Widget menu = Transform.translate(
      offset: const Offset(-6, 0),
      child: HomeVerticalNavMenu(
        margin: EdgeInsets.only(top: _actionsMenuTopOffset),""",
        """  Widget _buildActionsMenuOverlay(BuildContext context) {
    final items = _buildVerticalNavItems(context);
    final menuTopOffset = responsiveValue<double>(
      context,
      compact: _actionsMenuTopOffset,
      medium: 24,
      expanded: 24,
      wide: 24,
    );
    final menuRightOffset = responsiveValue<double>(
      context,
      compact: -6,
      medium: -14,
      expanded: -20,
      wide: -24,
    );
    final Widget menu = Transform.translate(
      offset: Offset(menuRightOffset, 0),
      child: HomeVerticalNavMenu(
        margin: EdgeInsets.only(top: menuTopOffset),""",
        "final menuRightOffset = responsiveValue<double>(",
        "adapt 3D map exploration menu position",
    )

    replace_once_or_applied(
        HOME_MAP_3D,
        """  Widget _buildContent(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final hasNearbyPoiCarousel = _nearbyPoiCandidates.length > 1;

    const bottomBarHeight = _homeBottomBarHeight;""",
        """  Widget _buildContent(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final hasNearbyPoiCarousel = _nearbyPoiCandidates.length > 1;
    final compassTop = responsiveValue<double>(
      context,
      compact: 104,
      medium: 24,
      expanded: 24,
      wide: 24,
    );
    final compassRight = responsiveValue<double>(
      context,
      compact: 14,
      medium: 24,
      expanded: 28,
      wide: 32,
    );

    const bottomBarHeight = _homeBottomBarHeight;""",
        "final compassTop = responsiveValue<double>(",
        "add adaptive 3D map control offsets",
    )

    replace_once_or_applied(
        HOME_MAP_3D,
        """            if (_activeCircuitName != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 88,
                right: 88,
                child: IgnorePointer(
                  child: Center(
                    child: ActiveCircuitHeaderBanner(
                      circuitName: _activeCircuitName!,
                    ),
                  ),
                ),
              ),""",
        """            if (_activeCircuitName != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: ResponsiveOverlayContainer(
                    compactHorizontalInset: 88,
                    mediumMaxWidth: 520,
                    expandedMaxWidth: 640,
                    wideMaxWidth: 720,
                    child: ActiveCircuitHeaderBanner(
                      circuitName: _activeCircuitName!,
                    ),
                  ),
                ),
              ),""",
        "wideMaxWidth: 720,",
        "constrain 3D map circuit banner",
    )

    replace_once_or_applied(
        HOME_MAP_3D,
        "            const Positioned(top: 104, right: 14, child: _HalfRedCompass()),",
        """            Positioned(
              top: compassTop,
              right: compassRight,
              child: const _HalfRedCompass(),
            ),""",
        "top: compassTop,",
        "adapt 3D compass position",
    )

    replace_once_or_applied(
        HOME_MAP_3D,
        """            if (_isTracking)
              Positioned(
                left: 16,
                right: 16,
                bottom:
                    bottomInset +
                    bottomBarHeight +
                    (hasNearbyPoiCarousel ? 122 : 12),
                child: _TrackingPill(
                  isTracking: _isTracking,
                  onToggle: _toggleTracking,
                ),
              ),""",
        """            if (_isTracking)
              Positioned(
                left: 0,
                right: 0,
                bottom:
                    bottomInset +
                    bottomBarHeight +
                    (hasNearbyPoiCarousel ? 122 : 12),
                child: ResponsiveOverlayContainer(
                  compactHorizontalInset: 16,
                  mediumMaxWidth: 560,
                  expandedMaxWidth: 600,
                  wideMaxWidth: 640,
                  child: _TrackingPill(
                    isTracking: _isTracking,
                    onToggle: _toggleTracking,
                  ),
                ),
              ),""",
        "expandedMaxWidth: 600,",
        "constrain 3D map tracking overlay",
    )


def verify() -> None:
    checks = {
        DEFAULT_MAP: (
            "import '../ui_kit/responsive/responsive.dart';",
            "compactHorizontalInset: 88,",
            "mediumMaxWidth: 560,",
            "medium: -14,",
        ),
        HOME_MAP_3D: (
            "import '../ui_kit/responsive/responsive.dart';",
            "final compassTop = responsiveValue<double>(",
            "compactHorizontalInset: 88,",
            "expandedMaxWidth: 600,",
        ),
        RESPONSIVE_EXPORT: ("responsive_overlay_container.dart",),
    }
    for path, markers in checks.items():
        source = path.read_text(encoding="utf-8")
        missing = [marker for marker in markers if marker not in source]
        if missing:
            raise RuntimeError(f"Responsive map verification failed for {path}: {missing}")
    print("Responsive map conversion verified")


def main() -> None:
    update_export()
    update_default_map()
    update_home_map_3d()
    verify()


if __name__ == "__main__":
    main()
