/// Raw FFI bindings to native/peel_webp.c (libwebp v1.6.0), compiled by
/// hook/build.dart. Use [WebpEncoder] instead of calling these directly.
@DefaultAsset('package:peel/sticker_engine/webp_ffi.dart')
library;

import 'dart:ffi';

@Native<Int32 Function()>(symbol: 'peel_webp_version')
external int peelWebpVersion();

@Native<Void Function(Pointer<Void>)>(symbol: 'peel_free')
external void peelFree(Pointer<Void> ptr);

@Native<
  Int32 Function(
    Pointer<Uint8>,
    Int32,
    Int32,
    Int32,
    Float,
    Int32,
    Int32,
    Pointer<Pointer<Uint8>>,
    Pointer<Size>,
  )
>(symbol: 'peel_encode_static')
external int peelEncodeStatic(
  Pointer<Uint8> rgba,
  int width,
  int height,
  int stride,
  double quality,
  int method,
  int lossless,
  Pointer<Pointer<Uint8>> out,
  Pointer<Size> outSize,
);

@Native<Pointer<Void> Function(Int32, Int32, Int32, Int32, Int32)>(
  symbol: 'peel_anim_new',
)
external Pointer<Void> peelAnimNew(
  int width,
  int height,
  int kmin,
  int kmax,
  int allowMixed,
);

@Native<
  Int32 Function(
    Pointer<Void>,
    Pointer<Uint8>,
    Int32,
    Int32,
    Int32,
    Int32,
    Float,
    Int32,
    Int32,
  )
>(symbol: 'peel_anim_add')
external int peelAnimAdd(
  Pointer<Void> encoder,
  Pointer<Uint8> rgba,
  int width,
  int height,
  int stride,
  int timestampMs,
  double quality,
  int method,
  int lossless,
);

@Native<
  Int32 Function(Pointer<Void>, Int32, Pointer<Pointer<Uint8>>, Pointer<Size>)
>(symbol: 'peel_anim_assemble')
external int peelAnimAssemble(
  Pointer<Void> encoder,
  int endTimestampMs,
  Pointer<Pointer<Uint8>> out,
  Pointer<Size> outSize,
);

@Native<Void Function(Pointer<Void>)>(symbol: 'peel_anim_delete')
external void peelAnimDelete(Pointer<Void> encoder);
