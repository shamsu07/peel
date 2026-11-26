import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peel_native/peel_native.dart';

import '../library/sticker_record.dart';
import '../sticker_engine/caption.dart';
import '../sticker_engine/composer.dart';

/// The photo sticker being made, shared by Peeling, the editor, Text and
/// Add sound.
class PhotoDraft {
  const PhotoDraft({
    required this.sourcePath,
    required this.composition,
    this.segmentStatus = 'ok',
    this.sound,
  });

  final String sourcePath;
  final PhotoComposition composition;

  /// From the native cut-out: ok, noSubject, modelDownloading, error.
  final String segmentStatus;
  final StickerSound? sound;

  bool get hasCutout => composition.cutout != null;

  PhotoDraft copyWith({
    PhotoComposition? composition,
    StickerSound? sound,
    bool clearSound = false,
  }) => PhotoDraft(
    sourcePath: sourcePath,
    composition: composition ?? this.composition,
    segmentStatus: segmentStatus,
    sound: clearSound ? null : (sound ?? this.sound),
  );
}

/// Owns the draft's images: they're freed when the draft is replaced or
/// cleared, so an abandoned photo doesn't hold ~10 MB of textures.
class PhotoDraftNotifier extends Notifier<PhotoDraft?> {
  @override
  PhotoDraft? build() {
    ref.onDispose(() => disposeDraftImages(state));
    return null;
  }

  void start(PhotoDraft draft) {
    final old = state;
    state = draft;
    if (!identical(old?.composition.original, draft.composition.original)) {
      disposeDraftImages(old);
    }
  }

  void update(PhotoDraft Function(PhotoDraft d) change) {
    final d = state;
    if (d != null) state = change(d);
  }

  void clear() {
    final old = state;
    state = null;
    disposeDraftImages(old);
  }
}

final photoDraftProvider = NotifierProvider<PhotoDraftNotifier, PhotoDraft?>(
  PhotoDraftNotifier.new,
);

enum VideoSoundMode { original, replace, mute }

/// The video sticker being made.
class VideoDraft {
  const VideoDraft({
    required this.path,
    required this.info,
    required this.startMs,
    required this.lengthMs,
    required this.crop,
    this.soundMode = VideoSoundMode.original,
    this.newSound,
    this.caption,
  });

  final String path;
  final VideoInfo info;
  final int startMs;
  final int lengthMs;
  final SquareCrop crop;
  final VideoSoundMode soundMode;

  /// The replacement sound when [soundMode] is replace.
  final StickerSound? newSound;
  final Caption? caption;

  /// The sound this sticker ends up with, if any.
  StickerSound? get sound => switch (soundMode) {
    VideoSoundMode.mute => null,
    VideoSoundMode.replace =>
      newSound == null
          ? null
          : StickerSound(
              origin: newSound!.origin,
              path: newSound!.path,
              startMs: newSound!.startMs,
              durationMs: lengthMs,
              label: newSound!.label,
            ),
    VideoSoundMode.original =>
      info.hasAudio
          ? StickerSound(
              origin: SoundOrigin.original,
              startMs: startMs,
              durationMs: lengthMs,
              label: 'Original sound',
            )
          : null,
  };

  VideoDraft copyWith({
    int? startMs,
    int? lengthMs,
    SquareCrop? crop,
    VideoSoundMode? soundMode,
    StickerSound? newSound,
    Caption? caption,
    bool clearCaption = false,
  }) => VideoDraft(
    path: path,
    info: info,
    startMs: startMs ?? this.startMs,
    lengthMs: lengthMs ?? this.lengthMs,
    crop: crop ?? this.crop,
    soundMode: soundMode ?? this.soundMode,
    newSound: newSound ?? this.newSound,
    caption: clearCaption ? null : (caption ?? this.caption),
  );
}

class VideoDraftNotifier extends Notifier<VideoDraft?> {
  @override
  VideoDraft? build() => null;

  void start(VideoDraft draft) => state = draft;

  void update(VideoDraft Function(VideoDraft d) change) {
    final d = state;
    if (d != null) state = change(d);
  }

  void clear() => state = null;
}

final videoDraftProvider = NotifierProvider<VideoDraftNotifier, VideoDraft?>(
  VideoDraftNotifier.new,
);

/// The centred square crop of a frame, covering its short side.
SquareCrop centeredCrop(VideoInfo info) {
  final w = info.width.toDouble();
  final h = info.height.toDouble();
  final side = w < h ? w : h;
  return SquareCrop(left: (w - side) / 2 / w, top: (h - side) / 2 / h, size: 1);
}

/// Keeps the original photo image alive while a draft uses it.
void disposeDraftImages(PhotoDraft? draft) {
  draft?.composition.original.dispose();
  draft?.composition.cutout?.dispose();
  draft?.composition.edgedCutout?.dispose();
}
