/// WhatsApp's rules for third-party sticker packs, from the official
/// WhatsApp/stickers README (Android and iOS). See
/// docs/research/01-whatsapp-stickers.md §2.
///
/// Sizes use 1 KB = 1024 bytes, as WhatsApp's own sample validator does.
abstract final class WhatsAppStickerRules {
  static const kb = 1024;

  /// Every sticker is exactly this many pixels square.
  static const canvasPx = 512;

  static const staticMaxBytes = 100 * kb;
  static const animatedMaxBytes = 500 * kb;

  /// Our own targets, with a safety margin under WhatsApp's limits
  /// (spec P0-1, P0-2). A pack is rejected if any file is even 1 byte over.
  static const staticTargetBytes = 95 * kb;
  static const animatedTargetBytes = 480 * kb;

  static const minFrameDuration = Duration(milliseconds: 8);
  static const maxAnimationDuration = Duration(seconds: 10);

  static const trayIconPx = 96;
  static const trayIconMaxBytes = 50 * kb;

  static const minStickersPerPack = 3;
  static const maxStickersPerPack = 30;
  static const maxPacksPerApp = 10;

  static const minEmojisPerSticker = 1;
  static const maxEmojisPerSticker = 3;

  static const maxNameLength = 128;
  static const maxPublisherLength = 128;

  /// The identifier must be shorter than 128 characters.
  static const maxIdentifierLength = 127;
  static final identifierPattern = RegExp(r'^[a-zA-Z0-9_.\- ]+$');

  static const maxAccessibilityTextStatic = 125;
  static const maxAccessibilityTextAnimated = 255;

  /// White outline WhatsApp recommends around each sticker, in pixels.
  static const recommendedOutlinePx = 8;

  static bool isValidIdentifier(String id) =>
      id.isNotEmpty &&
      id.length <= maxIdentifierLength &&
      identifierPattern.hasMatch(id);
}
