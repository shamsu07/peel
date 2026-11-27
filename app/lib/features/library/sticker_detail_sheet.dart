import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_state.dart';
import '../../core/design/tokens.dart';
import '../../core/design/whatsapp_colors.dart';
import '../../core/design/typography.dart';
import '../../core/routing/routes.dart';
import '../../core/widgets/common.dart';
import '../../library/sticker_record.dart';
import '../export/sticker_actions.dart';
import '../export/sticker_preview.dart';

/// Sticker details (canvas: Sticker details · share, delete).
Future<void> showStickerDetail(
  BuildContext context,
  WidgetRef ref,
  StickerRecord record,
) => showPeelSheet<void>(
  context,
  (_) => _DetailSheet(record: record, host: context),
);

class _DetailSheet extends ConsumerStatefulWidget {
  const _DetailSheet({required this.record, required this.host});

  final StickerRecord record;

  /// The screen behind the sheet, for snack bars after it closes.
  final BuildContext host;

  @override
  ConsumerState<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends ConsumerState<_DetailSheet> {
  void _delete() {
    final record = widget.record;
    final host = widget.host;
    final messenger = ScaffoldMessenger.of(host);
    ref.read(libraryProvider.notifier).hide(record.id);
    Navigator.of(context).pop();
    messenger.hideCurrentSnackBar();
    final bar = messenger.showSnackBar(
      // Closes by itself after 5 s; Undo works until then.
      peelSnackBar(
        'Sticker deleted.',
        actionLabel: 'Undo',
        duration: const Duration(seconds: 5),
      ),
      snackBarAnimationStyle: peelSnackMotion,
    );
    // Delete for real only once Undo is no longer possible.
    final container = ProviderScope.containerOf(host, listen: false);
    bar.closed.then((reason) async {
      if (reason != SnackBarClosedReason.action) {
        final library = await container.read(libraryStoreProvider.future);
        await library.delete(record);
      }
      await container.read(libraryProvider.notifier).reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final made = DateUtils.isSameDay(r.createdAt, DateTime.now())
        ? 'today'
        : '${r.createdAt.day}/${r.createdAt.month}';
    final meta = [
      r.source == StickerSource.video ? 'Video' : 'Photo',
      if (r.hasSound) 'with sound',
      made,
    ].join(' · ');

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          PeelSpace.gutter,
          10,
          PeelSpace.gutter,
          16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: ShapeDecoration(
                  color: PeelColors.hairline,
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // The sticker on the sheet itself: its white edge is the frame.
            SizedBox(
              height: 220,
              child: Stack(
                children: [
                  Center(
                    child: Transform.rotate(
                      angle: -0.05,
                      child: StickerPreview(r, size: 184),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: PeelColors.closeFill,
                        foregroundColor: PeelColors.tagRed,
                        fixedSize: const Size.square(44),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // One quiet line: where it is (the dot matches Home's), then
            // what it is.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: r.sentToWhatsApp
                        ? WhatsAppColors.green
                        : PeelColors.electric,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  r.sentToWhatsApp ? 'In WhatsApp' : 'Not sent yet',
                  style: PeelType.caption(color: PeelColors.ink)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                Text('  ·  $meta', style: PeelType.caption()),
              ],
            ),
            const SizedBox(height: 12),
            if (!r.sentToWhatsApp)
              _Row(
                icon: Icons.send_rounded,
                iconBackground: WhatsAppColors.green,
                iconColor: WhatsAppColors.onGreen,
                label: 'Send to WhatsApp',
                onTap: () {
                  Navigator.of(context).pop();
                  sendToWhatsApp(widget.host, ref, r, openSentScreen: false);
                },
              ),
            _Row(
              icon: Icons.content_copy_rounded,
              iconBackground: PeelPairs.lilac.fill,
              iconColor: PeelPairs.lilac.ink,
              label: 'Copy sticker',
              onTap: () => copySticker(context, ref, r),
            ),
            if (r.handoffVideo != null)
              _Row(
                icon: Icons.volume_up_rounded,
                iconBackground: PeelPairs.butter.fill,
                iconColor: PeelPairs.butter.ink,
                label: 'Make the sound version',
                chevron: true,
                onTap: () {
                  Navigator.of(context).pop();
                  widget.host.push(Routes.sound(r.id));
                },
              ),
            _Row(
              icon: Icons.download_rounded,
              iconBackground: PeelPairs.mint.fill,
              iconColor: PeelPairs.mint.ink,
              label: 'Save to Photos',
              onTap: () => saveToPhotos(context, ref, r),
            ),
            _Row(
              icon: Icons.ios_share_rounded,
              iconBackground: PeelPairs.sky.fill,
              iconColor: PeelPairs.sky.ink,
              label: shareLabel(r),
              onTap: () => shareSticker(ref, r),
            ),
            Divider(color: PeelColors.paper, height: 12),
            _Row(
              icon: Icons.delete_rounded,
              iconBackground: PeelColors.closeFill,
              iconColor: PeelColors.tagRed,
              labelColor: PeelColors.tagRed,
              label: 'Delete sticker',
              onTap: _delete,
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconBackground,
    this.iconColor,
    this.labelColor,
    this.chevron = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconBackground;
  final Color? iconColor;
  final Color? labelColor;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: ShapeDecoration(
                  color: iconBackground ?? PeelColors.paper,
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: Icon(icon, size: 20, color: iconColor ?? PeelColors.ink),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: PeelType.label(color: labelColor ?? PeelColors.ink)
                          .copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (chevron)
                Icon(Icons.chevron_right_rounded, color: PeelColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
