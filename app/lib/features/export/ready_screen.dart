import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_state.dart';
import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/routing/routes.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/pill_buttons.dart';
import '../../sticker_engine/sticker_check.dart';
import 'bonus_preview.dart';
import 'sticker_actions.dart';
import 'copy_sticker_button.dart';
import 'sticker_preview.dart';

/// "It’s ready." (canvas: Ready).
class ReadyScreen extends ConsumerStatefulWidget {
  const ReadyScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<ReadyScreen> createState() => _ReadyScreenState();
}

class _ReadyScreenState extends ConsumerState<ReadyScreen> {
  bool _sending = false;

  /// Bonus stickers that come with it: a sticker that starts a new pack
  /// gets two, so the pack reaches WhatsApp's minimum of three.
  int _bonus = 0;

  @override
  void initState() {
    super.initState();
    _loadBonus();
  }

  Future<void> _loadBonus() async {
    final record = findSticker(ref, widget.id);
    if (record == null || record.sentToWhatsApp) return;
    final exporter = await ref.read(exporterProvider.future);
    final packs = await exporter.packsToJoin(record.kind);
    if (mounted && packs.isEmpty) setState(() => _bonus = 2);
  }

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(libraryProvider).value ?? const [];
    final record = records.where((r) => r.id == widget.id).firstOrNull;
    if (record == null) return const Scaffold(body: SizedBox());
    final bonus = _bonus;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  PeelSpace.gutter,
                  8,
                  PeelSpace.gutter,
                  12,
                ),
                children: [
                  PeelHeader(
                    close: true,
                    onBack: () => context.go(Routes.home),
                  ),
                  const SizedBox(height: 10),
                  Text('It’s ready.', style: PeelType.title(size: 54)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 222,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        if (bonus > 0)
                          Positioned(
                            left: 0,
                            top: 92,
                            child: BonusPreview(
                              kind: record.kind,
                              index: 0,
                              tilt: -8,
                            ),
                          ),
                        if (bonus > 1)
                          Positioned(
                            right: 0,
                            top: 84,
                            child: BonusPreview(
                              kind: record.kind,
                              index: 1,
                              tilt: 7,
                            ),
                          ),
                        Align(
                          alignment: Alignment.topCenter,
                          child: Transform.rotate(
                            angle: -4 * math.pi / 180,
                            child: SizedBox.square(
                              dimension: 196,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  StickerPreview(record, size: 196),
                                  // Copy sits on the sticker it copies;
                                  // paste it into a chat to send just this.
                                  Positioned(
                                    top: -6,
                                    right: -6,
                                    child: CopyStickerButton(record: record),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (bonus > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      bonus == 1
                          ? 'A bonus sticker comes with it, so you can send yours right now. It makes room as you make more.'
                          : 'Two bonus stickers come with it, so you can send yours right now. They make room as you make more.',
                      textAlign: TextAlign.center,
                      style: PeelType.caption().copyWith(
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  ReadyPill(
                    checks: [
                      'Square, 512 × 512',
                      record.kind == StickerKind.still
                          ? 'Small enough: under 100 KB'
                          : 'Small enough: under 500 KB',
                      if (record.kind == StickerKind.moving)
                        '10 seconds or shorter',
                      'Tagged so it shows up in search',
                    ],
                  ),
                  if (record.hasSound) ...[
                    const SizedBox(height: 14),
                    const PeelNote(
                      pair: PeelPairs.butter,
                      icon: Icons.volume_up_rounded,
                      text: 'The sound comes next. WhatsApp needs one extra step for it. We’ll walk you through.',
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                PeelSpace.gutter,
                0,
                PeelSpace.gutter,
                20,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryPillButton(
                          label: 'Save to Photos',
                          leading: const Icon(Icons.download_rounded, size: 18),
                          onPressed: () => saveToPhotos(context, ref, record),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SecondaryPillButton(
                          label: 'Share',
                          leading: const Icon(
                            Icons.ios_share_rounded,
                            size: 18,
                          ),
                          onPressed: () => shareSticker(ref, record),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  PrimaryPillButton.whatsApp(
                    label: _sending ? 'Opening WhatsApp…' : 'Add to WhatsApp',
                    leading: const Icon(Icons.send_rounded, size: 20),
                    onPressed: _sending
                        ? null
                        : () async {
                            setState(() => _sending = true);
                            await sendToWhatsApp(context, ref, record);
                            if (mounted) setState(() => _sending = false);
                          },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
