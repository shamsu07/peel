import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/audio.dart';

import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/pill_buttons.dart';
import '../../library/sticker_record.dart';

const _maxMs = 10000;

/// "Add a sound." (canvas: Add sound / Recording). Returns the chosen sound.
///
/// [fixedLengthMs] is set for video stickers: the sound matches the clip.
/// How the sheet opens: asking, or straight into recording or the file
/// picker (for "Record again" and "Pick a file").
enum SoundStart { choose, record, file }

Future<StickerSound?> showSoundSheet(
  BuildContext context, {
  StickerSound? current,
  int? fixedLengthMs,
  SoundStart start = SoundStart.choose,
}) => showPeelSheet<StickerSound>(
  context,
  (_) => _SoundSheet(fixedLengthMs: fixedLengthMs, start: start),
);

enum _Mode { choose, recording, recorded, file }

class _SoundSheet extends StatefulWidget {
  const _SoundSheet({this.fixedLengthMs, this.start = SoundStart.choose});

  final int? fixedLengthMs;
  final SoundStart start;

  @override
  State<_SoundSheet> createState() => _SoundSheetState();
}

class _SoundSheetState extends State<_SoundSheet> {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  _Mode _mode = _Mode.choose;
  String? _message;

  // Recording.
  String? _recordingPath;
  final _levels = <double>[];
  StreamSubscription<Amplitude>? _ampSub;
  Timer? _timer;
  int _recordedMs = 0;

  // File.
  String? _filePath;
  String? _fileName;
  int _fileMs = 0;
  int _startMs = 0;
  late int _lengthMs = widget.fixedLengthMs ?? 3000;

  // Playback of the recording or the chosen part of a file.
  bool _playing = false;
  int _playedMs = 0;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _posSub;

  @override
  void initState() {
    super.initState();
    _stateSub = _player.playerStateStream.listen((s) {
      final playing =
          s.playing && s.processingState != ProcessingState.completed;
      if (mounted && playing != _playing) {
        setState(() {
          _playing = playing;
          if (!playing) _playedMs = 0;
        });
      }
    });
    _posSub = _player.positionStream.listen((p) {
      if (mounted && _playing) setState(() => _playedMs = p.inMilliseconds);
    });
    switch (widget.start) {
      case SoundStart.record:
        WidgetsBinding.instance.addPostFrameCallback((_) => _startRecording());
      case SoundStart.file:
        WidgetsBinding.instance.addPostFrameCallback((_) => _pickFile());
      case SoundStart.choose:
        break;
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _timer?.cancel();
    _ampSub?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    await _player.stop();
    if (!await _recorder.hasPermission()) {
      setState(
        () => _message = 'Peel can’t use the microphone. Turn it on in Settings, or pick an audio file.',
      );
      return;
    }
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    _levels.clear();
    _recordedMs = 0;
    _ampSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen(
          (a) => setState(
            () => _levels.add(((a.current + 45) / 45).clamp(0.08, 1.0)),
          ),
        );
    final limit = widget.fixedLengthMs ?? _maxMs;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      setState(() => _recordedMs += 100);
      if (_recordedMs >= limit) _stopRecording();
    });
    setState(() {
      _recordingPath = path;
      _mode = _Mode.recording;
      _message = null;
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    await _ampSub?.cancel();
    final path = await _recorder.stop();
    // Recording leaves iOS routing sound to the earpiece, which sounds
    // like silence. Switch back to normal playback through the speaker.
    await useSpeakerForPlayback();
    if (!mounted) return;
    if (path == null || _recordedMs < 300) {
      setState(() {
        _mode = _Mode.choose;
        _message = 'That was too short. Hold on a little longer.';
      });
      return;
    }
    setState(() {
      _recordingPath = path;
      _mode = _Mode.recorded;
    });
  }

  Future<void> _pickFile() async {
    final files = await FilePicker.pickFiles(type: FileType.audio);
    final file = files.singleOrNull;
    if (file?.path == null || !mounted) return;
    try {
      final d = await _player.setFilePath(file!.path!);
      final ms = d?.inMilliseconds ?? 0;
      if (ms < 300) throw StateError('too short');
      setState(() {
        _filePath = file.path;
        _fileName = file.name;
        _fileMs = ms;
        _startMs = 0;
        _lengthMs = math.min(widget.fixedLengthMs ?? 3000, ms);
        _mode = _Mode.file;
        _message = null;
      });
    } catch (_) {
      setState(() => _message = 'That file can’t be played. Try another one.');
    }
  }

  /// Plays [path] from [startMs] for [lengthMs], or stops if playing.
  Future<void> _play(String path, int startMs, int lengthMs) async {
    if (_playing) {
      await _player.stop();
      return;
    }
    try {
      await useSpeakerForPlayback();
      await _player.setFilePath(path);
      await _player.setClip(
        start: Duration(milliseconds: startMs),
        end: Duration(milliseconds: startMs + lengthMs),
      );
      _player.play();
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Couldn’t play that sound. Try again.');
      }
    }
  }

  void _use(StickerSound sound) => Navigator.of(context).pop(sound);

  @override
  Widget build(BuildContext context) {
    return switch (_mode) {
      _Mode.choose => _choose(),
      _Mode.recording || _Mode.recorded => _recordingView(),
      _Mode.file => _fileView(),
    };
  }

  Widget _choose() {
    return PeelSheet(
      title: 'Add a sound.',
      subtitle: 'Friends tap your sticker to hear it.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _SourceButton(
                  pair: PeelPairs.bubblegum,
                  icon: Icons.mic_none_rounded,
                  title: 'Record',
                  caption: 'Your voice',
                  onTap: _startRecording,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SourceButton(
                  pair: PeelPairs.sky,
                  icon: Icons.music_note_outlined,
                  title: 'Audio file',
                  caption: 'From your phone',
                  onTap: _pickFile,
                ),
              ),
            ],
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            PeelNote(text: _message!, pair: PeelPairs.butter),
          ],
          const SizedBox(height: 14),
          Text(
            'Use sounds you’re allowed to share.',
            style: PeelType.caption(),
          ),
        ],
      ),
    );
  }

  Widget _recordingView() {
    final recording = _mode == _Mode.recording;
    final limit = widget.fixedLengthMs ?? _maxMs;
    const pair = PeelPairs.bubblegum;
    return PeelSheet(
      title: recording ? 'Recording.' : 'Sounds good.',
      subtitle: recording
          ? 'Up to ${limit ~/ 1000} s. Tap the button to stop.'
          : 'Tap play to hear it. Not happy? Record again.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            decoration: BoxDecoration(
              color: pair.fill,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '0:${(_recordedMs / 1000).toStringAsFixed(1).padLeft(4, '0')}',
                      style: PeelType.title(size: 52, color: pair.ink).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'of ${limit ~/ 1000} s',
                      style: PeelType.caption(color: pair.ink)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 30; i++) ...[
                        Expanded(
                          child: FractionallySizedBox(
                            heightFactor: _barLevel(i),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: _barLit(i, limit)
                                    ? pair.ink
                                    : pair.ink.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                        if (i < 29) const SizedBox(width: 3),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: _recordedMs / limit,
                    minHeight: 6,
                    color: pair.ink,
                    backgroundColor: pair.ink.withValues(alpha: 0.18),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 96,
            child: Center(
              child: recording
                  ? _BigRoundButton(
                      label: 'Stop recording',
                      onTap: _stopRecording,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5C8A),
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SecondaryPillButton(
                          label: 'Record again',
                          leading: const Icon(Icons.mic_none_rounded, size: 18),
                          onPressed: _startRecording,
                        ),
                        const SizedBox(width: 16),
                        _BigRoundButton(
                          label: _playing
                              ? 'Stop playing'
                              : 'Play your recording',
                          onTap: () => _play(_recordingPath!, 0, _recordedMs),
                          child: Icon(
                            _playing
                                ? Icons.stop_rounded
                                : Icons.play_arrow_rounded,
                            color: PeelColors.surface,
                            size: 36,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          if (!recording)
            PrimaryPillButton(
              label: 'Use this sound',
              onPressed: () => _use(
                StickerSound(
                  origin: SoundOrigin.recording,
                  path: _recordingPath,
                  startMs: 0,
                  durationMs: widget.fixedLengthMs ?? _recordedMs,
                  label: 'Your voice',
                ),
              ),
            )
          else
            Text(
              'Tip: keep it short and loud. It plays when friends tap the sticker.',
              textAlign: TextAlign.center,
              style: PeelType.caption(),
            ),
        ],
      ),
    );
  }

  double _barLevel(int i) {
    if (_levels.isEmpty) return 0.12;
    final step = math.max(1, (_levels.length / 30).ceil());
    final idx = i * step;
    if (idx >= _levels.length) return 0.12;
    return _levels[idx];
  }

  int _filledBars(int limit) => (_recordedMs / limit * 30).round();

  /// While recording, bars fill as you speak; while playing back, they
  /// light up as the sound plays.
  bool _barLit(int i, int limit) {
    if (_mode == _Mode.recorded && _playing && _recordedMs > 0) {
      return i < (_playedMs / _recordedMs * _filledBars(limit)).round();
    }
    return i < _filledBars(limit);
  }

  Widget _fileView() {
    final maxStart = math.max(0, _fileMs - _lengthMs);
    final lengths = [
      2000,
      3000,
      5000,
      10000,
    ].where((l) => l <= _fileMs).toList();
    return PeelSheet(
      title: 'Add a sound.',
      subtitle: 'Pick the part you want.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4F6),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _fileName ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PeelType.label().copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _pickFile,
                      child: const Text('Change'),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton.filled(
                      tooltip: _playing ? 'Stop' : 'Play the chosen part',
                      onPressed: () => _play(_filePath!, _startMs, _lengthMs),
                      style: IconButton.styleFrom(
                        backgroundColor: PeelColors.ink,
                        fixedSize: const Size.square(48),
                      ),
                      icon: Icon(
                        _playing
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                        color: PeelColors.surface,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: _startMs.toDouble().clamp(
                          0,
                          maxStart.toDouble(),
                        ),
                        max: math.max(1, maxStart).toDouble(),
                        activeColor: PeelColors.ink,
                        inactiveColor: PeelColors.hairline,
                        label: _range(),
                        semanticFormatterCallback: (_) => _range(),
                        onChanged: maxStart == 0
                            ? null
                            : (v) => setState(() => _startMs = v.round()),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Slide to pick the best part',
                      style: PeelType.caption(),
                    ),
                    Text(
                      _range(),
                      style: PeelType.caption(color: PeelColors.ink)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (widget.fixedLengthMs == null && lengths.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  'How long',
                  style: PeelType.caption().copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                for (final l in lengths) ...[
                  ChoiceChip(
                    label: Text('${l ~/ 1000} s'),
                    selected: _lengthMs == l,
                    showCheckmark: false,
                    selectedColor: PeelColors.ink,
                    labelStyle: TextStyle(
                      color: _lengthMs == l
                          ? PeelColors.surface
                          : PeelColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                    onSelected: (_) => setState(() {
                      _lengthMs = l;
                      _startMs = math.min(_startMs, math.max(0, _fileMs - l));
                    }),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'Use sounds you’re allowed to share.',
            style: PeelType.caption(),
          ),
          const SizedBox(height: 12),
          PrimaryPillButton(
            label: 'Use this sound',
            onPressed: () => _use(
              StickerSound(
                origin: SoundOrigin.file,
                path: _filePath,
                startMs: _startMs,
                durationMs: _lengthMs,
                label: _fileName,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _range() {
    String f(int ms) =>
        '${ms ~/ 60000}:${((ms ~/ 1000) % 60).toString().padLeft(2, '0')}';
    return '${f(_startMs)} – ${f(_startMs + _lengthMs)}';
  }
}

class _SourceButton extends StatelessWidget {
  const _SourceButton({
    required this.pair,
    required this.icon,
    required this.title,
    required this.caption,
    required this.onTap,
  });

  final InkPair pair;
  final IconData icon;
  final String title;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF4F4F6),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 84),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: pair.fill,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: pair.ink, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: PeelType.label().copyWith(fontSize: 16),
                      ),
                      Text(
                        caption,
                        style: PeelType.caption().copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BigRoundButton extends StatelessWidget {
  const _BigRoundButton({
    required this.label,
    required this.onTap,
    required this.child,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: PeelColors.ink,
            shape: BoxShape.circle,
            border: Border.all(color: PeelColors.surface, width: 5),
            boxShadow: PeelShadows.floating,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
