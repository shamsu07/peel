import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'app_state.dart';
import 'core/audio.dart';
import 'core/design/theme.dart';
import 'core/design/tokens.dart';
import 'core/error_log.dart';
import 'core/temp_cleanup.dart';
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
    // Let the first screens settle before doing background work.
    await Future<void>.delayed(const Duration(seconds: 2));
    sweepTempFiles().ignore();
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

  /// Gives memory back when Peel goes to the background or the phone is
  /// short of memory, so the system is less likely to close it.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _trimMemory();
  }

  @override
  void didHaveMemoryPressure() => _trimMemory();

  void _trimMemory() {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
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
        scrollBehavior: const PeelScrollBehavior(),
        routerConfig: _router,
      ),
    );
  }
}

/// The same soft bounce at the ends of every list on both platforms, in
/// place of Android's stretch, which distorts the whole screen.
class PeelScrollBehavior extends MaterialScrollBehavior {
  const PeelScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
