import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:peel/features/lab/synthetic_clip.dart';
import 'package:peel/sticker_engine/compressor.dart';
import 'package:peel/sticker_engine/sticker_check.dart';
import 'package:peel/sticker_engine/webp_encoder.dart';
import 'package:peel/sticker_engine/webp_inspector.dart';
import 'package:peel/sticker_engine/whatsapp_rules.dart';

void main() {
  const encoder = WebpEncoder();

  group('WebpEncoder + inspector', () {
    test('still sticker is a 512x512 WebP with alpha', () {
      final clip = SyntheticClip(duration: Duration.zero, detailed: false);
      final bytes = encoder.encodeStatic(
        clip.render(0),
        512,
        512,
        const EncodeSettings(quality: 80),
      );
      final info = inspectWebp(bytes);
      expect(info.width, 512);
      expect(info.height, 512);
      expect(info.animated, isFalse);
      expect(info.hasAlpha, isTrue);
    });

    test('animation keeps every frame and the exact length', () {
      final clip = SyntheticClip(
        duration: const Duration(seconds: 2),
        detailed: false,
      );
      final writer = encoder.startAnimation(
        512,
        512,
        const EncodeSettings(quality: 60),
      );
      final plan = framePlan(clip.duration, 10);
      for (final ts in plan.timestampsMs) {
        writer.addFrame(clip.render(ts), ts);
      }
      final info = inspectWebp(writer.finish(plan.endMs));
      expect(info.animated, isTrue);
      expect(info.totalDurationMs, 2000);
      // libwebp merges frames that don't change, so allow fewer.
      expect(info.frameCount, inInclusiveRange(2, 20));
    });

    test('rejects pixel buffers of the wrong length', () {
      expect(
        () => encoder.encodeStatic(
          Uint8List(10),
          512,
          512,
          const EncodeSettings(quality: 80),
        ),
        throwsArgumentError,
      );
    });
  });

  group('checkSticker', () {
    test('flags bytes that are not WebP', () {
      final check = checkSticker(
        Uint8List.fromList(List.filled(64, 7)),
        kind: StickerKind.still,
      );
      expect(check.problems, [StickerProblem.notWebp]);
    });

    test('flags the wrong canvas size', () {
      final clip = SyntheticClip(
        duration: Duration.zero,
        detailed: false,
        size: 256,
      );
      final bytes = encoder.encodeStatic(
        clip.render(0),
        256,
        256,
        const EncodeSettings(quality: 80),
      );
      final check = checkSticker(bytes, kind: StickerKind.still);
      expect(check.problems, contains(StickerProblem.wrongSize));
    });

    test('flags a still image submitted as a moving sticker', () {
      final clip = SyntheticClip(duration: Duration.zero, detailed: false);
      final bytes = encoder.encodeStatic(
        clip.render(0),
        512,
        512,
        const EncodeSettings(quality: 80),
      );
      final check = checkSticker(bytes, kind: StickerKind.moving);
      expect(check.problems, contains(StickerProblem.wrongKind));
    });
  });

  group('framePlan', () {
    test('10 s at 15 fps gives 150 frames ending at 10 s', () {
      final plan = framePlan(const Duration(seconds: 10), 15);
      expect(plan.timestampsMs.length, 150);
      expect(plan.endMs, 10000);
    });

    test('frames are never shorter than WhatsApp\'s 8 ms minimum', () {
      final plan = framePlan(const Duration(milliseconds: 20), 1000);
      final gaps = [
        for (var i = 1; i < plan.timestampsMs.length; i++)
          plan.timestampsMs[i] - plan.timestampsMs[i - 1],
      ];
      expect(gaps.every((g) => g >= 8), isTrue);
    });
  });

  group('compressors', () {
    test('detailed still photo fits the 95 KB target', () {
      final clip = SyntheticClip(duration: Duration.zero, detailed: true);
      final result = StaticCompressor().compress(clip.render(0), 512);
      final check = checkSticker(
        result.bytes,
        kind: StickerKind.still,
        useOurTargets: true,
      );
      expect(check.passes, isTrue, reason: '${check.problems}');
    });

    test('3 s cartoon fits at the sharpest settings', () async {
      final result = await AnimatedCompressor().compress(
        SyntheticClip(duration: const Duration(seconds: 3), detailed: false),
      );
      expect(result.quality, StickerQuality.sharp);
      expect(
        checkSticker(
          result.bytes,
          kind: StickerKind.moving,
          useOurTargets: true,
        ).passes,
        isTrue,
      );
    });

    test(
      'worst case: 10 s detailed clip still fits 480 KB at full length',
      () async {
        final result = await AnimatedCompressor().compress(
          SyntheticClip(duration: const Duration(seconds: 10), detailed: true),
        );
        final check = checkSticker(
          result.bytes,
          kind: StickerKind.moving,
          useOurTargets: true,
        );
        expect(check.passes, isTrue, reason: '${check.problems}');
        expect(check.info!.totalDurationMs, 10000);
        expect(
          result.bytes.length,
          lessThanOrEqualTo(WhatsAppStickerRules.animatedTargetBytes),
        );
        // Print for the Phase 0 log.
        // ignore: avoid_print
        print(
          'worst case: ${(result.bytes.length / 1024).toStringAsFixed(1)} KB, '
          '${result.rung}, ${result.frameCount} frames, '
          '${result.attempts} encodes, ${result.elapsed.inMilliseconds} ms '
          '(Mac host)',
        );
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
