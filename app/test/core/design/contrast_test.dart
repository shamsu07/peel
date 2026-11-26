import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:peel/core/design/tokens.dart';

/// WCAG 2.x contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('Text contrast meets WCAG AA (4.5:1)', () {
    for (final pair in PeelPairs.all) {
      test('${pair.name} ink on ${pair.name} fill', () {
        expect(contrast(pair.ink, pair.fill), greaterThanOrEqualTo(4.5));
      });
    }

    test('muted text on paper', () {
      expect(
        contrast(PeelColors.muted, PeelColors.paper),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('muted text on white surface', () {
      expect(
        contrast(PeelColors.muted, PeelColors.surface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('unselected segment text on the grey track', () {
      expect(
        contrast(PeelColors.mutedStrong, PeelColors.track),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('white text on the black primary button', () {
      expect(
        contrast(PeelColors.surface, PeelColors.ink),
        greaterThanOrEqualTo(4.5),
      );
    });
  });
}
