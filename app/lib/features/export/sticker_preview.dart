import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

import '../../app_state.dart';
import '../../library/sticker_record.dart';
import '../../sticker_engine/composer.dart';
import '../../sticker_engine/sticker_check.dart';
import '../../sticker_engine/whatsapp_rules.dart';
import '../sound/sound_play_button.dart';
import 'sticker_actions.dart';
import 'sticker_image.dart';

/// A finished sticker as WhatsApp shows a sound sticker: it plays silently,
/// with a muted-speaker badge; tap the badge to hear it.
///
/// Moving stickers with sound play their square video, so the picture and
/// the sound stay in step. Everything else shows the sticker itself.
class StickerPreview extends ConsumerWidget {
  const StickerPreview(this.record, {super.key, required this.size});

  final StickerRecord record;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryStoreProvider).value;
    final video = record.handoffVideo;
    if (library != null &&
        record.kind == StickerKind.moving &&
        record.hasSound &&
        video != null) {
      return _SyncedVideoSticker(path: library.file(video).path, size: size);
    }
    final src = soundSource(library, record);
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: StickerImage(record, size: size)),
          if (src != null)
            Positioned(
              left: -4,
              bottom: -4,
              child: SoundPlayButton(
                path: src.path,
                startMs: src.startMs,
                durationMs: src.durationMs,
              ),
            ),
        ],
      ),
    );
  }
}

class _SyncedVideoSticker extends StatefulWidget {
  const _SyncedVideoSticker({required this.path, required this.size});

  final String path;
  final double size;

  @override
  State<_SyncedVideoSticker> createState() => _SyncedVideoStickerState();
}

class _SyncedVideoStickerState extends State<_SyncedVideoSticker> {
  late final VideoPlayerController _player = VideoPlayerController.file(
    File(widget.path),
    videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
  );
  bool _soundOn = false;

  @override
  void initState() {
    super.initState();
    _player.initialize().then((_) async {
      if (!mounted) return;
      await _player.setLooping(true);
      await _player.setVolume(0);
      await _player.play();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final on = !_soundOn;
    setState(() => _soundOn = on);
    if (on) {
      // Start from the top so the sound lines up with the moment it was
      // made for.
      await _player.seekTo(Duration.zero);
      await _player.setVolume(1);
      await _player.play();
    } else {
      await _player.setVolume(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    // The sticker's rounded corners, scaled to this size.
    final radius =
        size * VideoFrameStyle.radius / WhatsAppStickerRules.canvasPx;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: _player.value.isInitialized
                  ? VideoPlayer(_player)
                  : const ColoredBox(color: Color(0xFFFFFFFF)),
            ),
          ),
          Positioned(
            left: -4,
            bottom: -4,
            child: SoundBadge(on: _soundOn, onTap: _toggle),
          ),
        ],
      ),
    );
  }
}
