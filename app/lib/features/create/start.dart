import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_state.dart';
import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/routing/routes.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/die_cut_card.dart';
import '../../create/drafts.dart';
import '../../sticker_engine/whatsapp_rules.dart';

final _picker = ImagePicker();

/// Picks a photo (gallery or camera) and opens the Peeling screen.
Future<void> startPhoto(BuildContext context, ImageSource source) async {
  try {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      requestFullMetadata: false,
    );
    if (picked == null || !context.mounted) return;
    await context.push(Routes.peeling, extra: picked.path);
  } catch (e) {
    if (context.mounted) {
      showPeelSnack(
        context,
        source == ImageSource.camera
            ? 'Couldn’t open the camera. Check Peel can use it in Settings.'
            : 'Couldn’t open your photos. Check Peel can see them in Settings.',
      );
    }
  }
}

/// Picks a video and opens the video editor.
Future<void> startVideo(BuildContext context, WidgetRef ref) async {
  try {
    final picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked == null || !context.mounted) return;
    final info = await ref.read(nativeProvider).videoInfo(picked.path);
    if (info.durationMs <= 0 || info.width <= 0) {
      if (context.mounted) {
        showPeelSnack(context, 'That video can’t be read. Try another one.');
      }
      return;
    }
    final max = WhatsAppStickerRules.maxAnimationDuration.inMilliseconds;
    ref
        .read(videoDraftProvider.notifier)
        .start(
          VideoDraft(
            path: picked.path,
            info: info,
            startMs: 0,
            lengthMs: math.min(info.durationMs, max),
            crop: centeredCrop(info),
          ),
        );
    if (context.mounted) await context.push(Routes.video);
  } catch (e) {
    if (context.mounted) {
      showPeelSnack(context, 'Couldn’t open that video. Try another one.');
    }
  }
}

/// "New sticker." sheet (Create on the design canvas).
Future<void> showCreateSheet(BuildContext context, WidgetRef ref) {
  return showPeelSheet<void>(context, (sheet) {
    void then(Future<void> Function() action) {
      Navigator.of(sheet).pop();
      action();
    }

    return PeelSheet(
      title: 'New sticker.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _SourceTile(
                  pair: PeelPairs.mint,
                  icon: Icons.image_outlined,
                  title: 'Photo',
                  caption: 'From your gallery',
                  tilt: -1.5,
                  onTap: () =>
                      then(() => startPhoto(context, ImageSource.gallery)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SourceTile(
                  pair: PeelPairs.bubblegum,
                  icon: Icons.smart_display_outlined,
                  title: 'Video',
                  caption: 'Up to 10 s',
                  tilt: 1.5,
                  onTap: () => then(() => startVideo(context, ref)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Material(
            color: PeelColors.paper,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => then(() => startPhoto(context, ImageSource.camera)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: PeelColors.surface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.photo_camera_outlined, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Take a photo now',
                        style: PeelType.label().copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(
                Icons.volume_up_outlined,
                size: 16,
                color: PeelColors.muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You can add a sound to either one in the next step.',
                  style: PeelType.caption().copyWith(fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  });
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.pair,
    required this.icon,
    required this.title,
    required this.caption,
    required this.tilt,
    required this.onTap,
  });

  final InkPair pair;
  final IconData icon;
  final String title;
  final String caption;
  final double tilt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DieCutCard(
      color: pair.fill,
      tiltDegrees: tilt,
      radius: 26,
      onTap: onTap,
      semanticLabel: '$title. $caption',
      padding: const EdgeInsets.all(9),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 122),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: PeelColors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: pair.ink, size: 24),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: PeelType.cardTitle(color: pair.ink).copyWith(fontSize: 24),
            ),
            const SizedBox(height: 3),
            Text(
              caption,
              style: PeelType.caption(color: pair.ink).copyWith(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
