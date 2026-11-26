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
import '../../whatsapp/pack_models.dart';
import '../create/start.dart';
import '../export/pack_picker.dart';
import '../export/sticker_image.dart';
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

  /// The pack being looked at, or null for all stickers.
  String? _packFilter;

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
    setState(() {
      _packs = packs;
      if (!packs.any((p) => p.identifier == _packFilter)) _packFilter = null;
    });
  }

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
      last = await exporter.send(
        batch,
        packIdentifier: choice.identifier,
        newPackName: choice.name,
      );
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

  /// The sticker grid: one pack's stickers when a pack is picked,
  /// otherwise all of them under date headings.
  List<Widget> _stickerSections(List<StickerRecord> stickers) {
    final filter = _packFilter;
    if (filter != null) {
      final pack = _packs.firstWhere((p) => p.identifier == filter);
      return [
        _SectionLabel(
          pack.name,
          action: TextButton(
            onPressed: () => setState(() => _packFilter = null),
            child: const Text('Show all'),
          ),
        ),
        _grid(stickers.where((r) => r.packIdentifier == filter).toList()),
      ];
    }
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
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: [
        for (final r in records)
          _Tile(record: r, onTap: () => showStickerDetail(context, ref, r)),
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
                            selected: _packFilter == p.identifier,
                            onTap: () => setState(
                              () => _packFilter = _packFilter == p.identifier
                                  ? null
                                  : p.identifier,
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
            const Icon(Icons.send_rounded, size: 18),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                sending ? 'Sending…' : 'Send $count new to WhatsApp',
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

/// A small uppercase heading over a part of the list.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.action});

  final String text;
  final Widget? action;

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
              ?action,
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
    required this.selected,
    required this.onTap,
  });

  final PackEntry pack;
  final List<StickerRecord> stickers;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = stickers.length;
    return Semantics(
      button: true,
      selected: selected,
      label: '${pack.name}, $count sticker${count == 1 ? '' : 's'}',
      excludeSemantics: true,
      child: Material(
        color: PeelColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected ? PeelColors.ink : PeelColors.surface,
            width: 2,
          ),
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
