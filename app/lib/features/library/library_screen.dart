import 'dart:math' as math;

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
import '../../whatsapp/pack_models.dart';
import '../create/start.dart';
import '../export/sticker_image.dart';
import 'pending_sheet.dart';
import 'sticker_detail_sheet.dart';

/// "My stickers." Home once the user has made a sticker (canvas: Home · my
/// stickers). Packs sit in a row on top (tap one to see just its
/// stickers); below, every sticker, grouped by when it was made.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key, required this.stickers});

  final List<StickerRecord> stickers;

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  bool _sending = false;
  List<PackEntry> _packs = const [];

  @override
  void initState() {
    super.initState();
    _loadPacks();
  }

  @override
  void didUpdateWidget(LibraryScreen old) {
    super.didUpdateWidget(old);
    if (!identical(old.stickers, widget.stickers)) _loadPacks();
  }

  /// Packs in WhatsApp that hold at least one of the user's stickers.
  Future<void> _loadPacks() async {
    final store = await ref.read(packStoreProvider.future);
    final ids = {for (final r in widget.stickers) r.packIdentifier};
    final packs = (await store.load()).packs.reversed
        .where((p) => p.inWhatsApp && ids.contains(p.identifier))
        .toList();
    if (!mounted) return;
    setState(() => _packs = packs);
  }

  Future<void> _sendNew() async {
    setState(() => _sending = true);
    await sendWaitingStickers(context, ref);
    if (mounted) setState(() => _sending = false);
  }

  /// Every sticker, under date headings.
  List<Widget> _stickerSections(List<StickerRecord> stickers) {
    final groups = <String, List<StickerRecord>>{};
    final now = DateTime.now();
    for (final r in stickers) {
      groups.putIfAbsent(_whenLabel(r.createdAt, now), () => []).add(r);
    }
    return [
      for (final e in groups.entries) ...[
        _SectionLabel(e.key),
        _grid(e.value),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
      ],
    ];
  }

  Widget _grid(List<StickerRecord> records) => SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: PeelSpace.gutter),
    sliver: SliverGrid.count(
      crossAxisCount: 3,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      children: [
        for (final r in records)
          StickerTile(
            key: ValueKey(r.id),
            record: r,
            onTap: () => showStickerDetail(context, ref, r),
          ),
      ],
    ),
  );

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// Today, Yesterday, This week, then the month (and year if not this one).
  static String _whenLabel(DateTime at, DateTime now) {
    final day = DateTime(at.year, at.month, at.day);
    final today = DateTime(now.year, now.month, now.day);
    final days = today.difference(day).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 7) return 'This week';
    final month = _months[at.month - 1];
    return at.year == now.year ? month : '$month ${at.year}';
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
                            icon: Icons.settings_rounded,
                            tooltip: 'Settings',
                            onPressed: () => context.push(Routes.settings),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Semantics(
                        header: true,
                        child: Text('Your peels.', style: PeelType.title()),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        [
                          '${stickers.length} sticker${stickers.length == 1 ? '' : 's'}',
                          if (_packs.isNotEmpty)
                            '${_packs.length} pack${_packs.length == 1 ? '' : 's'}',
                        ].join(' · '),
                        style: PeelType.caption().copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (unsent.isNotEmpty) ...[
                        _SendBar(
                          count: unsent.length,
                          sending: _sending,
                          onSend: _sendNew,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
                if (_packs.isNotEmpty) ...[
                  const _SectionLabel('Packs'),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 168,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: PeelSpace.gutter,
                        ),
                        itemCount: _packs.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, i) {
                          final p = _packs[i];
                          return _PackCard(
                            pack: p,
                            stickers: stickers
                                .where((r) => r.packIdentifier == p.identifier)
                                .toList(),
                            onTap: () => showPackSheet(
                              context,
                              pack: p,
                              stickers: stickers
                                  .where(
                                    (r) => r.packIdentifier == p.identifier,
                                  )
                                  .toList(),
                              onSticker: (r) =>
                                  showStickerDetail(context, ref, r),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                ],
                ..._stickerSections(stickers),
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
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0, 0.55],
                      colors: [
                        PeelColors.paper.withValues(alpha: 0),
                        PeelColors.paper,
                      ],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
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
          padding: const EdgeInsets.fromLTRB(16, 0, 20, 0),
          shape: const StadiumBorder(),
          textStyle: PeelType.label().copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The send icon carries a bubble with how many are waiting.
            SizedBox(
              width: 26,
              height: 22,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Positioned(
                    left: 0,
                    top: 2,
                    child: Icon(Icons.send_rounded, size: 18),
                  ),
                  Positioned(
                    left: 11,
                    top: -7,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: ShapeDecoration(
                        color: WhatsAppColors.onGreen,
                        shape: StadiumBorder(
                          side: BorderSide(
                            color: WhatsAppColors.green,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: PeelColors.white,
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
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                sending ? 'Sending…' : 'Send to WhatsApp',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One sticker on the page: no box around it (its own white edge is the
/// frame), a slight tilt like a sticker pressed on by hand, and a little
/// squash when tapped.
class StickerTile extends StatefulWidget {
  const StickerTile({super.key, required this.record, required this.onTap});

  final StickerRecord record;
  final VoidCallback onTap;

  @override
  State<StickerTile> createState() => _StickerTileState();
}

class _StickerTileState extends State<StickerTile> {
  bool _down = false;

  /// The same small tilt every time for the same sticker, -2.5° to 2.5°.
  double get _tilt {
    final h = widget.record.id.hashCode;
    return ((h % 11) - 5) / 2 * math.pi / 180;
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final moving = record.kind == StickerKind.moving;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.92 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Transform.rotate(
                    angle: _tilt,
                    child: StickerImage(record),
                  ),
                ),
              ),
              if (moving || record.hasSound)
                Positioned(
                  left: 2,
                  bottom: 2,
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
                  top: 2,
                  right: 2,
                  child: Semantics(
                    label: 'Not in WhatsApp yet',
                    child: Container(
                      width: 12,
                      height: 12,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: PeelColors.paper,
                        shape: BoxShape.circle,
                      ),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          color: PeelColors.electric,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
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
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: Color(0xCC111113),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 13, color: PeelColors.white),
    );
  }
}

/// A small uppercase heading over a part of the list.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        PeelSpace.gutter + 4,
        8,
        PeelSpace.gutter,
        8,
      ),
      sliver: SliverToBoxAdapter(
        child: SizedBox(
          height: 32,
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    text.toUpperCase(),
                    style: PeelType.caption().copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One pack: its first four stickers, its name and how many it holds.
class _PackCard extends StatelessWidget {
  const _PackCard({
    required this.pack,
    required this.stickers,
    required this.onTap,
  });

  final PackEntry pack;
  final List<StickerRecord> stickers;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = stickers.length;
    return Semantics(
      button: true,
      label: '${pack.name}, $count sticker${count == 1 ? '' : 's'}',
      excludeSemantics: true,
      child: Material(
        color: PeelColors.surface,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: SizedBox(
            width: 132,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 100,
                    child: GridView.count(
                      crossAxisCount: 2,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                      children: [
                        for (final r in stickers.take(4))
                          StickerImage(r, size: 48),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    pack.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PeelType.label().copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '$count sticker${count == 1 ? '' : 's'}',
                    style: PeelType.caption().copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A pack's stickers in a bottom sheet.
Future<void> showPackSheet(
  BuildContext context, {
  required PackEntry pack,
  required List<StickerRecord> stickers,
  required void Function(StickerRecord) onSticker,
}) {
  final n = stickers.length;
  return showPeelSheet<void>(
    context,
    (ctx) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(ctx).height * 0.8,
      ),
      child: PeelSheet(
        title: pack.name,
        subtitle: '$n sticker${n == 1 ? '' : 's'} · In WhatsApp',
        child: Flexible(
          child: GridView.count(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 8),
            crossAxisCount: 3,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            children: [
              for (final r in stickers)
                StickerTile(
                  record: r,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onSticker(r);
                  },
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
