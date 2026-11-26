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
                        'Now add\nthe sound.',
                        style: PeelType.title(size: 46),
                      ),
                    ),
                    if (_saved == _Saved.failed) ...[
                      const SizedBox(height: 12),
                      PeelNote(
                        pair: PeelPairs.bubblegum,
                        text: 'Couldn’t save the video to Photos.',
                        action: SecondaryPillButton(
                          label: 'Try again',
                          onPressed: _save,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    // Three steps, one line each.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: ShapeDecoration(
                        color: PeelColors.surface,
                        shape: RoundedSuperellipseBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Column(
                        children: [
                          _Step(
                            number: 1,
                            pair: PeelPairs.mint,
                            icon: Icons.emoji_emotions_rounded,
                            text: 'In a chat, tap the sticker icon',
                          ),
                          Divider(height: 1, color: PeelColors.paper),
                          _Step(
                            number: 2,
                            pair: PeelPairs.bubblegum,
                            icon: Icons.add_photo_alternate_rounded,
                            text: 'Create sticker, pick the newest video',
                          ),
                          Divider(height: 1, color: PeelColors.paper),
                          _Step(
                            number: 3,
                            pair: PeelPairs.butter,
                            icon: Icons.volume_up_rounded,
                            text: 'Keep the sound and send',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'No sound option? WhatsApp is still rolling it out.',
                      textAlign: TextAlign.center,
                      style: PeelType.caption(),
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

/// One step: a tilted pastel icon tile with its number, and one line.
class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.pair,
    required this.icon,
    required this.text,
  });

  final int number;
  final InkPair pair;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step $number: $text',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Transform.rotate(
              angle: (number.isEven ? 4 : -4) * math.pi / 180,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: ShapeDecoration(
                        color: pair.fill,
                        shape: RoundedSuperellipseBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Icon(icon, size: 24, color: pair.ink),
                    ),
                    Positioned(
                      right: -5,
                      top: -5,
                      child: Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: PeelColors.ink,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: PeelColors.surface,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          '$number',
                          style: TextStyle(
                            color: PeelColors.surface,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: PeelType.label().copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
