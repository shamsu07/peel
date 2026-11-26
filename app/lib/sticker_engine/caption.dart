import 'dart:ui' as ui;

import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../core/design/tokens.dart';
import '../core/design/typography.dart';

/// Sticker-style fonts for captions (spec P0-10).
enum CaptionFont {
  bubble('Bubble'),
  comic('Comic'),
  round('Round'),
  classy('Classy');

  const CaptionFont(this.label);

  final String label;

  bool get uppercase => this == CaptionFont.comic;

  TextStyle style({required double size, required Color color}) {
    final base = TextStyle(fontSize: size, color: color, height: 1.0);
    if (!PeelType.useBrandFonts) {
      return base.copyWith(
        fontWeight: FontWeight.w900,
        fontStyle: this == classy ? FontStyle.italic : FontStyle.normal,
      );
    }
    return switch (this) {
      CaptionFont.bubble => GoogleFonts.titanOne(textStyle: base),
      CaptionFont.comic => GoogleFonts.luckiestGuy(textStyle: base),
      CaptionFont.round => GoogleFonts.baloo2(
        textStyle: base.copyWith(fontWeight: FontWeight.w800),
      ),
      CaptionFont.classy => GoogleFonts.instrumentSerif(
        textStyle: base.copyWith(fontStyle: FontStyle.italic),
      ),
    };
  }
}

/// White outline letters, or text on a bright block.
enum CaptionLook { outline, block }

/// How big the text starts; long text still shrinks to fit the sticker.
enum CaptionSize {
  regular(76),
  big(100);

  const CaptionSize(this.startPx);

  /// Starting font size on a 512 px sticker.
  final double startPx;
}

class Caption {
  const Caption({
    required this.text,
    this.font = CaptionFont.bubble,
    this.color = const Color(0xFFFFD60A),
    this.look = CaptionLook.outline,
    this.centerY = 0.84,
    this.size = CaptionSize.regular,
  });

  final String text;
  final CaptionFont font;
  final Color color;
  final CaptionLook look;

  /// Vertical centre of the caption, 0 (top) – 1 (bottom).
  final double centerY;
  final CaptionSize size;

  bool get isEmpty => text.trim().isEmpty;

  Caption copyWith({
    String? text,
    CaptionFont? font,
    Color? color,
    CaptionLook? look,
    double? centerY,
    CaptionSize? size,
  }) => Caption(
    text: text ?? this.text,
    font: font ?? this.font,
    color: color ?? this.color,
    look: look ?? this.look,
    centerY: centerY ?? this.centerY,
    size: size ?? this.size,
  );

  /// Ink for text drawn on a [color] block: dark on light colours.
  Color get blockInk =>
      color.computeLuminance() > 0.4 ? PeelColors.onPastel : PeelColors.white;

  /// Outline colour: white, or black when the letters are white.
  Color get edge =>
      color.toARGB32() == 0xFFFFFFFF ? PeelColors.onPastel : PeelColors.white;

  /// Makes sure the caption fonts are downloaded before painting off-screen.
  static Future<void> ensureFontsLoaded() async {
    if (!PeelType.useBrandFonts) return;
    for (final f in CaptionFont.values) {
      f.style(size: 10, color: PeelColors.onPastel);
    }
    await GoogleFonts.pendingFonts();
    clearCache(); // Anything recorded before used a stand-in font.
  }

  /// Recorded captions, newest last. Laying out a caption takes about ten
  /// text layouts, and previews repaint it on every drag frame, so each
  /// look is drawn once and replayed.
  static final _cache = <String, ui.Picture>{};
  static const _cacheSize = 12;

  /// Drops recorded captions, e.g. once fonts have loaded.
  static void clearCache() {
    for (final p in _cache.values) {
      p.dispose();
    }
    _cache.clear();
  }

  /// Paints the caption across [size], scaled for a 512 px sticker.
  void paint(ui.Canvas canvas, ui.Size size) {
    if (isEmpty) return;
    final key =
        '$text|${font.name}|${color.toARGB32()}|${look.name}|$centerY|'
        '${this.size.name}|'
        '${size.width}x${size.height}';
    var picture = _cache.remove(key);
    if (picture == null) {
      final recorder = ui.PictureRecorder();
      _draw(ui.Canvas(recorder), size);
      picture = recorder.endRecording();
      if (_cache.length >= _cacheSize) {
        final oldest = _cache.keys.first;
        _cache.remove(oldest)!.dispose();
      }
    }
    _cache[key] = picture; // Most recently used goes last.
    canvas.drawPicture(picture);
  }

  void _draw(ui.Canvas canvas, ui.Size size) {
    final k = size.width / 512;
    final shown = font.uppercase ? text.toUpperCase() : text;
    final maxWidth = size.width * 0.9;

    TextPainter layout(TextStyle style) => TextPainter(
      text: TextSpan(text: shown, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);

    // Shrink long captions so they stay inside the sticker.
    var fontSize = this.size.startPx * k;
    var probe = layout(font.style(size: fontSize, color: color));
    while (probe.width > maxWidth * 0.98 && fontSize > 34 * k) {
      fontSize -= 4 * k;
      probe.dispose();
      probe = layout(font.style(size: fontSize, color: color));
    }

    final center = ui.Offset(size.width / 2, size.height * centerY);
    final topLeft = center - ui.Offset(probe.width / 2, probe.height / 2);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.06);
    canvas.translate(-center.dx, -center.dy);

    if (look == CaptionLook.block) {
      final pad = ui.Offset(22 * k, 12 * k);
      final rect = ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(
          topLeft.dx - pad.dx,
          topLeft.dy - pad.dy,
          probe.width + pad.dx * 2,
          probe.height + pad.dy * 2,
        ),
        ui.Radius.circular(22 * k),
      );
      canvas.drawRRect(rect.inflate(7 * k), ui.Paint()..color = edge);
      canvas.drawRRect(rect, ui.Paint()..color = color);
      layout(font.style(size: fontSize, color: blockInk))
        ..paint(canvas, topLeft)
        ..dispose();
    } else {
      final stroke = font
          .style(size: fontSize, color: edge)
          .copyWith(
            color: null,
            foreground: ui.Paint()
              ..style = ui.PaintingStyle.stroke
              ..strokeWidth = 14 * k
              ..strokeJoin = ui.StrokeJoin.round
              ..color = edge,
          );
      layout(stroke)
        ..paint(canvas, topLeft)
        ..dispose();
      // The probe was laid out with the fill style at this size.
      probe.paint(canvas, topLeft);
    }
    probe.dispose();
    canvas.restore();
  }
}

/// Paints a [Caption] over a widget, e.g. the video preview.
class CaptionPainter extends CustomPainter {
  const CaptionPainter(this.caption);

  final Caption caption;

  @override
  void paint(Canvas canvas, Size size) => caption.paint(canvas, size);

  @override
  bool shouldRepaint(CaptionPainter old) => old.caption != caption;
}
