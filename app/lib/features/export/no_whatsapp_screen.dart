import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_state.dart';
import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/routing/routes.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/pill_buttons.dart';
import 'sticker_actions.dart';
import 'sticker_image.dart';

/// Shown when WhatsApp isn't installed (canvas: Ready · WhatsApp not
/// installed). The sticker is safe; offer the other ways out.
class NoWhatsAppScreen extends ConsumerWidget {
  const NoWhatsAppScreen({super.key, this.id});

  final String? id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = id == null
        ? null
        : (ref.watch(libraryProvider).value ?? const [])
              .where((r) => r.id == id)
              .firstOrNull;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            PeelSpace.gutter,
            8,
            PeelSpace.gutter,
            20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PeelHeader(),
              const SizedBox(height: 10),
              Text(
                'WhatsApp isn’t on this phone.',
                style: PeelType.title(size: 44),
              ),
              const SizedBox(height: 12),
              Text(
                'Your sticker is saved in Peel. Install WhatsApp from the app '
                'store, then come back and tap Add to WhatsApp.',
                style: PeelType.body(),
              ),
              const SizedBox(height: 20),
              if (record != null)
                Center(child: StickerImage(record, size: 170)),
              const Spacer(),
              if (record != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: SecondaryPillButton(
                        label: 'Save to Photos',
                        leading: const Icon(Icons.download_rounded, size: 18),
                        onPressed: () => saveToPhotos(context, ref, record),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SecondaryPillButton(
                        label: 'Share',
                        leading: const Icon(Icons.ios_share_rounded, size: 18),
                        onPressed: () => shareSticker(ref, record),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              PrimaryPillButton(
                label: 'Back to my stickers',
                onPressed: () => context.go(Routes.home),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
