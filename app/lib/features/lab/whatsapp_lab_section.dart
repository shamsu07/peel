import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/widgets/peel_segmented.dart';
import '../../core/widgets/pill_buttons.dart';
import '../../sticker_engine/compressor.dart';
import '../../sticker_engine/render.dart';
import '../../sticker_engine/sticker_check.dart';
import '../../whatsapp/bonus_stickers.dart';
import '../../whatsapp/pack_models.dart';
import '../../whatsapp/pack_store.dart';
import '../../whatsapp/whatsapp_bridge.dart';
import 'synthetic_clip.dart';

/// Encodes a 3 s test cartoon on a background isolate.
///
/// Top-level on purpose: a closure created inside a State method captures
/// the State, which can't be sent to an isolate.
Future<Uint8List> encodeTestMovingSticker() => Isolate.run(
  () async => (await AnimatedCompressor().compress(
    SyntheticClip(duration: const Duration(seconds: 3), detailed: false),
  )).bytes,
);

/// Phase 0 checks for the WhatsApp bridge (spec Q-E2, Q-E5).
///
/// One kind at a time (still or moving), one pack card that shows exactly
/// what WhatsApp will receive, and two actions: make a test sticker, send.
class WhatsAppLabSection extends StatefulWidget {
  const WhatsAppLabSection({super.key});

  @override
  State<WhatsAppLabSection> createState() => _WhatsAppLabSectionState();
}

class _Thumb {
  const _Thumb(this.bytes, this.bonus);

  final Uint8List bytes;
  final bool bonus;
}

class _WhatsAppLabSectionState extends State<WhatsAppLabSection> {
  final _bridge = WhatsAppBridge();
  PackStore? _store;
  WhatsAppStatus? _status;
  StickerKind _kind = StickerKind.still;
  PackEntry? _pack;
  List<_Thumb> _thumbs = const [];
  final _log = <String>[];

  /// Packs sent this session, by identifier. On iPhone a second send adds a
  /// duplicate pack in WhatsApp, so we warn before it happens.
  final _sent = <String>{};
  String? _busyLabel;
  int _made = 0;

  bool get _busy => _busyLabel != null;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<PackStore> _openStore() async =>
      _store ??= await PackStore.open(bonus: DrawnBonusSource());

  Future<void> _refresh() async {
    final store = await _openStore();
    final packs = (await store.load()).packs.where((p) => p.kind == _kind);
    final pack = packs.isEmpty ? null : packs.last;
    final thumbs = <_Thumb>[];
    if (pack != null) {
      for (final s in pack.stickers) {
        final file = store.stickerFile(pack.identifier, s.imageFile);
        if (await file.exists()) {
          thumbs.add(_Thumb(await file.readAsBytes(), s.bonus));
        }
      }
    }
    WhatsAppStatus? status;
    try {
      status = await _bridge.status(identifier: pack?.identifier);
    } catch (e) {
      _note('Could not check WhatsApp: $e');
    }
    if (!mounted) return;
    setState(() {
      _pack = pack;
      _thumbs = thumbs;
      _status = status;
    });
  }

  void _note(String line) {
    if (!mounted) return;
    setState(() => _log.insert(0, line));
  }

  Future<void> _guard(String label, Future<void> Function() job) async {
    setState(() => _busyLabel = label);
    try {
      await job();
    } catch (e) {
      _note('Error: $e');
    } finally {
      if (mounted) setState(() => _busyLabel = null);
      await _refresh();
    }
  }

  Future<void> _makeSticker() => _guard('Making…', () async {
    final store = await _openStore();
    final variant = _made++;
    final clip = SyntheticClip(
      duration: const Duration(seconds: 3),
      detailed: false,
    );
    final firstFrame = clip.render(variant * 700);
    final tray = await trayPngFromRgba(firstFrame, clip.size);
    final webp = _kind == StickerKind.still
        ? StaticCompressor().compress(firstFrame, clip.size).bytes
        : await encodeTestMovingSticker();

    final pack = await store.addSticker(
      webp: webp,
      kind: _kind,
      trayPng: tray,
      accessibilityText: 'Lilac face test sticker',
    );
    _note(
      'Added to ${pack.name}: ${pack.userStickers.length} yours + '
      '${pack.bonusCount} bonus',
    );
  });

  Future<void> _send() => _guard('Opening WhatsApp…', () async {
    final pack = _pack;
    if (pack == null) return;
    final store = await _openStore();
    final result = await _bridge.addPack(store, pack);
    if (result.outcome == AddPackOutcome.added ||
        result.outcome == AddPackOutcome.sentToWhatsApp) {
      _sent.add(pack.identifier);
    }
    _note('Sent ${pack.name} (${_countLabel(pack)}): ${_describe(result)}');
  });

  Future<void> _clear() => _guard('Clearing…', () async {
    final store = await _openStore();
    await store.clearAll();
    _sent.clear();
    _note(
      'Cleared all test packs from this app. Packs already in '
      'WhatsApp stay there until removed in WhatsApp.',
    );
  });

  static String _countLabel(PackEntry pack) =>
      '${pack.userStickers.length} yours + ${pack.bonusCount} bonus';

  static String _describe(AddPackResult r) => switch (r.outcome) {
    AddPackOutcome.added => 'added in WhatsApp',
    AddPackOutcome.sentToWhatsApp => 'handed to WhatsApp',
    AddPackOutcome.cancelled => 'cancelled in WhatsApp',
    AddPackOutcome.rejected =>
      'WhatsApp refused it: ${r.message ?? 'no reason'}',
    AddPackOutcome.notInstalled => 'WhatsApp is not installed',
    AddPackOutcome.invalid => 'not sent, pack problems: ${r.problems}',
  };

  @override
  Widget build(BuildContext context) {
    final pack = _pack;
    final resendOnIOS =
        Platform.isIOS && pack != null && _sent.contains(pack.identifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('WhatsApp bridge.', style: PeelType.title(size: 32)),
        const SizedBox(height: 10),
        _StatusRow(status: _status),
        const SizedBox(height: 18),
        PeelSegmented<StickerKind>(
          semanticLabel: 'Sticker type',
          options: const [
            SegmentOption(StickerKind.still, 'Still'),
            SegmentOption(StickerKind.moving, 'Moving'),
          ],
          selected: _kind,
          onChanged: (kind) {
            setState(() => _kind = kind);
            _refresh();
          },
        ),
        const SizedBox(height: 14),
        _PackCard(
          kind: _kind,
          pack: pack,
          thumbs: _thumbs,
          inWhatsApp: _status?.consumerHasPack,
        ),
        const SizedBox(height: 14),
        SecondaryPillButton(
          label: _busyLabel == 'Making…' ? 'Making…' : 'Make a test sticker',
          leading: const Icon(Icons.add_rounded, size: 20),
          onPressed: _busy ? null : _makeSticker,
        ),
        const SizedBox(height: 10),
        PrimaryPillButton(
          label: _busyLabel == 'Opening WhatsApp…'
              ? 'Opening WhatsApp…'
              : 'Send to WhatsApp',
          trailing: const Icon(Icons.north_east_rounded, size: 20),
          onPressed: _busy || pack == null ? null : _send,
        ),
        if (resendOnIOS) ...[
          const SizedBox(height: 10),
          const _Note(
            'Already sent. On iPhone, sending again adds a second copy of '
            'this pack in WhatsApp; it does not update the first one.',
          ),
        ],
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _busy ? null : _clear,
            style: TextButton.styleFrom(
              foregroundColor: PeelColors.mutedStrong,
              minimumSize: const Size(0, PeelSpace.minTouch),
            ),
            child: Text(
              'Clear test packs',
              style: PeelType.caption(color: PeelColors.mutedStrong).copyWith(
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
        if (_log.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Activity', style: PeelType.label()),
          const SizedBox(height: 8),
          for (final line in _log)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(line, style: PeelType.caption()),
            ),
        ],
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.status});

  final WhatsAppStatus? status;

  @override
  Widget build(BuildContext context) {
    final s = status;
    if (s == null) {
      return Text('Checking WhatsApp…', style: PeelType.body());
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Chip(label: 'WhatsApp', ok: s.consumerInstalled),
        _Chip(label: 'WhatsApp Business', ok: s.businessInstalled),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final pair = ok ? PeelPairs.mint : null;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: pair?.fill ?? PeelColors.track,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ok ? Icons.check_rounded : Icons.remove_rounded,
              size: 16,
              color: pair?.ink ?? PeelColors.mutedStrong,
            ),
            const SizedBox(width: 6),
            Text(
              ok ? label : '$label not installed',
              style: PeelType.caption(
                color: pair?.ink ?? PeelColors.mutedStrong,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// What WhatsApp will receive: the pack's real stickers, bonus ones tagged.
class _PackCard extends StatelessWidget {
  const _PackCard({
    required this.kind,
    required this.pack,
    required this.thumbs,
    required this.inWhatsApp,
  });

  final StickerKind kind;
  final PackEntry? pack;
  final List<_Thumb> thumbs;
  final bool? inWhatsApp;

  @override
  Widget build(BuildContext context) {
    final p = pack;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        color: PeelColors.surface,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(PeelRadii.tile),
        ),
      ),
      child: p == null
          ? Text(
              'No ${kind == StickerKind.still ? 'still' : 'moving'} stickers '
              'yet. Make one and it gets a pack, filled with 2 bonus '
              'stickers so WhatsApp accepts it.',
              style: PeelType.body(),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(p.name, style: PeelType.label())),
                    if (inWhatsApp != null)
                      Text(
                        inWhatsApp! ? 'In WhatsApp' : 'Not in WhatsApp yet',
                        style: PeelType.caption(),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${p.userStickers.length} yours + ${p.bonusCount} bonus',
                  style: PeelType.caption(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 72,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: thumbs.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => _ThumbTile(thumb: thumbs[i]),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ThumbTile extends StatelessWidget {
  const _ThumbTile({required this.thumb});

  final _Thumb thumb;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 72,
          height: 72,
          padding: const EdgeInsets.all(6),
          decoration: ShapeDecoration(
            color: PeelColors.paper,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Image.memory(
            thumb.bytes,
            gaplessPlayback: true,
            semanticLabel: thumb.bonus ? 'Bonus sticker' : 'Your sticker',
          ),
        ),
        if (thumb.bonus)
          Positioned(
            left: 4,
            bottom: 4,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: PeelColors.surface,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                child: Text(
                  'BONUS',
                  style: PeelType.tag(color: PeelColors.mutedStrong)
                      .copyWith(fontSize: 9),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final pair = PeelPairs.butter;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: ShapeDecoration(
        color: pair.fill,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Text(text, style: PeelType.caption(color: pair.ink)),
    );
  }
}
