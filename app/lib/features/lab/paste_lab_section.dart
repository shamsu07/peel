import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_state.dart';
import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/widgets/common.dart';
import '../../library/sticker_record.dart';
import '../../sticker_engine/sticker_check.dart';
import '../export/sticker_image.dart';

/// Paste tests: copies a sticker to the clipboard in different forms, to
/// find which ones WhatsApp pastes as a moving sticker or with sound.
/// Copy one, paste it into a WhatsApp chat, and note what arrives.
class PasteLabSection extends ConsumerWidget {
  const PasteLabSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(libraryProvider).value ?? const [];
    final moving = all.where((r) => r.kind == StickerKind.moving).firstOrNull;
    final withSound = all
        .where((r) => r.hasSound && r.handoffVideo != null)
        .firstOrNull;
    final library = ref.watch(libraryStoreProvider).value;

    Future<void> copy(String name, Map<String, String> types) async {
      final ok = await ref.read(nativeProvider).copyFilesToClipboard(types);
      if (context.mounted) {
        showPeelSnack(
          context,
          ok
              ? '$name copied. Paste it into a WhatsApp chat.'
              : 'Couldn’t copy.',
        );
      }
    }

    final tests = <(String, String, StickerRecord?, Map<String, String>)>[];
    if (library != null && moving != null) {
      final webp = library.file(moving.webpFile).path;
      tests.addAll([
        (
          'A',
          'Moving: WebP only',
          moving,
          {'org.webmproject.webp': webp, 'public.webp': webp},
        ),
        ('B', 'Moving: WebP as image', moving, {'public.image': webp}),
        ('C', 'Moving: Google WebP type', moving, {'com.google.webp': webp}),
      ]);
    }
    if (library != null && withSound != null) {
      final webp = library.file(withSound.webpFile).path;
      final mp4 = library.file(withSound.handoffVideo!).path;
      tests.addAll([
        ('D', 'Sound: video only (MP4)', withSound, {'public.mpeg-4': mp4}),
        (
          'E',
          'Sound: sticker + video',
          withSound,
          {
            'org.webmproject.webp': webp,
            'public.webp': webp,
            'public.mpeg-4': mp4,
          },
        ),
        ('F', 'Sound: video as movie', withSound, {'public.movie': mp4}),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Paste tests', style: PeelType.title(size: 28)),
        const SizedBox(height: 6),
        Text(
          'Copy one, paste it into a WhatsApp chat, and note what arrives '
          '(moving sticker, still sticker, video, nothing).',
          style: PeelType.caption(),
        ),
        const SizedBox(height: 12),
        if (tests.isEmpty)
          Text(
            'Make a moving sticker and one with sound first.',
            style: PeelType.body(),
          ),
        for (final (id, name, record, types) in tests)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: PeelColors.surface,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => copy('Test $id', types),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: PeelColors.ink,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          id,
                          style: PeelType.label(color: PeelColors.surface),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          name,
                          style: PeelType.label().copyWith(fontSize: 15),
                        ),
                      ),
                      if (record != null) StickerImage(record, size: 40),
                      const SizedBox(width: 6),
                      Icon(Icons.content_copy_rounded, color: PeelColors.muted),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
