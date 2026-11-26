import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// A small on-phone error log, shown in the test lab, so problems found
/// while testing on a device can be read back without a debugger.
///
/// Holds no photos, sounds or personal data: only where it failed and why.
abstract final class ErrorLog {
  static const _maxLines = 200;

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/errors.log');
  }

  static Future<void> record(
    String where,
    Object error, [
    StackTrace? stack,
  ]) async {
    final line = '${DateTime.now().toIso8601String()} [$where] $error';
    debugPrint(line);
    if (stack != null) debugPrint('$stack');
    try {
      final f = await _file();
      final old = await f.exists() ? await f.readAsLines() : <String>[];
      final keep = [...old, line];
      await f.writeAsString(
        keep
            .skip(keep.length > _maxLines ? keep.length - _maxLines : 0)
            .join('\n'),
        flush: true,
      );
    } catch (_) {
      // Logging must never break the app.
    }
  }

  /// Newest first.
  static Future<List<String>> read() async {
    try {
      final f = await _file();
      if (!await f.exists()) return const [];
      return (await f.readAsLines()).reversed.toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> clear() async {
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
