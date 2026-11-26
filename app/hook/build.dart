import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

/// Compiles libwebp (vendored, v1.6.0) plus our small C shim into one native
/// library that Dart calls through FFI. Runs automatically for every
/// `flutter build`, `flutter run` and `flutter test`, on every platform.
void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;

    const webpRoot = 'third_party/libwebp';
    const webpDirs = [
      'src/dec', // anim_encode uses WebPDecode.
      'src/dsp',
      'src/enc',
      'src/mux',
      'src/utils',
      'sharpyuv',
    ];

    final sources = <String>[
      for (final dir in webpDirs)
        ...Directory.fromUri(input.packageRoot.resolve('$webpRoot/$dir/'))
            .listSync()
            .whereType<File>()
            .map((f) => f.uri.pathSegments.last)
            .where((name) => name.endsWith('.c'))
            .map((name) => '$webpRoot/$dir/$name'),
      'native/peel_webp.c',
    ]..sort();

    final targetOS = input.config.code.targetOS;

    await CBuilder.library(
      name: 'peel_webp',
      assetName: 'sticker_engine/webp_ffi.dart',
      sources: sources,
      includes: [webpRoot],
      defines: const {'WEBP_USE_THREAD': '1'},
      libraries: [if (targetOS == OS.android || targetOS == OS.linux) 'm'],
      // Small and lean: optimise for size, drop unused code, and export
      // only our peel_* functions (halves the library, ~0.27 MB).
      optimizationLevel: OptimizationLevel.oS,
      flags: [
        '-ffunction-sections',
        '-fdata-sections',
        if (targetOS == OS.iOS || targetOS == OS.macOS) ...[
          '-Wl,-dead_strip',
          '-Wl,-exported_symbol,_peel_*',
        ] else if (targetOS == OS.android || targetOS == OS.linux) ...[
          '-Wl,--gc-sections',
          '-Wl,--version-script=${input.packageRoot.resolve('native/peel_webp.map').toFilePath()}',
        ],
      ],
    ).run(input: input, output: output);
  });
}
