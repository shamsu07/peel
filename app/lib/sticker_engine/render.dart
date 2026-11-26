import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'whatsapp_rules.dart';

/// Draws with [paint] onto a transparent square canvas and returns
/// straight-alpha RGBA, ready for the WebP encoder.
///
/// This is the same drawing path the editor preview will use, so what the
/// user sees is what WhatsApp gets. Must run on the UI isolate.
Future<Uint8List> renderRgba(
  void Function(ui.Canvas canvas, ui.Size size) paint, {
  int size = WhatsAppStickerRules.canvasPx,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  paint(canvas, ui.Size(size.toDouble(), size.toDouble()));
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  try {
    final data = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

/// Shrinks a 512 px sticker (straight RGBA) into WhatsApp's 96x96 PNG tray
/// icon, keeping a little breathing room around it.
Future<Uint8List> trayPngFromRgba(Uint8List rgba, int size) async {
  final source = await _imageFromRgba(rgba, size);
  try {
    const tray = WhatsAppStickerRules.trayIconPx;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    const inset = 4.0;
    canvas.drawImageRect(
      source,
      ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      const ui.Rect.fromLTWH(inset, inset, tray - inset * 2, tray - inset * 2),
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(tray, tray);
    try {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      return png!.buffer.asUint8List();
    } finally {
      image.dispose();
      picture.dispose();
    }
  } finally {
    source.dispose();
  }
}

/// The 96x96 WhatsApp tray icon from any image file (e.g. a sticker PNG).
Future<Uint8List> trayPngFromImageFile(String path) async {
  final image = await decodeImage(await File(path).readAsBytes());
  try {
    final data = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    if (image.width != image.height) {
      throw ArgumentError('Tray source must be square');
    }
    return await trayPngFromRgba(data!.buffer.asUint8List(), image.width);
  } finally {
    image.dispose();
  }
}

/// Encodes straight RGBA as a PNG (for previews, sharing and copying).
Future<Uint8List> pngFromRgba(Uint8List rgba, int width, int height) async {
  final image = await imageFromRgba(rgba, width, height);
  try {
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    return png!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// Decodes any image file (PNG, JPEG, WebP) into a [ui.Image], at most
/// [maxSide] pixels on its long side when given (saves memory and time).
Future<ui.Image> decodeImage(Uint8List bytes, {int? maxSide}) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final codec = await ui.instantiateImageCodecWithSize(
    buffer,
    getTargetSize: (w, h) {
      if (maxSide == null || (w <= maxSide && h <= maxSide)) {
        return ui.TargetImageSize(width: w, height: h);
      }
      final s = maxSide / (w > h ? w : h);
      return ui.TargetImageSize(
        width: (w * s).round(),
        height: (h * s).round(),
      );
    },
  );
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

Future<ui.Image> imageFromRgba(Uint8List rgba, int width, int height) =>
    _imageFromRgba(rgba, width, height: height);

Future<ui.Image> _imageFromRgba(Uint8List rgba, int size, {int? height}) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: size,
    height: height ?? size,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await descriptor.instantiateCodec();
  final frame = await codec.getNextFrame();
  codec.dispose();
  descriptor.dispose();
  buffer.dispose();
  return frame.image;
}
