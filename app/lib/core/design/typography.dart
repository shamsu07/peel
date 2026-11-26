import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Type scale from the design canvas: Inter Tight for all UI, Instrument
/// Serif italic for text on stickers only.
///
/// TODO(release): bundle the font files under assets/fonts so the app never
/// fetches fonts at runtime (google_fonts uses bundled files when present).
abstract final class PeelType {
  /// Tests turn this off so no fonts are fetched over the network.
  static bool useBrandFonts = true;

  static TextStyle _interTight({
    required double size,
    required FontWeight weight,
    double? height,
    double trackingEm = 0,
    Color color = PeelColors.ink,
  }) {
    final base = TextStyle(
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: size * trackingEm,
      color: color,
    );
    return useBrandFonts ? GoogleFonts.interTight(textStyle: base) : base;
  }

  /// "Snap. Peel. Send." Headlines end in a full stop.
  static TextStyle display({Color color = PeelColors.ink}) => _interTight(
    size: 72,
    weight: FontWeight.w800,
    height: 0.88,
    trackingEm: -0.055,
    color: color,
  );

  /// Screen titles such as "It's ready." (40–54 px in the design).
  static TextStyle title({double size = 40, Color color = PeelColors.ink}) =>
      _interTight(
        size: size,
        weight: FontWeight.w800,
        height: 1.0,
        trackingEm: -0.05,
        color: color,
      );

  static TextStyle wordmark() =>
      _interTight(size: 26, weight: FontWeight.w800, trackingEm: -0.045);

  /// Card titles such as "Photo".
  static TextStyle cardTitle({Color color = PeelColors.ink}) => _interTight(
    size: 28,
    weight: FontWeight.w800,
    height: 1.0,
    trackingEm: -0.04,
    color: color,
  );

  static TextStyle label({Color color = PeelColors.ink}) => _interTight(
    size: 17,
    weight: FontWeight.w800,
    trackingEm: -0.02,
    color: color,
  );

  static TextStyle body({Color color = PeelColors.muted}) =>
      _interTight(size: 17, weight: FontWeight.w400, height: 1.4, color: color);

  /// Smallest text in the app is 13 px.
  static TextStyle caption({Color color = PeelColors.muted}) => _interTight(
    size: 13.5,
    weight: FontWeight.w500,
    height: 1.35,
    color: color,
  );

  static TextStyle button({Color color = PeelColors.surface}) =>
      _interTight(size: 17, weight: FontWeight.w700, color: color);

  static TextStyle tag({Color color = PeelColors.surface}) => _interTight(
    size: 12,
    weight: FontWeight.w800,
    trackingEm: 0.1,
    color: color,
  );

  /// Sticker text only, never UI.
  static TextStyle stickerSerif({
    double size = 30,
    Color color = PeelColors.ink,
  }) {
    final base = TextStyle(
      fontSize: size,
      fontStyle: FontStyle.italic,
      height: 1.0,
      color: color,
    );
    return useBrandFonts ? GoogleFonts.instrumentSerif(textStyle: base) : base;
  }
}
