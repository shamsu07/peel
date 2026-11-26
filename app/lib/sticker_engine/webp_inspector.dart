import 'dart:typed_data';

/// What a WebP file contains, read from its RIFF chunks without decoding.
class WebpInfo {
  const WebpInfo({
    required this.width,
    required this.height,
    required this.animated,
    required this.hasAlpha,
    required this.frameDurationsMs,
    required this.byteLength,
  });

  final int width;
  final int height;
  final bool animated;
  final bool hasAlpha;

  /// One entry per frame for animations; empty for still images.
  final List<int> frameDurationsMs;
  final int byteLength;

  int get frameCount => animated ? frameDurationsMs.length : 1;

  int get totalDurationMs => frameDurationsMs.fold(0, (sum, d) => sum + d);
}

class WebpFormatException implements Exception {
  WebpFormatException(this.message);

  final String message;

  @override
  String toString() => 'WebpFormatException: $message';
}

/// Reads the header and chunk list of a WebP file.
///
/// Throws [WebpFormatException] if the bytes are not a well-formed WebP.
WebpInfo inspectWebp(Uint8List bytes) {
  if (bytes.length < 20) throw WebpFormatException('File too short');
  final data = ByteData.sublistView(bytes);

  if (_fourcc(bytes, 0) != 'RIFF' || _fourcc(bytes, 8) != 'WEBP') {
    throw WebpFormatException('Not a RIFF/WEBP file');
  }
  final riffSize = data.getUint32(4, Endian.little);
  if (riffSize + 8 > bytes.length) {
    throw WebpFormatException('RIFF size larger than file');
  }

  int? width;
  int? height;
  var animated = false;
  var hasAlpha = false;
  var sawVp8x = false;
  final durations = <int>[];

  var offset = 12;
  final end = riffSize + 8;
  while (offset + 8 <= end) {
    final tag = _fourcc(bytes, offset);
    final size = data.getUint32(offset + 4, Endian.little);
    final payload = offset + 8;
    if (payload + size > end) {
      throw WebpFormatException('Chunk $tag runs past end of file');
    }

    switch (tag) {
      case 'VP8X':
        if (size < 10) throw WebpFormatException('VP8X chunk too short');
        sawVp8x = true;
        final flags = bytes[payload];
        animated = flags & 0x02 != 0;
        hasAlpha = flags & 0x10 != 0;
        width = 1 + _u24(bytes, payload + 4);
        height = 1 + _u24(bytes, payload + 7);
      case 'VP8 ':
        if (!sawVp8x) {
          if (size < 10 ||
              bytes[payload + 3] != 0x9d ||
              bytes[payload + 4] != 0x01 ||
              bytes[payload + 5] != 0x2a) {
            throw WebpFormatException('Bad VP8 frame header');
          }
          width = data.getUint16(payload + 6, Endian.little) & 0x3fff;
          height = data.getUint16(payload + 8, Endian.little) & 0x3fff;
        }
      case 'VP8L':
        if (!sawVp8x) {
          if (size < 5 || bytes[payload] != 0x2f) {
            throw WebpFormatException('Bad VP8L header');
          }
          final bits = data.getUint32(payload + 1, Endian.little);
          width = (bits & 0x3fff) + 1;
          height = ((bits >> 14) & 0x3fff) + 1;
          hasAlpha = (bits >> 28) & 1 == 1;
        }
      case 'ALPH':
        hasAlpha = true;
      case 'ANMF':
        if (size < 16) throw WebpFormatException('ANMF chunk too short');
        durations.add(_u24(bytes, payload + 12));
    }

    offset = payload + size + (size.isOdd ? 1 : 0);
  }

  if (width == null || height == null) {
    throw WebpFormatException('No image data found');
  }
  if (animated && durations.isEmpty) {
    throw WebpFormatException('Animated flag set but no frames found');
  }

  return WebpInfo(
    width: width,
    height: height,
    animated: animated,
    hasAlpha: hasAlpha,
    frameDurationsMs: List.unmodifiable(durations),
    byteLength: bytes.length,
  );
}

String _fourcc(Uint8List b, int at) => String.fromCharCodes(b, at, at + 4);

int _u24(Uint8List b, int at) => b[at] | (b[at + 1] << 8) | (b[at + 2] << 16);
