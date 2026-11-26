import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'compressor.dart';
import 'composer.dart';
import 'whatsapp_rules.dart';

// Background work for the sticker engine. Every isolate entry point here is
// a top-level function on purpose: closures made inside widget code capture
// the widget's State, which can't be sent to another isolate.

/// Encodes a still sticker under the size target, off the UI thread.
Future<StaticResult> encodeStillInBackground(Uint8List rgba) => Isolate.run(
  () => StaticCompressor().compress(rgba, WhatsAppStickerRules.canvasPx),
);

/// Frames written by the native extractor (`frame_00000.rgba` …), blended
/// with the sticker's rim and caption as they are read.
class FramesDirSource implements FrameSource {
  FramesDirSource({
    required this.dir,
    required this.frameCount,
    required this.fps,
    required this.duration,
    required this.layers,
  });

  final String dir;
  final int frameCount;
  final int fps;
  final VideoLayers layers;

  @override
  final Duration duration;

  @override
  int get size => WhatsAppStickerRules.canvasPx;

  @override
  Future<Uint8List> frameAt(Duration t) async {
    // Checked per frame so a cancel stops the encoder cleanly, freeing its
    // native memory, instead of killing the isolate mid-encode.
    if (_encodeCancelled) throw const CancelledEncode();
    final i = math.min(frameCount - 1, (t.inMilliseconds * fps / 1000).round());
    final name = 'frame_${i.toString().padLeft(5, '0')}.rgba';
    final frame = await File('$dir/$name').readAsBytes();
    blendVideoFrame(frame, layers);
    return frame;
  }
}

class VideoEncodeRequest {
  const VideoEncodeRequest({
    required this.framesDir,
    required this.frameCount,
    required this.fps,
    required this.duration,
    required this.layers,
  });

  final String framesDir;
  final int frameCount;
  final int fps;
  final Duration duration;
  final VideoLayers layers;
}

class VideoEncodeProgress {
  const VideoEncodeProgress(this.attempt, this.fraction);

  /// 1 for the first try, 2+ when squeezing to fit.
  final int attempt;
  final double fraction;
}

/// Set inside the encode isolate when the user cancels.
bool _encodeCancelled = false;

/// A running video encode: watch [progress], await [result], or [cancel].
class VideoEncodeJob {
  VideoEncodeJob._(this._isolate, this.result, this.progress, this._port);

  final Isolate _isolate;
  final ReceivePort _port;
  final Future<AnimatedResult> result;
  final Stream<VideoEncodeProgress> progress;
  SendPort? _control;

  /// Asks the encoder to stop at the next frame (so it frees its memory),
  /// and kills it if it hasn't stopped within two seconds.
  void cancel() {
    final control = _control;
    if (control == null) {
      _isolate.kill(priority: Isolate.immediate);
      _port.close();
      return;
    }
    control.send('cancel');
    Timer(const Duration(seconds: 2), () {
      _isolate.kill(priority: Isolate.immediate);
      _port.close();
    });
  }
}

Future<VideoEncodeJob> startVideoEncode(VideoEncodeRequest request) async {
  final port = ReceivePort();
  final progress = StreamController<VideoEncodeProgress>.broadcast();
  final done = Completer<AnimatedResult>();

  final isolate = await Isolate.spawn(
    _videoEncodeEntry,
    [
      port.sendPort,
      request.framesDir,
      request.frameCount,
      request.fps,
      request.duration.inMilliseconds,
      TransferableTypedData.fromList([request.layers.overlay]),
      TransferableTypedData.fromList([request.layers.mask]),
    ],
    // If the isolate dies (e.g. out of memory), say so instead of hanging.
    onExit: port.sendPort,
    onError: port.sendPort,
  );
  late final VideoEncodeJob job;

  void fail(String why) {
    if (!done.isCompleted) done.completeError(CompressionException(why));
    if (!progress.isClosed) progress.close();
    port.close();
  }

  port.listen(
    (message) {
      if (message == null) {
        fail('The encoder stopped unexpectedly');
      } else if (message is List && message.first == 'control') {
        job._control = message[1] as SendPort;
      } else if (message is List && message.first == 'cancelled') {
        if (!done.isCompleted) done.completeError(const CancelledEncode());
        if (!progress.isClosed) progress.close();
        port.close();
      } else if (message is List && message.first == 'progress') {
        progress.add(
          VideoEncodeProgress(message[1] as int, message[2] as double),
        );
      } else if (message is List && message.first == 'done') {
        done.complete(
          AnimatedResult(
            bytes: (message[1] as TransferableTypedData)
                .materialize()
                .asUint8List(),
            rung: CompressionRung(message[2] as int, message[3] as double),
            rungIndex: message[4] as int,
            frameCount: message[5] as int,
            attempts: message[6] as int,
            elapsed: Duration(milliseconds: message[7] as int),
          ),
        );
        progress.close();
        port.close();
      } else if (message is List && message.first == 'error') {
        fail(message[1] as String);
      } else if (message is List && message.length == 2) {
        fail('Encoder error: ${message[0]}'); // From onError.
      }
    },
    onDone: () {
      if (!done.isCompleted) done.completeError(const CancelledEncode());
      if (!progress.isClosed) progress.close();
    },
  );

  job = VideoEncodeJob._(isolate, done.future, progress.stream, port);
  return job;
}

class CancelledEncode implements Exception {
  const CancelledEncode();
}

Future<void> _videoEncodeEntry(List<Object?> args) async {
  final reply = args[0]! as SendPort;
  final control = ReceivePort();
  control.listen((m) {
    if (m == 'cancel') _encodeCancelled = true;
  });
  reply.send(['control', control.sendPort]);
  try {
    final source = FramesDirSource(
      dir: args[1]! as String,
      frameCount: args[2]! as int,
      fps: args[3]! as int,
      duration: Duration(milliseconds: args[4]! as int),
      layers: VideoLayers(
        overlay: (args[5]! as TransferableTypedData)
            .materialize()
            .asUint8List(),
        mask: (args[6]! as TransferableTypedData).materialize().asUint8List(),
      ),
    );
    var lastSent = -1.0;
    final result = await AnimatedCompressor().compress(
      source,
      onProgress: (attempt, fraction) {
        if (fraction - lastSent >= 0.02 || fraction >= 1) {
          lastSent = fraction >= 1 ? -1 : fraction;
          reply.send(['progress', attempt, fraction]);
        }
      },
    );
    reply.send([
      'done',
      TransferableTypedData.fromList([result.bytes]),
      result.rung.fps,
      result.rung.quality,
      result.rungIndex,
      result.frameCount,
      result.attempts,
      result.elapsed.inMilliseconds,
    ]);
  } on CancelledEncode {
    reply.send(['cancelled']);
  } catch (e) {
    reply.send(['error', '$e']);
  } finally {
    control.close();
  }
}

/// A rough "how will it look" label for the trimmer, before encoding.
/// Clips up to about 4 s nearly always keep full quality.
StickerQuality expectedQuality(Duration length) {
  final s = length.inMilliseconds / 1000;
  if (s <= 4) return StickerQuality.sharp;
  if (s <= 7) return StickerQuality.good;
  return StickerQuality.squeezed;
}
