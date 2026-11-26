import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:material_ui/material_ui.dart';

/// WhatsApp's sound-sticker control: a small dark round badge with a muted
/// speaker. Tap it to hear the sound; it shows a speaker with waves while
/// the sound plays and goes back to muted when it stops.
class SoundBadge extends StatelessWidget {
  const SoundBadge({
    super.key,
    required this.on,
    required this.onTap,
    this.size = 40,
  });

  /// True while the sound is playing.
  final bool on;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: on,
      label: on ? 'Sound on. Tap to mute' : 'Sound off. Tap to play the sound',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // A 44 pt touch target around the smaller badge.
        child: SizedBox.square(
          dimension: size < 44 ? 44 : size,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: on ? const Color(0xE6111113) : const Color(0x99111113),
                shape: BoxShape.circle,
              ),
              child: Icon(
                on ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                size: size * 0.5,
                color: const Color(0xFFFFFFFF),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A [SoundBadge] that plays an audio file (or a video's sound track).
class SoundPlayButton extends StatefulWidget {
  const SoundPlayButton({
    super.key,
    required this.path,
    this.startMs = 0,
    required this.durationMs,
    this.size = 40,
  });

  /// An audio file, or a video whose soundtrack is played.
  final String path;
  final int startMs;
  final int durationMs;
  final double size;

  @override
  State<SoundPlayButton> createState() => _SoundPlayButtonState();
}

class _SoundPlayButtonState extends State<SoundPlayButton> {
  final _player = AudioPlayer();
  StreamSubscription<PlayerState>? _sub;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _sub = _player.playerStateStream.listen((s) {
      final playing =
          s.playing && s.processingState != ProcessingState.completed;
      if (mounted && playing != _playing) setState(() => _playing = playing);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.stop();
      return;
    }
    setState(() => _playing = true);
    try {
      await _player.setFilePath(widget.path);
      await _player.setClip(
        start: Duration(milliseconds: widget.startMs),
        end: Duration(milliseconds: widget.startMs + widget.durationMs),
      );
      await _player.play();
    } catch (_) {
      if (mounted) setState(() => _playing = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      SoundBadge(on: _playing, onTap: _toggle, size: widget.size);
}
