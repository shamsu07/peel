import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Light, dark, or whatever the phone uses (the default).
enum Appearance { system, light, dark }

/// The saved choice, read once before the app starts so the first frame
/// is already in the right mode.
Appearance initialAppearance = Appearance.system;

Future<File> _file() async =>
    File('${(await getApplicationSupportDirectory()).path}/appearance.txt');

Future<void> loadAppearance() async {
  try {
    final f = await _file();
    if (!await f.exists()) return;
    final name = (await f.readAsString()).trim();
    initialAppearance = Appearance.values.firstWhere(
      (a) => a.name == name,
      orElse: () => Appearance.system,
    );
  } catch (_) {}
}

class AppearanceNotifier extends Notifier<Appearance> {
  @override
  Appearance build() => initialAppearance;

  Future<void> set(Appearance a) async {
    state = a;
    try {
      await (await _file()).writeAsString(a.name, flush: true);
    } catch (_) {}
  }
}

final appearanceProvider = NotifierProvider<AppearanceNotifier, Appearance>(
  AppearanceNotifier.new,
);
