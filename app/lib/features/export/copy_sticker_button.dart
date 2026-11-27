import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/design/tokens.dart';
import '../../library/sticker_record.dart';
import 'sticker_actions.dart';

/// A copy button that sits on a sticker's corner. Tapping it copies the
/// sticker (paste it into a WhatsApp chat to send just this one) and
/// briefly turns into a tick. Moving stickers copy as a GIF, so their
/// button says "GIF"; sound stickers have none.
class CopyStickerButton extends ConsumerStatefulWidget {
  const CopyStickerButton({super.key, required this.record});

  final StickerRecord record;

  @override
  ConsumerState<CopyStickerButton> createState() => _CopyStickerButtonState();
}

class _CopyStickerButtonState extends ConsumerState<CopyStickerButton> {
  bool _copied = false;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    final ok = await copySticker(context, ref, widget.record);
    if (!ok || !mounted) return;
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final kind = copyKindFor(widget.record);
    if (kind == null) return const SizedBox.shrink();
    final gif = kind == CopyKind.gif;
    return Semantics(
      button: true,
      label: _copied ? 'Copied' : copyLabel(kind),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _copy,
        child: SizedBox(
          height: 52,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 44,
              constraints: const BoxConstraints(minWidth: 44),
              padding: EdgeInsets.symmetric(horizontal: gif ? 12 : 0),
              // Electric blue with a white ring, like a small sticker on
              // the sticker, so it's noticed.
              decoration: BoxDecoration(
                color: _copied ? PeelPairs.mint.fill : PeelColors.electric,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: PeelColors.white, width: 3),
                boxShadow: PeelShadows.card,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Row(
                  key: ValueKey(_copied),
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _copied
                          ? Icons.check_rounded
                          : Icons.content_copy_rounded,
                      size: 20,
                      color: _copied ? PeelPairs.mint.ink : PeelColors.white,
                    ),
                    if (gif) ...[
                      const SizedBox(width: 5),
                      Text(
                        'GIF',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: _copied
                              ? PeelPairs.mint.ink
                              : PeelColors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
