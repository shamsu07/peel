import 'package:flutter_test/flutter_test.dart';
import 'package:peel/core/design/typography.dart';
import 'package:peel/features/lab/synthetic_clip.dart';
import 'package:peel/sticker_engine/render.dart';
import 'package:peel/sticker_engine/sticker_check.dart';
import 'package:peel/whatsapp/bonus_stickers.dart';
import 'package:peel/whatsapp/pack_store.dart';

void main() {
  setUpAll(() => PeelType.useBrandFonts = false);

  testWidgets('drawn bonus stickers pass WhatsApp rules for both kinds', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final source = DrawnBonusSource();
      for (final kind in StickerKind.values) {
        final bonus = await source.bonusFor(kind);
        expect(bonus, hasLength(2));
        for (final b in bonus) {
          final check = checkSticker(b.bytes, kind: kind, useOurTargets: true);
          expect(
            check.passes,
            isTrue,
            reason: '${b.fileName}: ${check.problems}',
          );
          expect(b.emojis, isNotEmpty);
        }
      }
    });
  });

  testWidgets('tray icon is a 96x96 PNG under 50 KB', (tester) async {
    await tester.runAsync(() async {
      final clip = SyntheticClip(duration: Duration.zero, detailed: true);
      final png = await trayPngFromRgba(clip.render(0), clip.size);
      expect(pngSize(png), (96, 96));
      expect(png.length, lessThan(50 * 1024));
    });
  });
}
