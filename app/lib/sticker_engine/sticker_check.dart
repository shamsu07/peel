import 'dart:typed_data';

import 'webp_inspector.dart';
import 'whatsapp_rules.dart';

enum StickerKind { still, moving }

/// Everything that can make WhatsApp reject a sticker file.
enum StickerProblem {
  notWebp,
  wrongSize,
  fileTooBig,
  wrongKind,
  tooLong,
  frameTooShort,
}

/// The pre-export checklist (spec P0-6). Each rule maps to a plain-language
/// fix in the UI; this class only reports.
class StickerCheck {
  const StickerCheck._(this.info, this.problems, this.limitBytes);

  final WebpInfo? info;
  final List<StickerProblem> problems;

  /// The size limit the file was checked against.
  final int limitBytes;

  bool get passes => problems.isEmpty;
}

/// Checks [bytes] against WhatsApp's rules.
///
/// With [useOurTargets], the size limit is our safer target (95 KB / 480 KB)
/// instead of WhatsApp's hard limit (100 KB / 500 KB).
StickerCheck checkSticker(
  Uint8List bytes, {
  required StickerKind kind,
  bool useOurTargets = false,
}) {
  final limit = switch ((kind, useOurTargets)) {
    (StickerKind.still, false) => WhatsAppStickerRules.staticMaxBytes,
    (StickerKind.still, true) => WhatsAppStickerRules.staticTargetBytes,
    (StickerKind.moving, false) => WhatsAppStickerRules.animatedMaxBytes,
    (StickerKind.moving, true) => WhatsAppStickerRules.animatedTargetBytes,
  };

  final WebpInfo info;
  try {
    info = inspectWebp(bytes);
  } on WebpFormatException {
    return StickerCheck._(null, const [StickerProblem.notWebp], limit);
  }

  final problems = <StickerProblem>[];
  if (info.width != WhatsAppStickerRules.canvasPx ||
      info.height != WhatsAppStickerRules.canvasPx) {
    problems.add(StickerProblem.wrongSize);
  }
  if (bytes.length > limit) problems.add(StickerProblem.fileTooBig);
  if (info.animated != (kind == StickerKind.moving)) {
    problems.add(StickerProblem.wrongKind);
  }
  if (info.animated) {
    final maxMs = WhatsAppStickerRules.maxAnimationDuration.inMilliseconds;
    if (info.totalDurationMs > maxMs) problems.add(StickerProblem.tooLong);
    final minMs = WhatsAppStickerRules.minFrameDuration.inMilliseconds;
    if (info.frameDurationsMs.any((d) => d < minMs)) {
      problems.add(StickerProblem.frameTooShort);
    }
  }
  return StickerCheck._(info, List.unmodifiable(problems), limit);
}
