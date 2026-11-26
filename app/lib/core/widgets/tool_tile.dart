import 'package:material_ui/material_ui.dart';

import '../design/tokens.dart';
import '../design/typography.dart';

/// What a tool's corner badge says about its state.
enum ToolBadge {
  /// Nothing added yet: a plus.
  add,

  /// Already added: a pencil, to change it.
  edit,

  /// No badge (e.g. on/off switches).
  none,
}

/// An editor tool: a white square button with an icon and a label, used
/// for White edge, Text and Sound. The icon, badge and label change with
/// the tool's state ("Add sound" + plus, then "Change sound" + pencil).
class ToolTile extends StatelessWidget {
  const ToolTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
    this.badge = ToolBadge.none,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  /// Draws the ink outline: the tool is on or has something added.
  final bool selected;
  final ToolBadge badge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: badge == ToolBadge.none ? selected : null,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: PeelColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected ? PeelColors.ink : PeelColors.surface,
            width: 2,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 76),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox.square(
                  dimension: 26,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(icon, size: 26),
                      if (badge != ToolBadge.none)
                        Positioned(
                          left: 17,
                          top: -6,
                          child: _Badge(badge: badge),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PeelType.caption(color: PeelColors.ink).copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The corner badge: a white ring with an ink dot inside, drawn as two
/// plain circles so the edge stays crisp.
class _Badge extends StatelessWidget {
  const _Badge({required this.badge});

  final ToolBadge badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        color: PeelColors.surface,
        shape: BoxShape.circle,
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: PeelColors.ink,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            badge == ToolBadge.add ? Icons.add_rounded : Icons.edit_rounded,
            size: badge == ToolBadge.add ? 12 : 8,
            color: PeelColors.surface,
          ),
        ),
      ),
    );
  }
}
