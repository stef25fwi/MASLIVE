from __future__ import annotations

import re
from pathlib import Path


ADMIN_DASHBOARD = Path("app/lib/admin/admin_main_dashboard.dart")
ADMIN_ANALYTICS = Path("app/lib/admin/admin_analytics_page.dart")
ADMIN_ORDERS = Path("app/lib/admin/admin_orders_page.dart")
TRACKING_LIVE = Path("app/lib/admin/tracking_live/tracking_live_page.dart")
CIRCUIT_WIZARD = Path("app/lib/admin/circuit_wizard_entry_page.dart")


def ensure_import(path: Path, anchor: str, import_line: str) -> None:
    source = path.read_text(encoding="utf-8")
    if import_line in source:
        return
    if anchor not in source:
        raise RuntimeError(f"Import anchor missing in {path}: {anchor}")
    path.write_text(
        source.replace(anchor, f"{anchor}\n{import_line}", 1),
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


def replace_after(path: Path, anchor: str, old: str, new: str, label: str) -> None:
    source = path.read_text(encoding="utf-8")
    anchor_index = source.find(anchor)
    if anchor_index < 0:
        raise RuntimeError(f"Missing anchor for {label} in {path}: {anchor}")
    target_index = source.find(old, anchor_index)
    if target_index < 0:
        raise RuntimeError(f"Missing {label} after anchor in {path}")
    path.write_text(
        source[:target_index] + new + source[target_index + len(old) :],
        encoding="utf-8",
    )


def regex_once(path: Path, pattern: str, replacement: str, label: str) -> None:
    source = path.read_text(encoding="utf-8")
    updated, count = re.subn(pattern, replacement, source, count=1, flags=re.S)
    if count != 1:
        raise RuntimeError(f"Expected one regex match for {label} in {path}, found {count}")
    path.write_text(updated, encoding="utf-8")


def _matching_paren(source: str, open_index: int) -> int:
    if source[open_index] != "(":
        raise RuntimeError("The supplied index is not an opening parenthesis")

    depth = 0
    index = open_index
    quote: str | None = None
    escaped = False
    line_comment = False
    block_comment = False

    while index < len(source):
        char = source[index]
        next_char = source[index + 1] if index + 1 < len(source) else ""

        if line_comment:
            if char == "\n":
                line_comment = False
            index += 1
            continue

        if block_comment:
            if char == "*" and next_char == "/":
                block_comment = False
                index += 2
                continue
            index += 1
            continue

        if quote is not None:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif source.startswith(quote, index):
                index += len(quote)
                quote = None
                continue
            index += 1
            continue

        if char == "/" and next_char == "/":
            line_comment = True
            index += 2
            continue
        if char == "/" and next_char == "*":
            block_comment = True
            index += 2
            continue
        if source.startswith("'''", index) or source.startswith('\"\"\"', index):
            quote = source[index : index + 3]
            index += 3
            continue
        if char in ("'", '"'):
            quote = char
            index += 1
            continue

        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0:
                return index
        index += 1

    raise RuntimeError("Unbalanced Dart call while wrapping responsive widget")


def wrap_call(path: Path, marker: str, wrapper: str, label: str) -> None:
    source = path.read_text(encoding="utf-8")
    marker_index = source.find(marker)
    if marker_index < 0:
        raise RuntimeError(f"Missing {label} marker in {path}: {marker}")

    call_start = marker_index + marker.rfind(" ") + 1
    open_index = source.find("(", call_start)
    if open_index < 0:
        raise RuntimeError(f"Missing opening parenthesis for {label} in {path}")
    close_index = _matching_paren(source, open_index)
    expression = source[call_start : close_index + 1]
    replacement = wrapper.replace("__CHILD__", expression)
    path.write_text(
        source[:call_start] + replacement + source[close_index + 1 :],
        encoding="utf-8",
    )


def transform_admin_dashboard() -> None:
    print("[admin] dashboard")
    ensure_import(
        ADMIN_DASHBOARD,
        "import 'package:masslive/ui_kit/tokens/maslive_tokens.dart';",
        "import '../ui_kit/responsive/responsive.dart';",
    )
    wrap_call(
        ADMIN_DASHBOARD,
        "body: SingleChildScrollView(",
        """ResponsivePageContainer(
  maxContentWidth: 1440,
  compactPadding: EdgeInsets.zero,
  mediumPadding: EdgeInsets.zero,
  expandedPadding: EdgeInsets.zero,
  widePadding: EdgeInsets.zero,
  child: __CHILD__,
)""",
        "admin dashboard body",
    )
    replace_after(
        ADMIN_DASHBOARD,
        "maxContentWidth: 1440",
        "padding: const EdgeInsets.all(16),",
        """padding: responsiveValue<EdgeInsets>(
  context,
  compact: const EdgeInsets.all(16),
  medium: const EdgeInsets.fromLTRB(24, 20, 24, 28),
  expanded: const EdgeInsets.fromLTRB(36, 24, 36, 32),
  wide: const EdgeInsets.fromLTRB(44, 28, 44, 36),
),""",
        "dashboard responsive padding",
    )


def transform_admin_analytics() -> None:
    print("[admin] analytics")
    ensure_import(
        ADMIN_ANALYTICS,
        "import '../theme/maslive_theme.dart';",
        "import '../ui_kit/responsive/responsive.dart';",
    )
    wrap_call(
        ADMIN_ANALYTICS,
        "child: SingleChildScrollView(",
        """ResponsivePageContainer(
  maxContentWidth: 1280,
  compactPadding: EdgeInsets.zero,
  mediumPadding: EdgeInsets.zero,
  expandedPadding: EdgeInsets.zero,
  widePadding: EdgeInsets.zero,
  child: __CHILD__,
)""",
        "analytics scroll content",
    )
    replace_after(
        ADMIN_ANALYTICS,
        "maxContentWidth: 1280",
        "padding: const EdgeInsets.all(16),",
        """padding: responsiveValue<EdgeInsets>(
  context,
  compact: const EdgeInsets.all(16),
  medium: const EdgeInsets.fromLTRB(24, 20, 24, 28),
  expanded: const EdgeInsets.fromLTRB(36, 24, 36, 32),
  wide: const EdgeInsets.fromLTRB(44, 28, 44, 36),
),""",
        "analytics responsive padding",
    )
    regex_once(
        ADMIN_ANALYTICS,
        r"crossAxisCount:\s*2,\s*shrinkWrap:",
        """crossAxisCount: responsiveValue<int>(
  context,
  compact: 2,
  medium: 3,
  expanded: 4,
  wide: 4,
),
          shrinkWrap:""",
        "analytics adaptive columns",
    )
    replace_once(
        ADMIN_ANALYTICS,
        "childAspectRatio: 1.5,",
        """childAspectRatio: responsiveValue<double>(
  context,
  compact: 1.5,
  medium: 1.7,
  expanded: 1.9,
  wide: 2.0,
),""",
        "analytics adaptive aspect ratio",
    )


def transform_admin_orders() -> None:
    print("[admin] orders")
    ensure_import(
        ADMIN_ORDERS,
        "import 'admin_gate.dart';",
        "import '../ui_kit/responsive/responsive.dart';",
    )
    wrap_call(
        ADMIN_ORDERS,
        "body: Column(",
        """ResponsivePageContainer(
  maxContentWidth: 1280,
  compactPadding: EdgeInsets.zero,
  mediumPadding: EdgeInsets.zero,
  expandedPadding: EdgeInsets.zero,
  widePadding: EdgeInsets.zero,
  child: __CHILD__,
)""",
        "orders body",
    )
    replace_after(
        ADMIN_ORDERS,
        "maxContentWidth: 1280",
        "padding: const EdgeInsets.all(16),",
        """padding: responsiveValue<EdgeInsets>(
  context,
  compact: const EdgeInsets.all(16),
  medium: const EdgeInsets.fromLTRB(24, 20, 24, 18),
  expanded: const EdgeInsets.fromLTRB(36, 24, 36, 20),
  wide: const EdgeInsets.fromLTRB(44, 28, 44, 22),
),""",
        "orders responsive filters",
    )
    wrap_call(
        ADMIN_ORDERS,
        "builder: (ctx) => StatefulBuilder(",
        """ResponsiveOverlayContainer(
  compactHorizontalInset: 0,
  mediumMaxWidth: 720,
  expandedMaxWidth: 820,
  wideMaxWidth: 900,
  alignment: Alignment.bottomCenter,
  child: __CHILD__,
)""",
        "orders detail sheet",
    )


def _responsive_tracking_header() -> str:
    return """class _Header extends StatelessWidget {
  const _Header({required this.provider});

  final TrackingLiveProvider provider;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final info = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.radar, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Tracking Live',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Monitoring des groupes et trackers en temps réel',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[700],
                        ),
                      ),
                      if (provider.lastUpdatedAt != null) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          'Dernière mise à jour: ${provider.presence.formatLastSeen(provider.lastUpdatedAt)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
            final selector = PeriodSelector(
              selection: provider.selectedPeriod,
              onChanged: provider.setPeriod,
            );

            if (context.isCompactLayout) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  info,
                  const SizedBox(height: 14),
                  Align(alignment: Alignment.centerLeft, child: selector),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: info),
                const SizedBox(width: 20),
                selector,
              ],
            );
          },
        ),
      ),
    );
  }
}

"""


def transform_tracking_live() -> None:
    print("[admin] tracking live")
    ensure_import(
        TRACKING_LIVE,
        "import 'widgets/tracking_kpi_tile.dart';",
        "import '../../ui_kit/responsive/responsive.dart';",
    )
    wrap_call(
        TRACKING_LIVE,
        "body: ListView(",
        """ResponsivePageContainer(
  maxContentWidth: 1440,
  compactPadding: EdgeInsets.zero,
  mediumPadding: EdgeInsets.zero,
  expandedPadding: EdgeInsets.zero,
  widePadding: EdgeInsets.zero,
  child: __CHILD__,
)""",
        "tracking body",
    )
    replace_after(
        TRACKING_LIVE,
        "maxContentWidth: 1440",
        "padding: const EdgeInsets.all(16),",
        """padding: responsiveValue<EdgeInsets>(
  context,
  compact: const EdgeInsets.all(16),
  medium: const EdgeInsets.fromLTRB(24, 20, 24, 28),
  expanded: const EdgeInsets.fromLTRB(36, 24, 36, 32),
  wide: const EdgeInsets.fromLTRB(44, 28, 44, 36),
),""",
        "tracking responsive padding",
    )
    source = TRACKING_LIVE.read_text(encoding="utf-8")
    start = source.find("class _Header extends StatelessWidget {")
    end = source.find("class _KpiGrid extends StatelessWidget {")
    if start < 0 or end < 0 or end <= start:
        raise RuntimeError("Unable to locate Tracking Live header class")
    TRACKING_LIVE.write_text(
        source[:start] + _responsive_tracking_header() + source[end:],
        encoding="utf-8",
    )


def transform_circuit_wizard() -> None:
    print("[admin] circuit wizard")
    ensure_import(
        CIRCUIT_WIZARD,
        "import '../ui/widgets/maslive_button.dart';",
        "import '../ui_kit/responsive/responsive.dart';",
    )
    wrap_call(
        CIRCUIT_WIZARD,
        "return ListView.builder(",
        """ResponsivePageContainer(
  maxContentWidth: 1200,
  compactPadding: EdgeInsets.zero,
  mediumPadding: EdgeInsets.zero,
  expandedPadding: EdgeInsets.zero,
  widePadding: EdgeInsets.zero,
  child: __CHILD__,
)""",
        "circuit projects list",
    )
    replace_after(
        CIRCUIT_WIZARD,
        "maxContentWidth: 1200",
        "padding: const EdgeInsets.all(16),",
        """padding: responsiveValue<EdgeInsets>(
  context,
  compact: const EdgeInsets.all(16),
  medium: const EdgeInsets.fromLTRB(24, 20, 24, 28),
  expanded: const EdgeInsets.fromLTRB(36, 24, 36, 32),
  wide: const EdgeInsets.fromLTRB(44, 28, 44, 36),
),""",
        "circuit projects padding",
    )
    regex_once(
        CIRCUIT_WIZARD,
        r"final screen = MediaQuery\.of\(context\)\.size;\s*"
        r"final availableWidth = \(screen\.width - 32\)\.clamp\(0\.0, double\.infinity\);\s*"
        r"final dialogWidth = availableWidth > 900 \? 900\.0 : availableWidth;\s*"
        r"final dialogMaxHeight = screen\.height \* 0\.9;",
        """final screen = MediaQuery.of(context).size;
    final compactWidth = (screen.width - 20).clamp(0.0, double.infinity);
    final requestedWidth = responsiveValue<double>(
      context,
      compact: compactWidth,
      medium: 760,
      expanded: 900,
      wide: 980,
    );
    final dialogWidth = requestedWidth.clamp(0.0, compactWidth).toDouble();
    final dialogMaxHeight = screen.height * 0.9;""",
        "circuit dialog width",
    )
    replace_once(
        CIRCUIT_WIZARD,
        "insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),",
        """insetPadding: responsiveValue<EdgeInsets>(
  context,
  compact: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
  medium: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
  expanded: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
  wide: const EdgeInsets.symmetric(horizontal: 44, vertical: 36),
),""",
        "circuit dialog insets",
    )
    replace_after(
        CIRCUIT_WIZARD,
        "constraints: BoxConstraints(maxWidth: dialogWidth",
        "padding: const EdgeInsets.all(16),",
        """padding: responsiveValue<EdgeInsets>(
  context,
  compact: const EdgeInsets.all(16),
  medium: const EdgeInsets.all(20),
  expanded: const EdgeInsets.all(24),
  wide: const EdgeInsets.all(28),
),""",
        "circuit dialog padding",
    )


def main() -> None:
    transform_admin_dashboard()
    transform_admin_analytics()
    transform_admin_orders()
    transform_tracking_live()
    transform_circuit_wizard()
    print("Responsive administration conversion applied successfully.")


if __name__ == "__main__":
    main()
