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
      SnackBar(
        content: const Text('Sticker deleted.'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Undo',
          textColor: PeelPairs.butter.fill,
          onPressed: () {},
        ),
      ),
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
        ? 'made today'
        : 'made ${r.createdAt.day}/${r.createdAt.month}';
    final meta = [
      r.source == StickerSource.video ? 'Video sticker' : 'Photo sticker',
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
                decoration: BoxDecoration(
                  color: PeelColors.hairline,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 230,
              child: Checkerboard(
                radius: 26,
                child: Stack(
                  children: [
                    Center(child: StickerPreview(r, size: 176)),
                    Positioned(
                      right: 10,
                      top: 10,
                      child: IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: PeelColors.paper,
                          fixedSize: const Size.square(44),
                        ),
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                r.sentToWhatsApp
                    ? const PeelChip(
                        label: 'In WhatsApp',
                        pair: PeelPairs.mint,
                        icon: Icons.check_rounded,
                      )
                    : const PeelChip(label: 'Not in WhatsApp yet'),
                Text(
                  meta,
                  style: PeelType.caption().copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!r.sentToWhatsApp)
              _Row(
                icon: Icons.north_east_rounded,
                iconBackground: WhatsAppColors.green,
                iconColor: WhatsAppColors.onGreen,
                label: 'Send to WhatsApp',
                onTap: () {
                  Navigator.of(context).pop();
                  sendToWhatsApp(widget.host, ref, r, openSentScreen: false);
                },
              ),
            if (r.handoffVideo != null)
              _Row(
                icon: Icons.volume_up_rounded,
                iconBackground: PeelPairs.butter.fill,
                label: 'Make the sound version',
                chevron: true,
                onTap: () {
                  Navigator.of(context).pop();
                  widget.host.push(Routes.sound(r.id));
                },
              ),
            _Row(
              icon: Icons.download_rounded,
              label: 'Save to Photos',
              onTap: () => saveToPhotos(context, ref, r),
            ),
            _Row(
              icon: Icons.ios_share_rounded,
              label: 'Share to another app',
              onTap: () => shareSticker(ref, r),
            ),
            _Row(
              icon: Icons.content_copy_rounded,
              label: 'Copy sticker',
              detail: 'Then paste it into a chat',
              onTap: () => copySticker(context, ref, r),
            ),
            const Divider(color: PeelColors.paper, height: 12),
            _Row(
              icon: Icons.delete_outline_rounded,
              iconBackground: const Color(0xFFFDE7E7),
              iconColor: const Color(0xFFB42318),
              labelColor: const Color(0xFFB42318),
              label: 'Delete sticker',
              detail: 'Also removes it from WhatsApp. You can undo.',
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
    this.detail,
    this.iconBackground = PeelColors.paper,
    this.iconColor = PeelColors.ink,
    this.labelColor = PeelColors.ink,
    this.chevron = false,
  });

  final IconData icon;
  final String label;
  final String? detail;
  final VoidCallback onTap;
  final Color iconBackground;
  final Color iconColor;
  final Color labelColor;
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
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: PeelType.label(color: labelColor)
                          .copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    if (detail != null)
                      Text(
                        detail!,
                        style: PeelType.caption().copyWith(fontSize: 13),
                      ),
                  ],
                ),
              ),
              if (chevron)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: PeelColors.muted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
