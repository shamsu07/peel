import 'package:flutter/painting.dart';

/// Design tokens, taken from the "Design language" board of the UI canvas.
///
/// Rule of the system: colour comes in pairs. Every pastel has its own dark
/// ink for line art and text, so colour never relies on black to read.
abstract final class PeelColors {
  /// True in dark mode. Set by the app from the phone's setting
  /// (see PeelApp); every colour below follows it.
  static bool dark = false;

  /// The app background: the warm off-white of a sticker sheet's backing
  /// paper, or the graphite of the app icon in dark mode.
  static Color get paper =>
      dark ? const Color(0xFF17171C) : const Color(0xFFF1EEE9);

  /// Cards and sheets.
  static Color get surface =>
      dark ? const Color(0xFF24242B) : const Color(0xFFFFFFFF);

  /// Text, icons and dark buttons. Light in dark mode, so ink buttons turn
  /// light with dark text.
  static Color get ink =>
      dark ? const Color(0xFFF4F2EE) : const Color(0xFF111113);
  static Color get muted =>
      dark ? const Color(0xFFA6A6B0) : const Color(0xFF5F5F68);
  static Color get mutedStrong =>
      dark ? const Color(0xFFC4C4CC) : const Color(0xFF4A4A52);
  static Color get track =>
      dark ? const Color(0xFF30303A) : const Color(0xFFE6E2DC);
  static Color get hairline =>
      dark ? const Color(0xFF3B3B45) : const Color(0xFFD8D3CC);

  /// Text and icons on a pastel pair fill, which stays light in both modes.
  static const onPastel = Color(0xFF111113);

  /// Things that are white whatever the mode: a sticker's die-cut edge.
  static const white = Color(0xFFFFFFFF);

  /// Sticker art and the "new" dot only.
  static const electric = Color(0xFF3D5AFE);

  /// The "NEW" tag and close buttons.
  static const tagRed = Color(0xFFE5383B);

  /// Soft red behind close buttons.
  static Color get closeFill =>
      dark ? const Color(0xFF3A2326) : const Color(0xFFFFE3E1);
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
  static List<BoxShadow> get card => [
    BoxShadow(
      color: PeelColors.dark
          ? const Color(0x66000000)
          : const Color(0x1A3A2A1A),
      blurRadius: 22,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> get floating => [
    BoxShadow(
      color: PeelColors.dark
          ? const Color(0x99000000)
          : const Color(0x47111113),
      blurRadius: 26,
      offset: const Offset(0, 12),
    ),
  ];
}
