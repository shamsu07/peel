import 'package:material_ui/material_ui.dart';

/// WhatsApp's own colours, for anything that stands for WhatsApp: its
/// buttons, the chat preview and the word in headings. Meta's brand rules
/// say the word "WhatsApp" keeps the surrounding font, so only colour
/// changes.
abstract final class WhatsAppColors {
  static const green = Color(0xFF25D366);

  /// Text and icons on [green], as on WhatsApp's own green buttons.
  static const onGreen = Color(0xFF111B21);
  static const teal = Color(0xFF008069);
  static const wallpaper = Color(0xFFEFEAE2);
  static const outgoing = Color(0xFFD9FDD3);
  static const tick = Color(0xFF53BDEB);
  static const meta = Color(0xFF667781);
  static const text = Color(0xFF111B21);
  static const mic = Color(0xFF00A884);
}
