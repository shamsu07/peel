import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_state.dart';
import '../../core/design/tokens.dart';
import '../../core/error_log.dart';
import '../../core/design/typography.dart';
import '../../core/routing/routes.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/pill_buttons.dart';
import '../../create/drafts.dart';
import '../../create/maker.dart';
import '../../sticker_engine/caption.dart';

/// "Making it.": the video sticker being encoded (canvas: Making).
class MakingScreen extends ConsumerStatefulWidget {
  const MakingScreen({super.key});

  @override
  ConsumerState<MakingScreen> createState() => _MakingScreenState();
}

class _MakingScreenState extends ConsumerState<MakingScreen> {
  VideoMaking? _making;
  MakingUpdate _update = const MakingUpdate(MakingStage.framing, 0);
  Uint8List? _frame;
  String? _error;
  final _watch = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final draft = ref.read(videoDraftProvider);
    if (draft == null) return;
    final native = ref.read(nativeProvider);
    native.videoThumbnail(draft.path, draft.startMs, 480).then((b) {
      if (mounted) setState(() => _frame = b);
    });
    final library = await ref.read(libraryStoreProvider.future);
    if (!mounted) return;
    _making = VideoMaking.start(
      draft: draft,
      library: library,
      native: native,
      onUpdate: (u) {
        if (mounted) setState(() => _update = u);
      },
      onDone: (record) async {
        await ref.read(libraryProvider.notifier).reload();
        ref.read(videoDraftProvider.notifier).clear();
        if (!mounted) return;
        context.go(Routes.home);
        context.push(Routes.ready(record.id));
      },
      onError: (e) {
        ErrorLog.record('make video sticker', e);
        if (mounted) setState(() => _error = '$e');
      },
    );
  }

  @override
  void dispose() {
    _making?.cancel();
    super.dispose();
  }

  void _cancel() {
    _making?.cancel();
    Navigator.of(context).maybePop();
  }

  String _eta() {
    final f = _update.fraction;
    if (f < 0.08) return 'Getting started';
    final total = _watch.elapsedMilliseconds / f;
    final left = ((total - _watch.elapsedMilliseconds) / 1000).ceil();
    return left <= 1 ? 'Almost done' : 'About $left seconds left';
  }

  @override
  Widget build(BuildContext context) {
    final pct = (_update.fraction * 100).round();
    final stage = _update.stage;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            PeelSpace.gutter,
            8,
            PeelSpace.gutter,
            20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PeelHeader(title: 'Video sticker', close: true, onBack: _cancel),
              const SizedBox(height: 24),
              Center(
                child: Container(
                  width: 236,
                  height: 236,
                  decoration: ShapeDecoration(
                    color: PeelPairs.lilac.fill,
                    shadows: PeelShadows.card,
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(32),
                      side: BorderSide(color: PeelColors.white, width: 6),
                    ),
                  ),
                  child: ClipRSuperellipse(
                    borderRadius: BorderRadius.circular(26),
                    child: _StickerFrame(
                      frame: _frame,
                      draft: ref.read(videoDraftProvider),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Text(
                _error == null ? 'Making it.' : 'That didn’t work.',
                style: PeelType.title(size: 54),
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                PeelNote(
                  pair: PeelPairs.bubblegum,
                  text: 'We couldn’t make a sticker from this clip. Try a different part of the video, or another video.',
                ),
              ] else ...[
                Semantics(
                  label: 'Making your sticker',
                  value: '$pct%',
                  child: ClipRSuperellipse(
                    borderRadius: BorderRadius.circular(7),
                    child: LinearProgressIndicator(
                      value: _update.fraction,
                      minHeight: 14,
                      color: PeelColors.ink,
                      backgroundColor: PeelColors.track,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _eta(),
                      style: PeelType.caption().copyWith(fontSize: 14),
                    ),
                    Text(
                      '$pct%',
                      style: PeelType.label().copyWith(fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _Step(
                  text: 'Trimmed and cropped square',
                  state: stage == MakingStage.framing
                      ? _StepState.now
                      : _StepState.done,
                ),
                _Step(
                  text: _update.attempt > 1
                      ? 'Squeezing it under WhatsApp’s size limit (try ${_update.attempt})'
                      : 'Squeezing it under WhatsApp’s size limit',
                  state: switch (stage) {
                    MakingStage.framing => _StepState.todo,
                    MakingStage.squeezing => _StepState.now,
                    _ => _StepState.done,
                  },
                ),
                _Step(
                  text: stage == MakingStage.sound
                      ? 'Preparing the sound version'
                      : 'Final check',
                  state:
                      stage == MakingStage.checking ||
                          stage == MakingStage.sound
                      ? _StepState.now
                      : _StepState.todo,
                ),
              ],
              const Spacer(),
              SecondaryPillButton(
                label: _error == null ? 'Cancel' : 'Back to the editor',
                onPressed: _cancel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _StepState { done, now, todo }

class _Step extends StatelessWidget {
  const _Step({required this.text, required this.state});

  final String text;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final icon = switch (state) {
      _StepState.done => Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: PeelPairs.mint.fill,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.check_rounded, size: 16, color: PeelPairs.mint.ink),
      ),
      _StepState.now => Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: PeelColors.ink, width: 3),
        ),
        child: Center(
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: PeelColors.ink,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
      _StepState.todo => Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFC4C4CC), width: 2),
        ),
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style:
                  PeelType.body(
                    color: state == _StepState.now
                        ? PeelColors.ink
                        : PeelColors.muted,
                  ).copyWith(
                    fontSize: 15,
                    fontWeight: state == _StepState.now
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The first frame as the sticker will look: your framing, with your text.
class _StickerFrame extends StatelessWidget {
  const _StickerFrame({required this.frame, required this.draft});

  final Uint8List? frame;
  final VideoDraft? draft;

  @override
  Widget build(BuildContext context) {
    final d = draft;
    final bytes = frame;
    if (d == null || bytes == null) return const SizedBox();
    return LayoutBuilder(
      builder: (context, box) {
        final inner = box.maxWidth;
        final w = d.info.width.toDouble();
        final h = d.info.height.toDouble();
        final scale = inner / (math.min(w, h) * d.crop.size);
        final vw = w * scale;
        final vh = h * scale;
        return Stack(
          children: [
            Positioned(
              left: -d.crop.left * vw,
              top: -d.crop.top * vh,
              width: vw,
              height: vh,
              child: Image.memory(
                bytes,
                fit: BoxFit.fill,
                gaplessPlayback: true,
              ),
            ),
            if (d.caption case final caption?)
              Positioned.fill(
                child: CustomPaint(painter: CaptionPainter(caption)),
              ),
          ],
        );
      },
    );
  }
}
