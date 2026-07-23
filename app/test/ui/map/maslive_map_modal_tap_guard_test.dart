import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MasLiveMap ignores taps while another modal route is active', () {
    final source = File('lib/ui/map/maslive_map.dart').readAsStringSync();

    expect(source, contains('ValueChanged<MapPoint>? _guardMapTap'));
    expect(source, contains('final route = ModalRoute.of(context);'));
    expect(source, contains('if (route != null && !route.isCurrent) return;'));
    expect(source, contains('onTap: guardedOnTap'));
  });
}
