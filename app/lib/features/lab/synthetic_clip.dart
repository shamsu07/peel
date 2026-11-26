import 'dart:math' as math;
import 'dart:typed_data';

import '../../sticker_engine/compressor.dart';

/// A made-up moving sticker for testing the encoder without real video:
/// a round cut-out subject that drifts around a transparent canvas.
///
/// [detailed] fills the subject with camera-like texture and grain, which is
/// close to the worst case for file size. Otherwise it is flat cartoon art.
class SyntheticClip implements FrameSource {
  SyntheticClip({
    required this.duration,
    required this.detailed,
    this.size = 512,
  });

  @override
  final Duration duration;
  @override
  final int size;
  final bool detailed;

  @override
  Future<Uint8List> frameAt(Duration t) async => render(t.inMilliseconds);

  Uint8List render(int ms) {
    final s = size;
    final out = Uint8List(s * s * 4);
    final phase = ms / 1000.0;
    final cx = s / 2 + math.sin(phase * 2.1) * s * 0.12;
    final cy = s / 2 + math.cos(phase * 1.7) * s * 0.08;
    final radius = s * 0.36;
    final r2 = radius * radius;
    final shift = (phase * 90).toInt();
    var seed = (ms * 2654435761) & 0x7fffffff;

    for (var y = 0; y < s; y++) {
      final dy = y - cy;
      final dy2 = dy * dy;
      for (var x = 0; x < s; x++) {
        final dx = x - cx;
        final d2 = dx * dx + dy2;
        if (d2 > r2) continue; // Transparent outside the subject.
        final i = (y * s + x) * 4;

        if (detailed) {
          final texture = (((x + shift) * 3) ^ (y * 5)) & 63;
          seed = (seed * 1103515245 + 12345) & 0x7fffffff;
          final grain = (seed >> 16) & 31;
          out[i] = math.min(255, (x * 200 ~/ s) + texture + grain);
          out[i + 1] = math.min(255, (y * 180 ~/ s) + (texture >> 1) + grain);
          out[i + 2] = math.min(255, 120 + ((x + y + shift) & 63) + grain);
        } else {
          // Flat face: lilac body, two eyes, a mouth.
          final ex = (dx.abs() - radius * 0.35).abs();
          final ey = dy + radius * 0.15;
          final eye = ex * ex + ey * ey < (radius * 0.09) * (radius * 0.09);
          final mouth =
              dy > radius * 0.25 &&
              dy < radius * 0.32 &&
              dx.abs() < radius * 0.3;
          if (eye || mouth) {
            out[i] = 0x4B;
            out[i + 1] = 0x2A;
            out[i + 2] = 0x9B;
          } else {
            out[i] = 0xDC;
            out[i + 1] = 0xCB;
            out[i + 2] = 0xFF;
          }
        }
        out[i + 3] = 255;
      }
    }
    return out;
  }
}
