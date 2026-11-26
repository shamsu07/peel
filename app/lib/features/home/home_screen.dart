import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/routing/routes.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/design_sticker.dart';
import '../../core/widgets/die_cut_card.dart';
import '../../core/widgets/pill_buttons.dart';
import '../create/start.dart';
import '../library/library_screen.dart';
import '../../app_state.dart';

/// Home, first run ("Home · first run" on the design canvas).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Once there's a sticker, Home becomes "My stickers.".
    final stickers = ref.watch(libraryProvider).value ?? const [];
    if (stickers.isNotEmpty) return LibraryScreen(stickers: stickers);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            PeelSpace.gutter,
            8,
            PeelSpace.gutter,
            30,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Long-press opens the Phase 0 encoder lab.
                  // TODO(launch): remove.
                  GestureDetector(
                    onLongPress: () => context.push(Routes.lab),
                    child: Semantics(header: true, child: const PeelLogo()),
                  ),
                  RoundIconButton(
                    icon: Icons.settings_outlined,
                    tooltip: 'Settings',
                    onPressed: () => context.push(Routes.settings),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const _Hero(),
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 310),
                child: Text(
                  'Turn a photo or video into a WhatsApp sticker in a few taps.',
                  style: PeelType.body(),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _SourceCard(
                      pair: PeelPairs.mint,
                      icon: Icons.image_outlined,
                      title: 'Photo',
                      caption: 'Background removed for you',
                      tiltDegrees: -1.5,
                      onTap: () => startPhoto(context, ImageSource.gallery),
                      cornerAction: _CornerAction(
                        icon: Icons.photo_camera_outlined,
                        label: 'Take a photo with the camera',
                        onTap: () => startPhoto(context, ImageSource.camera),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _SourceCard(
                      pair: PeelPairs.bubblegum,
                      icon: Icons.smart_display_outlined,
                      title: 'Video',
                      caption: 'A moving sticker, up to 10 s',
                      tiltDegrees: 1.5,
                      onTap: () => startVideo(context, ref),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SoundCard(onTap: () => showCreateSheet(context, ref)),
              const SizedBox(height: 28),
              const _PrivacyLine(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 230,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Semantics(
            header: true,
            label: 'Snap. Peel. Send.',
            excludeSemantics: true,
            child: Text('Snap.\nPeel.\nSend.', style: PeelType.display()),
          ),
          DesignStickerImage.positioned(
            DesignSticker.homeBadge,
            top: -6,
            right: -4,
          ),
          DesignStickerImage.positioned(
            DesignSticker.homeStar,
            top: 134,
            right: 78,
          ),
          DesignStickerImage.positioned(
            DesignSticker.homeFlame,
            top: 148,
            right: 4,
          ),
        ],
      ),
    );
  }
}

class _CornerAction {
  const _CornerAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.pair,
    required this.icon,
    required this.title,
    required this.caption,
    required this.tiltDegrees,
    required this.onTap,
    this.cornerAction,
  });

  final InkPair pair;
  final IconData icon;
  final String title;
  final String caption;
  final double tiltDegrees;
  final VoidCallback onTap;
  final _CornerAction? cornerAction;

  @override
  Widget build(BuildContext context) {
    final action = cornerAction;
    return Transform.rotate(
      angle: tiltDegrees * math.pi / 180,
      child: Stack(
        children: [
          DieCutCard(
            color: pair.fill,
            onTap: onTap,
            semanticLabel: '$title. $caption',
            padding: const EdgeInsets.all(11),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 152),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _IconDisc(icon: icon, color: pair.ink),
                  const SizedBox(height: 16),
                  Text(title, style: PeelType.cardTitle(color: pair.ink)),
                  const SizedBox(height: 4),
                  Text(
                    caption,
                    style: PeelType.caption(color: pair.ink)
                        .copyWith(fontSize: 14, height: 1.3),
                  ),
                ],
              ),
            ),
          ),
          if (action != null)
            Positioned(
              top: 16,
              right: 16,
              child: Semantics(
                button: true,
                label: action.label,
                excludeSemantics: true,
                child: Material(
                  color: const Color(0x99FFFFFF),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: action.onTap,
                    child: SizedBox.square(
                      dimension: 50,
                      child: Icon(action.icon, color: pair.ink, size: 22),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _IconDisc extends StatelessWidget {
  const _IconDisc({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: const BoxDecoration(
        color: PeelColors.surface,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 26),
    );
  }
}

class _SoundCard extends StatelessWidget {
  const _SoundCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const pair = PeelPairs.butter;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        DieCutCard(
          color: pair.fill,
          radius: 24,
          onTap: onTap,
          semanticLabel:
              'New: stickers with sound. Pick a photo or clip, then add your '
              'voice.',
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: PeelColors.ink,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.volume_up_rounded,
                    color: PeelColors.surface,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Stickers with sound', style: PeelType.label()),
                      const SizedBox(height: 3),
                      Text(
                        'Pick a photo or clip, then add your voice.',
                        style: PeelType.caption(color: pair.ink)
                            .copyWith(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: PeelColors.ink),
              ],
            ),
          ),
        ),
        Positioned(
          top: -14,
          right: 18,
          child: ExcludeSemantics(
            child: DieCutTag(label: 'NEW', textStyle: PeelType.tag()),
          ),
        ),
      ],
    );
  }
}

class _PrivacyLine extends StatelessWidget {
  const _PrivacyLine();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.lock_outline_rounded,
          size: 15,
          color: PeelColors.muted,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'No sign-up. Your photos never leave your phone.',
            textAlign: TextAlign.center,
            style: PeelType.caption().copyWith(fontSize: 13),
          ),
        ),
      ],
    );
  }
}
