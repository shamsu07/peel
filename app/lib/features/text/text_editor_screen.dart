import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_state.dart';
import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/peel_segmented.dart';
import '../../core/widgets/pill_buttons.dart';
import '../../create/drafts.dart';
import '../../sticker_engine/caption.dart';
import '../../sticker_engine/composer.dart';

/// "Add text": sticker fonts and bright colours (canvas: Add text).
class TextEditorScreen extends ConsumerStatefulWidget {
  const TextEditorScreen({super.key, required this.forVideo});

  final bool forVideo;

  @override
  ConsumerState<TextEditorScreen> createState() => _TextEditorScreenState();
}

class _TextEditorScreenState extends ConsumerState<TextEditorScreen> {
  late Caption _caption;
  late final TextEditingController _text;
  Uint8List? _videoFrame;

  @override
  void initState() {
    super.initState();
    final existing = widget.forVideo
        ? ref.read(videoDraftProvider)?.caption
        : ref.read(photoDraftProvider)?.composition.caption;
    _caption = existing ?? const Caption(text: 'who, me?');
    _text = TextEditingController(text: _caption.text);
    Caption.ensureFontsLoaded().then((_) {
      if (mounted) setState(() {});
    });
    if (widget.forVideo) _loadFrame();
  }

  Future<void> _loadFrame() async {
    final d = ref.read(videoDraftProvider);
    if (d == null) return;
    final bytes = await ref
        .read(nativeProvider)
        .videoThumbnail(d.path, d.startMs, 720);
    if (mounted) setState(() => _videoFrame = bytes);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _set(Caption c) => setState(() => _caption = c);

  void _done({bool remove = false}) {
    final caption = remove || _caption.isEmpty ? null : _caption;
    if (widget.forVideo) {
      ref
          .read(videoDraftProvider.notifier)
          .update(
            (d) => caption == null
                ? d.copyWith(clearCaption: true)
                : d.copyWith(caption: caption),
          );
    } else {
      ref
          .read(photoDraftProvider.notifier)
          .update(
            (d) => d.copyWith(
              composition: caption == null
                  ? d.composition.copyWith(clearCaption: true)
                  : d.composition.copyWith(caption: caption),
            ),
          );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.forVideo ? null : ref.watch(photoDraftProvider);
    final crop = widget.forVideo ? ref.watch(videoDraftProvider)?.crop : null;

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
                  PeelHeader(
                    title: 'Add text',
                    trailing: TextButton(
                      onPressed: () => _done(remove: true),
                      style: TextButton.styleFrom(
                        foregroundColor: PeelColors.mutedStrong,
                        minimumSize: const Size(0, PeelSpace.minTouch),
                      ),
                      child: const Text('Remove'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 290,
                    child: Checkerboard(
                      child: Center(
                        child: SizedBox.square(
                          dimension: 264,
                          child: GestureDetector(
                            onVerticalDragUpdate: (d) => _set(
                              _caption.copyWith(
                                centerY: (_caption.centerY + d.delta.dy / 264)
                                    .clamp(0.12, 0.9),
                              ),
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (photo != null)
                                  CustomPaint(
                                    painter: _PhotoPainter(
                                      photo.composition.copyWith(
                                        clearCaption: true,
                                      ),
                                    ),
                                  )
                                else if (_videoFrame != null && crop != null)
                                  ClipRSuperellipse(
                                    borderRadius: BorderRadius.circular(32),
                                    child: Image.memory(
                                      _videoFrame!,
                                      fit: BoxFit.cover,
                                      gaplessPlayback: true,
                                    ),
                                  ),
                                CustomPaint(painter: _CaptionPainter(_caption)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'Drag the text up or down to move it',
                      style: PeelType.caption(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _text,
                    maxLength: 40,
                    textCapitalization: TextCapitalization.sentences,
                    style: PeelType.body(color: PeelColors.ink)
                        .copyWith(fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: 'Your text',
                      filled: true,
                      fillColor: PeelColors.surface,
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) => _set(_caption.copyWith(text: v)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final f in CaptionFont.values) ...[
                        Expanded(
                          child: _FontTile(
                            font: f,
                            selected: _caption.font == f,
                            onTap: () => _set(_caption.copyWith(font: f)),
                          ),
                        ),
                        if (f != CaptionFont.values.last)
                          const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    label: 'Colour',
                    container: true,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (final c in StickerTextColors.all)
                          _Swatch(
                            color: c,
                            selected:
                                _caption.color.toARGB32() == c.color.toARGB32(),
                            onTap: () =>
                                _set(_caption.copyWith(color: c.color)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  PeelSegmented<CaptionLook>(
                    semanticLabel: 'Text style',
                    options: const [
                      SegmentOption(CaptionLook.outline, 'White outline'),
                      SegmentOption(CaptionLook.block, 'Colour block'),
                    ],
                    selected: _caption.look,
                    onChanged: (l) => _set(_caption.copyWith(look: l)),
                  ),
                  const SizedBox(height: 10),
                  PeelSegmented<CaptionSize>(
                    semanticLabel: 'Text size',
                    options: const [
                      SegmentOption(CaptionSize.regular, 'Regular size'),
                      SegmentOption(CaptionSize.big, 'Big'),
                    ],
                    selected: _caption.size,
                    onChanged: (v) => _set(_caption.copyWith(size: v)),
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
              child: PrimaryPillButton(label: 'Done', onPressed: () => _done()),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPainter extends CustomPainter {
  const _PhotoPainter(this.c);

  final PhotoComposition c;

  @override
  void paint(Canvas canvas, Size size) => c.paint(canvas, size);

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

class _CaptionPainter extends CustomPainter {
  const _CaptionPainter(this.caption);

  final Caption caption;

  @override
  void paint(Canvas canvas, Size size) => caption.paint(canvas, size);

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

class _FontTile extends StatelessWidget {
  const _FontTile({
    required this.font,
    required this.selected,
    required this.onTap,
  });

  final CaptionFont font;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      label: '${font.label} font',
      excludeSemantics: true,
      child: Material(
        color: PeelColors.surface,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? PeelColors.ink : PeelColors.surface,
            width: 2,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: SizedBox(
            height: 72,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Aa', style: font.style(size: 24, color: PeelColors.ink)),
                const SizedBox(height: 2),
                Text(
                  font.label,
                  style: PeelType.caption(color: PeelColors.mutedStrong)
                      .copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final NamedColor color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      label: color.name,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? PeelColors.ink
                  : (color.color.toARGB32() == 0xFFFFFFFF
                        ? PeelColors.hairline
                        : PeelColors.surface),
              width: selected ? 3 : 2,
            ),
            boxShadow: selected
                ? [BoxShadow(color: PeelColors.surface, spreadRadius: -6)]
                : null,
          ),
        ),
      ),
    );
  }
}
