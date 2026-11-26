import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_state.dart';
import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/pill_buttons.dart';
import '../../sticker_engine/sticker_check.dart';
import '../../whatsapp/pack_models.dart';
import '../../whatsapp/pack_store.dart';

/// Where new stickers go: an existing pack, or a new one ([identifier]
/// null) called [name].
class PackChoice {
  const PackChoice(this.identifier) : name = null;

  const PackChoice.newPack(this.name) : identifier = null;

  final String? identifier;
  final String? name;
}

/// Picked "New pack" in the list; the name is asked next.
const _newPack = PackChoice(null);

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
  if (packs.isNotEmpty) {
    if (!context.mounted) return null;
    final picked = await showPeelSheet<PackChoice>(
      context,
      (_) => _PackSheet(
        packs: packs,
        count: count,
        updatesMakeCopies: exporter.updatesMakeCopies,
      ),
    );
    if (picked == null || !identical(picked, _newPack)) return picked;
  }
  final suggested = await exporter.suggestPackName(kind);
  if (!context.mounted) return null;
  final name = await showPeelSheet<String>(
    context,
    (_) => _NameSheet(suggested: suggested),
  );
  return name == null ? null : PackChoice.newPack(name);
}

/// "Name your pack.": a suggested name, ready to keep or change.
class _NameSheet extends StatefulWidget {
  const _NameSheet({required this.suggested});

  final String suggested;

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  // Starts empty: the suggested name shows as a faint hint and is used
  // if nothing is typed.
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _done() {
    final name = _controller.text.trim();
    Navigator.of(context).pop(name.isEmpty ? widget.suggested : name);
  }

  @override
  Widget build(BuildContext context) {
    return PeelSheet(
      title: 'Name your pack.',
      subtitle: 'Type a name, or keep the one shown.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: PackStore.maxNameLength,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _done(),
            style: PeelType.label().copyWith(fontSize: 18),
            decoration: InputDecoration(
              filled: true,
              fillColor: PeelColors.paper,
              hintText: widget.suggested,
              hintStyle: PeelType.label(
                color: PeelColors.muted.withValues(alpha: 0.55),
              ).copyWith(fontSize: 18),
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                tooltip: 'Clear',
                onPressed: _controller.clear,
                icon: Icon(Icons.cancel_rounded, color: PeelColors.muted),
              ),
            ),
          ),
          const SizedBox(height: 16),
          PrimaryPillButton.whatsApp(
            label: 'Add to WhatsApp',
            leading: const Icon(Icons.send_rounded, size: 20),
            onPressed: _done,
          ),
        ],
      ),
    );
  }
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
                onTap: () => Navigator.of(context).pop(_newPack),
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
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(20),
        ),
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
                  decoration: ShapeDecoration(
                    color: icon == null ? PeelColors.surface : PeelColors.ink,
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
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
                Icon(Icons.chevron_right_rounded, color: PeelColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
