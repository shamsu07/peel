import 'package:material_ui/material_ui.dart';

/// Sticker art from the design canvas, rendered by
/// tool/render_design_stickers.py with the white die-cut edge, shadow and
/// tilt baked in, then compressed to WebP.
///
/// Each image carries [DesignSticker.pad] px of transparent margin around
/// the design box, so it can be placed with the canvas's own coordinates
/// via [DesignStickerImage.positioned].
enum DesignSticker {
  homeBadge('home_badge', 122, 122),
  homeStar('home_star', 82, 82),
  homeFlame('home_flame', 62, 62),
  dog('dog', 80, 80),
  cat('cat', 80, 80),
  badge('badge', 80, 80),
  star('star', 80, 80),
  flame('flame', 76, 76),
  heartOk('heart_ok', 78, 78),
  googlyEyes('googly_eyes', 80, 80),
  cloud('cloud', 80, 80),
  runningLate('running_late', 100, 80),
  lolSame('lol_same', 120, 80),
  onMyWay('on_my_way', 100, 80),
  nope('nope', 100, 80),
  brb('brb', 100, 80);

  const DesignSticker(this.file, this.width, this.height);

  /// Transparent margin rendered around each sticker, in logical px.
  static const pad = 28.0;

  final String file;

  /// Size of the sticker's box on the design canvas.
  final double width;
  final double height;

  String get asset => 'assets/stickers/$file.webp';
}

class DesignStickerImage extends StatelessWidget {
  const DesignStickerImage(this.sticker, {super.key});

  final DesignSticker sticker;

  /// Places the sticker like the canvas does: [top]/[left]/[right] are the
  /// design box edges, the extra margin is handled here.
  static Widget positioned(
    DesignSticker sticker, {
    double? top,
    double? left,
    double? right,
  }) => Positioned(
    top: top == null ? null : top - DesignSticker.pad,
    left: left == null ? null : left - DesignSticker.pad,
    right: right == null ? null : right - DesignSticker.pad,
    child: DesignStickerImage(sticker),
  );

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      sticker.asset,
      width: sticker.width + DesignSticker.pad * 2,
      height: sticker.height + DesignSticker.pad * 2,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
      gaplessPlayback: true,
    );
  }
}
