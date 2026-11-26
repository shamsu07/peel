import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'app_state.dart';
import 'core/audio.dart';
import 'core/design/theme.dart';
import 'core/design/tokens.dart';
import 'core/error_log.dart';
import 'core/routing/router.dart';
import 'sticker_engine/sticker_check.dart';

class PeelApp extends ConsumerStatefulWidget {
  const PeelApp({super.key, this.warmUp = true});

  /// Prepares slow one-off work (bonus stickers, the cut-out model) after
  /// the first frame, so the first "Add to WhatsApp" doesn't stall.
  final bool warmUp;

  @override
  ConsumerState<PeelApp> createState() => _PeelAppState();
}

class _PeelAppState extends ConsumerState<PeelApp> with WidgetsBindingObserver {
  late final GoRouter _router = buildRouter();

  bool get _systemDark =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness ==
      Brightness.dark;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PeelColors.dark = _systemDark;
    if (widget.warmUp) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _warmUp());
    }
  }

  Future<void> _warmUp() async {
    try {
      await useSpeakerForPlayback();
      ref.read(nativeProvider).prepareSegmenter();
      final bonus = ref.read(bonusProvider);
      for (final kind in StickerKind.values) {
        await bonus.bonusFor(kind);
      }
    } catch (e, s) {
      await ErrorLog.record('warm up', e, s);
    }
  }

  /// Follows the phone's light/dark setting while the app is open.
  @override
  void didChangePlatformBrightness() {
    if (_systemDark != PeelColors.dark) {
      setState(() => PeelColors.dark = _systemDark);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = PeelColors.dark;
    // Colours are read when widgets build, so a mode change rebuilds the
    // whole app (the key); the router keeps where you were.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: MaterialApp.router(
        key: ValueKey(dark),
        title: 'Peel',
        debugShowCheckedModeBanner: false,
        theme: buildPeelTheme(),
        routerConfig: _router,
      ),
    );
  }
}
