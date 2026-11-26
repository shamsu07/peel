import 'package:flutter_test/flutter_test.dart';
import 'package:peel/sticker_engine/webp_ffi.dart';

void main() {
  test('libwebp is compiled in and reports version 1.6.0', () {
    final v = peelWebpVersion();
    final version = '${(v >> 16) & 0xff}.${(v >> 8) & 0xff}.${v & 0xff}';
    expect(version, '1.6.0');
  });
}
