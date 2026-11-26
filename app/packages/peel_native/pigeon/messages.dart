import 'package:pigeon/pigeon.dart';

// Native features Peel needs that Flutter doesn't have. After editing, run
//   dart run pigeon --input pigeon/messages.dart
// from packages/peel_native to regenerate the Dart, Kotlin and Swift code.

@ConfigurePigeon(
  PigeonOptions(
    dartPackageName: 'peel_native',
    dartOut: 'lib/src/messages.g.dart',
    kotlinOut: 'android/src/main/kotlin/app/peel/peel_native/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'app.peel.peel_native'),
    swiftOut: ['ios/peel_native/Sources/peel_native/Messages.g.swift'],
  ),
)
/// Result of cutting the main subject out of a photo.
class SegmentResult {
  SegmentResult({
    required this.status,
    this.path,
    this.width = 0,
    this.height = 0,
  });

  /// "ok", "noSubject", "modelDownloading" or "error".
  String status;

  /// PNG with transparent background, cropped to the subject.
  String? path;
  int width;
  int height;
}

/// A video as it is shown (rotation already applied).
class VideoInfo {
  VideoInfo({
    required this.durationMs,
    required this.width,
    required this.height,
    required this.hasAudio,
  });

  int durationMs;
  int width;
  int height;
  bool hasAudio;
}

/// A square crop of a video frame, as fractions of the shown frame.
class SquareCrop {
  SquareCrop({required this.left, required this.top, required this.size});

  /// Left edge, 0–1 of the frame width.
  double left;

  /// Top edge, 0–1 of the frame height.
  double top;

  /// Side length, 0–1 of the shorter frame side.
  double size;
}

/// Turns part of a video into square RGBA frames on disk, one raw file per
/// frame (`frame_00000.rgba`, `outSize * outSize * 4` bytes each).
class FrameJob {
  FrameJob({
    required this.videoPath,
    required this.startMs,
    required this.durationMs,
    required this.fps,
    required this.crop,
    required this.outSize,
    required this.outDir,
  });

  String videoPath;
  int startMs;
  int durationMs;
  int fps;
  SquareCrop crop;
  int outSize;
  String outDir;
}

/// Makes the short MP4 the user turns into a sound sticker inside WhatsApp.
class HandoffJob {
  HandoffJob({
    required this.outPath,
    required this.durationMs,
    required this.audioMode,
    this.imagePath,
    this.videoPath,
    this.videoStartMs = 0,
    this.crop,
    this.audioPath,
    this.audioStartMs = 0,
    this.overlayPath,
  });

  String outPath;
  int durationMs;

  /// "original" (video's own sound), "replace" (audioPath) or "mute".
  String audioMode;

  /// Photo stickers: the finished sticker image (PNG).
  String? imagePath;

  /// Video stickers: the source clip, trim start and square crop.
  String? videoPath;
  int videoStartMs;
  SquareCrop? crop;

  String? audioPath;
  int audioStartMs;

  /// Video stickers: a square PNG drawn over every frame (the sticker's
  /// white edge, text and corners), so the MP4 looks like the sticker.
  String? overlayPath;
}

@HostApi()
abstract class PeelNativeApi {
  /// Starts downloading the cut-out model if the phone needs it (Android).
  void prepareSegmenter();

  @async
  SegmentResult segmentSubject(String imagePath, String outPath, int maxSide);

  @async
  VideoInfo videoInfo(String path);

  /// A JPEG of the frame at [timeMs], longest side at most [maxSide].
  @async
  Uint8List videoThumbnail(String path, int timeMs, int maxSide);

  /// Returns how many frames were written.
  @async
  int extractFrames(FrameJob job);

  /// Returns the written MP4 path.
  @async
  String exportHandoffVideo(HandoffJob job);

  /// Puts a sticker image on the clipboard (WebP plus a PNG fallback).
  bool copyStickerToClipboard(String webpPath, String pngPath);
}
