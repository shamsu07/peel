import 'package:flutter_test/flutter_test.dart';
import 'package:peel/sticker_engine/whatsapp_rules.dart';

void main() {
  group('WhatsAppStickerRules', () {
    test('our size targets leave a margin under WhatsApp limits', () {
      expect(
        WhatsAppStickerRules.staticTargetBytes,
        lessThan(WhatsAppStickerRules.staticMaxBytes),
      );
      expect(
        WhatsAppStickerRules.animatedTargetBytes,
        lessThan(WhatsAppStickerRules.animatedMaxBytes),
      );
    });

    test('accepts identifiers made of allowed characters', () {
      expect(
        WhatsAppStickerRules.isValidIdentifier('my_stickers-1.2 a'),
        isTrue,
      );
    });

    test('rejects empty, too long, or disallowed identifiers', () {
      expect(WhatsAppStickerRules.isValidIdentifier(''), isFalse);
      expect(WhatsAppStickerRules.isValidIdentifier('a' * 128), isFalse);
      expect(WhatsAppStickerRules.isValidIdentifier('stickers/1'), isFalse);
      expect(WhatsAppStickerRules.isValidIdentifier('émoji'), isFalse);
    });
  });
}
