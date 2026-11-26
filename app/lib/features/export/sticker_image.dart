import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_state.dart';
import '../../library/sticker_record.dart';

/// Shows a saved sticker (moving ones animate).
class StickerImage extends ConsumerWidget {
  const StickerImage(this.record, {super.key, this.size, this.semanticLabel});

  final StickerRecord record;
  final double? size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryStoreProvider).value;
    if (library == null) return SizedBox.square(dimension: size);
    // Decode only as many pixels as are shown: a grid of animated stickers
    // at full 512 px is the heaviest thing on the home screen.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final pixels = ((size ?? 110) * dpr).round().clamp(64, 512);
    return Image.file(
      File(library.file(record.webpFile).path),
      width: size,
      height: size,
      cacheWidth: pixels,
      cacheHeight: pixels,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      semanticLabel: semanticLabel ?? _describe(record),
      errorBuilder: (_, _, _) => SizedBox.square(dimension: size),
    );
  }

  static String _describe(StickerRecord r) {
    final kind = r.source == StickerSource.video ? 'Moving sticker' : 'Sticker';
    return r.hasSound ? '$kind, with sound' : kind;
  }
}
