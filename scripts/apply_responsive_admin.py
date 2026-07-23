from __future__ import annotations

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


def replace_last(path: Path, old: str, new: str, label: str) -> None:
    source = path.read_text(encoding="utf-8")
    index = source.rfind(old)
    if index < 0:
        raise RuntimeError(f"Missing {label} in {path}")
    path.write_text(
        source[:index] + new + source[index + len(old) :],
        encoding="utf-8",
    )


def transform_admin_dashboard() -> None:
    ensure_import(
        ADMIN_DASHBOARD,
        "import 'package:masslive/ui_kit/tokens/maslive_tokens.dart';",
        "import '../ui_kit/responsive/responsive.dart';",
    )

    replace_once(
        ADMIN_DASHBOARD,
        """            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
""",
        """            body: ResponsivePageContainer(
              maxContentWidth: 1440,
              compactPadding: EdgeInsets.zero,
              mediumPadding: EdgeInsets.zero,
              expandedPadding: EdgeInsets.zero,
              widePadding: EdgeInsets.zero,
              child: SingleChildScrollView(
                padding: responsiveValue<EdgeInsets>(
                  context,
                  compact: const EdgeInsets.all(16),
                  medium: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                  expanded: const EdgeInsets.fromLTRB(36, 24, 36, 32),
                  wide: const EdgeInsets.fromLTRB(44, 28, 44, 36),
                ),
                child: Column(
""",
        "admin dashboard container start",
    )

    replace_last(
        ADMIN_DASHBOARD,
        """                ],
              ),
            ),
          );
""",
        """                  ],
                ),
              ),
            ),
          );
""",
        "admin dashboard container end",
    )


def transform_admin_analytics() -> None:
    ensure_import(
        ADMIN_ANALYTICS,
        "import '../theme/maslive_theme.dart';",
        "import '../ui_kit/responsive/responsive.dart';",
    )

    replace_once(
        ADMIN_ANALYTICS,
        """              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
""",
        """              child: ResponsivePageContainer(
                maxContentWidth: 1280,
                compactPadding: EdgeInsets.zero,
                mediumPadding: EdgeInsets.zero,
                expandedPadding: EdgeInsets.zero,
                widePadding: EdgeInsets.zero,
                child: SingleChildScrollView(
                  padding: responsiveValue<EdgeInsets>(
                    context,
                    compact: const EdgeInsets.all(16),
                    medium: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                    expanded: const EdgeInsets.fromLTRB(36, 24, 36, 32),
                    wide: const EdgeInsets.fromLTRB(44, 28, 44, 36),
                  ),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
""",
        "analytics container start",
    )

    replace_once(
        ADMIN_ANALYTICS,
        """                  ],
                ),
              ),
            ),
""",
        """                    ],
                  ),
                ),
              ),
            ),
""",
        "analytics container end",
    )

    replace_once(
        ADMIN_ANALYTICS,
        """        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
""",
        """        GridView.count(
          crossAxisCount: responsiveValue<int>(
            context,
            compact: 2,
            medium: 3,
            expanded: 4,
            wide: 4,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: responsiveValue<double>(
            context,
            compact: 1.5,
            medium: 1.7,
            expanded: 1.9,
            wide: 2.0,
          ),
""",
        "analytics metric grid",
    )


def transform_admin_orders() -> None:
    ensure_import(
        ADMIN_ORDERS,
        "import 'admin_gate.dart';",
        "import '../ui_kit/responsive/responsive.dart';",
    )

    replace_once(
        ADMIN_ORDERS,
        """        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
""",
        """        body: ResponsivePageContainer(
          maxContentWidth: 1280,
          compactPadding: EdgeInsets.zero,
          mediumPadding: EdgeInsets.zero,
          expandedPadding: EdgeInsets.zero,
          widePadding: EdgeInsets.zero,
          child: Column(
            children: [
              Padding(
                padding: responsiveValue<EdgeInsets>(
                  context,
                  compact: const EdgeInsets.all(16),
                  medium: const EdgeInsets.fromLTRB(24, 20, 24, 18),
                  expanded: const EdgeInsets.fromLTRB(36, 24, 36, 20),
                  wide: const EdgeInsets.fromLTRB(44, 28, 44, 22),
                ),
""",
        "orders container start",
    )

    replace_once(
        ADMIN_ORDERS,
        """            const Divider(height: 1),
            Expanded(
""",
        """              const Divider(height: 1),
              Expanded(
""",
        "orders inner indentation divider",
    )

    replace_once(
        ADMIN_ORDERS,
        """            ),
          ],
        ),
      ),
""",
        """              ),
            ],
          ),
        ),
      ),
""",
        "orders container end",
    )

    replace_once(
        ADMIN_ORDERS,
        """                   return ListView.separated(
                     padding: const EdgeInsets.all(16),
""",
        """                   return ListView.separated(
                     padding: responsiveValue<EdgeInsets>(
                       context,
                       compact: const EdgeInsets.all(16),
                       medium: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                       expanded: const EdgeInsets.fromLTRB(36, 20, 36, 28),
                       wide: const EdgeInsets.fromLTRB(44, 22, 44, 32),
                     ),
""",
        "orders list padding",
    )


def transform_tracking_live() -> None:
    ensure_import(
        TRACKING_LIVE,
        "import 'widgets/tracking_kpi_tile.dart';",
        "import '../../ui_kit/responsive/responsive.dart';",
    )

    replace_once(
        TRACKING_LIVE,
        """      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
""",
        """      body: ResponsivePageContainer(
        maxContentWidth: 1440,
        compactPadding: EdgeInsets.zero,
        mediumPadding: EdgeInsets.zero,
        expandedPadding: EdgeInsets.zero,
        widePadding: EdgeInsets.zero,
        child: ListView(
          padding: responsiveValue<EdgeInsets>(
            context,
            compact: const EdgeInsets.all(16),
            medium: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            expanded: const EdgeInsets.fromLTRB(36, 24, 36, 32),
            wide: const EdgeInsets.fromLTRB(44, 28, 44, 36),
          ),
          children: [
""",
        "tracking container start",
    )

    replace_once(
        TRACKING_LIVE,
        """        ],
      ),
    );
""",
        """          ],
        ),
      ),
    );
""",
        "tracking container end",
    )

    replace_once(
        TRACKING_LIVE,
        """        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.radar, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tracking Live',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Monitoring des groupes et trackers en temps réel',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                  ),
                  if (provider.lastUpdatedAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Dernière mise à jour: ${provider.presence.formatLastSeen(provider.lastUpdatedAt)}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
            PeriodSelector(
              selection: provider.selectedPeriod,
              onChanged: provider.setPeriod,
            ),
          ],
        ),
""",
        """        child: LayoutBuilder(
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
""",
        "tracking responsive header",
    )


def transform_circuit_wizard() -> None:
    ensure_import(
        CIRCUIT_WIZARD,
        "import '../ui/widgets/maslive_button.dart';",
        "import '../ui_kit/responsive/responsive.dart';",
    )

    replace_once(
        CIRCUIT_WIZARD,
        """                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: projects.length,
                  itemBuilder: (context, index) {
                    final project = projects[index];
                    return _buildProjectCard(project);
                  },
                );
""",
        """                return ResponsivePageContainer(
                  maxContentWidth: 1200,
                  compactPadding: EdgeInsets.zero,
                  mediumPadding: EdgeInsets.zero,
                  expandedPadding: EdgeInsets.zero,
                  widePadding: EdgeInsets.zero,
                  child: ListView.builder(
                    padding: responsiveValue<EdgeInsets>(
                      context,
                      compact: const EdgeInsets.all(16),
                      medium: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                      expanded: const EdgeInsets.fromLTRB(36, 24, 36, 32),
                      wide: const EdgeInsets.fromLTRB(44, 28, 44, 36),
                    ),
                    itemCount: projects.length,
                    itemBuilder: (context, index) {
                      final project = projects[index];
                      return _buildProjectCard(project);
                    },
                  ),
                );
""",
        "circuit projects container",
    )

    replace_once(
        CIRCUIT_WIZARD,
        """    final screen = MediaQuery.of(context).size;
    final availableWidth = (screen.width - 32).clamp(0.0, double.infinity);
    final dialogWidth = availableWidth > 900 ? 900.0 : availableWidth;
    final dialogMaxHeight = screen.height * 0.9;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
""",
        """    final screen = MediaQuery.of(context).size;
    final compactWidth = (screen.width - 20).clamp(0.0, double.infinity);
    final requestedWidth = responsiveValue<double>(
      context,
      compact: compactWidth,
      medium: 760,
      expanded: 900,
      wide: 980,
    );
    final dialogWidth = requestedWidth.clamp(0.0, compactWidth).toDouble();
    final dialogMaxHeight = screen.height * 0.9;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: responsiveValue<EdgeInsets>(
        context,
        compact: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
        medium: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        expanded: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
        wide: const EdgeInsets.symmetric(horizontal: 44, vertical: 36),
      ),
""",
        "circuit dialog sizing",
    )

    replace_once(
        CIRCUIT_WIZARD,
        """          child: Padding(
            padding: const EdgeInsets.all(16),
""",
        """          child: Padding(
            padding: responsiveValue<EdgeInsets>(
              context,
              compact: const EdgeInsets.all(16),
              medium: const EdgeInsets.all(20),
              expanded: const EdgeInsets.all(24),
              wide: const EdgeInsets.all(28),
            ),
""",
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
