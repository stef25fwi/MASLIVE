import 'package:flutter/widgets.dart';

import 'responsive_value.dart';

/// Shared adaptive grid delegate. Compact values remain the source of truth;
/// larger screens only receive additional columns and spacing.
class ResponsiveGridDelegate extends SliverGridDelegateWithFixedCrossAxisCount {
  ResponsiveGridDelegate({
    required BuildContext context,
    required int compactCount,
    int? mediumCount,
    int? expandedCount,
    int? wideCount,
    double compactMainAxisSpacing = 12,
    double? mediumMainAxisSpacing,
    double? expandedMainAxisSpacing,
    double? wideMainAxisSpacing,
    double compactCrossAxisSpacing = 12,
    double? mediumCrossAxisSpacing,
    double? expandedCrossAxisSpacing,
    double? wideCrossAxisSpacing,
    double childAspectRatio = 1,
    double? mainAxisExtent,
  }) : super(
         crossAxisCount: responsiveValue<int>(
           context,
           compact: compactCount,
           medium: mediumCount,
           expanded: expandedCount,
           wide: wideCount,
         ),
         mainAxisSpacing: responsiveValue<double>(
           context,
           compact: compactMainAxisSpacing,
           medium: mediumMainAxisSpacing,
           expanded: expandedMainAxisSpacing,
           wide: wideMainAxisSpacing,
         ),
         crossAxisSpacing: responsiveValue<double>(
           context,
           compact: compactCrossAxisSpacing,
           medium: mediumCrossAxisSpacing,
           expanded: expandedCrossAxisSpacing,
           wide: wideCrossAxisSpacing,
         ),
         childAspectRatio: childAspectRatio,
         mainAxisExtent: mainAxisExtent,
       );
}
