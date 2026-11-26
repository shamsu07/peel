import 'package:flutter/painting.dart';

/// Design tokens, taken from the "Design language" board of the UI canvas.
///
/// Rule of the system: colour comes in pairs. Every pastel has its own dark
/// ink for line art and text, so colour never relies on black to read.
abstract final class PeelColors {
  static const paper = Color(0xFFEEEEF0);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF111113);
  static const muted = Color(0xFF5F5F68);
  static const mutedStrong = Color(0xFF4A4A52);
  static const track = Color(0xFFE1E1E5);
  static const hairline = Color(0xFFD3D3D9);

  /// Sticker art and the "new" dot only.
  static const electric = Color(0xFF3D5AFE);

  /// The "NEW" tag only.
  static const tagRed = Color(0xFFE5383B);
}

/// A pastel fill with the dark ink that sits on it.
class InkPair {
  const InkPair(this.name, this.fill, this.ink, {required this.role});

  final String name;
  final Color fill;
  final Color ink;

  /// What the colour means in the app, e.g. photo, video, sound.
  final String role;
}

abstract final class PeelPairs {
  static const mint = InkPair(
    'Mint',
    Color(0xFFCFF5B4),
    Color(0xFF1C5B2C),
    role: 'photo',
  );
  static const bubblegum = InkPair(
    'Bubblegum',
    Color(0xFFFFD0EE),
    Color(0xFFA3166F),
    role: 'video',
  );
  static const butter = InkPair(
    'Butter',
    Color(0xFFFFE88F),
    Color(0xFF6B3A00),
    role: 'sound',
  );
  static const sky = InkPair(
    'Sky',
    Color(0xFFCFE6FB),
    Color(0xFF1E3F7A),
    role: 'info',
  );
  static const lilac = InkPair(
    'Lilac',
    Color(0xFFDCCBFF),
    Color(0xFF4B2A9B),
    role: 'moving',
  );

  static const all = [mint, bubblegum, butter, sky, lilac];
}

/// A colour with a human name, for pickers that need an accessible label.
class NamedColor {
  const NamedColor(this.name, this.color);

  final String name;
  final Color color;
}

/// Bright colours for text on stickers (Text editor, spec P0-10).
abstract final class StickerTextColors {
  static const sun = NamedColor('Sun yellow', Color(0xFFFFD60A));
  static const hotPink = NamedColor('Hot pink', Color(0xFFFF3DA5));
  static const electric = NamedColor('Electric blue', Color(0xFF3D5AFE));
  static const lime = NamedColor('Lime', Color(0xFF9BE000));
  static const tangerine = NamedColor('Tangerine', Color(0xFFFF7A00));
  static const white = NamedColor('White', Color(0xFFFFFFFF));
  static const black = NamedColor('Black', Color(0xFF111113));

  static const all = [sun, hotPink, electric, lime, tangerine, white, black];
}

abstract final class PeelRadii {
  static const card = 28.0;
  static const tile = 22.0;
  static const control = 16.0;
  static const segment = 12.0;
}

abstract final class PeelSpace {
  /// Side gutter of every screen.
  static const gutter = 20.0;

  /// Default gap between stacked blocks.
  static const gap = 14.0;

  /// Minimum touch target on both platforms.
  static const minTouch = 44.0;
}

/// The white die-cut edge that makes UI pieces look like stickers.
abstract final class PeelDieCut {
  /// White edge on UI cards.
  static const edge = 5.0;

  /// Most a UI card may be tilted, in degrees.
  static const maxTiltDegrees = 1.5;

  /// White outline on exported stickers, in sticker pixels (WhatsApp's
  /// recommendation for a 512 px canvas).
  static const stickerOutline = 8.0;
}

abstract final class PeelShadows {
  static const card = [
    BoxShadow(color: Color(0x1A111113), blurRadius: 22, offset: Offset(0, 10)),
  ];

  static const floating = [
    BoxShadow(color: Color(0x47111113), blurRadius: 26, offset: Offset(0, 12)),
  ];
}
