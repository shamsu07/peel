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
import '../../library/sticker_record.dart';
import 'sticker_actions.dart';

/// "Finish it in WhatsApp." The sound version can't be added by apps yet,
/// so we save a short video and guide the user through WhatsApp's own
/// "Create sticker" (spec P0-5; canvas: Finish sound sticker).
class SoundHandoffScreen extends ConsumerStatefulWidget {
  const SoundHandoffScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<SoundHandoffScreen> createState() => _SoundHandoffScreenState();
}

enum _Saved { saving, saved, failed }

class _SoundHandoffScreenState extends ConsumerState<SoundHandoffScreen> {
  _Saved _saved = _Saved.saving;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _save());
  }

  Future<void> _save() async {
    final record = findSticker(ref, widget.id);
    if (record == null) return;
    setState(() => _saved = _Saved.saving);
    final ok = await saveHandoffVideo(context, ref, record);
    if (mounted) setState(() => _saved = ok ? _Saved.saved : _Saved.failed);
  }

  @override
  Widget build(BuildContext context) {
    final record = (ref.watch(libraryProvider).value ?? const [])
        .where((r) => r.id == widget.id)
        .firstOrNull;
    final source = record?.source == StickerSource.video ? 'clip' : 'photo';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            PeelSpace.gutter,
            8,
            PeelSpace.gutter,
            20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  RoundIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Close',
                    onPressed: () => context.go(Routes.home),
                  ),
                  const Spacer(),
                  Transform.rotate(
                    angle: 0.07,
                    child: switch (_saved) {
                      _Saved.saving => const PeelChip(label: 'Saving…'),
                      _Saved.saved => const PeelChip(
                        label: 'Saved to Photos',
                        pair: PeelPairs.mint,
                        icon: Icons.check_rounded,
                      ),
                      _Saved.failed => const PeelChip(
                        label: 'Not saved',
                        pair: PeelPairs.bubblegum,
                      ),
                    },
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(top: 12),
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'Finish it in WhatsApp.',
                        style: PeelType.title(size: 46),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Your sticker video and its sound are in Photos. '
                      'WhatsApp turns them into a sound sticker.',
                      style: PeelType.body(),
                    ),
                    if (_saved == _Saved.failed) ...[
                      const SizedBox(height: 12),
                      PeelNote(
                        pair: PeelPairs.bubblegum,
                        text:
                            'We couldn’t save the video to Photos. Allow Peel '
                            'to add to Photos in Settings, then try again.',
                        action: SecondaryPillButton(
                          label: 'Try again',
                          onPressed: _save,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const _StepCard(
                      number: 1,
                      pair: PeelPairs.mint,
                      title: 'Open a chat and tap the sticker icon',
                      detail: 'It’s next to the message box.',
                    ),
                    _StepCard(
                      number: 2,
                      pair: PeelPairs.bubblegum,
                      title: 'Tap Create sticker and pick the video',
                      detail:
                          'It’s the newest one in Photos, made from your $source.',
                    ),
                    const _StepCard(
                      number: 3,
                      pair: PeelPairs.butter,
                      title: 'Keep the original sound and send',
                      detail: 'Friends tap the sticker to hear it.',
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFC4C4CC),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: PeelColors.mutedStrong,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'No sound option yet? WhatsApp is still rolling sound '
                              'stickers out. Update WhatsApp and try again. Your '
                              'sticker stays saved.',
                              style: PeelType.caption(
                                color: PeelColors.mutedStrong,
                              ).copyWith(height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              PrimaryPillButton.whatsApp(
                label: 'Open WhatsApp',
                leading: const Icon(Icons.open_in_new_rounded, size: 20),
                onPressed: () async {
                  final opened = await ref.read(bridgeProvider).open();
                  if (!opened && context.mounted) {
                    showPeelSnack(
                      context,
                      'WhatsApp isn’t installed on this phone.',
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.pair,
    required this.title,
    required this.detail,
  });

  final int number;
  final InkPair pair;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PeelColors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Transform.rotate(
            angle: (number.isEven ? 4 : -4) * math.pi / 180,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: pair.fill,
                shape: BoxShape.circle,
                border: Border.all(color: PeelColors.surface, width: 3),
                boxShadow: PeelShadows.card,
              ),
              alignment: Alignment.center,
              child: Text(
                '$number',
                style: PeelType.label(color: pair.ink).copyWith(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: PeelType.label().copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(detail, style: PeelType.caption()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
