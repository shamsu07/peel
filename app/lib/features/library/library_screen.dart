import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_state.dart';
import '../../core/design/tokens.dart';
import '../../core/design/whatsapp_colors.dart';
import '../../core/design/typography.dart';
import '../../core/routing/routes.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/pill_buttons.dart';
import '../../library/sticker_record.dart';
import '../../sticker_engine/sticker_check.dart';
import '../../whatsapp/exporter.dart';
import '../create/start.dart';
import '../export/pack_picker.dart';
import '../export/sticker_image.dart';
import 'sticker_detail_sheet.dart';

/// "My stickers." Home once the user has made a sticker (canvas: Home · my
/// stickers). Packs are never shown; only stickers.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key, required this.stickers});

  final List<StickerRecord> stickers;

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  bool _sending = false;

  Future<void> _sendNew(List<StickerRecord> unsent) async {
    setState(() => _sending = true);
    final exporter = await ref.read(exporterProvider.future);
    SendResult? last;
    for (final kind in StickerKind.values) {
      // Oldest first, at most a full pack at a time.
      final batch = unsent.reversed
          .where((r) => r.kind == kind)
          .take(30)
          .toList();
      if (batch.isEmpty) continue;
      if (!mounted) return;
      final choice = await choosePack(
        context,
        ref,
        kind: kind,
        count: batch.length,
      );
      if (choice == null) break;
      last = await exporter.send(batch, packIdentifier: choice.identifier);
      if (!last.ok) break;
    }
    await ref.read(libraryProvider.notifier).reload();
    if (!mounted) return;
    setState(() => _sending = false);
    switch (last?.outcome) {
      case SendOutcome.sent:
        showPeelSnack(context, 'Sent to WhatsApp.');
      case SendOutcome.notInstalled:
        context.push(Routes.noWhatsApp);
      case SendOutcome.cancelled:
        showPeelSnack(context, 'Not added. Tap Send to try again.');
      case SendOutcome.rejected:
      case SendOutcome.failed:
        showPeelSnack(context, 'WhatsApp didn’t take them. Please try again.');
      case SendOutcome.nothingToSend:
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stickers = widget.stickers;
    final unsent = stickers.where((r) => !r.sentToWhatsApp).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    PeelSpace.gutter,
                    8,
                    PeelSpace.gutter,
                    0,
                  ),
                  sliver: SliverList.list(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Long-press opens the Phase 0 lab. TODO(launch): remove.
                          GestureDetector(
                            onLongPress: () => context.push(Routes.lab),
                            child: Semantics(
                              header: true,
                              child: const PeelLogo(),
                            ),
                          ),
                          RoundIconButton(
                            icon: Icons.settings_outlined,
                            tooltip: 'Settings',
                            onPressed: () => context.push(Routes.settings),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              'My stickers.',
                              style: PeelType.title(),
                            ),
                          ),
                          Text(
                            '${stickers.length}',
                            style: PeelType.caption().copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (unsent.isNotEmpty) ...[
                        _SendBar(
                          count: unsent.length,
                          sending: _sending,
                          onSend: () => _sendNew(unsent),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    PeelSpace.gutter,
                    0,
                    PeelSpace.gutter,
                    0,
                  ),
                  sliver: SliverGrid.count(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    children: [
                      for (final r in stickers)
                        _Tile(
                          record: r,
                          onTap: () => showStickerDetail(context, ref, r),
                        ),
                    ],
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 140)),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                ignoring: false,
                child: Container(
                  padding: EdgeInsets.only(
                    top: 40,
                    bottom: 24 + MediaQuery.paddingOf(context).bottom,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0, 0.55],
                      colors: [Color(0x00EEEEF0), PeelColors.paper],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.all(Radius.circular(29)),
                      boxShadow: PeelShadows.floating,
                    ),
                    child: FilledButton.icon(
                      onPressed: () => showCreateSheet(context, ref),
                      icon: const Icon(Icons.add_rounded, size: 22),
                      label: const Text('New sticker'),
                      style: FilledButton.styleFrom(
                        backgroundColor: PeelColors.ink,
                        foregroundColor: PeelColors.surface,
                        minimumSize: const Size(0, 58),
                        padding: const EdgeInsets.fromLTRB(22, 0, 28, 0),
                        shape: const StadiumBorder(),
                        textStyle: PeelType.button(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SendBar extends StatelessWidget {
  const _SendBar({
    required this.count,
    required this.sending,
    required this.onSend,
  });

  final int count;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FilledButton(
        onPressed: sending ? null : onSend,
        style: FilledButton.styleFrom(
          backgroundColor: WhatsAppColors.green,
          foregroundColor: WhatsAppColors.onGreen,
          minimumSize: const Size(0, PeelSpace.minTouch),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: const StadiumBorder(),
          textStyle: PeelType.label().copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Text(
          sending ? 'Sending…' : 'Send $count new to WhatsApp',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.record, required this.onTap});

  final StickerRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final moving = record.kind == StickerKind.moving;
    return Material(
      color: PeelColors.surface,
      borderRadius: BorderRadius.circular(PeelRadii.tile),
      child: InkWell(
        borderRadius: BorderRadius.circular(PeelRadii.tile),
        onTap: onTap,
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: StickerImage(record),
              ),
            ),
            if (moving || record.hasSound)
              Positioned(
                left: 8,
                bottom: 8,
                child: Row(
                  children: [
                    if (moving) const _Badge(icon: Icons.play_arrow_rounded),
                    if (moving && record.hasSound) const SizedBox(width: 4),
                    if (record.hasSound)
                      const _Badge(icon: Icons.volume_up_rounded),
                  ],
                ),
              ),
            if (!record.sentToWhatsApp)
              Positioned(
                top: 9,
                right: 9,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: PeelColors.electric,
                    shape: BoxShape.circle,
                    border: Border.all(color: PeelColors.surface, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        color: PeelColors.ink,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 14, color: PeelColors.surface),
    );
  }
}
