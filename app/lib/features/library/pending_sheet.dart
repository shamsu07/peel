import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_state.dart';
import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/routing/routes.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/peel_segmented.dart';
import '../../core/widgets/pill_buttons.dart';
import '../../library/sticker_record.dart';
import '../../sticker_engine/sticker_check.dart';
import '../../sticker_engine/whatsapp_rules.dart';
import '../../whatsapp/exporter.dart';
import '../export/pack_picker.dart';
import '../export/sticker_image.dart';

/// Sends waiting stickers to WhatsApp in as many packs as the user likes.
///
/// The sheet opens with every waiting sticker ticked, so "all into one
/// pack" is one tap. Untick some to make a pack of just those; the sheet
/// then comes back with the rest for the next pack, until none are left
/// or the user closes it.
Future<void> sendWaitingStickers(BuildContext context, WidgetRef ref) async {
  while (context.mounted) {
    final waiting = (ref.read(libraryProvider).value ?? const [])
        .where((r) => !r.sentToWhatsApp)
        .toList()
        .reversed // Oldest first.
        .toList();
    if (waiting.isEmpty || !context.mounted) return;
    final picked = await showPeelSheet<List<StickerRecord>>(
      context,
      (_) => _WaitingSheet(waiting: waiting),
    );
    if (picked == null || picked.isEmpty || !context.mounted) return;

    final choice = await choosePack(
      context,
      ref,
      kind: picked.first.kind,
      count: picked.length,
    );
    if (choice == null) continue; // Back to the selection.

    final exporter = await ref.read(exporterProvider.future);
    final result = await exporter.send(
      picked,
      packIdentifier: choice.identifier,
      newPackName: choice.name,
    );
    await ref.read(libraryProvider.notifier).reload();
    if (!context.mounted) return;
    switch (result.outcome) {
      case SendOutcome.sent:
        final n = picked.length;
        showPeelSnack(
          context,
          'Added $n sticker${n == 1 ? '' : 's'} to ${result.packName ?? 'WhatsApp'}.',
        );
      case SendOutcome.notInstalled:
        context.push(Routes.noWhatsApp);
        return;
      case SendOutcome.cancelled:
        showPeelSnack(context, 'Not added. Pick them again to retry.');
      case SendOutcome.rejected:
      case SendOutcome.failed:
        showPeelSnack(context, 'WhatsApp didn’t take them. Please try again.');
        return;
      case SendOutcome.nothingToSend:
        return;
    }
  }
}

/// The waiting stickers, all ticked, with one button to send the ticked
/// ones. Photo and video stickers can't share a pack, so when there are
/// both, a switch shows one kind at a time.
class _WaitingSheet extends StatefulWidget {
  const _WaitingSheet({required this.waiting});

  final List<StickerRecord> waiting;

  @override
  State<_WaitingSheet> createState() => _WaitingSheetState();
}

class _WaitingSheetState extends State<_WaitingSheet> {
  late StickerKind _kind = widget.waiting.first.kind;
  late final Set<String> _ticked = {for (final r in widget.waiting) r.id};

  List<StickerRecord> get _shown =>
      widget.waiting.where((r) => r.kind == _kind).toList();

  List<StickerRecord> get _picked =>
      _shown.where((r) => _ticked.contains(r.id)).toList();

  bool get _bothKinds => widget.waiting.map((r) => r.kind).toSet().length > 1;

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    final picked = _picked;
    final n = picked.length;
    final allTicked = n == shown.length;
    final tooMany = n > WhatsAppStickerRules.maxStickersPerPack;
    final count = widget.waiting.length;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: PeelSheet(
        title: 'Send to WhatsApp',
        subtitle: '$count sticker${count == 1 ? '' : 's'} waiting',
        child: Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_bothKinds) ...[
                PeelSegmented<StickerKind>(
                  semanticLabel: 'Sticker type',
                  options: [
                    SegmentOption(
                      StickerKind.still,
                      'Photos (${widget.waiting.where((r) => r.kind == StickerKind.still).length})',
                    ),
                    SegmentOption(
                      StickerKind.moving,
                      'Videos (${widget.waiting.where((r) => r.kind == StickerKind.moving).length})',
                    ),
                  ],
                  selected: _kind,
                  onChanged: (k) => setState(() => _kind = k),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$n of ${shown.length} selected',
                      style: PeelType.caption().copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      if (allTicked) {
                        _ticked.removeAll(shown.map((r) => r.id));
                      } else {
                        _ticked.addAll(shown.map((r) => r.id));
                      }
                    }),
                    style: TextButton.styleFrom(
                      foregroundColor: PeelColors.ink,
                      minimumSize: const Size(0, PeelSpace.minTouch),
                    ),
                    child: Text(allTicked ? 'Clear' : 'Select all'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Flexible(
                child: GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  children: [
                    for (final r in shown)
                      _PickTile(
                        record: r,
                        ticked: _ticked.contains(r.id),
                        onTap: () => setState(() {
                          if (!_ticked.remove(r.id)) _ticked.add(r.id);
                        }),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              PrimaryPillButton.whatsApp(
                label: tooMany
                    ? 'A pack holds up to 30'
                    : n == 0
                    ? 'Select stickers'
                    : allTicked && n > 1
                    ? 'Add all $n to a pack'
                    : 'Add $n to a pack',
                leading: const Icon(Icons.send_rounded, size: 20),
                onPressed: n == 0 || tooMany
                    ? null
                    : () => Navigator.of(context).pop(picked),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A waiting sticker with a tick in its corner; unticked ones fade.
class _PickTile extends StatelessWidget {
  const _PickTile({
    required this.record,
    required this.ticked,
    required this.onTap,
  });

  final StickerRecord record;
  final bool ticked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: ticked,
      label: ticked ? 'Selected sticker' : 'Sticker, not selected',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: ticked ? 1 : 0.35,
                duration: const Duration(milliseconds: 120),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: StickerImage(record),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: ticked ? PeelColors.ink : PeelColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ticked ? PeelColors.surface : PeelColors.hairline,
                    width: 2,
                  ),
                ),
                child: ticked
                    ? Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: PeelColors.surface,
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
