import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'app_state.dart';
import 'core/audio.dart';
import 'core/design/theme.dart';
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

class _PeelAppState extends ConsumerState<PeelApp> {
  late final GoRouter _router = buildRouter();

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Peel',
      debugShowCheckedModeBanner: false,
      theme: buildPeelTheme(),
      routerConfig: _router,
    );
  }
}
