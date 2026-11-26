import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_state.dart';
import '../../library/sticker_record.dart';

/// Shows a saved sticker.
///
/// Grids show the still first frame ([animate] false): a page of stickers
/// all animating at once keeps the phone decoding frames non-stop. Focus
/// views (Ready, details, the chat preview) animate.
class StickerImage extends ConsumerWidget {
  const StickerImage(
    this.record, {
    super.key,
    this.size,
    this.semanticLabel,
    this.animate = false,
  });

  final StickerRecord record;
  final double? size;
  final String? semanticLabel;
  final bool animate;

  /// Decode sizes are rounded to a few buckets so one sticker shown at
  /// several sizes shares cached pixels.
  static int _bucket(double px) => px <= 128
      ? 128
      : px <= 256
      ? 256
      : 512;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryStoreProvider).value;
    if (library == null) return SizedBox.square(dimension: size);
    // Decode only as many pixels as are shown (at most 2x: sharper than
    // the eye can tell on a sticker, and far less memory than 3x).
    final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 2.0);
    final pixels = _bucket((size ?? 110) * dpr);
    final file = animate ? record.webpFile : record.previewFile;
    return Image.file(
      File(library.file(file).path),
      width: size,
      height: size,
      cacheWidth: pixels,
      cacheHeight: pixels,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.low,
      semanticLabel: semanticLabel ?? _describe(record),
      errorBuilder: (_, _, _) => SizedBox.square(dimension: size),
    );
  }

  static String _describe(StickerRecord r) {
    final kind = r.source == StickerSource.video ? 'Moving sticker' : 'Sticker';
    return r.hasSound ? '$kind, with sound' : kind;
  }
}
