import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_state.dart';
import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../sticker_engine/sticker_check.dart';

/// One of the bonus stickers that fill a pack, with its "BONUS" tag.
class BonusPreview extends ConsumerWidget {
  const BonusPreview({
    super.key,
    required this.kind,
    required this.index,
    this.tilt = 0,
  });

  final StickerKind kind;
  final int index;
  final double tilt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref.read(bonusProvider).bonusFor(kind),
      builder: (context, snap) {
        final list = snap.data;
        final Uint8List? bytes = list != null && index < list.length
            ? list[index].bytes
            : null;
        return Transform.rotate(
          angle: tilt * math.pi / 180,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 84,
                child: bytes == null
                    ? null
                    : Image.memory(
                        bytes,
                        gaplessPlayback: true,
                        semanticLabel: 'Bonus sticker',
                      ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: PeelColors.surface,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  'BONUS',
                  style: PeelType.tag(color: PeelColors.mutedStrong),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
