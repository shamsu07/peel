import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:peel/core/design/typography.dart';
import 'package:peel/create/drafts.dart';
import 'package:peel/library/sticker_record.dart';
import 'package:peel/sticker_engine/background.dart';
import 'package:peel/sticker_engine/caption.dart';
import 'package:peel/sticker_engine/composer.dart';
import 'package:peel/sticker_engine/compressor.dart';
import 'package:peel/sticker_engine/render.dart';
import 'package:peel_native/peel_native.dart';

int alphaAt(Uint8List rgba, int x, int y, [int size = 512]) =>
    rgba[(y * size + x) * 4 + 3];

void main() {
  setUpAll(() => PeelType.useBrandFonts = false);

  testWidgets(
    'cut-out sticker: subject in the middle, white edge, clear corners',
    (tester) async {
      await tester.runAsync(() async {
        // A 200x200 red square "subject" with a transparent background.
        final subject = await renderRgba(
          (c, s) => c.drawRect(
            const ui.Rect.fromLTWH(100, 100, 200, 200),
            ui.Paint()..color = const ui.Color(0xFFFF0000),
          ),
          size: 400,
        );
        final cutout = await imageFromRgba(subject, 400, 400);
        final original = await imageFromRgba(subject, 400, 400);

        final rgba = await PhotoComposition(
          original: original,
          cutout: cutout,
        ).renderRgba();
        expect(rgba.length, 512 * 512 * 4);
        expect(alphaAt(rgba, 0, 0), 0, reason: 'corners stay see-through');
        final mid = (256 * 512 + 256) * 4;
        expect(rgba.sublist(mid, mid + 4), [255, 0, 0, 255]);

        // Just outside the subject there is a white edge.
        final edge = await PhotoComposition(
          original: original,
          cutout: cutout,
        ).renderRgba();
        var white = false;
        for (var x = 0; x < 256; x++) {
          final i = (256 * 512 + x) * 4;
          if (edge[i + 3] == 255 && edge[i] == 255 && edge[i + 1] == 255) {
            white = true;
            break;
          }
        }
        expect(white, isTrue);
      });
    },
  );

  testWidgets('caption draws text on top of the sticker', (tester) async {
    await tester.runAsync(() async {
      final blank = await renderRgba((c, s) {}, size: 64);
      final image = await imageFromRgba(blank, 64, 64);
      final withText = await PhotoComposition(
        original: image,
        mode: CutMode.whole,
        whiteEdge: false,
        caption: const Caption(text: 'hi', look: CaptionLook.block),
      ).renderRgba();
      final low = (0.84 * 512).round();
      expect(alphaAt(withText, 256, low), greaterThan(0));
    });
  });

  test('video blend: frame shows inside, rim on top, corners clear', () {
    const n = 4;
    final frame = Uint8List.fromList(
      List.generate(n * 4, (i) => i % 4 == 3 ? 255 : 100),
    );
    // Pixel 0: outside the mask. 1: inside. 2: rim (white overlay). 3: half rim.
    final mask = Uint8List.fromList([
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      255,
      0,
      0,
      0,
      255,
      0,
      0,
      0,
      255,
    ]);
    final overlay = Uint8List.fromList([
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      255,
      255,
      255,
      255,
      255,
      255,
      255,
      128,
    ]);
    blendVideoFrame(frame, VideoLayers(overlay: overlay, mask: mask));
    expect(frame.sublist(0, 4)[3], 0);
    expect(frame.sublist(4, 8), [100, 100, 100, 255]);
    expect(frame.sublist(8, 12), [255, 255, 255, 255]);
    expect(frame[15], 255);
    expect(frame[12], inInclusiveRange(170, 185));
  });

  test('trimmer quality hint', () {
    expect(expectedQuality(const Duration(seconds: 3)), StickerQuality.sharp);
    expect(expectedQuality(const Duration(seconds: 6)), StickerQuality.good);
    expect(
      expectedQuality(const Duration(seconds: 10)),
      StickerQuality.squeezed,
    );
  });

  group('VideoDraft sound', () {
    final info = VideoInfo(
      durationMs: 8000,
      width: 1080,
      height: 1920,
      hasAudio: true,
    );
    final draft = VideoDraft(
      path: '/v.mp4',
      info: info,
      startMs: 1000,
      lengthMs: 4000,
      crop: centeredCrop(info),
    );

    test('original sound follows the trim', () {
      final s = draft.sound!;
      expect(
        (s.origin, s.startMs, s.durationMs),
        (SoundOrigin.original, 1000, 4000),
      );
    });

    test('mute has no sound', () {
      expect(draft.copyWith(soundMode: VideoSoundMode.mute).sound, isNull);
    });

    test('a new sound is cut to the clip length', () {
      final s = draft
          .copyWith(
            soundMode: VideoSoundMode.replace,
            newSound: const StickerSound(
              origin: SoundOrigin.file,
              path: '/a.mp3',
              startMs: 500,
              durationMs: 10000,
            ),
          )
          .sound!;
      expect((s.path, s.startMs, s.durationMs), ('/a.mp3', 500, 4000));
    });

    test('centred crop covers the short side', () {
      final c = centeredCrop(info);
      expect(c.left, 0);
      expect(c.top, closeTo((1920 - 1080) / 2 / 1920, 1e-9));
      expect(c.size, 1);
    });
  });

  testWidgets('framing: zoom and pan stay in bounds; switching mode resets', (
    tester,
  ) async {
    await tester.runAsync(() async {
      // A 400 x 200 photo: the square is 200 wide, so it can move sideways.
      final rgba = await renderRgba((c, s) {}, size: 400);
      final wide = await imageFromRgba(
        rgba.sublist(0, 400 * 200 * 4),
        400,
        200,
      );
      final cut = await imageFromRgba(rgba.sublist(0, 100 * 100 * 4), 100, 100);
      var c = PhotoComposition(
        original: wide,
        cutout: cut,
        mode: CutMode.whole,
      );

      c = c.copyWith(zoom: 9, pan: const Offset(5, 5));
      expect(c.zoom, PhotoComposition.maxZoom);
      final side = 200 / PhotoComposition.maxZoom;
      expect(c.pan.dx, closeTo((400 - side) / 2 / 400, 1e-9));
      expect(c.pan.dy, closeTo((200 - side) / 2 / 200, 1e-9));

      c = c.copyWith(mode: CutMode.cutout);
      expect((c.zoom, c.pan), (1.0, Offset.zero));

      c = c.copyWith(pan: const Offset(3, -3));
      expect(c.pan, const Offset(0.45, -0.45));
    });
  });

  testWidgets('pre-drawn edge is 8 px on the sticker at normal size', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final rgba = await renderRgba(
        (c, s) => c.drawCircle(
          const Offset(100, 100),
          80,
          ui.Paint()..color = const ui.Color(0xFF00AA00),
        ),
        size: 200,
      );
      final cut = await imageFromRgba(rgba, 200, 200);
      final (edged, pad) = await PhotoComposition.buildEdged(cut);
      const fit = (512 - 2 * (8 + 14)) / 200;
      expect(pad * fit, closeTo(8, 1e-9));
      expect(edged.width, (200 + pad * 2).ceil());
    });
  });
}
