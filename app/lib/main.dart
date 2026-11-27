import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';
import 'core/appearance.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // A sticker app shows many small images: keep the cache modest so the
  // app stays light on 2–3 GB phones.
  PaintingBinding.instance.imageCache
    ..maximumSize = 60
    ..maximumSizeBytes = 32 << 20;
  // Fonts ship inside the app (assets/google_fonts): no download, they
  // work offline, and stickers never get a stand-in font.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(_fontLicenses);
  await loadAppearance();
  runApp(const ProviderScope(child: PeelApp()));
}

Stream<LicenseEntry> _fontLicenses() async* {
  const files = {
    'Inter Tight': 'OFL-InterTight.txt',
    'Titan One': 'OFL-TitanOne.txt',
    'Luckiest Guy': 'LICENSE-LuckiestGuy.txt',
    'Baloo 2': 'OFL-Baloo2.txt',
    'Instrument Serif': 'OFL-InstrumentSerif.txt',
  };
  for (final e in files.entries) {
    final text = await rootBundle.loadString('assets/google_fonts/${e.value}');
    yield LicenseEntryWithLineBreaks([e.key], text);
  }
}
