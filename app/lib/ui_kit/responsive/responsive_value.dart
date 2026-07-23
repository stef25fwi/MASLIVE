import 'package:flutter/widgets.dart';

import 'responsive_breakpoints.dart';

/// Selects a value from the current MASLIVE window class.
///
/// Compact values are mandatory so existing smartphone rendering remains the
/// default. Larger values fall back progressively when omitted.
T responsiveValue<T>(
  BuildContext context, {
  required T compact,
  T? medium,
  T? expanded,
  T? wide,
}) {
  switch (context.windowClass) {
    case MasliveWindowClass.compact:
      return compact;
    case MasliveWindowClass.medium:
      return medium ?? compact;
    case MasliveWindowClass.expanded:
      return expanded ?? medium ?? compact;
    case MasliveWindowClass.wide:
      return wide ?? expanded ?? medium ?? compact;
  }
}

extension MasliveResponsiveNum on num {
  double responsive(
    BuildContext context, {
    num? medium,
    num? expanded,
    num? wide,
  }) {
    return responsiveValue<num>(
      context,
      compact: this,
      medium: medium,
      expanded: expanded,
      wide: wide,
    ).toDouble();
  }
}
