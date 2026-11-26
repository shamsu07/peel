import 'dart:math' as math;
import 'dart:typed_data';

import 'webp_encoder.dart';
import 'whatsapp_rules.dart';

/// Supplies square RGBA frames of a clip, one at a time, so a 10 s clip never
/// has to sit in memory all at once.
abstract interface class FrameSource {
  int get size;
  Duration get duration;

  /// Packed RGBA, `size * size * 4` bytes, for the moment [t].
  Future<Uint8List> frameAt(Duration t);
}

/// One step of the step-down ladder: frame rate and WebP quality.
class CompressionRung {
  const CompressionRung(this.fps, this.quality);

  final int fps;
  final double quality;

  @override
  String toString() => '${fps}fps q${quality.round()}';
}

/// The label users see in the trimmer and editor ("Sharp / Good / Squeezed").
enum StickerQuality { sharp, good, squeezed }

class AnimatedResult {
  const AnimatedResult({
    required this.bytes,
    required this.rung,
    required this.rungIndex,
    required this.frameCount,
    required this.attempts,
    required this.elapsed,
  });

  final Uint8List bytes;
  final CompressionRung rung;
  final int rungIndex;
  final int frameCount;
  final int attempts;
  final Duration elapsed;

  StickerQuality get quality => AnimatedCompressor.qualityFor(rungIndex);
}

class CompressionException implements Exception {
  CompressionException(this.message);

  final String message;

  @override
  String toString() => 'CompressionException: $message';
}

/// The automatic compressor for moving stickers (spec P0-2).
///
/// Lowers quality first, then frame rate, until the file fits. Because the
/// last rungs keep very few frames, any clip up to 10 s ends up fitting:
/// the user's chosen length is never cut.
class AnimatedCompressor {
  AnimatedCompressor({
    this.encoder = const WebpEncoder(),
    this.targetBytes = WhatsAppStickerRules.animatedTargetBytes,
    this.method = 4,
  });

  final WebpEncoder encoder;
  final int targetBytes;
  final int method;

  static const ladder = [
    CompressionRung(15, 80),
    CompressionRung(15, 65),
    CompressionRung(15, 50),
    CompressionRung(12, 50),
    CompressionRung(10, 45),
    CompressionRung(8, 40),
    CompressionRung(6, 35),
    CompressionRung(5, 30),
    CompressionRung(4, 25),
    CompressionRung(3, 20),
    CompressionRung(2, 15),
    CompressionRung(1, 10),
  ];

  static StickerQuality qualityFor(int rungIndex) => switch (rungIndex) {
    <= 1 => StickerQuality.sharp,
    <= 4 => StickerQuality.good,
    _ => StickerQuality.squeezed,
  };

  /// [onProgress] gets the attempt number (1-based) and how far through
  /// that attempt's frames the encoder is (0–1).
  Future<AnimatedResult> compress(
    FrameSource source, {
    void Function(int attempt, double fraction)? onProgress,
  }) async {
    final maxDuration = WhatsAppStickerRules.maxAnimationDuration;
    if (source.duration > maxDuration) {
      throw ArgumentError('Clip is longer than ${maxDuration.inSeconds} s');
    }
    if (source.duration <= Duration.zero) {
      throw ArgumentError('Clip has no length');
    }

    final stopwatch = Stopwatch()..start();
    final tried = <int>{};
    var index = 0;
    var attempts = 0;
    while (true) {
      final rung = ladder[index];
      final plan = framePlan(source.duration, rung.fps);
      final bytes = await _encode(
        source,
        rung,
        plan,
        (f) => onProgress?.call(attempts + 1, f),
      );
      attempts++;
      tried.add(index);

      if (bytes.length <= targetBytes) {
        var best = AnimatedResult(
          bytes: bytes,
          rung: rung,
          rungIndex: index,
          frameCount: plan.timestampsMs.length,
          attempts: attempts,
          elapsed: stopwatch.elapsed,
        );
        // The skip-ahead guesses. If it landed well under the target, try
        // the next better rung once and keep it if it also fits.
        final better = index - 1;
        if (bytes.length < targetBytes * 0.8 &&
            better >= 0 &&
            !tried.contains(better)) {
          final betterRung = ladder[better];
          final betterPlan = framePlan(source.duration, betterRung.fps);
          final betterBytes = await _encode(
            source,
            betterRung,
            betterPlan,
            (f) => onProgress?.call(attempts + 1, f),
          );
          attempts++;
          if (betterBytes.length <= targetBytes) {
            best = AnimatedResult(
              bytes: betterBytes,
              rung: betterRung,
              rungIndex: better,
              frameCount: betterPlan.timestampsMs.length,
              attempts: attempts,
              elapsed: stopwatch.elapsed,
            );
          } else {
            best = AnimatedResult(
              bytes: best.bytes,
              rung: best.rung,
              rungIndex: best.rungIndex,
              frameCount: best.frameCount,
              attempts: attempts,
              elapsed: stopwatch.elapsed,
            );
          }
        }
        return best;
      }
      if (index == ladder.length - 1) {
        throw CompressionException(
          'Still ${bytes.length} bytes at the last rung ($rung)',
        );
      }
      index = _nextRung(index, bytes.length, source.duration);
    }
  }

  /// Skips rungs that are predicted to still be too big, so a hard clip
  /// takes a few encodes instead of a dozen.
  int _nextRung(int current, int measuredBytes, Duration duration) {
    final from = ladder[current];
    final fromFrames = framePlan(duration, from.fps).timestampsMs.length;
    var next = current + 1;
    while (next < ladder.length - 1) {
      final to = ladder[next];
      final toFrames = framePlan(duration, to.fps).timestampsMs.length;
      final predicted =
          measuredBytes *
          (toFrames / fromFrames) *
          (_sizeFactor(to.quality) / _sizeFactor(from.quality));
      if (predicted <= targetBytes * 0.92) break;
      next++;
    }
    return next;
  }

  Future<Uint8List> _encode(
    FrameSource source,
    CompressionRung rung,
    FramePlan plan, [
    void Function(double fraction)? onFrame,
  ]) async {
    final writer = encoder.startAnimation(
      source.size,
      source.size,
      EncodeSettings(quality: rung.quality, method: method),
    );
    try {
      final stamps = plan.timestampsMs;
      for (var i = 0; i < stamps.length; i++) {
        final frame = await source.frameAt(Duration(milliseconds: stamps[i]));
        writer.addFrame(frame, stamps[i]);
        onFrame?.call((i + 1) / stamps.length);
      }
      return writer.finish(plan.endMs);
    } catch (_) {
      writer.dispose();
      rethrow;
    }
  }
}

/// Which moments of a clip become frames, at a given frame rate.
class FramePlan {
  const FramePlan(this.timestampsMs, this.endMs);

  final List<int> timestampsMs;
  final int endMs;
}

FramePlan framePlan(Duration duration, int fps) {
  final totalMs = duration.inMilliseconds;
  final count = math.max(1, (totalMs * fps / 1000).round());
  final minMs = WhatsAppStickerRules.minFrameDuration.inMilliseconds;
  final step = math.max(minMs, totalMs / count);
  final stamps = <int>[for (var i = 0; i < count; i++) (i * step).round()];
  return FramePlan(stamps, math.max(totalMs, stamps.last + minMs));
}

/// Rough relative file size at a WebP quality, measured on sticker-like
/// content (q80 = 1.0). Only used to guess how far down the ladder to jump.
double _sizeFactor(double quality) {
  const points = <(double, double)>[
    (10, 0.24),
    (15, 0.27),
    (20, 0.30),
    (25, 0.34),
    (30, 0.38),
    (35, 0.42),
    (40, 0.46),
    (45, 0.50),
    (50, 0.55),
    (65, 0.72),
    (80, 1.0),
  ];
  if (quality <= points.first.$1) return points.first.$2;
  for (var i = 1; i < points.length; i++) {
    final (q1, f1) = points[i];
    if (quality <= q1) {
      final (q0, f0) = points[i - 1];
      return f0 + (f1 - f0) * (quality - q0) / (q1 - q0);
    }
  }
  return points.last.$2;
}

class StaticResult {
  const StaticResult(this.bytes, this.quality, this.attempts);

  final Uint8List bytes;
  final double quality;
  final int attempts;
}

/// Encodes a still sticker under the size target, highest quality first.
class StaticCompressor {
  StaticCompressor({
    this.encoder = const WebpEncoder(),
    this.targetBytes = WhatsAppStickerRules.staticTargetBytes,
  });

  final WebpEncoder encoder;
  final int targetBytes;

  static const qualities = [90.0, 80, 70, 60, 50, 40, 30, 20, 10];

  StaticResult compress(Uint8List rgba, int size) {
    for (var i = 0; i < qualities.length; i++) {
      final q = qualities[i].toDouble();
      final bytes = encoder.encodeStatic(
        rgba,
        size,
        size,
        EncodeSettings(quality: q, method: 6),
      );
      if (bytes.length <= targetBytes) return StaticResult(bytes, q, i + 1);
    }
    throw CompressionException('Could not fit a still sticker under target');
  }
}
