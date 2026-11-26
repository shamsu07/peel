import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_state.dart';
import '../../core/design/tokens.dart';
import '../../core/error_log.dart';
import '../../core/design/typography.dart';
import '../../core/routing/routes.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/peel_segmented.dart';
import '../../core/widgets/pill_buttons.dart';
import '../../core/widgets/tool_tile.dart';
import '../../create/drafts.dart';
import '../../library/sticker_record.dart';
import '../../create/maker.dart';
import '../../sticker_engine/caption.dart';
import '../../sticker_engine/composer.dart';
import '../sound/sound_play_button.dart';
import '../sound/sound_sheet.dart';

/// Photo sticker editor (canvas: Photo sticker).
class PhotoEditorScreen extends ConsumerStatefulWidget {
  const PhotoEditorScreen({super.key});

  @override
  ConsumerState<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends ConsumerState<PhotoEditorScreen> {
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Captions paint on a canvas, so wait for their fonts, then repaint.
    Caption.ensureFontsLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _addSound(
    PhotoDraft draft, {
    SoundStart start = SoundStart.choose,
  }) async {
    final sound = await showSoundSheet(
      context,
      current: draft.sound,
      start: start,
    );
    if (sound == null || !mounted) return;
    ref
        .read(photoDraftProvider.notifier)
        .update((d) => d.copyWith(sound: sound));
  }

  /// With a sound already added: record again, pick a file, or remove it.
  Future<void> _soundOptions(PhotoDraft draft) async {
    final choice = await showPeelSheet<String>(
      context,
      (ctx) => PeelSheet(
        title: 'Sound.',
        subtitle:
            '${draft.sound?.label ?? 'Your sound'}, ${((draft.sound?.durationMs ?? 0) / 1000).toStringAsFixed(1)} s',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (id, icon, label) in const [
              ('record', Icons.mic_none_rounded, 'Record again'),
              ('file', Icons.music_note_outlined, 'Pick a file'),
              ('remove', Icons.delete_outline_rounded, 'Remove sound'),
            ])
              ListTile(
                leading: Icon(icon, color: PeelColors.ink),
                title: Text(label, style: PeelType.label()),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onTap: () => Navigator.of(ctx).pop(id),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'record':
        await _addSound(draft, start: SoundStart.record);
      case 'file':
        await _addSound(draft, start: SoundStart.file);
      case 'remove':
        ref
            .read(photoDraftProvider.notifier)
            .update((d) => d.copyWith(clearSound: true));
    }
  }

  Future<void> _save(PhotoDraft draft) async {
    setState(() => _saving = true);
    try {
      final record = await savePhotoSticker(
        draft: draft,
        library: await ref.read(libraryStoreProvider.future),
        native: ref.read(nativeProvider),
      );
      await ref.read(libraryProvider.notifier).reload();
      if (!mounted) return;
      final old = ref.read(photoDraftProvider);
      ref.read(photoDraftProvider.notifier).clear();
      disposeDraftImages(old);
      context.pushReplacement(Routes.ready(record.id));
    } catch (e, st) {
      await ErrorLog.record('save photo sticker', e, st);
      if (mounted) {
        showPeelSnack(context, 'Couldn’t save the sticker. Please try again.');
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(photoDraftProvider);
    if (draft == null) {
      return const Scaffold(body: SizedBox());
    }
    final c = draft.composition;
    final notifier = ref.read(photoDraftProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  PeelSpace.gutter,
                  8,
                  PeelSpace.gutter,
                  16,
                ),
                children: [
                  const PeelHeader(title: 'Photo sticker'),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 300,
                    child: Checkerboard(
                      child: Stack(
                        children: [
                          Center(
                            child: SizedBox.square(
                              dimension: 264,
                              child: Semantics(
                                image: true,
                                label: c.usesCutout
                                    ? 'Your photo, cut out as a sticker'
                                    : 'Your whole photo as a sticker',
                                child: _Framing(
                                  composition: c,
                                  onChanged: (next) => notifier.update(
                                    (d) => d.copyWith(composition: next),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (draft.sound?.path != null)
                            Positioned(
                              right: 14,
                              bottom: 14,
                              child: SoundPlayButton(
                                key: ValueKey(draft.sound!.path),
                                path: draft.sound!.path!,
                                startMs: draft.sound!.startMs,
                                durationMs: draft.sound!.durationMs,
                              ),
                            ),
                          if (c.usesCutout)
                            Positioned(
                              top: 14,
                              left: 14,
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(8, 6, 11, 6),
                                decoration: BoxDecoration(
                                  color: PeelColors.ink,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.auto_awesome,
                                      size: 14,
                                      color: PeelColors.surface,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Background removed',
                                      style: PeelType.caption(
                                        color: PeelColors.surface,
                                      ).copyWith(fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (!draft.hasCutout && draft.segmentStatus != 'skipped') ...[
                    const SizedBox(height: 12),
                    PeelNote(
                      text: switch (draft.segmentStatus) {
                        'modelDownloading' => 'The cut-out tool is still downloading to your phone, so we kept the whole photo. Try again in a minute.',
                        'noSubject' => 'We couldn’t spot a clear subject, so we kept the whole photo.',
                        _ => 'The cut-out didn’t work on this photo, so we kept the whole photo.',
                      },
                    ),
                  ],
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Pinch to zoom, drag to move. Double-tap to reset.',
                      style: PeelType.caption(),
                    ),
                  ),
                  const SizedBox(height: 10),

                  const Center(
                    child: ReadyPill(
                      checks: [
                        'Square, 512 × 512',
                        'Small enough for WhatsApp',
                        'See-through background',
                        'Tagged so it shows up in search',
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  PeelSegmented<CutMode>(
                    semanticLabel: 'Background',
                    options: [
                      SegmentOption(
                        CutMode.cutout,
                        draft.hasCutout ? 'Cut-out' : 'Cut-out (none)',
                      ),
                      const SegmentOption(CutMode.whole, 'Whole photo'),
                    ],
                    selected: c.usesCutout ? CutMode.cutout : CutMode.whole,
                    onChanged: (m) {
                      if (m == CutMode.cutout && !draft.hasCutout) return;
                      notifier.update(
                        (d) => d.copyWith(
                          composition: d.composition.copyWith(mode: m),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ToolTile(
                          label: 'White edge',
                          selected: c.whiteEdge,
                          icon: c.whiteEdge
                              ? Icons.toggle_on_rounded
                              : Icons.toggle_off_outlined,
                          onTap: () => notifier.update(
                            (d) => d.copyWith(
                              composition: d.composition.copyWith(
                                whiteEdge: !c.whiteEdge,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ToolTile(
                          label: c.caption == null ? 'Add text' : 'Edit text',
                          selected: c.caption != null,
                          icon: Icons.text_fields_rounded,
                          badge: c.caption == null
                              ? ToolBadge.add
                              : ToolBadge.edit,
                          onTap: () => context.push(Routes.photoText),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ToolTile(
                          label: draft.sound == null
                              ? 'Add sound'
                              : 'Change sound',
                          selected: draft.sound != null,
                          icon: switch (draft.sound?.origin) {
                            null => Icons.volume_up_rounded,
                            SoundOrigin.recording => Icons.mic_rounded,
                            _ => Icons.music_note_rounded,
                          },
                          badge: draft.sound == null
                              ? ToolBadge.add
                              : ToolBadge.edit,
                          onTap: () => draft.sound == null
                              ? _addSound(draft)
                              : _soundOptions(draft),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                PeelSpace.gutter,
                4,
                PeelSpace.gutter,
                20,
              ),
              child: PrimaryPillButton(
                label: _saving ? 'Saving…' : 'Save sticker',
                onPressed: _saving ? null : () => _save(draft),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pinch to zoom, drag to move, double-tap to reset.
class _Framing extends StatefulWidget {
  const _Framing({required this.composition, required this.onChanged});

  final PhotoComposition composition;
  final ValueChanged<PhotoComposition> onChanged;

  @override
  State<_Framing> createState() => _FramingState();
}

class _FramingState extends State<_Framing> {
  double _startZoom = 1;

  @override
  Widget build(BuildContext context) {
    final c = widget.composition;
    return LayoutBuilder(
      builder: (context, box) => GestureDetector(
        onScaleStart: (_) => _startZoom = c.zoom,
        onScaleUpdate: (e) {
          var next = widget.composition.dragBy(e.focalPointDelta, box.maxWidth);
          if (e.pointerCount > 1) {
            next = next.copyWith(zoom: _startZoom * e.scale);
          }
          widget.onChanged(next);
        },
        onDoubleTap: () =>
            widget.onChanged(c.copyWith(zoom: 1, pan: Offset.zero)),
        child: RepaintBoundary(
          child: CustomPaint(painter: _CompositionPainter(c)),
        ),
      ),
    );
  }
}

class _CompositionPainter extends CustomPainter {
  const _CompositionPainter(this.composition);

  final PhotoComposition composition;

  @override
  void paint(Canvas canvas, Size size) => composition.paint(canvas, size);

  @override
  bool shouldRepaint(covariant _CompositionPainter old) => true;
}
