import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import '../../app_state.dart';
import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/routing/routes.dart';
import '../../core/widgets/common.dart';
import '../../create/drafts.dart';
import '../../sticker_engine/composer.dart';
import '../../sticker_engine/render.dart';

/// "Peeling…": the photo while the background is removed (canvas: Peeling).
class PeelingScreen extends ConsumerStatefulWidget {
  const PeelingScreen({super.key, required this.imagePath});

  final String imagePath;

  @override
  ConsumerState<PeelingScreen> createState() => _PeelingScreenState();
}

class _PeelingScreenState extends ConsumerState<PeelingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  ui.Image? _original;
  bool _skipped = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _sweep.stop();
    } else if (!_sweep.isAnimating) {
      _sweep.repeat();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    if (!_done) _original?.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final native = ref.read(nativeProvider);
    native.prepareSegmenter();
    final original = await decodeImage(
      await File(widget.imagePath).readAsBytes(),
      maxSide: 1280,
    );
    if (!mounted) {
      original.dispose();
      return;
    }
    setState(() => _original = original);

    final tmp = await getTemporaryDirectory();
    final outPath =
        '${tmp.path}/cutout_${DateTime.now().microsecondsSinceEpoch}.png';
    var status = 'error';
    ui.Image? cutout;
    (ui.Image, double)? edged;
    try {
      final result = await native.segmentSubject(
        widget.imagePath,
        outPath,
        1280,
      );
      status = result.status;
      if (result.status == 'ok' && result.path != null) {
        final file = File(result.path!);
        cutout = await decodeImage(await file.readAsBytes(), maxSide: 1280);
        // The PNG has done its job; don't leave it in temp.
        file.delete().ignore();
        edged = await PhotoComposition.buildEdged(cutout);
      }
    } catch (_) {
      status = 'error';
    }
    if (!mounted || _skipped) {
      cutout?.dispose();
      edged?.$1.dispose();
      return;
    }
    _finish(cutout, status, edged);
  }

  void _finish(ui.Image? cutout, String status, [(ui.Image, double)? edged]) {
    final original = _original;
    if (original == null || _done) return;
    _done = true;
    ref
        .read(photoDraftProvider.notifier)
        .start(
          PhotoDraft(
            sourcePath: widget.imagePath,
            segmentStatus: status,
            composition: PhotoComposition(
              original: original,
              cutout: cutout,
              // The white edge drawn once, so framing draws one image
              // per frame instead of 25.
              edgedCutout: edged?.$1,
              edgePad: edged?.$2 ?? 0,
              mode: cutout == null ? CutMode.whole : CutMode.cutout,
            ),
          ),
        );
    context.pushReplacement(Routes.photo);
  }

  void _skip() {
    _skipped = true;
    _finish(null, 'skipped');
  }

  @override
  Widget build(BuildContext context) {
    final image = _original;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            PeelSpace.gutter,
            8,
            PeelSpace.gutter,
            30,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PeelHeader(title: 'Photo sticker'),
              const SizedBox(height: 14),
              Expanded(
                flex: 0,
                child: SizedBox(
                  height: 300,
                  child: ClipRSuperellipse(
                    borderRadius: BorderRadius.circular(28),
                    child: ColoredBox(
                      color: PeelColors.surface,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (image != null)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: ClipRSuperellipse(
                                borderRadius: BorderRadius.circular(18),
                                child: RawImage(
                                  image: image,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          AnimatedBuilder(
                            animation: _sweep,
                            builder: (context, _) => FractionalTranslation(
                              translation: Offset(-1.4 + 3 * _sweep.value, 0),
                              child: Transform.rotate(
                                angle: 0.3,
                                child: const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0x00FFFFFF),
                                        Color(0x8CFFFFFF),
                                        Color(0x00FFFFFF),
                                      ],
                                    ),
                                  ),
                                  child: SizedBox(width: 90),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 16,
                            left: 16,
                            child: Transform.rotate(
                              angle: -0.05,
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(9, 7, 12, 7),
                                decoration: ShapeDecoration(
                                  color: PeelColors.ink,
                                  shape: RoundedSuperellipseBorder(
                                    borderRadius: BorderRadius.circular(999),
                                    side: BorderSide(
                                      color: PeelColors.surface,
                                      width: 3,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.auto_awesome,
                                      size: 14,
                                      color: PeelColors.surface,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Peeling…',
                                      style: PeelType.caption(
                                        color: PeelColors.surface,
                                      ).copyWith(fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Semantics(
                liveRegion: true,
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: PeelColors.ink,
                        backgroundColor: PeelColors.hairline,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Finding the subject',
                      style: PeelType.label().copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text('Done in a second', style: PeelType.caption()),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: TextButton(
                  onPressed: image == null ? null : _skip,
                  style: TextButton.styleFrom(
                    foregroundColor: PeelColors.ink,
                    minimumSize: const Size(0, PeelSpace.minTouch),
                  ),
                  child: Text(
                    'Skip, keep the whole photo',
                    style: PeelType.button(color: PeelColors.ink).copyWith(
                      fontSize: 15,
                      decoration: TextDecoration.underline,
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
