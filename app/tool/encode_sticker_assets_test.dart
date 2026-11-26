// Converts the PNGs from tool/render_design_stickers.py into small WebP app
// assets, using the app's own libwebp encoder. Not part of the test suite;
// run it by hand:
//
//   flutter test tool/encode_sticker_assets_test.dart \
//     --dart-define=PNG_DIR=<dir with PNGs> \
//     --dart-define=OUT_DIR=assets/stickers
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:peel/sticker_engine/webp_encoder.dart';

void main() {
  const pngDir = String.fromEnvironment('PNG_DIR');
  const outDir = String.fromEnvironment(
    'OUT_DIR',
    defaultValue: 'assets/stickers',
  );

  testWidgets('encode design stickers to WebP', (tester) async {
    expect(pngDir, isNotEmpty, reason: 'Pass --dart-define=PNG_DIR=...');
    await tester.runAsync(() async {
      const encoder = WebpEncoder();
      await Directory(outDir).create(recursive: true);
      final pngs =
          Directory(pngDir)
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.png'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      var before = 0;
      var after = 0;
      for (final png in pngs) {
        final bytes = await png.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final image = (await codec.getNextFrame()).image;
        final rgba = (await image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        ))!.buffer.asUint8List();

        final lossless = encoder.encodeStatic(
          rgba,
          image.width,
          image.height,
          const EncodeSettings(quality: 100, method: 6, lossless: true),
        );
        final lossy = encoder.encodeStatic(
          rgba,
          image.width,
          image.height,
          const EncodeSettings(quality: 90, method: 6),
        );
        final best = lossless.length <= lossy.length ? lossless : lossy;
        final name = png.uri.pathSegments.last.replaceAll('.png', '.webp');
        await File('$outDir/$name').writeAsBytes(best);

        before += bytes.length;
        after += best.length;
        // ignore: avoid_print
        print(
          '$name ${image.width}x${image.height}: '
          '${bytes.length ~/ 1024} KB png -> ${best.length ~/ 1024} KB '
          '${identical(best, lossless) ? 'lossless' : 'q90'}',
        );
        image.dispose();
        codec.dispose();
      }
      // ignore: avoid_print
      print('total: ${before ~/ 1024} KB -> ${after ~/ 1024} KB');
    });
  });
}
