import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Clears leftovers from temp storage: picked photos and videos, cut-out
/// PNGs, voice recordings, video frames and half-made files from a sticker
/// that was interrupted. Runs at start-up, when nothing is in progress, and
/// only removes things over an hour old.
Future<void> sweepTempFiles() async {
  final tmp = await getTemporaryDirectory();
  if (!await tmp.exists()) return;
  final cutoff = DateTime.now().subtract(const Duration(hours: 1));
  const prefixes = [
    'frames_',
    'cutout_',
    'voice_',
    'peel_still_',
    'image_picker',
    'scaled_',
  ];
  const dirs = ['file_picker', 'image_picker'];
  const media = [
    '.mp4',
    '.mov',
    '.m4v',
    '.jpg',
    '.jpeg',
    '.png',
    '.heic',
    '.webp',
    '.m4a',
    '.aac',
    '.mp3',
    '.wav',
    '.rgba',
  ];
  await for (final entity in tmp.list(followLinks: false)) {
    final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
    final lower = name.toLowerCase();
    final ours =
        prefixes.any(lower.startsWith) ||
        dirs.contains(lower) ||
        (entity is File && media.any(lower.endsWith));
    if (!ours) continue;
    try {
      final stat = await entity.stat();
      if (stat.modified.isAfter(cutoff)) continue;
      await entity.delete(recursive: true);
    } catch (_) {
      // In use or already gone; try again next start.
    }
  }
}
