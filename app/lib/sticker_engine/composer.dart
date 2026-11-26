import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'caption.dart';
import 'render.dart';
import 'whatsapp_rules.dart';

enum CutMode { cutout, whole }

/// Everything that makes a photo sticker. Painted the same way for the
/// editor preview and the exported 512 px file, so they always match.
class PhotoComposition {
  const PhotoComposition({
    required this.original,
    this.cutout,
    this.mode = CutMode.cutout,
    this.whiteEdge = true,
    this.caption,
    this.zoom = 1,
    this.pan = ui.Offset.zero,
    this.edgedCutout,
    this.edgePad = 0,
  });

  /// The cut-out with its white edge already drawn (see [buildEdged]), so
  /// the preview draws one image per frame instead of 25.
  final ui.Image? edgedCutout;

  /// Width of that edge, in cut-out pixels.
  final double edgePad;

  final ui.Image original;

  /// Pinch zoom, 1 (fit) to 4.
  final double zoom;

  /// Drag position. Whole photo: where the square's centre sits, as a
  /// fraction of the photo's size from its centre. Cut-out: how far the
  /// subject is moved, as a fraction of the sticker's size.
  final ui.Offset pan;

  static const maxZoom = 4.0;

  /// The subject on a transparent background, if one was found.
  final ui.Image? cutout;
  final CutMode mode;
  final bool whiteEdge;
  final Caption? caption;

  bool get usesCutout => mode == CutMode.cutout && cutout != null;

  PhotoComposition copyWith({
    CutMode? mode,
    bool? whiteEdge,
    Caption? caption,
    bool clearCaption = false,
    double? zoom,
    ui.Offset? pan,
  }) {
    final nextMode = mode ?? this.mode;
    // Switching between cut-out and whole photo starts framing afresh.
    final reset = nextMode != this.mode;
    final nextZoom = reset ? 1.0 : (zoom ?? this.zoom).clamp(1.0, maxZoom);
    return PhotoComposition(
      original: original,
      cutout: cutout,
      edgedCutout: edgedCutout,
      edgePad: edgePad,
      mode: nextMode,
      whiteEdge: whiteEdge ?? this.whiteEdge,
      caption: clearCaption ? null : (caption ?? this.caption),
      zoom: nextZoom,
      pan: reset
          ? ui.Offset.zero
          : _clampPan(pan ?? this.pan, nextMode, nextZoom),
    );
  }

  /// Keeps the framing inside sensible bounds.
  ui.Offset _clampPan(ui.Offset p, CutMode m, double z) {
    if (m == CutMode.cutout && cutout != null) {
      return ui.Offset(p.dx.clamp(-0.45, 0.45), p.dy.clamp(-0.45, 0.45));
    }
    final w = original.width.toDouble();
    final h = original.height.toDouble();
    final side = math.min(w, h) / z;
    final maxX = (w - side) / 2 / w;
    final maxY = (h - side) / 2 / h;
    return ui.Offset(p.dx.clamp(-maxX, maxX), p.dy.clamp(-maxY, maxY));
  }

  /// Applies a drag of [delta] preview pixels on a preview [previewSide]
  /// wide, so the content follows the finger.
  PhotoComposition dragBy(ui.Offset delta, double previewSide) {
    if (usesCutout) {
      return copyWith(pan: pan + delta / previewSide);
    }
    final w = original.width.toDouble();
    final h = original.height.toDouble();
    final srcSide = math.min(w, h) / zoom;
    final perPx = srcSide / previewSide;
    return copyWith(
      pan: pan - ui.Offset(delta.dx * perPx / w, delta.dy * perPx / h),
    );
  }

  void paint(ui.Canvas canvas, ui.Size size) {
    final k = size.width / WhatsAppStickerRules.canvasPx;
    final edge = WhatsAppStickerRules.recommendedOutlinePx * k;
    final paint = ui.Paint()..filterQuality = ui.FilterQuality.high;

    if (usesCutout) {
      final image = cutout!;
      // Room for the white edge plus a small margin.
      final box = ui.Rect.fromLTWH(
        0,
        0,
        size.width,
        size.height,
      ).deflate(edge + 14 * k);
      final fitted = _fit(image, box);
      final dst = ui.Rect.fromCenter(
        center:
            fitted.center +
            ui.Offset(pan.dx * size.width, pan.dy * size.height),
        width: fitted.width * zoom,
        height: fitted.height * zoom,
      );
      final src = ui.Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      );
      final edged = edgedCutout;
      if (whiteEdge && edged != null) {
        final grow = edgePad * dst.width / image.width;
        canvas.drawImageRect(
          edged,
          ui.Rect.fromLTWH(
            0,
            0,
            edged.width.toDouble(),
            edged.height.toDouble(),
          ),
          dst.inflate(grow),
          paint,
        );
        caption?.paint(canvas, size);
        return;
      }
      if (whiteEdge) {
        // The die-cut edge: the subject's shape, drawn in white, nudged in
        // every direction around it.
        final white = ui.Paint()
          ..filterQuality = ui.FilterQuality.medium
          ..colorFilter = const ui.ColorFilter.mode(
            ui.Color(0xFFFFFFFF),
            ui.BlendMode.srcIn,
          );
        const steps = 24;
        for (var i = 0; i < steps; i++) {
          final a = 2 * math.pi * i / steps;
          canvas.drawImageRect(
            image,
            src,
            dst.shift(ui.Offset(math.cos(a) * edge, math.sin(a) * edge)),
            white,
          );
        }
      }
      canvas.drawImageRect(image, src, dst, paint);
    } else {
      // The whole photo as a rounded square.
      final image = original;
      final inset = whiteEdge ? edge + 6 * k : 6 * k;
      final rect = ui.Rect.fromLTWH(
        0,
        0,
        size.width,
        size.height,
      ).deflate(inset);
      final rrect = ui.RRect.fromRectAndRadius(
        rect,
        ui.Radius.circular(56 * k),
      );
      if (whiteEdge) {
        canvas.drawRRect(
          rrect.inflate(edge),
          ui.Paint()..color = const ui.Color(0xFFFFFFFF),
        );
      }
      canvas.save();
      canvas.clipRRect(rrect);
      final side = math.min(image.width, image.height).toDouble() / zoom;
      final src = ui.Rect.fromCenter(
        center: ui.Offset(
          image.width / 2 + pan.dx * image.width,
          image.height / 2 + pan.dy * image.height,
        ),
        width: side,
        height: side,
      );
      canvas.drawImageRect(image, src, rect, paint);
      canvas.restore();
    }

    caption?.paint(canvas, size);
  }

  static ui.Rect _fit(ui.Image image, ui.Rect box) {
    final s = math.min(box.width / image.width, box.height / image.height);
    final w = image.width * s;
    final h = image.height * s;
    return ui.Rect.fromLTWH(
      box.left + (box.width - w) / 2,
      box.top + (box.height - h) / 2,
      w,
      h,
    );
  }

  /// Draws the cut-out with its white die-cut edge into one image, once.
  /// The edge is sized so it is WhatsApp's 8 px on the 512 px sticker when
  /// the subject is shown at its normal size.
  static Future<(ui.Image, double)> buildEdged(ui.Image cutout) async {
    const canvas = WhatsAppStickerRules.canvasPx;
    const outline = WhatsAppStickerRules.recommendedOutlinePx;
    const box = canvas - 2 * (outline + 14);
    final fit = math.min(box / cutout.width, box / cutout.height);
    final pad = outline / fit;
    final w = cutout.width + pad * 2;
    final h = cutout.height + pad * 2;
    final recorder = ui.PictureRecorder();
    final c = ui.Canvas(recorder);
    final white = ui.Paint()
      ..colorFilter = const ui.ColorFilter.mode(
        ui.Color(0xFFFFFFFF),
        ui.BlendMode.srcIn,
      );
    const steps = 24;
    for (var i = 0; i < steps; i++) {
      final a = 2 * math.pi * i / steps;
      c.drawImage(
        cutout,
        ui.Offset(pad + math.cos(a) * pad, pad + math.sin(a) * pad),
        white,
      );
    }
    c.drawImage(cutout, ui.Offset(pad, pad), ui.Paint());
    final picture = recorder.endRecording();
    final image = await picture.toImage(w.ceil(), h.ceil());
    picture.dispose();
    return (image, pad);
  }

  /// The finished sticker as straight RGBA, 512 x 512.
  Future<Uint8List> renderRgba() async {
    if (caption != null) await Caption.ensureFontsLoaded();
    return renderRgbaWith(paint);
  }
}

/// Paint helper kept separate so tests can render without fonts.
Future<Uint8List> renderRgbaWith(void Function(ui.Canvas, ui.Size) painter) =>
    renderRgba(painter);

/// The frame around a video sticker (spec: rounded square, white edge) and
/// its caption, as two layers that are blended into every frame.
class VideoFrameStyle {
  const VideoFrameStyle({this.whiteEdge = true, this.caption});

  final bool whiteEdge;
  final Caption? caption;

  static const radius = 60.0;
  static const edgeWidth = 11.0;

  /// Draws the white rim and caption over a transparent canvas.
  void paintOverlay(ui.Canvas canvas, ui.Size size) {
    final k = size.width / WhatsAppStickerRules.canvasPx;
    if (whiteEdge) {
      final outer = ui.RRect.fromRectAndRadius(
        ui.Offset.zero & size,
        ui.Radius.circular(radius * k),
      );
      final inner = outer.deflate(edgeWidth * k);
      canvas.drawDRRect(
        outer,
        inner,
        ui.Paint()..color = const ui.Color(0xFFFFFFFF),
      );
    }
    caption?.paint(canvas, size);
  }

  /// The overlay for the sticker's MP4: the white edge and caption, plus
  /// white corners, since a video can't be transparent.
  void paintVideoOverlay(ui.Canvas canvas, ui.Size size) {
    final k = size.width / WhatsAppStickerRules.canvasPx;
    final corners = ui.Path()
      ..fillType = ui.PathFillType.evenOdd
      ..addRect(ui.Offset.zero & size)
      ..addRRect(
        ui.RRect.fromRectAndRadius(
          ui.Offset.zero & size,
          ui.Radius.circular(radius * k),
        ),
      );
    canvas.drawPath(corners, ui.Paint()..color = const ui.Color(0xFFFFFFFF));
    paintOverlay(canvas, size);
  }

  /// Draws the area the video shows through (white = visible).
  void paintMask(ui.Canvas canvas, ui.Size size) {
    final k = size.width / WhatsAppStickerRules.canvasPx;
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Offset.zero & size,
        ui.Radius.circular(radius * k),
      ),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );
  }

  /// Renders both layers at sticker size. Runs on the UI isolate; the
  /// result is plain bytes that a background isolate can blend.
  Future<VideoLayers> renderLayers() async {
    if (caption != null) await Caption.ensureFontsLoaded();
    return VideoLayers(
      overlay: await renderRgba(paintOverlay),
      mask: await renderRgba(paintMask),
    );
  }
}

class VideoLayers {
  const VideoLayers({required this.overlay, required this.mask});

  /// RGBA, straight alpha: white rim and caption.
  final Uint8List overlay;

  /// RGBA: alpha says where the video shows.
  final Uint8List mask;
}

/// Blends one opaque video frame with the mask and overlay, in place.
/// Pure Dart so it can run on a background isolate.
void blendVideoFrame(Uint8List frame, VideoLayers layers) {
  final o = layers.overlay;
  final m = layers.mask;
  for (var i = 0; i < frame.length; i += 4) {
    final fa = m[i + 3];
    final oa = o[i + 3];
    if (oa == 0) {
      frame[i + 3] = fa;
      continue;
    }
    if (oa == 255) {
      frame[i] = o[i];
      frame[i + 1] = o[i + 1];
      frame[i + 2] = o[i + 2];
      frame[i + 3] = 255;
      continue;
    }
    // Overlay "over" the masked frame, straight alpha.
    final outA = oa + (fa * (255 - oa)) ~/ 255;
    if (outA == 0) {
      frame[i + 3] = 0;
      continue;
    }
    for (var c = 0; c < 3; c++) {
      final v =
          (o[i + c] * oa * 255 + frame[i + c] * fa * (255 - oa)) ~/
          (outA * 255);
      frame[i + c] = v > 255 ? 255 : v;
    }
    frame[i + 3] = outA;
  }
}
