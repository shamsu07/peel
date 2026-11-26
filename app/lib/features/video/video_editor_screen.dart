import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:peel_native/peel_native.dart';
import 'package:video_player/video_player.dart' hide Caption;

import '../../app_state.dart';
import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/routing/routes.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/peel_segmented.dart';
import '../../core/widgets/pill_buttons.dart';
import '../../create/drafts.dart';
import '../../library/sticker_record.dart';
import '../../sticker_engine/caption.dart';
import '../../sticker_engine/background.dart';
import '../../sticker_engine/compressor.dart';
import '../../sticker_engine/whatsapp_rules.dart';
import '../sound/sound_sheet.dart';

/// Video sticker editor (canvas: Video sticker).
class VideoEditorScreen extends ConsumerStatefulWidget {
  const VideoEditorScreen({super.key});

  @override
  ConsumerState<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends ConsumerState<VideoEditorScreen> {
  VideoPlayerController? _player;

  /// Plays "Your sound" in step with the preview.
  final _voice = AudioPlayer();
  String? _voicePath;
  bool _wasPlaying = false;
  final _thumbs = <Uint8List?>[for (var i = 0; i < 10; i++) null];
  int? _lengthBeforeShorten;

  static const _minMs = 500;
  int get _maxMs => WhatsAppStickerRules.maxAnimationDuration.inMilliseconds;

  @override
  void initState() {
    super.initState();
    final d = ref.read(videoDraftProvider);
    if (d == null) return;
    final player = VideoPlayerController.file(File(d.path));
    _player = player;
    player.initialize().then((_) {
      if (!mounted) return;
      player
        ..setVolume(d.soundMode == VideoSoundMode.original ? 1 : 0)
        ..seekTo(Duration(milliseconds: d.startMs))
        ..play();
      player.addListener(_onTick);
      setState(() {});
    });
    _loadThumbs(d);
  }

  Future<void> _loadThumbs(VideoDraft d) async {
    final native = ref.read(nativeProvider);
    for (var i = 0; i < _thumbs.length; i++) {
      final t = (d.info.durationMs * (i + 0.5) / _thumbs.length).round();
      try {
        final bytes = await native.videoThumbnail(d.path, t, 160);
        if (!mounted) return;
        setState(() => _thumbs[i] = bytes);
      } catch (_) {}
    }
  }

  void _onTick() {
    final p = _player;
    if (p == null || !p.value.isInitialized) return;
    if (_loop(p)) {
      _wasPlaying = true;
      return;
    }
    final playing = p.value.isPlaying;
    if (playing && !_wasPlaying) {
      _restartVoice();
    } else if (!playing && _wasPlaying) {
      _voice.pause();
    }
    _wasPlaying = playing;
  }

  bool _jumping = false;

  /// Plays only the trimmed part, over and over, with "Your sound" starting
  /// again from the top each time. True when it jumped back.
  bool _loop(VideoPlayerController p) {
    final d = ref.read(videoDraftProvider);
    if (d == null || _jumping) return _jumping;
    final end = Duration(milliseconds: d.startMs + d.lengthMs);
    final atClipEnd =
        p.value.duration > Duration.zero &&
        p.value.position >= p.value.duration - const Duration(milliseconds: 60);
    if (p.value.position >= end ||
        atClipEnd ||
        p.value.position < Duration(milliseconds: d.startMs - 200)) {
      _jumping = true;
      () async {
        await p.seekTo(Duration(milliseconds: d.startMs));
        // A trim that runs to the very end of the video stops the player.
        if (atClipEnd) await p.play();
        _jumping = false;
        await _restartVoice(fromStart: true);
      }();
      return true;
    }
    return false;
  }

  /// Starts "Your sound" at the point that matches the preview (or stops it
  /// when another sound option is chosen).
  Future<void> _restartVoice({bool fromStart = false}) async {
    final d = ref.read(videoDraftProvider);
    final p = _player;
    final sound = d?.soundMode == VideoSoundMode.replace ? d?.newSound : null;
    final path = sound?.path;
    if (d == null || p == null || sound == null || path == null) {
      await _voice.pause();
      return;
    }
    try {
      if (_voicePath != path) {
        _voicePath = path;
        await _voice.setFilePath(path);
      }
      var offset = fromStart
          ? 0
          : math.max(0, p.value.position.inMilliseconds - d.startMs);
      if (offset >= d.lengthMs) offset = 0;
      // Pause first: after the sound has finished once, play() alone does
      // nothing.
      await _voice.pause();
      await _voice.seek(Duration(milliseconds: sound.startMs + offset));
      if (p.value.isPlaying) _voice.play();
    } catch (_) {
      _voicePath = null;
    }
  }

  @override
  void dispose() {
    _player?.removeListener(_onTick);
    _player?.dispose();
    _voice.dispose();
    super.dispose();
  }

  void _update(VideoDraft Function(VideoDraft) change, {bool seek = false}) {
    ref.read(videoDraftProvider.notifier).update(change);
    if (seek) {
      _player
          ?.seekTo(
            Duration(milliseconds: ref.read(videoDraftProvider)!.startMs),
          )
          .then((_) => _restartVoice());
    }
  }

  Future<void> _newSound(
    VideoDraft d, {
    SoundStart start = SoundStart.choose,
  }) async {
    // Silence the preview while the sound sheet is open, so a recording
    // doesn't pick up the clip's own sound.
    final wasPlaying = _player?.value.isPlaying ?? false;
    await _player?.pause();
    await _voice.pause();
    if (!mounted) return;
    final sound = await showSoundSheet(
      context,
      fixedLengthMs: d.lengthMs,
      start: start,
    );
    if (sound == null) {
      if (wasPlaying && mounted) await _player?.play();
      return;
    }
    _update(
      (d) => d.copyWith(soundMode: VideoSoundMode.replace, newSound: sound),
    );
    _player?.setVolume(0);
    // Play the new sound from the top of the clip.
    await _player?.seekTo(Duration(milliseconds: d.startMs));
    await _player?.play();
    await _restartVoice(fromStart: true);
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(videoDraftProvider);
    if (d == null) return const Scaffold(body: SizedBox());
    final quality = expectedQuality(Duration(milliseconds: d.lengthMs));
    final player = _player;

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
                  const PeelHeader(title: 'Video sticker'),
                  const SizedBox(height: 14),
                  Center(
                    // Only the preview listens to playback; the rest of the
                    // screen doesn't rebuild on every frame.
                    child: ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable:
                          player ??
                          ValueNotifier(VideoPlayerValue.uninitialized()),
                      builder: (context, value, _) {
                        final playing = value.isPlaying;
                        final posMs = math.max(
                          0,
                          value.position.inMilliseconds - d.startMs,
                        );
                        return _CropPreview(
                          draft: d,
                          player: player,
                          onPan: (crop) =>
                              _update((d) => d.copyWith(crop: crop)),
                          label:
                              '${(posMs / 1000).toStringAsFixed(1)} / ${(d.lengthMs / 1000).toStringAsFixed(1)} s',
                          playing: playing,
                          onPlayPause: () =>
                              playing ? player?.pause() : player?.play(),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: _TextTool(
                      hasText: d.caption != null,
                      onTap: () => context.push(Routes.videoText),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Trimmer(
                    draft: d,
                    thumbs: _thumbs,
                    minMs: _minMs,
                    maxMs: _maxMs,
                    onChanged: (start, length) => _update(
                      (d) => d.copyWith(startMs: start, lengthMs: length),
                      seek: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _QualityRow(quality: quality),

                  if (quality == StickerQuality.squeezed &&
                      _lengthBeforeShorten == null) ...[
                    const SizedBox(height: 12),
                    PeelNote(
                      text: 'WhatsApp caps moving stickers at 500 KB, so we’ll squeeze this one to fit. Shorter clips look sharper.',
                      action: SecondaryPillButton(
                        label: 'Make it 4 s and sharper',
                        onPressed: () {
                          setState(() => _lengthBeforeShorten = d.lengthMs);
                          _update(
                            (d) => d.copyWith(lengthMs: 4000),
                            seek: true,
                          );
                        },
                      ),
                    ),
                  ],
                  if (_lengthBeforeShorten != null) ...[
                    const SizedBox(height: 12),
                    PeelNote(
                      pair: PeelPairs.mint,
                      icon: Icons.check_rounded,
                      text: 'Sharper now. Drag the ends to change it.',
                      action: SecondaryPillButton(
                        label: 'Undo',
                        onPressed: () {
                          final back = _lengthBeforeShorten!;
                          setState(() => _lengthBeforeShorten = null);
                          _update(
                            (d) => d.copyWith(
                              lengthMs: math.min(
                                back,
                                d.info.durationMs - d.startMs,
                              ),
                            ),
                            seek: true,
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  PeelSegmented<VideoSoundMode>(
                    semanticLabel: 'Sound',
                    options: [
                      SegmentOption(
                        VideoSoundMode.original,
                        d.info.hasAudio ? 'Original' : 'No sound',
                      ),
                      SegmentOption(
                        VideoSoundMode.replace,
                        d.newSound == null ? 'New sound' : 'Your sound',
                      ),
                      const SegmentOption(VideoSoundMode.mute, 'Mute'),
                    ],
                    selected: d.soundMode,
                    onChanged: (m) {
                      // Your sound stays with the draft: switching back to it
                      // brings it back instead of asking again.
                      if (m == VideoSoundMode.replace && d.newSound == null) {
                        _newSound(d);
                        return;
                      }
                      _update((d) => d.copyWith(soundMode: m));
                      _player?.setVolume(m == VideoSoundMode.original ? 1 : 0);
                      _restartVoice();
                    },
                  ),
                  const SizedBox(height: 10),
                  _SoundPanel(
                    draft: d,
                    onRecordAgain: () => _newSound(d, start: SoundStart.record),
                    onPickFile: () => _newSound(d, start: SoundStart.file),
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
                label: 'Save sticker',
                onPressed: () {
                  _player?.pause();
                  context.push(Routes.making);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The rounded sticker frame showing the square part of the video. Drag to
/// move the square.
class _CropPreview extends StatefulWidget {
  const _CropPreview({
    required this.draft,
    required this.player,
    required this.onPan,
    required this.label,
    required this.playing,
    required this.onPlayPause,
  });

  final VideoDraft draft;
  final VideoPlayerController? player;
  final ValueChanged<SquareCrop> onPan;
  final String label;
  final bool playing;
  final VoidCallback onPlayPause;

  static const side = 264.0;
  static const inner = side - 12;

  /// Smallest crop: zoomed in to 40% of the short side.
  static const minSize = 0.4;

  @override
  State<_CropPreview> createState() => _CropPreviewState();
}

class _CropPreviewState extends State<_CropPreview> {
  static const inner = _CropPreview.inner;
  double _startSize = 1;

  VideoDraft get draft => widget.draft;
  VideoPlayerController? get player => widget.player;
  String get label => widget.label;
  bool get playing => widget.playing;
  VoidCallback get onPlayPause => widget.onPlayPause;

  /// Moves the square by a drag and/or zooms it, keeping it inside the frame.
  void _apply(Offset delta, double? scale) {
    final w = draft.info.width.toDouble();
    final h = draft.info.height.toDouble();
    final short = math.min(w, h);
    final crop = draft.crop;
    final size = scale == null
        ? crop.size
        : (_startSize / scale).clamp(_CropPreview.minSize, 1.0);
    // Keep the centre where it was while zooming.
    final cx = crop.left * w + crop.size * short / 2;
    final cy = crop.top * h + crop.size * short / 2;
    final px = inner / (short * size); // preview px per video px
    final side = size * short;
    final left = ((cx - side / 2) - delta.dx / px) / w;
    final top = ((cy - side / 2) - delta.dy / px) / h;
    widget.onPan(
      SquareCrop(
        left: left.clamp(0.0, math.max(0.0, 1 - side / w)),
        top: top.clamp(0.0, math.max(0.0, 1 - side / h)),
        size: size,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const side = _CropPreview.side;
    final w = draft.info.width.toDouble();
    final h = draft.info.height.toDouble();
    final crop = draft.crop;
    final scale = inner / (math.min(w, h) * crop.size);
    final vw = w * scale;
    final vh = h * scale;

    return Container(
      width: side,
      height: side,
      decoration: BoxDecoration(
        color: PeelPairs.lilac.fill,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: PeelColors.surface, width: 6),
        boxShadow: PeelShadows.card,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: GestureDetector(
          onScaleStart: (_) => _startSize = draft.crop.size,
          onScaleUpdate: (e) =>
              _apply(e.focalPointDelta, e.pointerCount > 1 ? e.scale : null),
          onDoubleTap: () => widget.onPan(centeredCrop(draft.info)),
          child: Stack(
            children: [
              if (player != null && player!.value.isInitialized)
                Positioned(
                  left: -crop.left * vw,
                  top: -crop.top * vh,
                  width: vw,
                  height: vh,
                  child: VideoPlayer(player!),
                ),
              // Text sits on top exactly as it will on the sticker.
              if (draft.caption case final caption?)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: CaptionPainter(caption)),
                  ),
                ),
              Positioned(
                top: 10,
                left: 10,
                child: _Pill(
                  background: const Color(0xDBFFFFFF),
                  color: PeelPairs.lilac.ink,
                  icon: Icons.open_with_rounded,
                  text: 'Drag or pinch to frame',
                ),
              ),
              Positioned(
                left: 10,
                bottom: 10,
                child: _Pill(
                  background: const Color(0xD1111113),
                  color: PeelColors.surface,
                  text: label,
                ),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: IconButton(
                  tooltip: playing ? 'Pause preview' : 'Play preview',
                  onPressed: onPlayPause,
                  style: IconButton.styleFrom(
                    backgroundColor: PeelColors.surface,
                    fixedSize: const Size.square(44),
                  ),
                  icon: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: PeelColors.ink,
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

class _Pill extends StatelessWidget {
  const _Pill({
    required this.background,
    required this.color,
    required this.text,
    this.icon,
  });

  final Color background;
  final Color color;
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: PeelType.caption(color: color).copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _Trimmer extends StatelessWidget {
  const _Trimmer({
    required this.draft,
    required this.thumbs,
    required this.minMs,
    required this.maxMs,
    required this.onChanged,
  });

  final VideoDraft draft;
  final List<Uint8List?> thumbs;
  final int minMs;
  final int maxMs;
  final void Function(int startMs, int lengthMs) onChanged;

  @override
  Widget build(BuildContext context) {
    final total = draft.info.durationMs;
    return Column(
      children: [
        SizedBox(
          height: 62,
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth;
              final left = draft.startMs / total * w;
              final width = math.max(36.0, draft.lengthMs / total * w);
              int msFor(double dx) => (dx / w * total).round();

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    top: 3,
                    bottom: 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Row(
                        children: [
                          for (final t in thumbs)
                            Expanded(
                              child: t == null
                                  ? ColoredBox(color: PeelPairs.lilac.fill)
                                  : Image.memory(
                                      t,
                                      fit: BoxFit.cover,
                                      height: double.infinity,
                                      gaplessPlayback: true,
                                    ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Dim what's outside the trim.
                  Positioned(
                    left: 0,
                    top: 3,
                    bottom: 3,
                    width: left,
                    child: const ColoredBox(color: Color(0xC7EEEEF0)),
                  ),
                  Positioned(
                    left: left + width,
                    top: 3,
                    bottom: 3,
                    right: 0,
                    child: const ColoredBox(color: Color(0xC7EEEEF0)),
                  ),
                  Positioned(
                    left: left,
                    width: width,
                    top: 0,
                    bottom: 0,
                    child: Semantics(
                      label:
                          'Trimmed to ${(draft.lengthMs / 1000).toStringAsFixed(1)} seconds of ${(total / 1000).toStringAsFixed(1)}',
                      child: GestureDetector(
                        onHorizontalDragUpdate: (e) {
                          final start = (draft.startMs + msFor(e.delta.dx))
                              .clamp(0, total - draft.lengthMs)
                              .toInt();
                          onChanged(start, draft.lengthMs);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: PeelColors.ink, width: 3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _Handle(
                                left: true,
                                onDrag: (dx) {
                                  final end = draft.startMs + draft.lengthMs;
                                  final start = (draft.startMs + msFor(dx))
                                      .clamp(
                                        math.max(0, end - maxMs),
                                        end - minMs,
                                      )
                                      .toInt();
                                  onChanged(start, end - start);
                                },
                              ),
                              _Handle(
                                left: false,
                                onDrag: (dx) {
                                  final end =
                                      (draft.startMs +
                                              draft.lengthMs +
                                              msFor(dx))
                                          .clamp(
                                            draft.startMs + minMs,
                                            math.min(
                                              total,
                                              draft.startMs + maxMs,
                                            ),
                                          )
                                          .toInt();
                                  onChanged(draft.startMs, end - draft.startMs);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0 s', style: PeelType.caption()),
            Text(
              '${(draft.lengthMs / 1000).toStringAsFixed(1)} s',
              style: PeelType.caption(color: PeelColors.ink)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              'whole clip ${(total / 1000).toStringAsFixed(1)} s',
              style: PeelType.caption(),
            ),
          ],
        ),
      ],
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle({required this.left, required this.onDrag});

  final bool left;
  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: left ? 'Start of clip' : 'End of clip',
      slider: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (e) => onDrag(e.delta.dx),
        child: Container(
          width: 22,
          decoration: BoxDecoration(
            color: PeelColors.ink,
            borderRadius: left
                ? const BorderRadius.horizontal(left: Radius.circular(12))
                : const BorderRadius.horizontal(right: Radius.circular(12)),
          ),
          child: Center(
            child: Container(
              width: 3,
              height: 18,
              decoration: BoxDecoration(
                color: PeelColors.surface,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QualityRow extends StatelessWidget {
  const _QualityRow({required this.quality});

  final StickerQuality quality;

  @override
  Widget build(BuildContext context) {
    final level = switch (quality) {
      StickerQuality.sharp => 3,
      StickerQuality.good => 2,
      StickerQuality.squeezed => 1,
    };
    final label = switch (quality) {
      StickerQuality.sharp => 'Sharp',
      StickerQuality.good => 'Good',
      StickerQuality.squeezed => 'Squeezed to fit',
    };
    return Semantics(
      label: 'Quality: $label',
      excludeSemantics: true,
      child: Row(
        children: [
          Text(
            'Quality',
            style: PeelType.caption().copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          for (var i = 1; i <= 3; i++) ...[
            Container(
              width: 28,
              height: 6,
              decoration: BoxDecoration(
                color: i <= level ? PeelColors.ink : PeelColors.hairline,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 4),
          ],
          const SizedBox(width: 6),
          Text(label, style: PeelType.label().copyWith(fontSize: 14)),
        ],
      ),
    );
  }
}

/// What the chosen sound option means, under the Original / Your sound /
/// Mute switch, with ways to change your sound.
class _SoundPanel extends StatelessWidget {
  const _SoundPanel({
    required this.draft,
    required this.onRecordAgain,
    required this.onPickFile,
  });

  final VideoDraft draft;
  final VoidCallback onRecordAgain;
  final VoidCallback onPickFile;

  @override
  Widget build(BuildContext context) {
    final seconds = '${(draft.lengthMs / 1000).toStringAsFixed(1)} s';
    final newSound = draft.newSound;
    final (
      InkPair pair,
      IconData icon,
      String title,
      String detail,
    ) = switch (draft.soundMode) {
      VideoSoundMode.original when draft.info.hasAudio => (
        PeelPairs.mint,
        Icons.graphic_eq_rounded,
        'The clip’s own sound',
        '$seconds, plays when friends tap the sticker',
      ),
      VideoSoundMode.original => (
        PeelPairs.mint,
        Icons.volume_off_rounded,
        'This clip has no sound',
        'Add your own with Your sound',
      ),
      VideoSoundMode.mute => (
        PeelPairs.lilac,
        Icons.volume_off_rounded,
        'No sound',
        'A silent moving sticker',
      ),
      VideoSoundMode.replace => (
        PeelPairs.bubblegum,
        newSound?.origin == SoundOrigin.recording
            ? Icons.mic_none_rounded
            : Icons.music_note_outlined,
        newSound?.label ?? 'Your sound',
        '$seconds, plays in step with the preview',
      ),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PeelColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: pair.fill,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: pair.ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PeelType.label().copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(detail, style: PeelType.caption()),
                  ],
                ),
              ),
            ],
          ),
          if (draft.soundMode == VideoSoundMode.replace) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SecondaryPillButton(
                    label: 'Record again',
                    background: pair.fill,
                    foreground: pair.ink,
                    leading: const Icon(Icons.mic_none_rounded, size: 18),
                    onPressed: onRecordAgain,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SecondaryPillButton(
                    label: 'Pick a file',
                    background: pair.fill,
                    foreground: pair.ink,
                    leading: const Icon(Icons.music_note_outlined, size: 18),
                    onPressed: onPickFile,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The text tool: a small "Aa Add text" pill under the preview.
class _TextTool extends StatelessWidget {
  const _TextTool({required this.hasText, required this.onTap});

  final bool hasText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const pair = PeelPairs.butter;
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: pair.fill,
        foregroundColor: pair.ink,
        minimumSize: const Size(0, PeelSpace.minTouch),
        padding: const EdgeInsets.fromLTRB(14, 0, 18, 0),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Aa',
            style: PeelType.label(color: pair.ink)
                .copyWith(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 8),
          Text(
            hasText ? 'Edit text' : 'Add text',
            style: PeelType.label(color: pair.ink)
                .copyWith(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
