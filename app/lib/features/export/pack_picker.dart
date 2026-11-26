import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_state.dart';
import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/widgets/common.dart';
import '../../sticker_engine/sticker_check.dart';
import '../../whatsapp/pack_models.dart';

/// Where new stickers go: an existing pack, or a new one ([identifier] null).
class PackChoice {
  const PackChoice(this.identifier);

  const PackChoice.newPack() : identifier = null;

  final String? identifier;
}

/// Asks which pack [count] stickers of [kind] should join. Skips the
/// question (new pack) when there's no pack in WhatsApp to join yet.
/// Returns null if the user closes the sheet.
Future<PackChoice?> choosePack(
  BuildContext context,
  WidgetRef ref, {
  required StickerKind kind,
  int count = 1,
}) async {
  final exporter = await ref.read(exporterProvider.future);
  final packs = await exporter.packsToJoin(kind, count: count);
  if (packs.isEmpty) return const PackChoice.newPack();
  if (!context.mounted) return null;
  return showPeelSheet<PackChoice>(
    context,
    (_) => _PackSheet(
      packs: packs,
      count: count,
      updatesMakeCopies: exporter.updatesMakeCopies,
    ),
  );
}

class _PackSheet extends ConsumerWidget {
  const _PackSheet({
    required this.packs,
    required this.count,
    required this.updatesMakeCopies,
  });

  final List<PackEntry> packs;
  final int count;
  final bool updatesMakeCopies;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(packStoreProvider).value;
    final what = count == 1 ? 'this sticker' : 'these $count stickers';
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: PeelSheet(
        title: 'Add to a pack',
        subtitle: 'Put $what in a pack you already have, or start a new one.',
        child: Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
              for (final p in packs)
                _PackRow(
                  title: p.name,
                  detail:
                      '${p.userStickers.length} sticker${p.userStickers.length == 1 ? '' : 's'}',
                  thumbs: [
                    if (store != null)
                      for (final s in p.userStickers.take(4))
                        Image.file(
                          store.stickerFile(p.identifier, s.imageFile),
                          cacheWidth: 120,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const SizedBox(),
                        ),
                  ],
                  onTap: () =>
                      Navigator.of(context).pop(PackChoice(p.identifier)),
                ),
              _PackRow(
                title: 'New pack',
                detail: 'Starts its own pack in WhatsApp',
                icon: Icons.add_rounded,
                onTap: () =>
                    Navigator.of(context).pop(const PackChoice.newPack()),
              ),
              if (updatesMakeCopies) ...[
                const SizedBox(height: 12),
                const PeelNote(
                  text:
                      'On iPhone, WhatsApp can’t add stickers to a pack it '
                      'already has. Picking a pack adds it again with your '
                      'new sticker in it. You can then delete the older copy '
                      'in WhatsApp’s sticker settings.',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PackRow extends StatelessWidget {
  const _PackRow({
    required this.title,
    required this.detail,
    required this.onTap,
    this.thumbs = const [],
    this.icon,
  });

  final String title;
  final String detail;
  final VoidCallback onTap;
  final List<Widget> thumbs;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: PeelColors.paper,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: icon == null ? PeelColors.surface : PeelColors.ink,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: icon != null
                      ? Icon(icon, color: PeelColors.surface, size: 26)
                      : GridView.count(
                          crossAxisCount: 2,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          mainAxisSpacing: 2,
                          crossAxisSpacing: 2,
                          children: thumbs,
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: PeelType.label().copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(detail, style: PeelType.caption()),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: PeelColors.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
