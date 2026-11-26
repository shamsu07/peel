import 'package:material_ui/material_ui.dart';

import '../design/tokens.dart';
import '../design/typography.dart';

class SegmentOption<T> {
  const SegmentOption(this.value, this.label);

  final T value;
  final String label;
}

/// Grey track with a white raised segment, e.g. "Cut-out | Whole photo" or
/// "Original | New sound | Mute".
class PeelSegmented<T> extends StatelessWidget {
  const PeelSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.semanticLabel,
  });

  final List<SegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: PeelColors.track,
          borderRadius: BorderRadius.circular(PeelRadii.control),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              for (final option in options)
                Expanded(child: _segment(option, option.value == selected)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _segment(SegmentOption<T> option, bool isSelected) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: isSelected,
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isSelected ? PeelColors.surface : const Color(0x00FFFFFF),
          borderRadius: BorderRadius.circular(PeelRadii.segment),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x1A111113),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ]
              : const [],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(PeelRadii.segment),
            onTap: isSelected ? null : () => onChanged(option.value),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: PeelSpace.minTouch),
              child: Center(
                child: Text(
                  option.label,
                  textAlign: TextAlign.center,
                  style:
                      PeelType.button(
                        color: isSelected
                            ? PeelColors.ink
                            : PeelColors.mutedStrong,
                      ).copyWith(
                        fontSize: 15,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
