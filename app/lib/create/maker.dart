import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:peel_native/peel_native.dart';

import '../core/error_log.dart';
import '../library/library_store.dart';
import '../library/sticker_record.dart';
import '../sticker_engine/background.dart';
import '../sticker_engine/compressor.dart';
import '../sticker_engine/composer.dart';
import '../sticker_engine/render.dart';
import '../sticker_engine/sticker_check.dart';
import '../sticker_engine/whatsapp_rules.dart';
import 'drafts.dart';

/// Turns drafts into finished stickers in the library.

/// Saves a photo sticker: renders it (same painter as the preview), encodes
/// it under 95 KB off the UI thread, and makes the sound-sticker MP4 if it
/// has a sound.
Future<StickerRecord> savePhotoSticker({
  required PhotoDraft draft,
  required LibraryStore library,
  required PeelNativeApi native,
}) async {
  const size = WhatsAppStickerRules.canvasPx;
  final rgba = await draft.composition.renderRgba();
  final encoded = await encodeStillInBackground(rgba);
  final preview = await pngFromRgba(rgba, size, size);
  final tray = await trayPngFromRgba(rgba, size);

  final sound = await _keepSound(draft.sound, library);
  var record = await library.add(
    webp: encoded.bytes,
    previewPng: preview,
    trayPng: tray,
    kind: StickerKind.still,
    source: StickerSource.photo,
    sound: sound,
    accessibilityText: 'Photo sticker',
  );

  if (sound != null && sound.path != null) {
    // The sound version is extra: if it fails, the sticker still saves.
    final out = library.newPath('mp4');
    try {
      await native.exportHandoffVideo(
        HandoffJob(
          outPath: out,
          durationMs: sound.durationMs,
          audioMode: 'replace',
          imagePath: library.file(record.previewFile).path,
          videoStartMs: 0,
          audioPath: sound.path,
          audioStartMs: sound.startMs,
        ),
      );
      record = await library.update(
        record.copyWith(handoffVideo: out.split('/').last),
      );
    } catch (e, s) {
      await ErrorLog.record('photo sound video', e, s);
      await _deletePartial(out);
    }
  }
  return record;
}

/// Copies a recording or picked audio file into the library so it outlives
/// the picker's temporary folder.
Future<StickerSound?> _keepSound(
  StickerSound? sound,
  LibraryStore library,
) async {
  final path = sound?.path;
  if (sound == null || path == null) return sound;
  final ext = path.contains('.') ? path.split('.').last : 'm4a';
  final kept = library.newPath(ext);
  await File(path).copy(kept);
  return StickerSound(
    origin: sound.origin,
    path: kept,
    startMs: sound.startMs,
    durationMs: sound.durationMs,
    label: sound.label,
  );
}

/// Stages of making a video sticker, for the "Making it" screen.
enum MakingStage { framing, squeezing, sound, checking }

class MakingUpdate {
  const MakingUpdate(this.stage, this.fraction, {this.attempt = 1});

  final MakingStage stage;

  /// Overall progress, 0–1.
  final double fraction;
  final int attempt;
}

/// A video sticker being made. Cancel any time.
class VideoMaking {
  VideoMaking._();

  VideoEncodeJob? _job;
  bool _cancelled = false;

  void cancel() {
    _cancelled = true;
    _job?.cancel();
  }

  static VideoMaking start({
    required VideoDraft draft,
    required LibraryStore library,
    required PeelNativeApi native,
    required void Function(MakingUpdate) onUpdate,
    required void Function(StickerRecord) onDone,
    required void Function(Object error) onError,
  }) {
    final making = VideoMaking._();
    making
        ._run(draft, library, native, onUpdate)
        .then(
          (r) {
            if (r != null) onDone(r);
          },
          onError: (Object e) {
            if (!making._cancelled) onError(e);
          },
        );
    return making;
  }

  static const _extractFps = 15;

  Future<StickerRecord?> _run(
    VideoDraft draft,
    LibraryStore library,
    PeelNativeApi native,
    void Function(MakingUpdate) onUpdate,
  ) async {
    const size = WhatsAppStickerRules.canvasPx;
    final tmp = await getTemporaryDirectory();
    final framesDir = Directory(
      '${tmp.path}/frames_${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      onUpdate(const MakingUpdate(MakingStage.framing, 0.02));
      final count = await native.extractFrames(
        FrameJob(
          videoPath: draft.path,
          startMs: draft.startMs,
          durationMs: draft.lengthMs,
          fps: _extractFps,
          crop: draft.crop,
          outSize: size,
          outDir: framesDir.path,
        ),
      );
      if (_cancelled) return null;
      if (count == 0) {
        throw StateError('No frames could be read from the video');
      }
      onUpdate(const MakingUpdate(MakingStage.squeezing, 0.2));

      final layers = await VideoFrameStyle(caption: draft.caption)
          .renderLayers();
      final job = await startVideoEncode(
        VideoEncodeRequest(
          framesDir: framesDir.path,
          frameCount: count,
          fps: _extractFps,
          duration: Duration(milliseconds: draft.lengthMs),
          layers: layers,
        ),
      );
      _job = job;
      if (_cancelled) {
        // Cancelled while the encoder was starting.
        job.cancel();
        return null;
      }
      final sub = job.progress.listen((p) {
        // Each extra attempt is shorter (fewer frames); keep the bar moving.
        final base = 0.2 + 0.6 * (1 - 1 / p.attempt);
        final span = 0.6 / p.attempt;
        onUpdate(
          MakingUpdate(
            MakingStage.squeezing,
            (base + span * p.fraction).clamp(0.2, 0.8),
            attempt: p.attempt,
          ),
        );
      });
      final AnimatedResult result;
      try {
        result = await job.result;
      } finally {
        await sub.cancel();
      }
      if (_cancelled) return null;

      // Preview and tray from the first finished frame.
      final first = await FramesDirSource(
        dir: framesDir.path,
        frameCount: count,
        fps: _extractFps,
        duration: Duration(milliseconds: draft.lengthMs),
        layers: layers,
      ).frameAt(Duration.zero);
      final preview = await pngFromRgba(first, size, size);
      final tray = await trayPngFromRgba(first, size);

      onUpdate(const MakingUpdate(MakingStage.checking, 0.85));
      final check = checkSticker(result.bytes, kind: StickerKind.moving);
      if (!check.passes) {
        throw StateError('Sticker failed WhatsApp checks: ${check.problems}');
      }

      final sound = await _keepSound(draft.sound, library);
      var record = await library.add(
        webp: result.bytes,
        previewPng: preview,
        trayPng: tray,
        kind: StickerKind.moving,
        source: StickerSource.video,
        sound: sound,
        accessibilityText: 'Video sticker',
      );

      // A square MP4 of the sticker: used for Save to Photos, and with its
      // sound for WhatsApp's own "Create sticker". Optional: if it fails,
      // the sticker still saves.
      onUpdate(const MakingUpdate(MakingStage.sound, 0.92));
      final out = library.newPath('mp4');
      try {
        // The white edge, corners and text, drawn over the video so the MP4
        // looks like the sticker.
        final style = VideoFrameStyle(caption: draft.caption);
        final overlayPng = await pngFromRgba(
          await renderRgba(style.paintVideoOverlay),
          size,
          size,
        );
        final overlay = File('${framesDir.path}/overlay.png');
        await overlay.writeAsBytes(overlayPng, flush: true);
        await native.exportHandoffVideo(
          HandoffJob(
            outPath: out,
            durationMs: draft.lengthMs,
            audioMode: switch (draft.soundMode) {
              _ when sound == null => 'mute',
              VideoSoundMode.original => 'original',
              VideoSoundMode.replace => 'replace',
              VideoSoundMode.mute => 'mute',
            },
            videoPath: draft.path,
            videoStartMs: draft.startMs,
            crop: draft.crop,
            audioPath: sound?.path,
            audioStartMs: sound?.startMs ?? 0,
            overlayPath: overlay.path,
          ),
        );
        record = await library.update(
          record.copyWith(handoffVideo: out.split('/').last),
        );
      } catch (e, s) {
        await ErrorLog.record('video sticker MP4', e, s);
        await _deletePartial(out);
      }
      onUpdate(const MakingUpdate(MakingStage.checking, 1));
      return record;
    } finally {
      if (await framesDir.exists()) {
        await framesDir.delete(recursive: true);
      }
    }
  }
}

/// Removes a half-written export so failed attempts don't pile up.
Future<void> _deletePartial(String path) async {
  try {
    final f = File(path);
    if (await f.exists()) await f.delete();
  } catch (_) {}
}
