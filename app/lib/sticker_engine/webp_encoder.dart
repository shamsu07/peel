import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'webp_ffi.dart';

class WebpEncodeException implements Exception {
  WebpEncodeException(this.code, this.stage);

  final int code;
  final String stage;

  @override
  String toString() => 'WebpEncodeException($stage failed with code $code)';
}

class EncodeSettings {
  const EncodeSettings({
    required this.quality,
    this.method = 4,
    this.lossless = false,
  });

  /// 0–100. Lower is smaller and blurrier.
  final double quality;

  /// 0 (fast) – 6 (slow, smaller). 4 is libwebp's balanced default.
  final int method;
  final bool lossless;
}

/// Encodes packed RGBA pixels (4 bytes per pixel, no row padding) to WebP.
class WebpEncoder {
  const WebpEncoder();

  Uint8List encodeStatic(
    Uint8List rgba,
    int width,
    int height,
    EncodeSettings settings,
  ) {
    _checkLength(rgba, width, height);
    return using((arena) {
      final input = arena<Uint8>(rgba.length);
      input.asTypedList(rgba.length).setAll(0, rgba);
      final out = arena<Pointer<Uint8>>();
      final outSize = arena<Size>();
      final rc = peelEncodeStatic(
        input,
        width,
        height,
        width * 4,
        settings.quality,
        settings.method,
        settings.lossless ? 1 : 0,
        out,
        outSize,
      );
      if (rc != 0) throw WebpEncodeException(rc, 'static encode');
      return _takeBytes(out.value, outSize.value);
    });
  }

  AnimatedWebpWriter startAnimation(
    int width,
    int height,
    EncodeSettings settings,
  ) => AnimatedWebpWriter._(width, height, settings);
}

/// Streams frames into an animated WebP so only one frame is in memory at
/// a time. Always call [finish] or [dispose].
class AnimatedWebpWriter {
  AnimatedWebpWriter._(this.width, this.height, this.settings)
    : _encoder = peelAnimNew(width, height, _kMin, _kMax, 0),
      _frame = malloc<Uint8>(width * height * 4) {
    if (_encoder == nullptr) {
      malloc.free(_frame);
      throw WebpEncodeException(-1, 'animation start');
    }
  }

  // Key frame spacing. Wider spacing gives smaller files; these match
  // libwebp's gif2webp defaults for lossless and work well for stickers.
  static const _kMin = 9;
  static const _kMax = 17;

  final int width;
  final int height;
  final EncodeSettings settings;

  final Pointer<Void> _encoder;
  final Pointer<Uint8> _frame;
  bool _closed = false;
  int frameCount = 0;

  void addFrame(Uint8List rgba, int timestampMs) {
    if (_closed) throw StateError('Writer already closed');
    _checkLength(rgba, width, height);
    _frame.asTypedList(rgba.length).setAll(0, rgba);
    final rc = peelAnimAdd(
      _encoder,
      _frame,
      width,
      height,
      width * 4,
      timestampMs,
      settings.quality,
      settings.method,
      settings.lossless ? 1 : 0,
    );
    if (rc != 0) {
      dispose();
      throw WebpEncodeException(rc, 'animation frame $frameCount');
    }
    frameCount++;
  }

  /// Ends the animation at [endTimestampMs] and returns the file bytes.
  Uint8List finish(int endTimestampMs) {
    if (_closed) throw StateError('Writer already closed');
    try {
      return using((arena) {
        final out = arena<Pointer<Uint8>>();
        final outSize = arena<Size>();
        final rc = peelAnimAssemble(_encoder, endTimestampMs, out, outSize);
        if (rc != 0) throw WebpEncodeException(rc, 'animation assemble');
        return _takeBytes(out.value, outSize.value);
      });
    } finally {
      dispose();
    }
  }

  void dispose() {
    if (_closed) return;
    _closed = true;
    peelAnimDelete(_encoder);
    malloc.free(_frame);
  }
}

void _checkLength(Uint8List rgba, int width, int height) {
  if (width <= 0 || height <= 0 || rgba.length != width * height * 4) {
    throw ArgumentError(
      'Expected ${width * height * 4} RGBA bytes for ${width}x$height, '
      'got ${rgba.length}',
    );
  }
}

Uint8List _takeBytes(Pointer<Uint8> ptr, int length) {
  final copy = Uint8List.fromList(ptr.asTypedList(length));
  peelFree(ptr.cast());
  return copy;
}
