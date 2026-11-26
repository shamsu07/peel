import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Type scale from the design canvas: Inter Tight for all UI, Instrument
/// Serif italic for text on stickers only.
///
abstract final class PeelType {
  /// Tests turn this off so no fonts are fetched over the network.
  static bool useBrandFonts = true;

  static TextStyle _interTight({
    required double size,
    required FontWeight weight,
    double? height,
    double trackingEm = 0,
    Color? color,
  }) {
    final base = TextStyle(
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: size * trackingEm,
      color: color ?? PeelColors.ink,
    );
    return useBrandFonts ? GoogleFonts.interTight(textStyle: base) : base;
  }

  /// "Snap. Peel. Send." Headlines end in a full stop.
  static TextStyle display({Color? color}) => _interTight(
    size: 72,
    weight: FontWeight.w800,
    height: 0.88,
    trackingEm: -0.055,
    color: color ?? PeelColors.ink,
  );

  /// Screen titles such as "It's ready." (40–54 px in the design).
  static TextStyle title({double size = 40, Color? color}) => _interTight(
    size: size,
    weight: FontWeight.w800,
    height: 1.0,
    trackingEm: -0.05,
    color: color ?? PeelColors.ink,
  );

  static TextStyle wordmark() =>
      _interTight(size: 26, weight: FontWeight.w800, trackingEm: -0.045);

  /// Card titles such as "Photo".
  static TextStyle cardTitle({Color? color}) => _interTight(
    size: 28,
    weight: FontWeight.w800,
    height: 1.0,
    trackingEm: -0.04,
    color: color ?? PeelColors.ink,
  );

  static TextStyle label({Color? color}) => _interTight(
    size: 17,
    weight: FontWeight.w800,
    trackingEm: -0.02,
    color: color ?? PeelColors.ink,
  );

  static TextStyle body({Color? color}) => _interTight(
    size: 17,
    weight: FontWeight.w400,
    height: 1.4,
    color: color ?? PeelColors.muted,
  );

  /// Smallest text in the app is 13 px.
  static TextStyle caption({Color? color}) => _interTight(
    size: 13.5,
    weight: FontWeight.w500,
    height: 1.35,
    color: color ?? PeelColors.muted,
  );

  static TextStyle button({Color? color}) => _interTight(
    size: 17,
    weight: FontWeight.w700,
    color: color ?? PeelColors.surface,
  );

  static TextStyle tag({Color? color}) => _interTight(
    size: 12,
    weight: FontWeight.w800,
    trackingEm: 0.1,
    color: color ?? PeelColors.white,
  );

  /// Sticker text only, never UI.
  static TextStyle stickerSerif({double size = 30, Color? color}) {
    final base = TextStyle(
      fontSize: size,
      fontStyle: FontStyle.italic,
      height: 1.0,
      color: color ?? PeelColors.onPastel,
    );
    return useBrandFonts ? GoogleFonts.instrumentSerif(textStyle: base) : base;
  }
}
