import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

import '../core/design/tokens.dart';
import '../core/design/typography.dart';
import '../sticker_engine/background.dart';
import '../sticker_engine/render.dart';
import '../sticker_engine/sticker_check.dart';
import '../sticker_engine/webp_encoder.dart';
import 'pack_store.dart';

/// The two "Bonus" stickers from the design canvas ("It’s ready."): a mint
/// "okay!" pill and a sky "haha" block, in the sticker serif italic.
class DrawnBonusSource implements BonusSource {
  DrawnBonusSource({this.encoder = const WebpEncoder()});

  final WebpEncoder encoder;
  final _cache = <StickerKind, Future<List<BonusSticker>>>{};

  static const _designs = [
    _BonusDesign(
      id: 'okay',
      text: 'okay!',
      pair: PeelPairs.mint,
      pill: true,
      tilt: -0.14,
      emojis: ['👍', '👌'],
      alt: 'Mint sticker with text that reads "okay!"',
    ),
    _BonusDesign(
      id: 'haha',
      text: 'haha',
      pair: PeelPairs.sky,
      pill: false,
      tilt: 0.12,
      emojis: ['😂', '🤣'],
      alt: 'Blue sticker with text that reads "haha"',
    ),
  ];

  @override
  Future<List<BonusSticker>> bonusFor(StickerKind kind) =>
      _cache[kind] ??= _make(kind);

  Future<List<BonusSticker>> _make(StickerKind kind) async {
    final cache = await _cacheDir();
    String? family;
    final out = <BonusSticker>[];
    for (final d in _designs) {
      final name =
          'bonus_${d.id}_${kind == StickerKind.still ? 'still' : 'moving'}.webp';
      final cached = cache == null ? null : File('${cache.path}/$name');
      Uint8List bytes;
      if (cached != null && await cached.exists()) {
        bytes = await cached.readAsBytes();
      } else {
        family ??= await _serifFamily();
        bytes = kind == StickerKind.still
            ? await _still(d, family)
            : await _moving(d, family);
        if (cached != null) await cached.writeAsBytes(bytes, flush: true);
      }
      out.add(
        BonusSticker(
          fileName: name,
          bytes: bytes,
          emojis: d.emojis,
          accessibilityText: d.alt,
        ),
      );
    }
    return out;
  }

  /// Bonus stickers are made once and kept on disk (versioned folder, so a
  /// design change makes new ones). Null where there's no app folder (tests).
  static Future<Directory?> _cacheDir() async {
    try {
      final support = await getApplicationSupportDirectory();
      final dir = Directory('${support.path}/bonus_v2');
      await dir.create(recursive: true);
      return dir;
    } catch (_) {
      return null;
    }
  }

  /// Loads Instrument Serif (when brand fonts are on) and returns its family.
  static Future<String?> _serifFamily() async {
    if (!PeelType.useBrandFonts) return null;
    try {
      final family = GoogleFonts.instrumentSerif(fontStyle: ui.FontStyle.italic)
          .fontFamily;
      await GoogleFonts.pendingFonts();
      return family;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List> _still(_BonusDesign d, String? family) async {
    final rgba = await renderRgba((c, s) => _paint(c, s, d, family, 0));
    return (await encodeStillInBackground(rgba)).bytes;
  }

  /// A gentle wiggle, 8 frames over 0.8 s. The first frame is the full
  /// sticker, as WhatsApp requires.
  Future<Uint8List> _moving(_BonusDesign d, String? family) async {
    const frames = 8;
    final rgba = <Uint8List>[
      for (var i = 0; i < frames; i++)
        await renderRgba(
          (c, s) => _paint(
            c,
            s,
            d,
            family,
            math.sin(i / frames * math.pi * 2) * 0.07,
          ),
        ),
    ];
    // Drawing needs the UI thread; encoding doesn't, so it runs off it.
    return Isolate.run(() => encodeWiggle(rgba));
  }

  static void _paint(
    ui.Canvas canvas,
    ui.Size size,
    _BonusDesign d,
    String? family,
    double wiggle,
  ) {
    final center = size.center(ui.Offset.zero);
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(d.tilt + wiggle)
      ..translate(-center.dx, -center.dy);

    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: ui.TextAlign.center,
              fontFamily: family,
              fontStyle: ui.FontStyle.italic,
              fontSize: 150,
              height: 1.0,
            ),
          )
          ..pushStyle(ui.TextStyle(color: d.pair.ink))
          ..addText(d.text);
    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 460));
    final textWidth = paragraph.longestLine;

    final block = ui.RRect.fromRectAndRadius(
      ui.Rect.fromCenter(
        center: center,
        width: math.min(470, textWidth + 90),
        height: paragraph.height + 56,
      ),
      ui.Radius.circular(d.pill ? 200 : 60),
    );
    // White die-cut edge, a soft shadow, then the colour block.
    canvas.drawRRect(
      block.inflate(18).shift(const ui.Offset(0, 10)),
      ui.Paint()
        ..color = const ui.Color(0x29111113)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 12),
    );
    canvas.drawRRect(block.inflate(18), ui.Paint()..color = PeelColors.surface);
    canvas.drawRRect(block, ui.Paint()..color = d.pair.fill);
    canvas.drawParagraph(
      paragraph,
      ui.Offset(center.dx - 230, center.dy - paragraph.height / 2 - 4),
    );
    canvas.restore();
  }
}

class _BonusDesign {
  const _BonusDesign({
    required this.id,
    required this.text,
    required this.pair,
    required this.pill,
    required this.tilt,
    required this.emojis,
    required this.alt,
  });

  final String id;
  final String text;
  final InkPair pair;
  final bool pill;
  final double tilt;
  final List<String> emojis;
  final String alt;
}

/// Encodes the 8 wiggle frames (100 ms each) as an animated WebP. Top-level
/// so it can run on a background isolate.
Uint8List encodeWiggle(List<Uint8List> frames) {
  const frameMs = 100;
  final writer = const WebpEncoder().startAnimation(
    512,
    512,
    const EncodeSettings(quality: 75),
  );
  try {
    for (var i = 0; i < frames.length; i++) {
      writer.addFrame(frames[i], i * frameMs);
    }
    return writer.finish(frames.length * frameMs);
  } catch (_) {
    writer.dispose();
    rethrow;
  }
}
