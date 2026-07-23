import 'package:flutter_test/flutter_test.dart';
import 'package:masslive/ui_kit/responsive/responsive_breakpoints.dart';

void main() {
  group('MasliveBreakpoints', () {
    test('keeps smartphone widths in compact class', () {
      expect(MasliveBreakpoints.isCompact(320), isTrue);
      expect(MasliveBreakpoints.isCompact(599), isTrue);
      expect(MasliveBreakpoints.isCompact(600), isFalse);
    });

    test('classifies tablet widths as medium', () {
      expect(MasliveBreakpoints.isMedium(600), isTrue);
      expect(MasliveBreakpoints.isMedium(1023), isTrue);
      expect(MasliveBreakpoints.isMedium(1024), isFalse);
    });

    test('classifies desktop widths as expanded', () {
      expect(MasliveBreakpoints.isExpanded(1024), isTrue);
      expect(MasliveBreakpoints.isExpanded(1439), isTrue);
      expect(MasliveBreakpoints.isExpanded(1440), isFalse);
    });

    test('classifies large desktop widths as wide', () {
      expect(MasliveBreakpoints.isWide(1440), isTrue);
      expect(MasliveBreakpoints.isWide(1920), isTrue);
    });
  });
}
